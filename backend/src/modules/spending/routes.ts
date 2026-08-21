import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AppError } from '../../lib/errors.js';
import { rateLimit } from '../../lib/rateLimit.js';
import * as spendingService from './service.js';
import { categorizeTransactionsForUser } from './categorize.js';

const periodSchema = z
  .string()
  .regex(/^\d{4}-\d{2}$/, 'Period must look like 2026-08')
  .optional();

const recategorizeSchema = z.object({
  category: z.string().trim().min(1),
  // The "also apply this to future charges from here" prompt in the sheet.
  // Defaults to false: silently creating standing rules from a single tap
  // would be a surprising amount of behaviour to infer from one correction.
  applyToFuture: z.boolean().optional().default(false),
});

const setBudgetSchema = z.object({
  category: z.string().trim().min(1),
  // Capped well above any realistic monthly category budget in naira, purely
  // so a fat-fingered entry cannot overflow the numeric(12,2) column.
  monthlyLimit: z.number().positive().max(999_999_999),
});

const recategorizeLimit = rateLimit({
  name: 'spending:recategorize:user',
  windowMs: 60 * 1000,
  max: 60,
  keyGenerator: (r) => r.user.sub,
});

export async function spendingRoutes(app: FastifyInstance) {
  /** This month's total and per-category breakdown, with budgets folded in. */
  app.get('/spending/summary', { onRequest: [app.authenticate] }, async (request, reply) => {
    const query = request.query as { period?: string };
    const parsed = periodSchema.safeParse(query.period);
    if (!parsed.success) throw AppError.badRequest('Period must look like 2026-08', 'BAD_PERIOD');

    const summary = await spendingService.getSpendingSummary(
      request.user.sub,
      parsed.data ?? spendingService.currentPeriod(),
    );
    return reply.send(summary);
  });

  /** The transactions behind a category, for the tap-through from the breakdown. */
  app.get('/spending/transactions', { onRequest: [app.authenticate] }, async (request, reply) => {
    const query = request.query as {
      period?: string;
      category?: string;
      limit?: string;
      offset?: string;
    };
    const parsed = periodSchema.safeParse(query.period);
    if (!parsed.success) throw AppError.badRequest('Period must look like 2026-08', 'BAD_PERIOD');

    const page = await spendingService.listTransactions(request.user.sub, {
      period: parsed.data ?? spendingService.currentPeriod(),
      category: query.category,
      limit: query.limit ? Number(query.limit) : undefined,
      offset: query.offset ? Number(query.offset) : undefined,
    });
    return reply.send(page);
  });

  app.patch(
    '/spending/transactions/:id/category',
    { onRequest: [app.authenticate], preHandler: [recategorizeLimit] },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const parsed = recategorizeSchema.safeParse(request.body);
      if (!parsed.success) {
        const first = parsed.error.issues[0];
        throw AppError.badRequest(first ? first.message : 'Invalid request body');
      }

      const result = await spendingService.recategorizeTransaction(
        request.user.sub,
        id,
        parsed.data.category,
        parsed.data.applyToFuture,
      );
      return reply.send(result);
    },
  );

  /** The category list, so the client never hardcodes a taxonomy the server owns. */
  app.get('/spending/categories', { onRequest: [app.authenticate] }, async (_request, reply) => {
    return reply.send({ categories: spendingService.SPEND_CATEGORIES.map((c) => c.toLowerCase()) });
  });

  /**
   * Re-runs the categorizer over this user's transactions. Exists for the
   * same reason POST /detection/run does: a user who linked a bank before
   * this feature shipped has a full history of uncategorized rows, and this
   * is what backfills them without waiting for the next Mono webhook.
   */
  app.post('/spending/categorize', { onRequest: [app.authenticate] }, async (request, reply) => {
    const result = await categorizeTransactionsForUser(request.user.sub);
    return reply.send(result);
  });

  // ---------------------------------------------------------------- budgets

  app.get('/budgets', { onRequest: [app.authenticate] }, async (request, reply) => {
    const budgets = await spendingService.listBudgets(request.user.sub);
    return reply.send({ budgets });
  });

  app.put('/budgets', { onRequest: [app.authenticate] }, async (request, reply) => {
    const parsed = setBudgetSchema.safeParse(request.body);
    if (!parsed.success) {
      const first = parsed.error.issues[0];
      throw AppError.badRequest(first ? first.message : 'Invalid request body');
    }
    const budget = await spendingService.setBudget(
      request.user.sub,
      parsed.data.category,
      parsed.data.monthlyLimit,
    );
    return reply.send({ budget });
  });

  app.delete('/budgets/:category', { onRequest: [app.authenticate] }, async (request, reply) => {
    const { category } = request.params as { category: string };
    await spendingService.deleteBudget(request.user.sub, category);
    return reply.status(204).send();
  });
}
