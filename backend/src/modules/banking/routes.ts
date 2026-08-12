import type { FastifyInstance } from 'fastify';
import * as bankingService from './service.js';
import { rateLimit } from '../../lib/rateLimit.js';

// Scoped to the signed-in user (not IP) since these routes are
// authenticated — bounds how many link/sync calls one account can fire,
// independent of how many devices/IPs it's coming from.
const linkInitiateLimit = rateLimit({ name: 'banking:link-initiate:user', windowMs: 15 * 60 * 1000, max: 10, keyGenerator: (r) => r.user.sub });
const syncNowLimit = rateLimit({ name: 'banking:sync-now:user', windowMs: 5 * 60 * 1000, max: 5, keyGenerator: (r) => r.user.sub });

export async function bankingRoutes(app: FastifyInstance) {
  // Returns a one-time Mono-hosted URL for the client to open in a webview.
  // No request body — the signed-in user (from the bearer token) is all
  // this needs.
  app.post('/banking/link/initiate', { onRequest: [app.authenticate], preHandler: [linkInitiateLimit] }, async (request, reply) => {
    const result = await bankingService.initiateLink(request.user.sub);
    return reply.send(result);
  });

  app.get('/banking/accounts', { onRequest: [app.authenticate] }, async (request, reply) => {
    const banks = await bankingService.listLinkedBanks(request.user.sub);
    return reply.send({ banks });
  });

  app.delete('/banking/accounts/:id', { onRequest: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const bank = await bankingService.unlinkBank(request.user.sub, id);
    return reply.send({ bank });
  });

  app.post('/banking/accounts/:id/sync', { onRequest: [app.authenticate], preHandler: [syncNowLimit] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const result = await bankingService.syncNow(request.user.sub, id);
    return reply.send(result);
  });
}
