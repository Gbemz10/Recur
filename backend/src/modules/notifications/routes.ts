import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { env } from '../../config/env.js';
import { AppError } from '../../lib/errors.js';
import { rateLimit } from '../../lib/rateLimit.js';
import { runDueNotifications } from './job.js';
import {
  verifyUnsubscribeToken,
  type UnsubscribeChannel,
} from '../../lib/unsubscribeToken.js';
import { renderUnsubscribePage } from '../../lib/unsubscribePage.js';
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
  // Gmail's one-click unsubscribe POSTs `List-Unsubscribe=One-Click` as
  // application/x-www-form-urlencoded. Fastify only parses JSON out of the
  // box, so without this the request is rejected with 415 before it reaches
  // the handler, and the unsubscribe button silently fails in the one client
  // this feature exists for. Verified: it returned 415 until this was added.
  //
  // The body is ignored on purpose. The token lives in the query string, so
  // there is nothing here worth parsing, only a content type worth accepting.
  app.addContentTypeParser(
    ['application/x-www-form-urlencoded', 'text/plain'],
    { parseAs: 'string' },
    (_request, _body, done) => done(null, undefined),
  );

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
   * One-click unsubscribe, per channel.
   *
   * Answers both GET and POST on the same path. GET is a person clicking the
   * link in the footer; POST is RFC 8058, which is what Gmail and Apple Mail
   * fire when someone uses their own unsubscribe button, and it must not
   * require any interaction beyond that.
   *
   * No session. The token is the authority, and it can only ever turn one
   * channel off for one user. Requiring a login here would defeat the point:
   * the person most likely to click has already uninstalled the app.
   */
  const unsubscribe = async (token: string) => {
    const parsed = verifyUnsubscribeToken(token);
    if (!parsed) return null;
    const patch =
      parsed.channel === 'digest' ? { weeklyDigest: false } : { renewalReminders: false };
    await notificationsService.updatePreferences(parsed.userId, patch);
    return parsed.channel;
  };

  app.get('/notifications/unsubscribe', async (request, reply) => {
    const token = (request.query as { t?: string }).t ?? '';
    const channel = await unsubscribe(token);
    return reply
      .type('text/html; charset=utf-8')
      .status(channel ? 200 : 400)
      .send(renderUnsubscribePage(channel));
  });

  // Gmail and Apple Mail POST here with no body and expect a 2xx. They never
  // render the response, so it stays deliberately empty.
  app.post('/notifications/unsubscribe', async (request, reply) => {
    const token = (request.query as { t?: string }).t ?? '';
    const channel = await unsubscribe(token);
    return reply.status(channel ? 204 : 400).send();
  });

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
