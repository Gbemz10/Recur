import type { FastifyInstance } from 'fastify';
import { runDetectionForUser } from './service.js';

export async function detectionRoutes(app: FastifyInstance) {
  // On-demand re-scan, mainly useful for testing/debugging without waiting
  // on a Mono webhook — normal operation runs detection automatically
  // after every transaction sync (see banking/service.ts).
  app.post('/detection/run', { onRequest: [app.authenticate] }, async (request, reply) => {
    const result = await runDetectionForUser(request.user.sub);
    return reply.send(result);
  });
}
