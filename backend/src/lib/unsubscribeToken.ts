import { createHmac, timingSafeEqual } from 'node:crypto';
import { env } from '../config/env.js';

/**
 * The two things a person can be unsubscribed from.
 *
 * Per channel rather than all-or-nothing, because they are different promises.
 * "Your card is about to be charged" is worth having even to someone who never
 * wants another Monday summary, and forcing that choice is how you lose the
 * one that would have saved them money.
 *
 * `reminders` covers renewal and trial reminders together: both are gated by
 * the same `renewalReminders` preference, so offering them separately would be
 * a promise the preferences table cannot keep.
 */
export type UnsubscribeChannel = 'reminders' | 'digest';

const CHANNELS: readonly UnsubscribeChannel[] = ['reminders', 'digest'];

export function isUnsubscribeChannel(value: string): value is UnsubscribeChannel {
  return (CHANNELS as readonly string[]).includes(value);
}

function sign(payload: string): string {
  return createHmac('sha256', env.JWT_SECRET).update(payload).digest('base64url');
}

/**
 * A token identifying one user and one channel.
 *
 * Deliberately never expires. The email it lives in does not expire either,
 * and an unsubscribe link that has gone stale is worse than useless: the
 * person clicking it has already decided, and a dead link means the next mail
 * arrives anyway. Rotating JWT_SECRET invalidates every outstanding link,
 * which is the intended and only kill switch.
 *
 * Not a JWT, because this is not a session. It grants exactly one power, on
 * one user, in one direction: turning a channel off. It cannot be replayed
 * into anything else, and leaking one costs the holder nothing but a
 * preference they can flip back in the app.
 */
export function createUnsubscribeToken(userId: string, channel: UnsubscribeChannel): string {
  const payload = `${userId}.${channel}`;
  return `${Buffer.from(payload).toString('base64url')}.${sign(payload)}`;
}

export function verifyUnsubscribeToken(
  token: string,
): { userId: string; channel: UnsubscribeChannel } | null {
  const parts = token.split('.');
  if (parts.length !== 2) return null;

  const [encoded, signature] = parts as [string, string];
  let payload: string;
  try {
    payload = Buffer.from(encoded, 'base64url').toString('utf8');
  } catch {
    return null;
  }

  const expected = sign(payload);
  const a = Buffer.from(signature);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;

  const [userId, channel] = payload.split('.');
  if (!userId || !channel || !isUnsubscribeChannel(channel)) return null;
  return { userId, channel };
}

/** The link that goes in the email. */
export function unsubscribeUrl(userId: string, channel: UnsubscribeChannel): string {
  const token = createUnsubscribeToken(userId, channel);
  return `${env.PUBLIC_API_URL}/notifications/unsubscribe?t=${encodeURIComponent(token)}`;
}
