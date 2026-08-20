import { and, eq, gte, inArray, isNull, lte, ne, or, sql } from 'drizzle-orm';
import { db } from '../../db/client.js';
import {
  notificationPreferences,
  subscriptions,
  trialReminders,
  users,
} from '../../db/schema.js';
import { isEmailSuppressed, sendEmail } from '../../lib/email.js';
import {
  renderRenewalReminderEmail,
  renderTrialReminderEmail,
  renderWeeklyDigestEmail,
  type RenewalReminderCharge,
} from '../../lib/emailTemplates.js';
import { currentPeriod, getSpendingSummary } from '../spending/service.js';

/**
 * Nigeria has no daylight saving, so a fixed offset is correct rather than a
 * simplification. Same constant and same reasoning as spending/service.ts.
 */
const WAT_OFFSET_MS = 1 * 60 * 60 * 1000;

/** Local WAT wall-clock, expressed as a UTC date whose fields read as WAT. */
function watNow(now: Date): Date {
  return new Date(now.getTime() + WAT_OFFSET_MS);
}

/**
 * ISO week key, `YYYY-Www`, computed in WAT.
 *
 * ISO weeks start Monday and belong to the year containing their Thursday,
 * which is why this shifts to Thursday before reading the year. Getting that
 * wrong would collapse the last week of December and the first of January
 * into one key, and the digest for one of them would never send.
 */
export function isoWeekKey(now = new Date()): string {
  const d = watNow(now);
  const day = (d.getUTCDay() + 6) % 7; // Monday = 0
  d.setUTCDate(d.getUTCDate() - day + 3); // the Thursday of this week
  const isoYear = d.getUTCFullYear();
  const firstThursday = new Date(Date.UTC(isoYear, 0, 4));
  const firstDay = (firstThursday.getUTCDay() + 6) % 7;
  firstThursday.setUTCDate(firstThursday.getUTCDate() - firstDay + 3);
  const week = 1 + Math.round((d.getTime() - firstThursday.getTime()) / (7 * 86400000));
  return `${isoYear}-W${String(week).padStart(2, '0')}`;
}

/** True on a Monday in Lagos, whatever the server's timezone is. */
export function isMondayInWat(now = new Date()): boolean {
  return watNow(now).getUTCDay() === 1;
}

/** Midnight WAT on the day `days` from now, as a UTC instant. */
function watMidnightIn(days: number, now: Date): Date {
  const wat = watNow(now);
  wat.setUTCHours(0, 0, 0, 0);
  wat.setUTCDate(wat.getUTCDate() + days);
  return new Date(wat.getTime() - WAT_OFFSET_MS);
}

export interface RunSummary {
  renewalEmails: number;
  trialEmails: number;
  digestEmails: number;
  failures: number;
  /// Addresses on the suppression list. Counted separately so a run that
  /// looks busy is not mistaken for a run that actually delivered anything.
  suppressed: number;
}

/**
 * Sends everything that is due, once.
 *
 * Safe to run repeatedly and safe to run more often than necessary: each pass
 * writes a marker before it would send again, so a second run inside the same
 * window finds nothing. That is deliberate. This is driven by a scheduler,
 * and schedulers get retried, restarted and occasionally doubled up; an
 * at-most-once guarantee that depends on the caller behaving is not one.
 *
 * One user's failure never stops the others. Sending is a network call to
 * someone else's service, so a single bad address or a provider hiccup has to
 * cost that user's email and nothing more.
 */
export async function runDueNotifications(now = new Date()): Promise<RunSummary> {
  const summary: RunSummary = {
    renewalEmails: 0,
    trialEmails: 0,
    digestEmails: 0,
    failures: 0,
    suppressed: 0,
  };

  await runRenewalReminders(now, summary);
  await runTrialReminders(now, summary);
  if (isMondayInWat(now)) await runWeeklyDigests(now, summary);

  return summary;
}

// ------------------------------------------------------------------ renewals

/**
 * A heads-up for every charge inside the user's lead window.
 *
 * The guard is `renewal_reminded_for`, which stores the charge date a reminder
 * has already gone out for rather than a boolean or a timestamp. That makes
 * the job idempotent for free: it re-sends exactly when the projected date
 * moves to a new cycle, which is the only time a second reminder is wanted.
 */
