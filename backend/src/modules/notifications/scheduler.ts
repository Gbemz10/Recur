import { env } from '../../config/env.js';
import { runDueNotifications } from './job.js';

/**
 * Drives [runDueNotifications] on a timer inside the API process.
 *
 * This is the pragmatic option for a single service, not the durable one. Two
 * things follow from that and are handled deliberately:
 *
 * Overlap. A tick that is still running when the next one fires would query
 * the same due rows twice, and the guards in the job are written after the
 * send, so the window between them is real. `running` closes it in-process.
 *
 * Multiple instances. `running` is per-process, so scaling the API past one
 * instance reopens that window across processes. Postgres advisory locks are
 * the fix when that day comes; until then, set NOTIFICATIONS_SCHEDULER=off and
 * drive POST /notifications/run from a platform cron instead, which is one
 * caller by construction.
 *
 * The interval is deliberately much shorter than a day. Reminders are keyed to
 * a lead in days, so the exact minute does not matter, but a long interval
 * means a restart can skip a window entirely. Running often and finding
 * nothing is the cheap side of that trade.
 */
let running = false;
let timer: NodeJS.Timeout | null = null;

export async function tick(): Promise<void> {
  if (running) return;
  running = true;
  try {
    const summary = await runDueNotifications();
    const sent = summary.renewalEmails + summary.trialEmails + summary.digestEmails;
    if (sent > 0 || summary.failures > 0) {
      console.log(
        `[notifications] renewals=${summary.renewalEmails} trials=${summary.trialEmails} ` +
          `digests=${summary.digestEmails} failures=${summary.failures}`,
      );
    }
  } catch (error) {
    // Never let a bad tick take the process down. The next one retries, and
    // everything it would have sent is still marked as unsent.
    console.error('[notifications] tick failed:', error);
  } finally {
    running = false;
  }
}

export function startNotificationScheduler(): void {
  if (env.NOTIFICATIONS_SCHEDULER !== 'on') {
    console.log('[notifications] in-process scheduler off; drive POST /notifications/run instead');
    return;
  }
  if (timer) return;

  const intervalMs = env.NOTIFICATIONS_INTERVAL_MINUTES * 60 * 1000;
  // Not on boot. A deploy loop that crashes after start would otherwise send
  // on every restart, and nothing here is urgent to the minute.
  timer = setInterval(() => void tick(), intervalMs);
  // Does not hold the event loop open, so shutdown is not blocked waiting for
  // a timer that only ever logs.
  timer.unref();

  console.log(`[notifications] scheduler on, every ${env.NOTIFICATIONS_INTERVAL_MINUTES}m`);
}

export function stopNotificationScheduler(): void {
  if (timer) clearInterval(timer);
  timer = null;
}
