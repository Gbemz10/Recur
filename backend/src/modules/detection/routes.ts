import type { FastifyInstance } from 'fastify';
import { rateLimit } from '../../lib/rateLimit.js';
import { runDetectionForUser } from './service.js';

// Every other authenticated write-ish action in the app has a limiter
// (banking sync, trial creation, avatar upload) — this scans the user's
// full raw_transactions history plus an upsert per detected cluster on
// every call, so it's not free, and unlike a normal sync it isn't
// naturally rate-limited by how often Mono actually has new data.
const detectionRunLimit = rateLimit({
  name: 'detection:run:user',
  windowMs: 5 * 60 * 1000,
  max: 10,
  keyGenerator: (r) => r.user.sub,
});

export async function detectionRoutes(app: FastifyInstance) {
  // On-demand re-scan, mainly useful for testing/debugging without waiting
  // on a Mono webhook — normal operation runs detection automatically
  // after every transaction sync (see banking/service.ts).
  app.post('/detection/run', { onRequest: [app.authenticate], preHandler: [detectionRunLimit] }, async (request, reply) => {
    const result = await runDetectionForUser(request.user.sub);
    return reply.send(result);
  });
}
