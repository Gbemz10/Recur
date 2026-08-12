import type { FastifyReply, FastifyRequest } from 'fastify';
import '@fastify/jwt';

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: { sub: string; email: string };
    user: { sub: string; email: string };
  }
}

declare module 'fastify' {
  interface FastifyInstance {
    /** onRequest guard: verifies the bearer token or throws 401. */
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
}
