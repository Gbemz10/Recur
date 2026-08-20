/**
 * Builds a self-contained demo account: one user, one linked bank, six months
 * of realistic Nigerian transaction history, and everything the app renders
 * downstream of that.
 *
 * Why a separate user rather than seeding a real one: demo data and a person's
 * actual bank history must never share an account. Everything here hangs off a
 * single email, so signing in as anyone else shows none of it, and the whole
 * fixture can be rebuilt or dropped without touching real records.
 *
 * Nothing is hand-written into the app. Transactions go into `raw_transactions`
 * — the same table a Mono sync writes to — and then the real categorizer and
 * the real detection engine run over them. The subscriptions, the spending
 * breakdown, the six-month trend and the calendar are all genuine output of the
 * pipeline, so a demo shows the product working rather than a mockup of it.
 *
 * Re-running is safe: it clears this demo user's own rows first, then rebuilds.
 *
 * Usage:
 *   npm run db:seed-demo
 */
import { randomUUID } from 'node:crypto';
import { eq, and } from 'drizzle-orm';
import { db, pool } from './client.js';
import {
  users,
  linkedBanks,
  rawTransactions,
  subscriptions,
  merchants,
  trialReminders,
  budgets,
} from './schema.js';
import { hashPassword } from '../lib/password.js';
import { runDetectionForUser } from '../modules/detection/service.js';
import { categorizeTransactionsForUser } from '../modules/spending/categorize.js';

const DEMO_EMAIL = 'demo@recur.website';
const DEMO_NAME = 'Ada Okonkwo';

/**
 * The demo password, from `DEMO_PASSWORD` with a development-only fallback.
 *
 * The fallback is committed, so treat it as public: anyone with the repo knows
 * it. That is acceptable for a local fixture and unacceptable anywhere real,
 * which is what [assertSafeTarget] is for. Set `DEMO_PASSWORD` in the
 * environment to use something that is not in git history.
 */
const DEMO_PASSWORD = process.env.DEMO_PASSWORD ?? 'RecurDemo2026';

/**
 * Refuses to run anywhere that looks like production.
 *
 * This script creates a fully verified account whose password is published in
 * this file. Against a real database that is an unauthorised login, so the rule
 * cannot be "remember not to do that" — it has to be enforced by the thing
 * doing the writing, at the moment it would write.
 *
 * Two independent checks, because either signal alone can be wrong: NODE_ENV is
 * easy to leave unset, and a hosted database URL is easy to point at while
 * NODE_ENV still says development.
 */
function assertSafeTarget() {
  const env = process.env.NODE_ENV ?? 'development';
  const url = process.env.DATABASE_URL ?? '';
  const override = process.env.ALLOW_DEMO_SEED === 'yes-i-am-sure';

  const reasons: string[] = [];
  if (env === 'production') reasons.push(`NODE_ENV is "${env}"`);

  // Managed Postgres hosts people actually deploy Recur against. A local or
  // Docker database never matches these.
  const hostedPattern = /(render\.com|amazonaws\.com|neon\.tech|railway\.app|heroku|fly\.dev|azure\.com)/i;
  const host = url.replace(/^[^@]*@/, '');
  if (hostedPattern.test(host)) {
    reasons.push('DATABASE_URL points at a managed host');
  }
  if (/[?&]sslmode=require/i.test(url) && env === 'production') {
    reasons.push('DATABASE_URL requires SSL under a production NODE_ENV');
  }

  if (reasons.length === 0) return;

  if (override) {
    console.warn(`WARNING: seeding a demo account despite ${reasons.join(' and ')}.`);
    console.warn('This creates a known-password account. Delete it when the demo is over.');
    return;
  }

  console.error('Refusing to seed the demo account.');
  for (const reason of reasons) console.error(`  - ${reason}`);
  console.error('');
  console.error('This script creates a verified user whose password is committed to the repo.');
  console.error('If you genuinely mean to do this, set ALLOW_DEMO_SEED=yes-i-am-sure,');
  console.error('and set DEMO_PASSWORD to something that is not in git history.');
  process.exit(1);
}

/** `days` ago, at a fixed hour so ordering is stable across runs. */
function daysAgo(days: number): Date {
  const d = new Date();
  d.setDate(d.getDate() - days);
  d.setHours(11, 30, 0, 0);
  return d;
}

/**
 * A recurring merchant, expressed the way a bank statement would show it.
 *
 * `everyDays` is the true cadence and `count` how many charges to lay down, so
 * detection measures a real interval instead of being told one. `startedDaysAgo`
 * anchors the most recent charge — staggering these is what gives the calendar
 * and "Up next" a spread of dates rather than one crowded day.
 */
