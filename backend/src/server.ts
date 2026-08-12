import closeWithGrace from 'close-with-grace';
import { buildApp } from './app.js';
import { env } from './config/env.js';
import { pool } from './db/client.js';

const app = buildApp();

closeWithGrace({ delay: 5000 }, async ({ err }) => {
  if (err) app.log.error(err);
  await app.close();
  await pool.end();
});

try {
  await app.listen({ port: env.PORT, host: '0.0.0.0' });
} catch (error) {
  app.log.error(error);
  process.exit(1);
}
