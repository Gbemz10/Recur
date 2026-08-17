import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import { env } from '../config/env.js';
import * as schema from './schema.js';

/**
 * One connection pool for the whole process. `pg.Pool` connects lazily —
 * nothing hits the network until the first query runs, so the server can
 * boot even if Postgres isn't reachable yet (useful for local dev where
 * the DB container starts a beat after the app does).
 *
 * `max`/`connectionTimeoutMillis` are set explicitly rather than left on
 * `pg`'s defaults (`max: 10` is fine, but `connectionTimeoutMillis`
 * defaults to 0 — no timeout at all). Under a traffic spike that exhausts
 * the pool, an unbounded wait means every new request queues silently
 * behind whichever queries are already running, and the whole app just
 * stalls instead of failing fast. A finite timeout turns that into a
 * clean 500 for the caller instead of a hang.
 */
export const pool = new Pool({
  connectionString: env.DATABASE_URL,
  max: 10,
  connectionTimeoutMillis: 5_000,
  idleTimeoutMillis: 30_000,
});

export const db = drizzle(pool, { schema });
