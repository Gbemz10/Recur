import { and, eq, inArray } from 'drizzle-orm';
import { db } from '../../db/client.js';
import { rawTransactions, merchants, subscriptions, chargeRecords } from '../../db/schema.js';

type Merchant = typeof merchants.$inferSelect;
type Cycle = 'WEEKLY' | 'MONTHLY' | 'QUARTERLY' | 'YEARLY';

interface Txn {
  id: string;
  narration: string;
  amount: number;
  date: Date;
}

// Median-interval bands (in days) a cluster's charges have to fall into to
// be classified as that cycle. Wide enough to absorb bank-processing jitter
// (a "monthly" charge landing anywhere from the 24th to the 36th day is
// still monthly) without WEEKLY and MONTHLY bands overlapping.
const CYCLE_DAY_BANDS: [Cycle, number, number][] = [
  ['WEEKLY', 5, 10],
  ['MONTHLY', 24, 36],
  ['QUARTERLY', 80, 100],
  ['YEARLY', 335, 395],
];
const CYCLE_DAYS: Record<Cycle, number> = { WEEKLY: 7, MONTHLY: 30, QUARTERLY: 91, YEARLY: 365 };

// Need at least two occurrences to establish any periodicity at all — a
// single transaction carries no signal about whether it repeats.
const MIN_OCCURRENCES = 2;

