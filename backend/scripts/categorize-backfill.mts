// One-off backfill: categorize every existing transaction for every user who
// has any. Exists because the spending feature shipped after these rows were
// already synced from Mono, so nothing would categorize them until the next
// webhook fired. Safe to re-run: the categorizer only touches rows whose
// source is null, RULE or MONO, never USER.
import 'dotenv/config';
import { sql } from 'drizzle-orm';
import { db, pool } from '../src/db/client.js';
import { categorizeTransactionsForUser } from '../src/modules/spending/categorize.js';

async function main() {
  const users = await db.execute(
    sql`select user_id, count(*)::int n from raw_transactions group by user_id order by n desc`,
  );

  for (const u of users.rows as { user_id: string; n: number }[]) {
    const result = await categorizeTransactionsForUser(u.user_id);
    console.log(`user ${u.user_id.slice(0, 8)}  txns ${u.n}  ->  categorized ${result.categorized}`);
  }

  const dist = await db.execute(sql`
    select spend_category, category_source, count(*)::int n
    from raw_transactions group by 1, 2 order by n desc
  `);
  console.log('\ndistribution:');
  for (const r of dist.rows as { spend_category: string | null; category_source: string | null; n: number }[]) {
    console.log(`   ${String(r.spend_category ?? 'UNCATEGORIZED').padEnd(14)} ${String(r.category_source ?? '-').padEnd(5)} ${r.n}`);
  }

  const sample = await db.execute(sql`
    select narration, payee, spend_category from raw_transactions
    where spend_category = 'OTHER' limit 12
  `);
  console.log('\nsample of what landed in OTHER (the tuning signal):');
  for (const r of sample.rows as { narration: string; payee: string }[]) {
    console.log(`   ${String(r.payee).padEnd(22)} | ${String(r.narration).slice(0, 60)}`);
  }

  await pool.end();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
