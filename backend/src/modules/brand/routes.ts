import type { FastifyInstance } from 'fastify';
import { RECUR_MARK_PNG_BASE64 } from '../../lib/emailAssets.js';

/**
 * The brand mark, served over HTTP for transactional email.
 *
 * Email used to embed this as a `data:` URI. That renders in Apple Mail and
 * almost nowhere else: Gmail, Outlook.com and Yahoo all strip `data:` image
 * sources, so for most recipients every Recur email arrived with a broken
 * image where the logo should be. Mail clients will happily fetch an https
 * URL, and this backend is already public, so it hosts it.
 *
 * Decoded once at module load rather than per request — it is a fixed asset a
 * few kilobytes long, and every send references it.
 */
const MARK_PNG = Buffer.from(RECUR_MARK_PNG_BASE64, 'base64');

export async function brandRoutes(app: FastifyInstance) {
  app.get('/brand/mark.png', async (_request, reply) => {
    return reply
      .type('image/png')
      // A year, and immutable: the file only changes if the brand does, and
      // then it changes name. Gmail proxies and caches images itself, so a
      // short TTL here buys nothing and costs a fetch per open.
      .header('Cache-Control', 'public, max-age=31536000, immutable')
      .header('Content-Length', String(MARK_PNG.length))
      .send(MARK_PNG);
  });
}
