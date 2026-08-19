import { and, desc, eq, gte, lt, sql } from 'drizzle-orm';
import { db } from '../../db/client.js';
import { budgets, rawTransactions, userCategoryRules, spendingCategoryEnum } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import { matchKeyFor } from './categorize.js';

type SpendCategory = (typeof spendingCategoryEnum.enumValues)[number];

export const SPEND_CATEGORIES = spendingCategoryEnum.enumValues;

/**
 * Nigeria runs on WAT (UTC+1) year round, with no daylight saving, and every
 * user of this app is spending naira in that timezone. Month boundaries are
 * therefore computed at +01:00 rather than in UTC: a charge at half past
 * midnight on the 1st is 23:30 UTC on the last of the previous month, and
 * bucketing that into last month's spend would be wrong on exactly the days
 * people are most likely to check.
 */
const WAT_OFFSET_HOURS = 1;

/** `YYYY-MM` for the current WAT month. */
export function currentPeriod(now = new Date()): string {
  const wat = new Date(now.getTime() + WAT_OFFSET_HOURS * 60 * 60 * 1000);
  return `${wat.getUTCFullYear()}-${String(wat.getUTCMonth() + 1).padStart(2, '0')}`;
}

/** Half-open [start, end) UTC instants bounding a `YYYY-MM` WAT month. */
export function periodRange(period: string): { start: Date; end: Date } {
  const match = /^(\d{4})-(\d{2})$/.exec(period);
  if (!match) throw AppError.badRequest('Period must look like 2026-08', 'BAD_PERIOD');
  const year = Number(match[1]);
  const month = Number(match[2]);
  if (month < 1 || month > 12) throw AppError.badRequest('Period month must be 01-12', 'BAD_PERIOD');

  const start = new Date(Date.UTC(year, month - 1, 1, 0 - WAT_OFFSET_HOURS, 0, 0));
  const end = new Date(Date.UTC(year, month, 1, 0 - WAT_OFFSET_HOURS, 0, 0));
  return { start, end };
}

/** Enum values travel lowercase on the wire, matching the subscriptions module and the Dart enums. */
function toWire(category: SpendCategory): string {
  return category.toLowerCase();
}

export function fromWire(value: string): SpendCategory {
  const upper = value.toUpperCase() as SpendCategory;
  if (!SPEND_CATEGORIES.includes(upper)) {
    throw AppError.badRequest(`Unknown category "${value}"`, 'BAD_CATEGORY');
  }
  return upper;
}

export interface CategorySpend {
  category: string;
  spent: number;
  transactionCount: number;
  monthlyLimit: number | null;
}

/**
 * This month's spend, per category, against whatever budgets exist.
 *
 * Only DEBIT rows count. Credits are income, and folding them in would make
 * the headline number mean nothing. Rows the categorizer has not reached yet
 * are reported separately in `uncategorizedCount` rather than being counted
 * as OTHER, so "we have not looked at these yet" never renders as
 * "miscellaneous spending".
 */
export async function getSpendingSummary(userId: string, period: string) {
  const { start, end } = periodRange(period);

  const [rows, budgetRows] = await Promise.all([
    db
      .select({
        category: rawTransactions.spendCategory,
        spent: sql<string>`sum(${rawTransactions.amount})`,
        count: sql<number>`count(*)::int`,
      })
      .from(rawTransactions)
      .where(
        and(
          eq(rawTransactions.userId, userId),
          eq(rawTransactions.type, 'DEBIT'),
          gte(rawTransactions.date, start),
          lt(rawTransactions.date, end),
        ),
      )
      .groupBy(rawTransactions.spendCategory),
    db.select().from(budgets).where(eq(budgets.userId, userId)),
  ]);

  const limitByCategory = new Map(budgetRows.map((b) => [b.category, Number(b.monthlyLimit)]));

  let total = 0;
  let uncategorizedCount = 0;
  const spendByCategory = new Map<SpendCategory, { spent: number; count: number }>();

  for (const row of rows) {
    const spent = Number(row.spent ?? 0);
    total += spent;
    if (row.category === null) {
      uncategorizedCount += row.count;
      continue;
    }
    spendByCategory.set(row.category, { spent, count: row.count });
  }

  // Every category with either spend or a budget is returned, so the client
  // can render a budget the user set but has not spent against yet. Sorted by
  // spend descending because the UI leads with "where the money went".
  const categories: CategorySpend[] = SPEND_CATEGORIES.filter(
    (category) => spendByCategory.has(category) || limitByCategory.has(category),
  )
    .map((category) => ({
      category: toWire(category),
      spent: spendByCategory.get(category)?.spent ?? 0,
      transactionCount: spendByCategory.get(category)?.count ?? 0,
      monthlyLimit: limitByCategory.get(category) ?? null,
    }))
    .sort((a, b) => b.spent - a.spent);

  // Folded into the summary rather than served from its own endpoint: the
  // screen that wants the breakdown always wants the trend beside it, and two
  // round trips to draw one card is a worse trade than one slightly wider
  // response.
  const trend = await getSpendingTrend(userId);

  return { period, total, uncategorizedCount, categories, trend };
}

