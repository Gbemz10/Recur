import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { env } from '../../config/env.js';
import { AppError } from '../../lib/errors.js';
import { rateLimit } from '../../lib/rateLimit.js';
import { runDueNotifications } from './job.js';
import * as notificationsService from './service.js';
import { MAX_LEAD_DAYS, MIN_LEAD_DAYS } from './service.js';

const patchSchema = z
  .object({
    renewalReminders: z.boolean().optional(),
    reminderLeadDays: z.number().int().min(MIN_LEAD_DAYS).max(MAX_LEAD_DAYS).optional(),
    weeklyDigest: z.boolean().optional(),
  })
  // An empty body is a client bug, not a no-op worth a 200.
  .refine((v) => Object.keys(v).length > 0, { message: 'No preferences supplied' });

// The settings screen writes on every toggle, so this is bounded rather than
// tight; a person flipping switches should never hit it.
const updateLimit = rateLimit({
  name: 'notifications:prefs:user',
  windowMs: 60 * 1000,
  max: 60,
  keyGenerator: (r) => r.user.sub,
});

export async function notificationRoutes(app: FastifyInstance) {
  app.get('/notifications/preferences', { onRequest: [app.authenticate] }, async (request, reply) => {
    const preferences = await notificationsService.getPreferencesForApi(request.user.sub);
    return reply.send({ preferences });
  });

  app.patch(
    '/notifications/preferences',
    { onRequest: [app.authenticate], preHandler: [updateLimit] },
    async (request, reply) => {
      const parsed = patchSchema.safeParse(request.body);
      if (!parsed.success) {
        const first = parsed.error.issues[0];
        throw AppError.badRequest(first ? first.message : 'Invalid request body');
      }
      const preferences = await notificationsService.updatePreferences(request.user.sub, parsed.data);
      return reply.send({ preferences });
    },
  );

  /**
   * Drives one pass of the notification job.
   *
   * Exists so a platform cron can own the schedule instead of the API process.
   * That is the correct arrangement past a single instance: the in-process
   * timer guards against overlap with a per-process flag, which stops guarding
   * anything the moment there are two processes. One external caller on a
   * schedule is one caller by construction.
   *
   * Guarded by a shared secret rather than a user JWT, because the caller is a
   * machine with no user. An unset secret disables the route rather than
   * leaving it open, so forgetting to configure it fails closed.
   */
  app.post('/notifications/run', async (request, reply) => {
    if (!env.NOTIFICATIONS_RUN_TOKEN) {
      throw AppError.notFound('Not found');
    }

    const header = request.headers.authorization ?? '';
    const supplied = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!timingSafeEqual(supplied, env.NOTIFICATIONS_RUN_TOKEN)) {
      throw AppError.unauthorized('Invalid run token');
    }

    const summary = await runDueNotifications();
    return reply.send({ summary });
  });
}

/**
 * Constant-time compare, so the response time cannot be used to guess the
 * token a character at a time.
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i += 1) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