async function runRenewalReminders(now: Date, summary: RunSummary): Promise<void> {
  // The widest window anyone can have asked for; each user's own lead is
  // applied below. One query rather than one per distinct lead value.
  const horizon = watMidnightIn(15, now);

  const rows = await db
    .select({
      userId: subscriptions.userId,
      email: users.email,
      subscriptionId: subscriptions.id,
      displayName: subscriptions.displayName,
      amount: subscriptions.amount,
      nextChargeDate: subscriptions.nextChargeDate,
      leadDays: notificationPreferences.reminderLeadDays,
    })
    .from(subscriptions)
    .innerJoin(users, eq(users.id, subscriptions.userId))
    .innerJoin(notificationPreferences, eq(notificationPreferences.userId, subscriptions.userId))
    .where(
      and(
        eq(subscriptions.status, 'ACTIVE'),
        eq(notificationPreferences.renewalReminders, true),
        // Not yet charged, and inside the widest lead window.
        gte(subscriptions.nextChargeDate, now),
        lte(subscriptions.nextChargeDate, horizon),
        // Never reminded, or reminded for an earlier cycle than this one.
        or(
          isNull(subscriptions.renewalRemindedFor),
          ne(subscriptions.renewalRemindedFor, subscriptions.nextChargeDate),
        ),
      ),
    );

  // Group per user: one email listing everything due, not one per charge.
  const byUser = new Map<
    string,
    { email: string; leadDays: number; charges: RenewalReminderCharge[]; ids: string[] }
  >();

  for (const row of rows) {
    const daysAway = Math.floor((row.nextChargeDate.getTime() - now.getTime()) / 86400000);
    if (daysAway > row.leadDays) continue;

    const entry = byUser.get(row.userId) ?? {
      email: row.email,
      leadDays: row.leadDays,
      charges: [],
      ids: [],
    };
    entry.charges.push({
      name: row.displayName,
      amount: Number(row.amount),
      chargeDate: row.nextChargeDate,
    });
    entry.ids.push(row.subscriptionId);
    byUser.set(row.userId, entry);
  }

  for (const [userId, entry] of byUser) {
    entry.charges.sort((a, b) => a.chargeDate.getTime() - b.chargeDate.getTime());
    const email = renderRenewalReminderEmail({ charges: entry.charges, leadDays: entry.leadDays });

    try {
      await sendEmail({ to: entry.email, subject: email.subject, text: email.text, html: email.html });
      // Marked only after the send resolves. Marking first would lose the
      // reminder entirely on a provider error, and a missed charge warning is
      // worse than a repeated one.
      await db
        .update(subscriptions)
        .set({ renewalRemindedFor: sql`${subscriptions.nextChargeDate}` })
        .where(and(eq(subscriptions.userId, userId), inArray(subscriptions.id, entry.ids)));
      if (isEmailSuppressed(entry.email)) summary.suppressed += 1;
      else summary.renewalEmails += 1;
    } catch (error) {
      summary.failures += 1;
      console.error(`Renewal reminder failed for user ${userId}:`, error);
    }
  }
}

// -------------------------------------------------------------------- trials

/**
 * Trials convert silently, which is the whole reason this table exists. The
 * lead is the user's own reminder preference, and `reminded_at` is the guard.
 */
async function runTrialReminders(now: Date, summary: RunSummary): Promise<void> {
  const horizon = watMidnightIn(15, now);

  const rows = await db
    .select({
      id: trialReminders.id,
      userId: trialReminders.userId,
      email: users.email,
      label: trialReminders.label,
      trialEndsAt: trialReminders.trialEndsAt,
      leadDays: notificationPreferences.reminderLeadDays,
    })
    .from(trialReminders)
    .innerJoin(users, eq(users.id, trialReminders.userId))
    .innerJoin(notificationPreferences, eq(notificationPreferences.userId, trialReminders.userId))
    .where(
      and(
        eq(notificationPreferences.renewalReminders, true),
        isNull(trialReminders.remindedAt),
        isNull(trialReminders.dismissedAt),
        lte(trialReminders.trialEndsAt, horizon),
      ),
    );

  for (const row of rows) {
    const daysAway = Math.floor((row.trialEndsAt.getTime() - now.getTime()) / 86400000);
    if (daysAway > row.leadDays) continue;

    const email = renderTrialReminderEmail({
      label: row.label,
      endsAt: row.trialEndsAt,
      daysAway,
    });

    try {
      await sendEmail({ to: row.email, subject: email.subject, text: email.text, html: email.html });
      await db
        .update(trialReminders)
        .set({ remindedAt: new Date() })
        .where(eq(trialReminders.id, row.id));
      if (isEmailSuppressed(row.email)) summary.suppressed += 1;
      else summary.trialEmails += 1;
    } catch (error) {
      summary.failures += 1;
      console.error(`Trial reminder failed for trial ${row.id}:`, error);
    }
  }
}

