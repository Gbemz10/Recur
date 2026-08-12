/**
 * Seeds realistic Nigerian subscription-shaped raw transactions for a real
 * user's real linked bank, then runs the detection engine over them.
 *
 * Why this exists: Mono's sandbox test banks return sample transaction data
 * (see docs.mono.co/docs/sandbox), but what's in that sample set varies by
 * which test bank/scenario you pick, and there's no guarantee it contains
 * anything that actually looks like a recurring subscription debit — a
 * single P2P transfer narration, for instance, will never produce a
 * subscription card, because the detection engine (src/modules/detection/
 * service.ts) requires at least two DEBIT transactions with a matching
 * narration/amount pattern before it'll classify anything as recurring.
 * That's correct behavior, not a bug — it just means sandbox data alone
 * can't demonstrate the feature.
 *
 * This script inserts directly into `raw_transactions` — the same table
 * Mono syncs land in — for whichever bank the given user has actually
 * linked, so the rest of the pipeline (detection, dashboard, subscription
 * cards, real merchant logos) runs exactly as it would against real bank
 * data. It does NOT touch Mono at all; this is purely local test data.
 *
 * Usage:
 *   npm run db:seed-transactions -- you@example.com
 */
import { randomUUID } from 'node:crypto';
import { eq, and } from 'drizzle-orm';
import { db, pool } from './client.js';
import { users, linkedBanks, rawTransactions } from './schema.js';
import { runDetectionForUser } from '../modules/detection/service.js';

function monthsAgo(months: number, day = 14): Date {
  const d = new Date();
  d.setMonth(d.getMonth() - months, day);
  return d;
}

// Narrations mirror what Nigerian bank statements actually look like for
// these merchants — the detection engine's merchant matcher looks for the
// domain/slug/name keyword inside the raw narration, same as it would
// against a real Mono transaction.
const recurringSeeds = [
  { narration: 'NETFLIX.COM NGN CARD DEBIT', amount: 7000, months: 5 },
  { narration: 'MULTICHOICE NIG DSTV SUB', amount: 19000, months: 4 },
  { narration: 'SPOTIFY P17A9C NGN', amount: 1300, months: 6 },
  { narration: 'MTNNG DATA AUTORENEW', amount: 10000, months: 3 },
  { narration: 'OPENAI *CHATGPT USD', amount: 32000, months: 4 },
  { narration: 'SHOWMAX NG RECURRING', amount: 3500, months: 3 },
];

// A few one-off, non-recurring debits so the seeded data doesn't look
// artificially clean — these should NOT produce subscription cards.
const noiseSeeds = [
  { narration: 'NIP TRANSFER OLAMIDE KUDA', amount: 15000, monthsAgoValue: 0 },
  { narration: 'POS PURCHASE SHOPRITE LEKKI', amount: 24500, monthsAgoValue: 1 },
  { narration: 'NIP TRANSFER JOHN GTB', amount: 8000, monthsAgoValue: 2 },
];

async function main() {
  const email = process.argv[2];
  if (!email) {
    console.error('Usage: npm run db:seed-transactions -- you@example.com');
    process.exitCode = 1;
    return;
  }

  const [user] = await db.select().from(users).where(eq(users.email, email)).limit(1);
  if (!user) throw new Error(`No user found for ${email}`);

  const [bank] = await db
    .select()
    .from(linkedBanks)
    .where(and(eq(linkedBanks.userId, user.id), eq(linkedBanks.status, 'ACTIVE')))
    .limit(1);
  if (!bank) throw new Error(`${email} has no ACTIVE linked bank — link one in the app first`);

  console.log(`Seeding transactions for ${email} against linked bank ${bank.id}...`);

  const rows: (typeof rawTransactions.$inferInsert)[] = [];

  for (const seed of recurringSeeds) {
    for (let i = 0; i < seed.months; i++) {
      rows.push({
        linkedBankId: bank.id,
        userId: user.id,
        monoTransactionId: `seed_${randomUUID()}`,
        narration: seed.narration,
        amount: seed.amount.toFixed(2),
        type: 'DEBIT',
        date: monthsAgo(i),
      });
    }
  }

  for (const seed of noiseSeeds) {
    rows.push({
      linkedBankId: bank.id,
      userId: user.id,
      monoTransactionId: `seed_${randomUUID()}`,
      narration: seed.narration,
      amount: seed.amount.toFixed(2),
      type: 'DEBIT',
      date: monthsAgo(seed.monthsAgoValue),
    });
  }

  await db.insert(rawTransactions).values(rows);
  console.log(`Inserted ${rows.length} raw transactions.`);

  console.log('Running detection...');
  const result = await runDetectionForUser(user.id);
  console.log(`Detection found ${result.clustersFound} recurring clusters. Check the dashboard now.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
