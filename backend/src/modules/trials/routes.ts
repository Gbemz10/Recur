import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError } from '../../lib/errors.js';
import { rateLimit } from '../../lib/rateLimit.js';
import * as trialsService from './service.js';

const createTrialReminderSchema = z.object({
  label: z.string().trim().min(1).max(80),
  trialEndsAt: z.string().datetime({ offset: true }).or(z.string().datetime()),
  merchantSlug: z.string().trim().min(1).max(80).nullable().optional(),
});

// Generous, but still bounded — nothing here should be hit hard enough to
// need it, this is just a floor against a runaway client.
const createLimit = rateLimit({ name: 'trials:create:user', windowMs: 60 * 1000, max: 20, keyGenerator: (r) => r.user.sub });

export async function trialRoutes(app: FastifyInstance) {
  app.get('/trials', { onRequest: [app.authenticate] }, async (request, reply) => {
    const trialReminders = await trialsService.listTrialReminders(request.user.sub);
    return reply.send({ trialReminders });
  });

  app.post('/trials', { onRequest: [app.authenticate], preHandler: [createLimit] }, async (request, reply) => {
    const parsed = createTrialReminderSchema.safeParse(request.body);
    if (!parsed.success) {
      const first = parsed.error.issues[0];
      throw AppError.badRequest(first ? first.message : 'Invalid request body');
    }
    const trialReminder = await trialsService.createTrialReminder(request.user.sub, {
      label: parsed.data.label,
      trialEndsAt: new Date(parsed.data.trialEndsAt),
      merchantSlug: parsed.data.merchantSlug ?? null,
    });
    return reply.status(201).send({ trialReminder });
  });

  app.patch('/trials/:id/dismiss', { onRequest: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const trialReminder = await trialsService.dismissTrialReminder(request.user.sub, id);
    return reply.send({ trialReminder });
  });
}
