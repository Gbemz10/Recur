import type { FastifyInstance } from 'fastify';
import { pool } from '../../db/client.js';

export async function healthRoutes(app: FastifyInstance) {
  app.get('/health', async () => ({ status: 'ok', time: new Date().toISOString() }));

  // Separate from /health on purpose — a load balancer's liveness probe
  // shouldn't fail just because Postgres hiccuped for a second.
  app.get('/health/db', async (request, reply) => {
    try {
      await pool.query('SELECT 1');
      return { status: 'ok' };
    } catch (error) {
      // Logged (not swallowed) so a "down" response is actually debuggable
      // from the server's own terminal instead of a dead end.
      request.log.error(error, 'Health check: database unreachable');
      return reply.status(503).send({ status: 'down' });
    }
  });
}
