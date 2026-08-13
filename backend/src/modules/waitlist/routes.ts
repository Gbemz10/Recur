import type { FastifyInstance } from 'fastify';
import { AppError } from '../../lib/errors.js';
import { rateLimit, emailKey } from '../../lib/rateLimit.js';
import { waitlistSignupSchema } from './schemas.js';
import * as waitlistService from './service.js';

// Generous IP limit (this is a public, unauthenticated endpoint anyone on
// the internet can hit) and a tighter email limit — repeat submissions of
// the same address are a no-op in the service layer anyway, this just
// blunts a script from grinding the Resend API bill via one address.
const waitlistIpLimit = rateLimit({ name: 'waitlist:join:ip', windowMs: 60 * 60 * 1000, max: 20 });
const waitlistEmailLimit = rateLimit({ name: 'waitlist:join:email', windowMs: 60 * 60 * 1000, max: 5, keyGenerator: emailKey });

export async function waitlistRoutes(app: FastifyInstance) {
  app.post('/waitlist', { preHandler: [waitlistIpLimit, waitlistEmailLimit] }, async (request, reply) => {
    const parsed = waitlistSignupSchema.safeParse(request.body);
    if (!parsed.success) {
      const first = parsed.error.issues[0];
      throw AppError.badRequest(first ? `${first.path.join('.')}: ${first.message}` : 'Invalid request body');
    }
    await waitlistService.joinWaitlist(parsed.data.email, parsed.data.source);
    return reply.send({ message: "You're on the list" });
  });
}