interface RecurringSeed {
  /** Merchant slug the detector should resolve this to, or null when the
   *  narration matches nothing in the merchants table. */
  slug: string | null;
  narration: string;
  amount: number;
  everyDays: number;
  count: number;
  startedDaysAgo: number;
  /** Where it should end up once the user has been through the review flow. */
  status: 'ACTIVE' | 'UNREVIEWED' | 'CANCELLED';
}

const recurring: RecurringSeed[] = [
  // --- confirmed, still running -------------------------------------------
  { slug: 'netflix', narration: 'NETFLIX.COM NGN CARD DEBIT', amount: 7000, everyDays: 30, count: 6, startedDaysAgo: 26, status: 'ACTIVE' },
  { slug: 'spotify', narration: 'SPOTIFY P17A9C NGN', amount: 1300, everyDays: 30, count: 6, startedDaysAgo: 23, status: 'ACTIVE' },
  { slug: 'dstv', narration: 'MULTICHOICE NIG DSTV SUB', amount: 19000, everyDays: 30, count: 5, startedDaysAgo: 28, status: 'ACTIVE' },
  { slug: 'mtn', narration: 'MTNNG DATA AUTORENEW', amount: 10000, everyDays: 30, count: 6, startedDaysAgo: 29, status: 'ACTIVE' },
  { slug: 'openai', narration: 'OPENAI *CHATGPT USD', amount: 32000, everyDays: 30, count: 4, startedDaysAgo: 21, status: 'ACTIVE' },

  // A yearly plan, so the "₦x/mo" normalisation on the tile has something to do.
  { slug: 'canva', narration: 'CANVA* I05LM2 SYDNEY AU', amount: 64000, everyDays: 365, count: 2, startedDaysAgo: 40, status: 'ACTIVE' },

  // --- detected, awaiting the user's yes/no --------------------------------
  // Fewer charges and a looser cadence, which is what actually drives
  // computeConfidence down and lands them in Review.
  { slug: 'showmax', narration: 'SHOWMAX NG RECURRING', amount: 3500, everyDays: 31, count: 3, startedDaysAgo: 14, status: 'UNREVIEWED' },
  { slug: 'ifitness', narration: 'IFITNESS LEKKI POS', amount: 25000, everyDays: 33, count: 2, startedDaysAgo: 17, status: 'UNREVIEWED' },

  // --- stopped charging, still marked active --------------------------------
  //
  // The case the product exists for, and the one a projected date cannot show
  // you: six monthly charges that ended five months ago. The backend's
  // projectNextChargeDate walks forward in whole cycles until it lands in the
  // future, so this still reports a date next week and still counts toward
  // the monthly total. Only reading the charge history reveals it.
  //
  // Seeded deliberately, because a demo whose data is uniformly healthy cannot
  // show the one thing worth showing.
  { slug: 'bolt', narration: 'BOLT.EU RIDE PASS NG', amount: 8500, everyDays: 30, count: 6, startedDaysAgo: 152, status: 'ACTIVE' },

  // --- cancelled ------------------------------------------------------------
  { slug: 'apple', narration: 'APPLE.COM/BILL ITUNES', amount: 1100, everyDays: 30, count: 4, startedDaysAgo: 35, status: 'CANCELLED' },
];

/**
 * Everything else the money went on. This is what fills the Spending tab: the
 * donut needs more than one category to be a donut, and the six-month trend
 * needs months behind the current one.
 *
 * Narrations are chosen to exercise the real keyword rules in
 * modules/spending/categorize.ts rather than to be labelled directly.
 */
