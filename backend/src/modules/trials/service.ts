import { and, asc, eq, isNull } from 'drizzle-orm';
import { db } from '../../db/client.js';
import { trialReminders } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';

/**
 * Manually-entered trial reminders — the user tells Recur "I just signed up
 * for X, remind me before it converts to paid" right after signing up,
 * rather than waiting for the detection engine to notice a charge that's
 * already happened. Deliberately no server-side notification job here yet
 * (that needs a scheduler, which is a separate, not-yet-built piece of
 * infrastructure) — the API just stores the reminder; the client decides
 * how urgently to surface it based on how close `trialEndsAt` is.
 */
function serializeTrialReminder(row: typeof trialReminders.$inferSelect) {
  return {
    id: row.id,
    merchantSlug: row.merchantSlug,
    label: row.label,
    trialEndsAt: row.trialEndsAt.toISOString(),
    remindedAt: row.remindedAt ? row.remindedAt.toISOString() : null,
    dismissedAt: row.dismissedAt ? row.dismissedAt.toISOString() : null,
    createdAt: row.createdAt.toISOString(),
  };
}

export async function listTrialReminders(userId: string) {
  const rows = await db
    .select()
    .from(trialReminders)
    .where(and(eq(trialReminders.userId, userId), isNull(trialReminders.dismissedAt)))
    .orderBy(asc(trialReminders.trialEndsAt));
  return rows.map(serializeTrialReminder);
}

export async function createTrialReminder(
  userId: string,
  data: { label: string; trialEndsAt: Date; merchantSlug: string | null },
) {
  const [created] = await db
    .insert(trialReminders)
    .values({
      userId,
      label: data.label,
      trialEndsAt: data.trialEndsAt,
      merchantSlug: data.merchantSlug,
    })
    .returning();
  if (!created) throw AppError.internal('Failed to create trial reminder');
  return serializeTrialReminder(created);
}

/**
 * Puts a dismissed reminder back.
 *
 * `dismissedAt` was always a soft flag rather than a delete, so the row never
 * went anywhere; nothing could clear it. That made the app's delete a one-way
 * door, which is why it needed a confirmation dialog in front of it. With a
 * way back, an undo is honest and the dialog is unnecessary friction.
 */
export async function restoreTrialReminder(userId: string, trialReminderId: string) {
  const existing = await db.query.trialReminders.findFirst({
    where: and(eq(trialReminders.id, trialReminderId), eq(trialReminders.userId, userId)),
  });
  if (!existing) throw AppError.notFound('Trial reminder not found');

  const [updated] = await db
    .update(trialReminders)
    .set({ dismissedAt: null })
    .where(eq(trialReminders.id, trialReminderId))
    .returning();
  if (!updated) throw AppError.notFound('Trial reminder not found');

  return serializeTrialReminder(updated);
}

export async function dismissTrialReminder(userId: string, trialReminderId: string) {
  const existing = await db.query.trialReminders.findFirst({
    where: and(eq(trialReminders.id, trialReminderId), eq(trialReminders.userId, userId)),
  });
  if (!existing) throw AppError.notFound('Trial reminder not found');

  const [updated] = await db
    .update(trialReminders)
    .set({ dismissedAt: new Date() })
    .where(eq(trialReminders.id, trialReminderId))
    .returning();
  if (!updated) throw AppError.notFound('Trial reminder not found');

  return serializeTrialReminder(updated);
}
