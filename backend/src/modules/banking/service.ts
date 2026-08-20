import { randomUUID } from 'node:crypto';
import { eq, and } from 'drizzle-orm';
import { db } from '../../db/client.js';
import { linkedBanks, users } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import { env } from '../../config/env.js';
import { encryptSecret } from '../../lib/encryption.js';
import { initiateAccountLinking, unlinkMonoAccount } from '../../lib/mono.js';
import { syncLinkedBank } from './sync.js';
import { runDetectionForUser } from '../detection/service.js';
import { categorizeTransactionsForUser } from '../spending/categorize.js';

function maskAccountNumber(accountNumber: string): string {
  const last4 = accountNumber.slice(-4);
  return `••••${last4}`;
}

/**
 * Kicks off a bank link via Mono's Connect Link flow: asks Mono for a
 * hosted linking URL, which the client opens in a webview. Nothing is
 * written to `linked_banks` here — there's no account id yet, only a
 * `ref` that lets the `account_connected` webhook correlate the eventual
 * result back to this user once they finish.
 *
 * `ref` must be unique per *attempt*, not per user — Mono rejects
 * `/v2/accounts/initiate` with "The provided ref already exists" if you
 * reuse one (e.g. the user backs out and retries, or links a second bank
 * later). It used to just be the user's id, which broke on the very next
 * attempt. Embedding the id alongside a fresh UUID keeps both properties:
 * unique per call, and still parseable back to a user in
 * handleAccountConnected below without needing a lookup table.
 */
export async function initiateLink(userId: string) {
  const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!user) throw AppError.notFound('User not found');

  // No display-name field is collected at signup — the email's local part
  // is a reasonable stand-in for what Mono's `customer.name` requires.
  const customerName = user.email.split('@')[0] ?? user.email;

  const monoUrl = await initiateAccountLinking({
    customerName,
    customerEmail: user.email,
    ref: `${userId}:${randomUUID()}`,
    redirectUrl: env.MONO_REDIRECT_URL,
  });

  // Returned alongside monoUrl so the client watches for the exact same
  // URL the server told Mono to redirect to — one source of truth instead
  // of the redirect URL being configured twice and risking drift.
  return { monoUrl, redirectUrl: env.MONO_REDIRECT_URL };
}

export async function listLinkedBanks(userId: string) {
  return db.select().from(linkedBanks).where(eq(linkedBanks.userId, userId));
}

export async function unlinkBank(userId: string, linkedBankId: string) {
  const [bank] = await db
    .select()
    .from(linkedBanks)
    .where(and(eq(linkedBanks.id, linkedBankId), eq(linkedBanks.userId, userId)))
    .limit(1);
  if (!bank) throw AppError.notFound('Linked bank not found');

  try {
    await unlinkMonoAccount(bank.providerAccountId);
  } catch (error) {
    // Best-effort — if Mono's side fails we still want the user's app to
    // reflect "unlinked" rather than get stuck; a stale Mono-side link
    // with no local record of it is a lesser problem than a stuck UI.
    console.error(`Mono unlink failed for account ${bank.providerAccountId}:`, error);
  }

  const [updated] = await db
    .update(linkedBanks)
    .set({ status: 'REVOKED' })
    .where(eq(linkedBanks.id, linkedBankId))
    .returning();
  return updated;
}

/** Manual "sync now" entry point, e.g. a pull-to-refresh in the app. */
export async function syncNow(userId: string, linkedBankId: string) {
  const [bank] = await db
    .select()
    .from(linkedBanks)
    .where(and(eq(linkedBanks.id, linkedBankId), eq(linkedBanks.userId, userId), eq(linkedBanks.status, 'ACTIVE')))
    .limit(1);
  if (!bank) throw AppError.notFound('Linked bank not found');

  const result = await syncLinkedBank(bank);
  // Categorization and detection both read the rows sync just wrote, and
  // neither reads the other's output, so ordering between them is arbitrary.
  await Promise.all([categorizeTransactionsForUser(userId), runDetectionForUser(userId)]);
  return result;
}

// ---------------------------------------------------------------- webhooks

/**
 * First point where a linked account actually becomes known to us. `ref`
 * is whatever we passed as `meta.ref` on the initiate call — `userId:uuid`
 * (see initiateLink above) — so this is the join between "a user asked to
 * link a bank" and "Mono says a bank got linked."
 */
export async function handleAccountConnected(monoAccountId: string, ref: string) {
  const [existing] = await db.select().from(linkedBanks).where(eq(linkedBanks.providerAccountId, monoAccountId)).limit(1);
  if (existing) {
    // Re-linking the same account (retry after an earlier failed attempt)
    // — reactivate rather than create a duplicate row.
    await db.update(linkedBanks).set({ status: 'ACTIVE' }).where(eq(linkedBanks.id, existing.id));
    return;
  }

  // Split off just the userId prefix — falls back to the whole ref for any
  // pending link created before this format changed.
  const userId = ref.includes(':') ? ref.slice(0, ref.indexOf(':')) : ref;
  const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!user) {
    console.warn(`account_connected webhook with ref "${ref}" doesn't match any user`);
    return;
  }

  await db.insert(linkedBanks).values({
    userId: user.id,
    provider: 'mono',
    bankName: 'Syncing…',
    bankCode: '',
    accountNumberMask: '',
    providerAccountId: monoAccountId,
    // Encrypted at rest even though it's just a copy of monoAccountId
    // today (see the comment on providerToken in db/schema.ts) — the
    // moment this holds a real provider secret instead, nothing here
    // needs to change. Decrypt with decryptSecret() from lib/encryption.
    providerToken: encryptSecret(monoAccountId),
    status: 'ACTIVE',
  });
}

export async function handleAccountUpdated(monoAccountId: string, institution: {
  name: string;
  bankCode: string;
  accountNumber: string;
} | null, dataStatus: string) {
  const [bank] = await db
    .select()
    .from(linkedBanks)
    .where(eq(linkedBanks.providerAccountId, monoAccountId))
    .limit(1);
  if (!bank) {
    console.warn(`account_updated webhook for unknown Mono account ${monoAccountId}`);
    return;
  }

  if (institution) {
    await db
      .update(linkedBanks)
      .set({
        bankName: institution.name,
        bankCode: institution.bankCode,
        accountNumberMask: maskAccountNumber(institution.accountNumber),
        lastSyncedAt: new Date(),
      })
      .where(eq(linkedBanks.id, bank.id));
  }

  // Only pull transactions once Mono confirms the data is actually ready —
  // calling the Transactions endpoint while data_status is PROCESSING
  // would just return an incomplete/empty set.
  if (dataStatus === 'AVAILABLE') {
    await syncLinkedBank(bank);
    await Promise.all([categorizeTransactionsForUser(bank.userId), runDetectionForUser(bank.userId)]);
  }
}

export async function handleAccountUnlinked(monoAccountId: string) {
  await db.update(linkedBanks).set({ status: 'REVOKED' }).where(eq(linkedBanks.providerAccountId, monoAccountId));
}