const oneOff: { narration: string; amount: number; daysAgo: number }[] = [
  // Food & groceries
  { narration: 'POS PURCHASE SHOPRITE LEKKI', amount: 42500, daysAgo: 4 },
  { narration: 'CHOWDECK ORDER LAGOS', amount: 8900, daysAgo: 2 },
  { narration: 'PRINCE EBEANO SUPERMARKET', amount: 63200, daysAgo: 12 },
  { narration: 'CHICKEN REPUBLIC IKEJA', amount: 6500, daysAgo: 9 },
  { narration: 'POS PURCHASE SPAR VI', amount: 38700, daysAgo: 38 },
  { narration: 'CHOWDECK ORDER LAGOS', amount: 19400, daysAgo: 47 },
  { narration: 'MARKET SQUARE YABA', amount: 51400, daysAgo: 68 },
  { narration: 'THE PLACE RESTAURANT', amount: 14800, daysAgo: 74 },

  // Transport
  { narration: 'BOLT RIDE LAGOS NG', amount: 4200, daysAgo: 1 },
  { narration: 'BOLT RIDE LAGOS NG', amount: 9700, daysAgo: 6 },
  { narration: 'NNPC FILLING STATION', amount: 35000, daysAgo: 11 },
  { narration: 'UBER TRIP NG', amount: 5600, daysAgo: 19 },
  { narration: 'TOTAL ENERGIES PMS', amount: 40000, daysAgo: 44 },
  { narration: 'AIR PEACE FLIGHT LOS ABV', amount: 128000, daysAgo: 55 },
  { narration: 'BOLT RIDE LAGOS NG', amount: 15300, daysAgo: 79 },

  // Bills & utilities
  { narration: 'EKEDC PREPAID METER', amount: 25000, daysAgo: 8 },
  { narration: 'SPECTRANET INTERNET', amount: 21000, daysAgo: 15 },
  { narration: 'EKEDC PREPAID METER', amount: 30000, daysAgo: 40 },
  { narration: 'LAWMA WASTE LEVY', amount: 6000, daysAgo: 52 },
  { narration: 'STARLINK NG MONTHLY', amount: 38000, daysAgo: 71 },

  // Shopping
  { narration: 'JUMIA ONLINE ORDER', amount: 47000, daysAgo: 7 },
  { narration: 'SLOT SYSTEMS IKEJA', amount: 185000, daysAgo: 33 },
  { narration: 'KONGA ONLINE NG', amount: 22400, daysAgo: 61 },

  // Health
  { narration: 'MEDPLUS PHARMACY VI', amount: 18500, daysAgo: 16 },
  { narration: 'RELIANCE HEALTH HMO', amount: 45000, daysAgo: 49 },

  // Savings & investments
  { narration: 'PIGGYVEST AUTOSAVE', amount: 50000, daysAgo: 5 },
  { narration: 'PIGGYVEST AUTOSAVE', amount: 50000, daysAgo: 35 },
  { narration: 'RISEVEST FUNDING', amount: 75000, daysAgo: 36 },
  { narration: 'COWRYWISE PLAN', amount: 30000, daysAgo: 66 },

  // Loans
  { narration: 'CARBON LOAN REPAYMENT', amount: 27500, daysAgo: 13 },
  { narration: 'CARBON LOAN REPAYMENT', amount: 27500, daysAgo: 73 },

  // Education
  { narration: 'UDEMY COURSE PURCHASE', amount: 14000, daysAgo: 27 },
  { narration: 'ALTSCHOOL AFRICA TUITION', amount: 95000, daysAgo: 58 },

  // Transfers, which is what most Nigerian statements are mostly made of.
  { narration: 'NIP TRANSFER TO CHIOMA GTB', amount: 35000, daysAgo: 3 },
  { narration: 'NIP TRANSFER TO EMEKA UBA', amount: 20000, daysAgo: 18 },
  { narration: 'ATM WITHDRAWAL LEKKI', amount: 40000, daysAgo: 24 },
  { narration: 'NIP TRANSFER TO TUNDE OPAY', amount: 60000, daysAgo: 41 },
  { narration: 'ATM WITHDRAWAL IKOYI', amount: 120000, daysAgo: 63 },

  // Months three to six back. Without these the trend chart cliffs: the older
  // months would contain nothing but the subscriptions, so the six-month
  // comparison would read as an explosion in spending rather than a person
  // living a normal life the whole time.
  { narration: 'POS PURCHASE SHOPRITE LEKKI', amount: 47800, daysAgo: 96 },
  { narration: 'PRINCE EBEANO SUPERMARKET', amount: 58300, daysAgo: 118 },
  { narration: 'KILIMANJARO RESTAURANT', amount: 12600, daysAgo: 131 },
  { narration: 'MARKET SQUARE YABA', amount: 44900, daysAgo: 152 },
  { narration: 'CHOWDECK ORDER LAGOS', amount: 7300, daysAgo: 167 },
  { narration: 'MOBIL FILLING STATION', amount: 32000, daysAgo: 101 },
  { narration: 'UBER TRIP NG', amount: 6800, daysAgo: 124 },
  { narration: 'TOTAL ENERGIES PMS', amount: 37500, daysAgo: 158 },
  { narration: 'EKEDC PREPAID METER', amount: 28000, daysAgo: 99 },
  { narration: 'SPECTRANET INTERNET', amount: 21000, daysAgo: 129 },
  { narration: 'EKEDC PREPAID METER', amount: 22500, daysAgo: 160 },
  { narration: 'JUMIA ONLINE ORDER', amount: 68400, daysAgo: 112 },
  { narration: 'SLOT SYSTEMS IKEJA', amount: 96000, daysAgo: 145 },
  { narration: 'MEDPLUS PHARMACY VI', amount: 16200, daysAgo: 137 },
  { narration: 'PIGGYVEST AUTOSAVE', amount: 50000, daysAgo: 95 },
  { narration: 'PIGGYVEST AUTOSAVE', amount: 50000, daysAgo: 125 },
  { narration: 'PIGGYVEST AUTOSAVE', amount: 50000, daysAgo: 155 },
  { narration: 'CARBON LOAN REPAYMENT', amount: 27500, daysAgo: 103 },
  { narration: 'CARBON LOAN REPAYMENT', amount: 27500, daysAgo: 133 },
  { narration: 'NIP TRANSFER TO CHIOMA GTB', amount: 45000, daysAgo: 107 },
  { narration: 'NIP TRANSFER TO EMEKA UBA', amount: 72000, daysAgo: 141 },
  { narration: 'ATM WITHDRAWAL LEKKI', amount: 80000, daysAgo: 163 },
  { narration: 'UNILAG PART TIME FEES', amount: 62000, daysAgo: 148 },
];