function normalizeNarration(raw: string): string {
  return raw
    .toUpperCase()
    .replace(/\d{4,}/g, '') // strip long digit runs — references, phone numbers, account numbers
    .replace(/[^A-Z\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function titleCase(text: string): string {
  return text
    .toLowerCase()
    .split(' ')
    .filter(Boolean)
    .map((word) => word[0]!.toUpperCase() + word.slice(1))
    .join(' ');
}

/** Matches a narration against the curated merchant table by domain/slug/name keyword. */
function matchMerchant(narration: string, merchantList: Merchant[]): Merchant | null {
  const upper = narration.toUpperCase();
  for (const merchant of merchantList) {
    const domainKeyword = merchant.domain.split('.')[0]?.toUpperCase();
    const slugKeyword = merchant.slug.replace(/_/g, ' ').toUpperCase();
    if (
      (domainKeyword && domainKeyword.length > 2 && upper.includes(domainKeyword)) ||
      upper.includes(slugKeyword) ||
      upper.includes(merchant.name.toUpperCase())
    ) {
      return merchant;
    }
  }
  return null;
}

function median(nums: number[]): number {
  const sorted = [...nums].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1 ? sorted[mid]! : (sorted[mid - 1]! + sorted[mid]!) / 2;
}

/**
 * Splits a narration/merchant group into amount-consistent clusters —
 * "NETFLIX ₦2,800" and "NETFLIX ₦7,000" are different subscriptions (or a
 * plan change) even if the narration matches, so they shouldn't merge into
 * one noisy signal.
 */
function clusterByAmount(txns: Txn[]): Txn[][] {
  const sorted = [...txns].sort((a, b) => a.amount - b.amount);
  const clusters: Txn[][] = [];
  let current: Txn[] = [];
  for (const txn of sorted) {
    const last = current[current.length - 1];
    if (last && Math.abs(txn.amount - last.amount) > Math.max(300, last.amount * 0.12)) {
      clusters.push(current);
      current = [];
    }
    current.push(txn);
  }
  if (current.length) clusters.push(current);
  return clusters;
}

function classifyCycle(sortedDates: Date[]): { cycle: Cycle; regularity: number } | null {
  if (sortedDates.length < MIN_OCCURRENCES) return null;
  const deltas: number[] = [];
  for (let i = 1; i < sortedDates.length; i++) {
    const days = (sortedDates[i]!.getTime() - sortedDates[i - 1]!.getTime()) / (1000 * 60 * 60 * 24);
    deltas.push(days);
  }
  const med = median(deltas);
  const band = CYCLE_DAY_BANDS.find(([, lo, hi]) => med >= lo && med <= hi);
  if (!band) return null;
  const avgAbsDeviation = deltas.reduce((sum, d) => sum + Math.abs(d - med), 0) / deltas.length;
  const regularity = Math.max(0, Math.min(1, 1 - avgAbsDeviation / med));
  return { cycle: band[0], regularity };
}

/**
 * 0.3–0.99. Weighted toward interval regularity and occurrence count, with
 * a bonus for hitting the curated merchant table — a narration match on
 * "NETFLIX" is a much stronger signal than three same-amount charges from
 * an unrecognized narration.
 */
function computeConfidence(occurrences: number, regularity: number, merchantMatched: boolean): number {
  const occurrenceScore = Math.min(1, (occurrences - 1) / 4);
  const confidence = 0.35 + occurrenceScore * 0.3 + regularity * 0.25 + (merchantMatched ? 0.1 : 0);
  return Math.min(0.99, Math.max(0.3, Number(confidence.toFixed(2))));
}

function projectNextChargeDate(lastDate: Date, cycle: Cycle): Date {
  const days = CYCLE_DAYS[cycle];
  let next = new Date(lastDate.getTime());
  const now = new Date();
  while (next.getTime() <= now.getTime()) {
    next = new Date(next.getTime() + days * 24 * 60 * 60 * 1000);
  }
  return next;
}

// --------------------------------------------------------- plan-change chains

// A single amount-consistent, cycle-classified run of charges — the output
// of clusterByAmount + classifyCycle for one price tier.
interface AmountCluster {
  txns: Txn[];
  cycle: Cycle;
  regularity: number;
  amountBucket: number;
  medianAmount: number;
  firstDate: Date;
  lastDate: Date;
}

function buildAmountClusters(txns: Txn[]): AmountCluster[] {
  const clusters: AmountCluster[] = [];
  for (const cluster of clusterByAmount(txns)) {
    if (cluster.length < MIN_OCCURRENCES) continue;
    const sorted = [...cluster].sort((a, b) => a.date.getTime() - b.date.getTime());
    const classification = classifyCycle(sorted.map((t) => t.date));
    if (!classification) continue;
    const medianAmount = median(sorted.map((t) => t.amount));
    clusters.push({
      txns: sorted,
      cycle: classification.cycle,
      regularity: classification.regularity,
      amountBucket: Math.round(medianAmount / 100) * 100,
      medianAmount,
      firstDate: sorted[0]!.date,
      lastDate: sorted[sorted.length - 1]!.date,
    });
  }
  return clusters;
}

// A "chain" is one or more amount clusters strung together over time —
// the full price history of a single subscription. A plan change (e.g.
// Spotify Individual ₦1,900 → Family ₦2,500) shows up as two amount
// clusters that are otherwise identical in every way that matters: same
// merchant/narration group, same billing cycle, and the second one starts
// only after the first one stops. That's the signal used to merge them
// into one chain instead of treating the price change as a brand new
// subscription. Clusters that overlap in time, or that never abut within
// a few cycles of each other, are left unmerged — that's what a genuinely
// separate, concurrent same-merchant subscription looks like.
interface Chain {
  segments: AmountCluster[]; // chronological, earliest first
}

function buildChains(clusters: AmountCluster[]): Chain[] {
  const sorted = [...clusters].sort((a, b) => a.firstDate.getTime() - b.firstDate.getTime());
  const chains: Chain[] = [];
  for (const cluster of sorted) {
    const maxGapMs = CYCLE_DAYS[cluster.cycle] * 3 * 24 * 60 * 60 * 1000;
    const target = chains.find((chain) => {
      const last = chain.segments[chain.segments.length - 1]!;
      return (
        last.cycle === cluster.cycle &&
        last.lastDate.getTime() < cluster.firstDate.getTime() &&
        cluster.firstDate.getTime() - last.lastDate.getTime() <= maxGapMs
      );
    });
    if (target) {
      target.segments.push(cluster);
    } else {
      chains.push({ segments: [cluster] });
    }
  }
  return chains;
}

/**
 * Scans a user's raw transaction history for recurring debit patterns and
 * upserts the result into `subscriptions` + `charge_records`, keyed by a
 * stable `detectionKey` so re-running this after every sync updates the
 * same rows instead of creating duplicates.
 *
 * Deliberately conservative about touching subscriptions a user has
 * already made a call on: CANCELLED rows are left alone entirely (a new
 * matching transaction doesn't un-cancel something the user turned off),
 * and everything newly detected lands as UNREVIEWED regardless of
 * confidence — this engine surfaces candidates, it doesn't unilaterally
 * decide something is a confirmed bill.
 */
export async function runDetectionForUser(userId: string) {
  const [transactions, merchantList] = await Promise.all([
    db.query.rawTransactions.findMany({ where: and(eq(rawTransactions.userId, userId), eq(rawTransactions.type, 'DEBIT')) }),
    db.select().from(merchants),
  ]);
  if (transactions.length === 0) return { clustersFound: 0 };

  // Group by matched merchant first (most reliable signal), falling back
  // to normalized narration for anything that doesn't hit the merchant
  // table — an unrecognized but consistently-repeating narration is still
  // a valid detection, just a lower-confidence one.
  const groups = new Map<string, { merchant: Merchant | null; txns: Txn[] }>();
  for (const txn of transactions) {
    const merchant = matchMerchant(txn.narration, merchantList);
    const key = merchant ? `merchant:${merchant.slug}` : `narration:${normalizeNarration(txn.narration)}`;
    const bucket = groups.get(key) ?? { merchant, txns: [] };
    bucket.txns.push({ id: txn.id, narration: txn.narration, amount: Number(txn.amount), date: txn.date });
    groups.set(key, bucket);
  }

  let clustersFound = 0;
  const merchantSlugsWithRealDetection = new Set<string>();

  for (const [groupKey, { merchant, txns }] of groups) {
    const amountClusters = buildAmountClusters(txns);
    const chains = buildChains(amountClusters);

    for (const chain of chains) {
      const allTxns = chain.segments.flatMap((segment) => segment.txns).sort((a, b) => a.date.getTime() - b.date.getTime());
      const latestSegment = chain.segments[chain.segments.length - 1]!;
      const priorSegment = chain.segments.length > 1 ? chain.segments[chain.segments.length - 2]! : null;
      const { cycle, regularity } = latestSegment;

      // Keyed off the FIRST segment's price, not the current one — this is
      // what makes the key stable across a plan change. Every future
      // re-run of detection still sees the same original first-observed
      // price for this chain (raw transaction history never gets pruned),
      // so a Family-plan upgrade updates the same row instead of minting
      // a new one, while two genuinely concurrent same-merchant
      // subscriptions (which never merge into one chain in the first
      // place) keep their own distinct keys.
      const detectionKey = `${groupKey}:${cycle}:${chain.segments[0]!.amountBucket}`;
      const confidence = computeConfidence(allTxns.length, regularity, Boolean(merchant));
      const lastTxn = allTxns[allTxns.length - 1]!;
      const nextChargeDate = projectNextChargeDate(lastTxn.date, cycle);
      const displayName =
        merchant?.name ?? (titleCase(normalizeNarration(lastTxn.narration).split(' ').slice(0, 4).join(' ')) || 'Unknown charge');
      const category = merchant?.category ?? 'OTHER';
      // Only set when this chain actually contains more than one price
      // tier — i.e. a real change was observed, not just "no prior data."
      const previousAmount = priorSegment ? priorSegment.medianAmount.toFixed(2) : null;

      const [existing] = await db
        .select()
        .from(subscriptions)
        .where(and(eq(subscriptions.userId, userId), eq(subscriptions.detectionKey, detectionKey)))
        .limit(1);

      let subscriptionId: string;

      if (existing) {
        if (existing.status === 'CANCELLED') continue;
        subscriptionId = existing.id;
        await db
          .update(subscriptions)
          .set({ amount: lastTxn.amount.toFixed(2), previousAmount, nextChargeDate, confidence, updatedAt: new Date() })
          .where(eq(subscriptions.id, existing.id));
      } else {
        const [created] = await db
          .insert(subscriptions)
          .values({
            userId,
            merchantId: merchant?.id ?? null,
            displayName,
            amount: lastTxn.amount.toFixed(2),
            previousAmount,
            cycle,
            nextChargeDate,
            category,
            status: 'UNREVIEWED',
            confidence,
            detectionKey,
          })
          .returning();
        if (!created) continue;
        subscriptionId = created.id;
      }

      clustersFound += 1;
      if (merchant) merchantSlugsWithRealDetection.add(merchant.slug);

      const chargeRows = allTxns.map((txn) => ({
        subscriptionId,
        date: txn.date,
        amount: txn.amount.toFixed(2),
        narration: txn.narration,
        rawTransactionId: txn.id,
      }));
      await db.insert(chargeRecords).values(chargeRows).onConflictDoNothing({ target: chargeRecords.rawTransactionId });
    }

    // ---- trial-prone first-charge heuristic ----
    //
    // A free trial converting to paid is, by definition, a SINGLE debit at
    // the point of detection — there's no second occurrence yet to prove a
    // pattern, which is exactly what the normal >= MIN_OCCURRENCES path
    // requires. For merchants known to run trial-then-charge signups
    // (Netflix, Spotify, etc. — see merchants.trialProne), a lone debit is
    // itself the signal worth surfacing: better a low-confidence heads-up
    // than silence until the second, harder-to-refund charge lands.
    if (merchant?.trialProne && txns.length === 1) {
      const txn = txns[0]!;
      const detectionKey = `merchant:${merchant.slug}:TRIAL_WATCH`;
      const [existing] = await db
        .select()
        .from(subscriptions)
        .where(and(eq(subscriptions.userId, userId), eq(subscriptions.detectionKey, detectionKey)))
        .limit(1);
      if (!existing) {
        // Cycle is a guess (monthly is the overwhelmingly common trial
        // cadence) — confidence is deliberately capped low so this never
        // outranks a real, multi-occurrence detection in the UI.
        const nextChargeDate = projectNextChargeDate(txn.date, 'MONTHLY');
        await db.insert(subscriptions).values({
          userId,
          merchantId: merchant.id,
          displayName: `${merchant.name} (possible trial)`,
          amount: txn.amount.toFixed(2),
          cycle: 'MONTHLY',
          nextChargeDate,
          category: merchant.category,
          status: 'UNREVIEWED',
          confidence: 0.35,
          detectionKey,
        });
        clustersFound += 1;
      }
    }
  }

  // A TRIAL_WATCH row is a placeholder for "we saw one charge and can't
  // confirm a pattern yet." Once the merchant graduates to a real,
  // multi-occurrence detection in this same run, the placeholder is
  // redundant — clean it up so the user doesn't see the same merchant
  // twice. Only ever deletes rows still sitting at UNREVIEWED, so a
  // placeholder the user has already acted on (dismissed to CANCELLED, or
  // somehow marked ACTIVE) is left alone rather than silently vanishing.
  if (merchantSlugsWithRealDetection.size > 0) {
    const staleKeys = [...merchantSlugsWithRealDetection].map((slug) => `merchant:${slug}:TRIAL_WATCH`);
    await db
      .delete(subscriptions)
      .where(
        and(
          eq(subscriptions.userId, userId),
          eq(subscriptions.status, 'UNREVIEWED'),
          inArray(subscriptions.detectionKey, staleKeys),
        ),
      );
  }

  return { clustersFound };
}
