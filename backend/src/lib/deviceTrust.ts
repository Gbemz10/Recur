import { and, eq } from 'drizzle-orm';
import { db } from '../db/client.js';
import { knownDevices } from '../db/schema.js';

/**
 * "New device" tracking for the sign-in notification email (see
 * emailTemplates.ts's renderNewDeviceEmail). Identity is the client-
 * generated `X-Device-Id` header (see the Flutter app's device_id.dart),
 * not IP address — a mobile client's IP rotates constantly across
 * cellular/wifi handoffs, so an IP-based check would fire on nearly every
 * sign-in and train users to ignore the email. `ip`/`userAgent` here are
 * purely descriptive, stored for display and overwritten on every sighting.
 */

export interface DeviceContext {
  deviceId: string | null;
  ip: string | null;
  userAgent: string | null;
}

/**
 * Records a sighting of this device for this user. Returns whether the
 * device was new (never seen for this user before). A missing/absent
 * `deviceId` (older client, or the header just didn't arrive) is treated
 * as "not new" — silently skipped — rather than guessed at, since there's
 * no reliable identity to key on.
 */
export async function recordDeviceSighting(userId: string, ctx: DeviceContext): Promise<{ isNew: boolean }> {
  if (!ctx.deviceId) return { isNew: false };

  const [existing] = await db
    .select()
    .from(knownDevices)
    .where(and(eq(knownDevices.userId, userId), eq(knownDevices.deviceId, ctx.deviceId)))
    .limit(1);

  if (existing) {
    await db
      .update(knownDevices)
      .set({ lastSeenAt: new Date(), lastIp: ctx.ip, lastUserAgent: ctx.userAgent })
      .where(eq(knownDevices.id, existing.id));
    return { isNew: false };
  }

  await db.insert(knownDevices).values({
    userId,
    deviceId: ctx.deviceId,
    lastIp: ctx.ip,
    lastUserAgent: ctx.userAgent,
  });
  return { isNew: true };
}

/** Pulls device context off a Fastify request — a thin adapter so route
 *  handlers don't each reach into `request.headers`/`request.ip` directly. */
export function deviceContextFromHeaders(headers: Record<string, unknown>, ip: string): DeviceContext {
  const deviceId = headers['x-device-id'];
  const userAgent = headers['user-agent'];
  return {
    deviceId: typeof deviceId === 'string' && deviceId.trim() ? deviceId.trim() : null,
    userAgent: typeof userAgent === 'string' ? userAgent : null,
    ip: ip || null,
  };
}