/** Trials, so that tab has something to say too. */
const trials: { slug: string | null; label: string; endsInDays: number }[] = [
  { slug: 'showmax', label: 'Showmax Premier League', endsInDays: 3 },
  { slug: 'canva', label: 'Canva Pro', endsInDays: 11 },
  { slug: null, label: 'Audiomack Premium', endsInDays: 26 },
];

/** A couple of caps, so the Spending tab shows budget meters rather than none. */
const demoBudgets: { category: 'FOOD' | 'TRANSPORT' | 'SHOPPING'; limit: number }[] = [
  { category: 'FOOD', limit: 150000 },
  { category: 'TRANSPORT', limit: 60000 },
  { category: 'SHOPPING', limit: 100000 },
];

async function main() {
  assertSafeTarget();
  console.log(`Building demo account for ${DEMO_EMAIL}...`);

  // ---- user -------------------------------------------------------------
  const [existing] = await db.select().from(users).where(eq(users.email, DEMO_EMAIL)).limit(1);

  let userId: string;
  if (existing) {
    userId = existing.id;
    // Rebuild from clean rather than layering a second set of transactions on
    // top of the first, which would double every amount on the Spending tab.
    console.log('Demo user exists — clearing its previous fixture...');
    // charge_records cascades from subscriptions, so it needs no pass of its own.
    await db.delete(subscriptions).where(eq(subscriptions.userId, userId));
    await db.delete(rawTransactions).where(eq(rawTransactions.userId, userId));
    await db.delete(trialReminders).where(eq(trialReminders.userId, userId));
    await db.delete(budgets).where(eq(budgets.userId, userId));
    await db
      .update(users)
      .set({
        passwordHash: await hashPassword(DEMO_PASSWORD),
        displayName: DEMO_NAME,
        emailVerifiedAt: new Date(),
        updatedAt: new Date(),
      })
      .where(eq(users.id, userId));
  } else {
    const [created] = await db
      .insert(users)
      .values({
        email: DEMO_EMAIL,
        passwordHash: await hashPassword(DEMO_PASSWORD),
        displayName: DEMO_NAME,
        // Pre-verified: the demo should not be gated behind an OTP email.
        emailVerifiedAt: new Date(),
        // Backdated so Profile reads "Member since" rather than today.
        createdAt: daysAgo(214),
      })
      .returning({ id: users.id });
    userId = created!.id;
  }

  // ---- linked bank ------------------------------------------------------
  // Marked provider 'demo' so nothing mistakes it for a Mono account and tries
  // to sync it. Transactions are written directly below instead.
  let [bank] = await db
    .select()
    .from(linkedBanks)
    .where(and(eq(linkedBanks.userId, userId), eq(linkedBanks.provider, 'demo')))
    .limit(1);

  if (!bank) {
    const [createdBank] = await db
      .insert(linkedBanks)
      .values({
        userId,
        provider: 'demo',
        bankName: 'Guaranty Trust Bank',
        bankCode: '058',
        accountNumberMask: '••••4417',
        providerAccountId: `demo_${randomUUID()}`,
        providerToken: 'demo-no-token',
        status: 'ACTIVE',
        linkedAt: daysAgo(212),
        lastSyncedAt: new Date(),
      })
      .returning();
    bank = createdBank!;
  } else {
    await db.update(linkedBanks).set({ lastSyncedAt: new Date() }).where(eq(linkedBanks.id, bank.id));
  }

  // ---- transactions -----------------------------------------------------
  const rows: (typeof rawTransactions.$inferInsert)[] = [];

  for (const seed of recurring) {
    for (let i = 0; i < seed.count; i++) {
      rows.push({
        linkedBankId: bank.id,
        userId,
        monoTransactionId: `demo_${randomUUID()}`,
        narration: seed.narration,
        amount: seed.amount.toFixed(2),
        type: 'DEBIT',
        date: daysAgo(seed.startedDaysAgo + i * seed.everyDays),
      });
    }
  }

  for (const seed of oneOff) {
    rows.push({
      linkedBankId: bank.id,
      userId,
      monoTransactionId: `demo_${randomUUID()}`,
      narration: seed.narration,
      amount: seed.amount.toFixed(2),
      type: 'DEBIT',
      date: daysAgo(seed.daysAgo),
    });
  }

  // Salary credits, so the account does not read as money leaving a void. These
  // are CREDITs and so are excluded from every spend total by construction.
  for (let i = 0; i < 6; i++) {
    rows.push({
      linkedBankId: bank.id,
      userId,
      monoTransactionId: `demo_${randomUUID()}`,
      narration: 'SALARY PAYMENT - PAYSTACK PAYROLL',
      amount: '850000.00',
      type: 'CREDIT',
      date: daysAgo(25 + i * 30),
    });
  }

  await db.insert(rawTransactions).values(rows);
  console.log(`Inserted ${rows.length} raw transactions.`);

  // ---- the real pipeline ------------------------------------------------
  const [{ categorized }, detection] = await Promise.all([
    categorizeTransactionsForUser(userId),
    runDetectionForUser(userId),
  ]);
  console.log(`Categorized ${categorized} transactions.`);
  console.log(`Detection found ${detection.clustersFound} recurring clusters.`);

  // ---- review outcomes --------------------------------------------------
  // Detection files everything as UNREVIEWED, which is correct — it has no idea
  // what the user decided. Replaying those decisions is what gives Active,
  // Review and Cancelled each something in them.
  const detected = await db.select().from(subscriptions).where(eq(subscriptions.userId, userId));

  // Match on the merchant the detector resolved, not on display text. Comparing
  // narration prefixes to display names silently missed DStv (narration says
  // MULTICHOICE) and ChatGPT (narration says OPENAI), leaving both stranded in
  // Review — the failure mode of matching two strings that were never the same
  // string to begin with.
  const merchantRows = await db.select().from(merchants);
  const slugById = new Map(merchantRows.map((m) => [m.id, m.slug]));

  // Standing commitments the detector finds from narration alone, with no
  // merchant row behind them. Worth confirming in the fixture because they are
  // the more interesting half of the product's claim: anyone can spot Netflix,
  // but a savings plan and a loan repayment are money leaving on a schedule
  // that people genuinely lose track of.
  const confirmedByName = ['PIGGYVEST', 'CARBON'];

  for (const sub of detected) {
    const slug = sub.merchantId ? slugById.get(sub.merchantId) : null;
    const match = slug ? recurring.find((seed) => seed.slug === slug) : undefined;
    const named = confirmedByName.some((n) => sub.displayName.toUpperCase().includes(n));
    const status = match?.status ?? (named ? 'ACTIVE' : 'UNREVIEWED');
    if (status !== 'UNREVIEWED') {
      await db.update(subscriptions).set({ status }).where(eq(subscriptions.id, sub.id));
    }
  }

  const finalCounts = await db.select().from(subscriptions).where(eq(subscriptions.userId, userId));
  const tally = finalCounts.reduce<Record<string, number>>((acc, s) => {
    acc[s.status] = (acc[s.status] ?? 0) + 1;
    return acc;
  }, {});

  // ---- trials and budgets ------------------------------------------------
  await db.insert(trialReminders).values(
    trials.map((t) => ({
      userId,
      merchantSlug: t.slug,
      label: t.label,
      trialEndsAt: daysAgo(-t.endsInDays),
    })),
  );

  await db.insert(budgets).values(
    demoBudgets.map((b) => ({ userId, category: b.category, monthlyLimit: b.limit.toFixed(2) })),
  );

  console.log('');
  console.log('  Demo account ready');
  console.log('  ------------------------------------------');
  console.log(`  Email:    ${DEMO_EMAIL}`);
  console.log(`  Password: ${DEMO_PASSWORD}`);
  console.log('  ------------------------------------------');
  console.log(`  Subscriptions: ${JSON.stringify(tally)}`);
  console.log(`  Trials: ${trials.length}   Budgets: ${demoBudgets.length}`);
  console.log('');
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
