import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError } from '../../lib/errors.js';
import * as subscriptionService from './service.js';

const updateStatusSchema = z.object({
  status: z.enum(['unreviewed', 'active', 'cancelled']),
});

export async function subscriptionRoutes(app: FastifyInstance) {
  app.get('/subscriptions', { onRequest: [app.authenticate] }, async (request, reply) => {
    const subscriptions = await subscriptionService.listSubscriptions(request.user.sub);
    return reply.send({ subscriptions });
  });

  app.patch('/subscriptions/:id/status', { onRequest: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const parsed = updateStatusSchema.safeParse(request.body);
    if (!parsed.success) {
      const first = parsed.error.issues[0];
      throw AppError.badRequest(first ? first.message : 'Invalid request body');
    }
    const subscription = await subscriptionService.updateSubscriptionStatus(request.user.sub, id, parsed.data.status);
    return reply.send({ subscription });
  });
}