export interface TrendPoint {
  period: string;
  total: number;
}

/**
 * Monthly debit totals for the last [months] periods, oldest first.
 *
 * Bucketed with `AT TIME ZONE 'Africa/Lagos'` rather than the fixed +1 offset
 * `periodRange` uses. Both are correct for Nigeria, which has no daylight
 * saving, but letting Postgres name the zone keeps the grouping honest if this
 * ever serves a second country, and does the bucketing in one pass rather than
 * one query per month.
 *
 * Months with no debits are filled in at zero rather than omitted. A bar chart
 * that silently skips an empty month draws a misleading series: the gap
 * disappears and two non-adjacent months end up side by side.
 */
export async function getSpendingTrend(userId: string, months = 6): Promise<TrendPoint[]> {
  const span = Math.min(Math.max(months, 1), 24);

  // Start from the first day of the earliest period we want, in WAT.
  const now = new Date();
  const watNow = new Date(now.getTime() + WAT_OFFSET_HOURS * 60 * 60 * 1000);
  const firstPeriod = new Date(Date.UTC(watNow.getUTCFullYear(), watNow.getUTCMonth() - (span - 1), 1));
  const { start } = periodRange(
    `${firstPeriod.getUTCFullYear()}-${String(firstPeriod.getUTCMonth() + 1).padStart(2, '0')}`,
  );

  const rows = await db
    .select({
      period: sql<string>`to_char(date_trunc('month', ${rawTransactions.date} AT TIME ZONE 'Africa/Lagos'), 'YYYY-MM')`,
      total: sql<string>`sum(${rawTransactions.amount})`,
    })
    .from(rawTransactions)
    .where(
      and(
        eq(rawTransactions.userId, userId),
        eq(rawTransactions.type, 'DEBIT'),
        gte(rawTransactions.date, start),
      ),
    )
    .groupBy(sql`1`)
    .orderBy(sql`1`);

  const byPeriod = new Map(rows.map((r) => [r.period, Number(r.total ?? 0)]));

  const out: TrendPoint[] = [];
  for (let i = span - 1; i >= 0; i--) {
    const d = new Date(Date.UTC(watNow.getUTCFullYear(), watNow.getUTCMonth() - i, 1));
    const period = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
    out.push({ period, total: byPeriod.get(period) ?? 0 });
  }
  return out;
}

export async function listTransactions(
  userId: string,
  // Explicit `| undefined` rather than bare optionals: this project runs
  // `exactOptionalPropertyTypes`, so "may be absent" and "may be undefined"
  // are different types and the route passes the latter.
  options: { period: string; category?: string | undefined; limit?: number | undefined },
) {
  const { start, end } = periodRange(options.period);
  const limit = Math.min(Math.max(options.limit ?? 100, 1), 200);

  const rows = await db
    .select({
      id: rawTransactions.id,
      narration: rawTransactions.narration,
      payee: rawTransactions.payee,
      amount: rawTransactions.amount,
      date: rawTransactions.date,
      category: rawTransactions.spendCategory,
      categorySource: rawTransactions.categorySource,
    })
    .from(rawTransactions)
    .where(
      and(
        eq(rawTransactions.userId, userId),
        eq(rawTransactions.type, 'DEBIT'),
        gte(rawTransactions.date, start),
        lt(rawTransactions.date, end),
        options.category ? eq(rawTransactions.spendCategory, fromWire(options.category)) : undefined,
      ),
    )
    .orderBy(desc(rawTransactions.date))
    .limit(limit);

  return rows.map((row) => ({
    id: row.id,
    narration: row.narration,
    payee: row.payee,
    amount: Number(row.amount),
    date: row.date.toISOString(),
    category: row.category ? toWire(row.category) : null,
    categorySource: row.categorySource ? row.categorySource.toLowerCase() : null,
  }));
}

