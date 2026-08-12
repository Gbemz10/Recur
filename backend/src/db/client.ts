import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import { env } from '../config/env.js';
import * as schema from './schema.js';

/**
 * One connection pool for the whole process. `pg.Pool` connects lazily —
 * nothing hits the network until the first query runs, so the server can
 * boot even if Postgres isn't reachable yet (useful for local dev where
 * the DB container starts a beat after the app does).
 */
export const pool = new Pool({ connectionString: env.DATABASE_URL });

export const db = drizzle(pool, { schema });
