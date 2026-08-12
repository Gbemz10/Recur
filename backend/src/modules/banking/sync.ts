import { eq } from 'drizzle-orm';
import { db } from '../../db/client.js';
import { rawTransactions, linkedBanks } from '../../db/schema.js';
import { fetchMonoTransactions } from '../../lib/mono.js';

type LinkedBank = typeof linkedBanks.$inferSelect;

// Caps a single sync at ~2,000 transactions. Recurring-charge detection
// only needs a handful of months of history to establish a pattern, so
// this is generous headroom rather than a real limit on how much data
// gets pulled — it exists purely so a pathological account can't turn one
// webhook into an unbounded fetch loop.
const MAX_PAGES = 20;

/**
 * Pulls transaction history for a linked bank from Mono and upserts it
 * into `raw_transactions`, keyed on Mono's own transaction id so re-syncing
 * overlapping pages (or re-running after a webhook retry) never
 * double-inserts.
 */
export async function syncLinkedBank(bank: LinkedBank) {
  let page = 1;
  let hasNext = true;
  let inserted = 0;

  while (hasNext && page <= MAX_PAGES) {
    const { transactions, hasNext: next } = await fetchMonoTransactions(bank.providerAccountId, page);
    if (transactions.length === 0) break;

    const rows = transactions.map((txn) => ({
      linkedBankId: bank.id,
      userId: bank.userId,
      monoTransactionId: txn.id,
      narration: txn.narration,
      // Mono returns amounts in kobo (lowest denomination); the rest of
      // the app works in naira, same convention as the numeric columns
      // for subscriptions/charge_records.
      amount: (txn.amount / 100).toFixed(2),
      type: txn.type.toUpperCase() as 'DEBIT' | 'CREDIT',
      category: txn.category || null,
      date: new Date(txn.date),
    }));

    const result = await db
      .insert(rawTransactions)
      .values(rows)
      .onConflictDoNothing({ target: [rawTransactions.linkedBankId, rawTransactions.monoTransactionId] })
      .returning({ id: rawTransactions.id });
    inserted += result.length;

    hasNext = next;
    page += 1;
  }

  await db.update(linkedBanks).set({ lastSyncedAt: new Date() }).where(eq(linkedBanks.id, bank.id));

  return { pagesFetched: page - 1, transactionsInserted: inserted };
}
