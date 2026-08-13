import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import multipart from '@fastify/multipart';
import sensible from '@fastify/sensible';
import { ZodError } from 'zod';
import { env } from './config/env.js';
import { AppError } from './lib/errors.js';
import { authRoutes } from './modules/auth/routes.js';
import { subscriptionRoutes } from './modules/subscriptions/routes.js';
import { healthRoutes } from './modules/health/routes.js';
import { bankingRoutes } from './modules/banking/routes.js';
import { webhookRoutes } from './modules/webhooks/routes.js';
import { detectionRoutes } from './modules/detection/routes.js';
import { waitlistRoutes } from './modules/waitlist/routes.js';

export function buildApp() {
  const app = Fastify({
    logger:
      env.NODE_ENV === 'development'
        ? { transport: { target: 'pino-pretty', options: { colorize: true, translateTime: 'HH:MM:ss' } } }
        : true,
    // Behind a reverse proxy (Render, Railway, Fly, nginx) in production,
    // trust its X-Forwarded-For so request.ip is the real client address —
    // otherwise every request looks like it comes from the proxy itself,
    // which would make the IP-scoped rate limiters in lib/rateLimit.ts
    // useless (everyone sharing one bucket).
    trustProxy: env.NODE_ENV === 'production',
  });

  // Browser-only concern — native mobile clients don't send an Origin
  // header, so this has no bearing on the Flutter app's own requests.
  // Matters once there's a web client (Flutter web, an admin dashboard).
  app.register(cors, { origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(',').map((origin) => origin.trim()) });
  app.register(sensible);
  app.register(jwt, {
    secret: env.JWT_SECRET,
    sign: { expiresIn: env.JWT_EXPIRES_IN },
  });
  // Avatar upload is the only multipart route in the app — a 6MB cap gives
  // storage.ts's own 5MB check some headroom rather than the two limits
  // fighting over which one actually rejects an oversized file.
  app.register(multipart, { limits: { fileSize: 6 * 1024 * 1024, files: 1 } });

  // Baseline security headers without pulling in @fastify/helmet as a new
  // dependency — see lib/rateLimit.ts for why new packages are avoided
  // here for now (this project's node_modules has already broken once
  // crossing Mac/Linux, not worth risking again for headers this simple).
  app.addHook('onSend', async (_request, reply, payload) => {
    reply.header('X-Content-Type-Options', 'nosniff');
    reply.header('X-Frame-Options', 'DENY');
    reply.header('Referrer-Policy', 'no-referrer');
    reply.header('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
    if (env.NODE_ENV === 'production') {
      reply.header('Strict-Transport-Security', 'max-age=63072000; includeSubDomains');
    }
    return payload;
  });

  // Every protected route opts in with `{ onRequest: [app.authenticate] }`
  // rather than a blanket global hook — keeps auth vs. public routes
  // explicit at the call site instead of relying on a route-name convention.
  app.decorate('authenticate', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      throw AppError.unauthorized('Sign in again', 'TOKEN_INVALID');
    }
  });

  // One shape for every error response: { error: { code, message } }.
  // AppError carries both explicitly; anything else collapses to a generic
  // 500 so a stray exception never leaks internals to the client.
  app.setErrorHandler((error, request, reply) => {
    if (error instanceof AppError) {
      return reply.status(error.statusCode).send({ error: { code: error.code, message: error.message } });
    }
    if (error instanceof ZodError) {
      const first = error.issues[0];
      return reply
        .status(400)
        .send({ error: { code: 'BAD_REQUEST', message: first ? `${first.path.join('.')}: ${first.message}` : 'Invalid request' } });
    }
    // Fastify's own errors (malformed JSON, empty body with a JSON
    // content-type, payload too large, etc.) already carry a real 4xx
    // statusCode and a stable `code` — surface those as-is instead of
    // flattening every non-AppError into a 500. A client sending a bad
    // request is not a server failure, and masking it as one hides the
    // actual problem from both logs and the client.
    //
    // Narrowed via a runtime check rather than a type assertion — the
    // handler's `error` parameter is typed `unknown` in this Fastify
    // version, and every FastifyError does carry these fields at runtime.
    if (
      typeof error === 'object' &&
      error !== null &&
      'statusCode' in error &&
      typeof (error as { statusCode: unknown }).statusCode === 'number'
    ) {
      const fastifyError = error as { statusCode: number; code?: string; message?: string };
      if (fastifyError.statusCode >= 400 && fastifyError.statusCode < 500) {
        return reply
          .status(fastifyError.statusCode)
          .send({ error: { code: fastifyError.code ?? 'BAD_REQUEST', message: fastifyError.message ?? 'Bad request' } });
      }
    }
    request.log.error(error);
    return reply.status(500).send({ error: { code: 'INTERNAL', message: 'Something went wrong' } });
  });

  app.register(healthRoutes);
  app.register(authRoutes);
  app.register(subscriptionRoutes);
  app.register(bankingRoutes);
  app.register(webhookRoutes);
  app.register(detectionRoutes);
  app.register(waitlistRoutes);

  return app;
}