// -------------------------------------------------------------------- digest

/**
 * The Monday summary, guarded by the ISO week it last covered.
 *
 * A week string rather than a timestamp because the question is "has this
 * week's digest gone out", and a string compare answers it without a date
 * calculation on every row.
 */
async function runWeeklyDigests(now: Date, summary: RunSummary): Promise<void> {
  const week = isoWeekKey(now);
  const weekEnd = watMidnightIn(8, now);
  const period = currentPeriod(now);
  const monthLabel = new Intl.DateTimeFormat('en-NG', {
    month: 'long',
    timeZone: 'Africa/Lagos',
  }).format(now);

  const recipients = await db
    .select({ userId: notificationPreferences.userId, email: users.email })
    .from(notificationPreferences)
    .innerJoin(users, eq(users.id, notificationPreferences.userId))
    .where(
      and(
        eq(notificationPreferences.weeklyDigest, true),
        or(
          isNull(notificationPreferences.digestSentForWeek),
          ne(notificationPreferences.digestSentForWeek, week),
        ),
      ),
    );

  for (const recipient of recipients) {
    try {
      const [active, spending] = await Promise.all([
        db
          .select({
            displayName: subscriptions.displayName,
            amount: subscriptions.amount,
            nextChargeDate: subscriptions.nextChargeDate,
            cycle: subscriptions.cycle,
          })
          .from(subscriptions)
          .where(
            and(eq(subscriptions.userId, recipient.userId), eq(subscriptions.status, 'ACTIVE')),
          ),
        getSpendingSummary(recipient.userId, period),
      ]);

      const weekAhead: RenewalReminderCharge[] = active
        .filter((s) => s.nextChargeDate >= now && s.nextChargeDate < weekEnd)
        .map((s) => ({
          name: s.displayName,
          amount: Number(s.amount),
          chargeDate: s.nextChargeDate,
        }))
        .sort((a, b) => a.chargeDate.getTime() - b.chargeDate.getTime());

      // An account with nothing tracked and nothing spent has no digest worth
      // sending. Silence is the correct output, and it still marks the week so
      // this is not recomputed every tick.
      const hasAnything = active.length > 0 || spending.total > 0;

      if (hasAnything) {
        const monthlyTotal = active.reduce(
          (sum, s) => sum + Number(s.amount) * monthlyFactor(s.cycle),
          0,
        );

        const email = renderWeeklyDigestEmail({
          weekAhead,
          monthSoFar: spending.total,
          monthLabel,
          topCategories: spending.categories
            .filter((c) => c.spent > 0)
            .slice(0, 3)
            .map((c) => ({ label: categoryLabel(c.category), spent: c.spent })),
          activeCount: active.length,
          monthlyTotal,
        });

        await sendEmail({
          to: recipient.email,
          subject: email.subject,
          text: email.text,
          html: email.html,
        });
        if (isEmailSuppressed(recipient.email)) summary.suppressed += 1;
        else summary.digestEmails += 1;
      }

      await db
        .update(notificationPreferences)
        .set({ digestSentForWeek: week, updatedAt: new Date() })
        .where(eq(notificationPreferences.userId, recipient.userId));
    } catch (error) {
      summary.failures += 1;
      console.error(`Weekly digest failed for user ${recipient.userId}:`, error);
    }
  }
}

/** Charges per month for a cycle, so a yearly plan is comparable to a monthly one. */
function monthlyFactor(cycle: string): number {
  switch (cycle) {
    case 'WEEKLY':
      return 52 / 12;
    case 'BIWEEKLY':
      return 26 / 12;
    case 'QUARTERLY':
      return 1 / 3;
    case 'YEARLY':
      return 1 / 12;
    default:
      return 1;
  }
}

/** Wire category to something a person reads. Mirrors the app's labels. */
function categoryLabel(category: string): string {
  const labels: Record<string, string> = {
    food: 'Food and groceries',
    transport: 'Transport',
    bills: 'Bills and utilities',
    entertainment: 'Entertainment',
    health: 'Health',
    shopping: 'Shopping',
    transfers: 'Transfers and cash',
    savings: 'Savings and investments',
    loans: 'Loans',
    education: 'Education',
    other: 'Other',
  };
  return labels[category] ?? 'Other';
}
