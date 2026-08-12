import { createHash, timingSafeEqual } from 'node:crypto';
import type { FastifyBaseLogger, FastifyInstance } from 'fastify';
import { env } from '../../config/env.js';
import * as bankingService from '../banking/service.js';
import { rateLimit } from '../../lib/rateLimit.js';

// `timingSafeEqual` throws on mismatched buffer lengths, which would leak
// exactly the information it's meant to hide (whether the guessed secret's
// length is even correct) via a thrown exception vs. a clean `false`.
// Hashing both sides first fixes the length at 32 bytes regardless of
// input, so the comparison is safe either way.
function secureEqual(a: string, b: string): boolean {
  const bufA = createHash('sha256').update(a).digest();
  const bufB = createHash('sha256').update(b).digest();
  return timingSafeEqual(bufA, bufB);
}

const webhookIpLimit = rateLimit({ name: 'webhooks:mono:ip', windowMs: 60 * 1000, max: 60 });

/**
 * Mono webhook payload shapes, per https://docs.mono.co/docs/financial-data/webhook-introduction
 * and the three event-specific pages linked from it. Kept loose (fields
 * marked optional where the docs' example payloads are inconsistent about
 * `id` vs `_id`) since this hasn't been exercised against a live webhook yet.
 */
interface MonoAccountConnectedPayload {
  event: 'mono.events.account_connected';
  data: { id: string; customer?: string; meta?: { ref?: string } };
}

interface MonoAccountUpdatedPayload {
  event: 'mono.events.account_updated';
  data: {
    account: {
      _id: string;
      accountNumber: string;
      institution?: { name: string; bankCode: string };
    };
    meta: { data_status: 'AVAILABLE' | 'PROCESSING' | 'UNAVAILABLE' | string };
  };
}

interface MonoAccountUnlinkedPayload {
  event: 'mono.events.account_unlinked';
  data: { account: { id?: string; _id?: string } };
}

type MonoWebhookPayload = MonoAccountConnectedPayload | MonoAccountUpdatedPayload | MonoAccountUnlinkedPayload | { event: string; data: unknown };

async function processMonoWebhook(payload: MonoWebhookPayload, log: FastifyBaseLogger) {
  switch (payload.event) {
    case 'mono.events.account_connected': {
      // This is the first point a linked account becomes known to us at
      // all under the Connect Link flow — `ref` is the user id we passed
      // when initiating the link (see banking/service.ts initiateLink).
      const { id, meta } = (payload as MonoAccountConnectedPayload).data;
      if (meta?.ref) {
        await bankingService.handleAccountConnected(id, meta.ref);
      } else {
        log.warn(`account_connected webhook missing meta.ref for account ${id}`);
      }
      break;
    }

    case 'mono.events.account_updated': {
      const { account, meta } = (payload as MonoAccountUpdatedPayload).data;
      await bankingService.handleAccountUpdated(
        account._id,
        account.institution ? { name: account.institution.name, bankCode: account.institution.bankCode, accountNumber: account.accountNumber } : null,
        meta.data_status,
      );
      break;
    }

    case 'mono.events.account_unlinked': {
      const { account } = (payload as MonoAccountUnlinkedPayload).data;
      const accountId = account.id ?? account._id;
      if (accountId) await bankingService.handleAccountUnlinked(accountId);
      break;
    }

    default:
      log.info(`Unhandled Mono webhook event: ${payload.event}`);
  }
}

export async function webhookRoutes(app: FastifyInstance) {
  app.post('/webhooks/mono', { preHandler: [webhookIpLimit] }, async (request, reply) => {
    const secretHeader = request.headers['mono-webhook-secret'];
    const secret = Array.isArray(secretHeader) ? secretHeader[0] : secretHeader;
    if (!env.MONO_WEBHOOK_SECRET || !secret || !secureEqual(secret, env.MONO_WEBHOOK_SECRET)) {
      return reply.status(401).send({ error: 'invalid webhook secret' });
    }

    const payload = request.body as MonoWebhookPayload;

    // Ack immediately — Mono retries on anything but a fast 2xx. The
    // actual sync + detection work happens after the response goes out.
    reply.status(200).send({ received: true });

    processMonoWebhook(payload, request.log).catch((error) => request.log.error(error, 'Failed processing Mono webhook'));
  });
}