/**
 * Recategorises one transaction, and optionally turns that correction into a
 * standing rule for the merchant behind it.
 *
 * The rule is what makes this worth building: correcting a single Netflix
 * charge is admin, correcting every future Netflix charge is a feature. The
 * write is marked USER so the categorizer will never overwrite it on a later
 * sync, and the rule is upserted on (userId, matchKey) so changing your mind
 * about a merchant replaces the old rule rather than stacking a second one.
 */
export async function recategorizeTransaction(
  userId: string,
  transactionId: string,
  categoryWire: string,
  applyToFuture: boolean,
) {
  const category = fromWire(categoryWire);

  const [txn] = await db
    .select()
    .from(rawTransactions)
    .where(and(eq(rawTransactions.id, transactionId), eq(rawTransactions.userId, userId)))
    .limit(1);
  if (!txn) throw AppError.notFound('Transaction not found');

  await db
    .update(rawTransactions)
    .set({ spendCategory: category, categorySource: 'USER' })
    .where(eq(rawTransactions.id, txn.id));

  let appliedTo = 1;

  if (applyToFuture) {
    const matchKey = matchKeyFor(txn.narration);
    if (matchKey) {
      await db
        .insert(userCategoryRules)
        .values({ userId, matchKey, category })
        .onConflictDoUpdate({
          target: [userCategoryRules.userId, userCategoryRules.matchKey],
          set: { category, updatedAt: new Date() },
        });

      // Apply to everything already on file that the rule matches, so the
      // breakdown updates immediately rather than only for charges that have
      // not happened yet. Rows the user corrected by hand are left alone:
      // this rule is newer, but a per-transaction correction is more specific
      // than a merchant-wide one and should win.
      const result = await db
        .update(rawTransactions)
        .set({ spendCategory: category, categorySource: 'USER' })
        .where(
          and(
            eq(rawTransactions.userId, userId),
            sql`${rawTransactions.categorySource} IS DISTINCT FROM 'USER'`,
            sql`${rawTransactions.payee} = ${txn.payee}`,
          ),
        )
        .returning({ id: rawTransactions.id });
      appliedTo += result.length;
    }
  }

  return { appliedTo };
}

// ------------------------------------------------------------------ budgets

export async function listBudgets(userId: string) {
  const rows = await db.select().from(budgets).where(eq(budgets.userId, userId));
  return rows.map((row) => ({
    category: toWire(row.category),
    monthlyLimit: Number(row.monthlyLimit),
  }));
}

export async function setBudget(userId: string, categoryWire: string, monthlyLimit: number) {
  const category = fromWire(categoryWire);
  const [row] = await db
    .insert(budgets)
    .values({ userId, category, monthlyLimit: monthlyLimit.toFixed(2) })
    .onConflictDoUpdate({
      target: [budgets.userId, budgets.category],
      set: {
        monthlyLimit: monthlyLimit.toFixed(2),
        updatedAt: new Date(),
        // Changing the limit resets this period's alert flags. Raising a cap
        // after blowing through it should not leave the user unable to be
        // warned again at the new number.
        notifiedAt80: null,
        notifiedAt100: null,
      },
    })
    .returning();
  if (!row) throw AppError.badRequest('Could not save that budget');
  return { category: toWire(row.category), monthlyLimit: Number(row.monthlyLimit) };
}

export async function deleteBudget(userId: string, categoryWire: string) {
  const category = fromWire(categoryWire);
  await db.delete(budgets).where(and(eq(budgets.userId, userId), eq(budgets.category, category)));
}
