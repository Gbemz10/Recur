/**
 * Refreshes the merchant reference table only: slugs, names, brand colours,
 * trial-prone flags and cancellation steps.
 *
 * Touches no user, no subscription and no transaction, so it is safe to run
 * against any environment. That matters here, because dev and production
 * currently share one database.
 *
 * Usage: npm run db:seed-merchants
 */
import { pool } from './client.js';
import { seedMerchants } from './merchantSeeds.js';

const count = await seedMerchants();
console.log(`Upserted ${count} merchants.`);
await pool.end();
