import { and, eq } from 'drizzle-orm';
import { db } from '../../db/client.js';
import { subscriptions, chargeRecords, merchants } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';

type SubscriptionStatusValue = 'UNREVIEWED' | 'ACTIVE' | 'CANCELLED';
const ALLOWED_STATUSES: SubscriptionStatusValue[] = ['UNREVIEWED', 'ACTIVE', 'CANCELLED'];

type SubscriptionWithRelations = typeof subscriptions.$inferSelect & {
  merchant: typeof merchants.$inferSelect | null;
  charges: (typeof chargeRecords.$inferSelect)[];
};

/**
 * Wire format uses lowercase enum strings ("monthly", "streaming",
 * "active") that match the Flutter client's Dart enum member names
 * one-to-one, so deserializing on that side is a straight `.byName()`
 * lookup rather than a translation table. Postgres enums are UPPER_CASE
 * by convention — this is the only place that boundary gets crossed.
 */
function serializeSubscription(sub: SubscriptionWithRelations) {
  return {
    id: sub.id,
    merchant: sub.merchant
      ? { slug: sub.merchant.slug, name: sub.merchant.name, domain: sub.merchant.domain, brandColor: sub.merchant.brandColor }
      : null,
    displayName: sub.displayName,
    amount: Number(sub.amount),
    cycle: sub.cycle.toLowerCase(),
    nextChargeDate: sub.nextChargeDate.toISOString(),
    category: sub.category.toLowerCase(),
    status: sub.status.toLowerCase(),
    confidence: sub.confidence,
    charges: [...sub.charges]
      .sort((a, b) => b.date.getTime() - a.date.getTime())
      .map((charge) => ({ date: charge.date.toISOString(), amount: Number(charge.amount), narration: charge.narration })),
  };
}

export async function listSubscriptions(userId: string) {
  const rows = await db.query.subscriptions.findMany({
    where: eq(subscriptions.userId, userId),
    with: { merchant: true, charges: true },
    orderBy: (table, { asc }) => asc(table.nextChargeDate),
  });
  return rows.map(serializeSubscription);
}

export async function updateSubscriptionStatus(userId: string, subscriptionId: string, status: string) {
  const upper = status.toUpperCase() as SubscriptionStatusValue;
  if (!ALLOWED_STATUSES.includes(upper)) {
    throw AppError.badRequest(`status must be one of: ${ALLOWED_STATUSES.map((s) => s.toLowerCase()).join(', ')}`);
  }

  const existing = await db.query.subscriptions.findFirst({
    where: and(eq(subscriptions.id, subscriptionId), eq(subscriptions.userId, userId)),
  });
  if (!existing) throw AppError.notFound('Subscription not found');

  await db
    .update(subscriptions)
    .set({ status: upper, updatedAt: new Date() })
    .where(eq(subscriptions.id, subscriptionId));

  const updated = await db.query.subscriptions.findFirst({
    where: eq(subscriptions.id, subscriptionId),
    with: { merchant: true, charges: true },
  });
  if (!updated) throw AppError.notFound('Subscription not found');

  return serializeSubscription(updated);
}
