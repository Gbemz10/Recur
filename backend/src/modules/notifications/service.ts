import { eq } from 'drizzle-orm';
import { db } from '../../db/client.js';
import { notificationPreferences } from '../../db/schema.js';

export type NotificationPreferences = typeof notificationPreferences.$inferSelect;

/** The lead times the app offers. Wider than the UI on purpose — see schema. */
export const MIN_LEAD_DAYS = 1;
export const MAX_LEAD_DAYS = 14;

function serialize(row: NotificationPreferences) {
  return {
    renewalReminders: row.renewalReminders,
    reminderLeadDays: row.reminderLeadDays,
    weeklyDigest: row.weeklyDigest,
  };
}

/**
 * The user's preferences, creating the row on first read.
 *
 * Lazily rather than at signup so the column defaults stay the single source
 * of truth for "has never touched this screen". A second definition of the
 * defaults in the signup path is a second thing to keep in step.
 *
 * The insert races itself if two requests arrive together for a user with no
 * row yet, which `onConflictDoNothing` on the unique user_id turns into a
 * no-op rather than an error; the select after it is what actually returns.
 */
export async function getPreferences(userId: string): Promise<NotificationPreferences> {
  const [existing] = await db
    .select()
    .from(notificationPreferences)
    .where(eq(notificationPreferences.userId, userId))
    .limit(1);
  if (existing) return existing;

  await db.insert(notificationPreferences).values({ userId }).onConflictDoNothing();

  const [created] = await db
    .select()
    .from(notificationPreferences)
    .where(eq(notificationPreferences.userId, userId))
    .limit(1);
  return created!;
}

export async function getPreferencesForApi(userId: string) {
  return serialize(await getPreferences(userId));
}

// `| undefined` spelled out on each because tsconfig sets
// exactOptionalPropertyTypes, under which `?:` means "may be absent" but not
// "may be present and undefined" — and a parsed partial body is exactly that.
export interface PreferencesPatch {
  renewalReminders?: boolean | undefined;
  reminderLeadDays?: number | undefined;
  weeklyDigest?: boolean | undefined;
}

/**
 * Applies a partial update.
 *
 * Turning a channel back on deliberately does **not** clear its bookkeeping
 * (`renewalRemindedFor`, `digestSentForWeek`). Someone who toggles the switch
 * off and on again in the same week is not asking to be sent this week's
 * digest a second time.
 */
export async function updatePreferences(userId: string, patch: PreferencesPatch) {
  await getPreferences(userId);

  const changes: Record<string, unknown> = { updatedAt: new Date() };
  if (patch.renewalReminders !== undefined) changes.renewalReminders = patch.renewalReminders;
  if (patch.weeklyDigest !== undefined) changes.weeklyDigest = patch.weeklyDigest;
  if (patch.reminderLeadDays !== undefined) {
    changes.reminderLeadDays = Math.min(MAX_LEAD_DAYS, Math.max(MIN_LEAD_DAYS, patch.reminderLeadDays));
  }

  const [updated] = await db
    .update(notificationPreferences)
    .set(changes)
    .where(eq(notificationPreferences.userId, userId))
    .returning();

  return serialize(updated!);
}
