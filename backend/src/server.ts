import closeWithGrace from 'close-with-grace';
import { buildApp } from './app.js';
import { env } from './config/env.js';
import { pool } from './db/client.js';
import {
  startNotificationScheduler,
  stopNotificationScheduler,
} from './modules/notifications/scheduler.js';

const app = buildApp();

closeWithGrace({ delay: 5000 }, async ({ err }) => {
  if (err) app.log.error(err);
  // `pool.end()` must run even if `app.close()` throws mid-shutdown —
  // otherwise a failed close leaves the Postgres pool (and its open
  // connections) dangling for the process's remaining lifetime instead of
  // actually releasing them.
  stopNotificationScheduler();
  try {
    await app.close();
  } catch (closeError) {
    app.log.error(closeError, 'Error while closing Fastify during shutdown');
  } finally {
    await pool.end();
  }
});

try {
  await app.listen({ port: env.PORT, host: '0.0.0.0' });
  startNotificationScheduler();
} catch (error) {
  app.log.error(error);
  process.exit(1);
}
