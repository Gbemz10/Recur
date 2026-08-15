import argon2 from 'argon2';
import { eq } from 'drizzle-orm';
import { db, pool } from './client.js';
import { users, merchants, subscriptions, chargeRecords } from './schema.js';

// Mirrors lib/data/merchants.dart on the client — same slugs, same colors,
// so a bundled logo asset on either side resolves the same way.
// `trialProne: true` marks merchants known to run free-trial-then-charge
// signups — the detection engine's single-occurrence trial heuristic (see
// detection/service.ts) only ever fires for these, so it doesn't start
// flagging every one-off debit as a "possible trial."
const merchantSeeds = [
  { slug: 'netflix', name: 'Netflix', domain: 'netflix.com', brandColor: '#E50914', category: 'STREAMING' as const, trialProne: true },
  { slug: 'dstv', name: 'DStv', domain: 'dstv.com', brandColor: '#0072CE', category: 'STREAMING' as const, trialProne: false },
  { slug: 'mtn', name: 'MTN', domain: 'mtn.ng', brandColor: '#FFCB05', category: 'TELECOM' as const, trialProne: false },
  { slug: 'spotify', name: 'Spotify', domain: 'spotify.com', brandColor: '#1DB954', category: 'STREAMING' as const, trialProne: true },
  { slug: 'openai', name: 'ChatGPT Plus', domain: 'openai.com', brandColor: '#10A37F', category: 'SOFTWARE' as const, trialProne: true },
  { slug: 'canva', name: 'Canva', domain: 'canva.com', brandColor: '#7D2AE8', category: 'SOFTWARE' as const, trialProne: true },
  { slug: 'showmax', name: 'Showmax', domain: 'showmax.com', brandColor: '#E10098', category: 'STREAMING' as const, trialProne: true },
  { slug: 'apple', name: 'Apple iCloud', domain: 'apple.com', brandColor: '#555555', category: 'SOFTWARE' as const, trialProne: false },
  { slug: 'ifitness', name: 'i-Fitness Gym', domain: 'ifitness.com.ng', brandColor: '#EF6C00', category: 'FITNESS' as const, trialProne: true },
  { slug: 'bolt', name: 'Bolt', domain: 'bolt.eu', brandColor: '#34D186', category: 'OTHER' as const, trialProne: false },
  { slug: 'chicken_republic', name: 'Chicken Republic', domain: 'chicken-republic.com', brandColor: '#E01F26', category: 'OTHER' as const, trialProne: false },
];

function daysFromNow(days: number): Date {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d;
}

function monthsAgo(months: number, day = 14): Date {
  const d = new Date();
  d.setMonth(d.getMonth() - months, day);
  return d;
}

async function main() {
  console.log('Seeding merchants...');
  for (const merchant of merchantSeeds) {
    await db
      .insert(merchants)
      .values(merchant)
      .onConflictDoUpdate({ target: merchants.slug, set: merchant });
  }
  const seededMerchants = await db.select().from(merchants);
  const bySlug = Object.fromEntries(seededMerchants.map((m) => [m.slug, m]));

  console.log('Seeding dev user...');
  const devEmail = 'dev@recur.app';
  const passwordHash = await argon2.hash('password123', { type: argon2.argon2id });

  let [devUser] = await db.select().from(users).where(eq(users.email, devEmail)).limit(1);
  if (!devUser) {
    [devUser] = await db.insert(users).values({ email: devEmail, passwordHash, emailVerifiedAt: new Date() }).returning();
  }
  if (!devUser) throw new Error('Seed error: failed to create dev user');

  // Clear out any previous seed run's subscriptions so this stays idempotent.
  await db.delete(subscriptions).where(eq(subscriptions.userId, devUser.id));

  const mockSubscriptions = [
    { merchant: 'netflix', displayName: 'Netflix', amount: 7000, cycle: 'MONTHLY' as const, nextChargeDate: daysFromNow(3), category: 'STREAMING' as const, status: 'ACTIVE' as const, confidence: 0.98, narration: 'NETFLIX.COM NGN CARD DEBIT' },
    { merchant: 'dstv', displayName: 'DStv Compact', amount: 19000, cycle: 'MONTHLY' as const, nextChargeDate: daysFromNow(6), category: 'STREAMING' as const, status: 'ACTIVE' as const, confidence: 0.96, narration: 'MULTICHOICE NIG DSTV SUB' },
    { merchant: 'spotify', displayName: 'Spotify Premium', amount: 2500, previousAmount: 1300, cycle: 'MONTHLY' as const, nextChargeDate: daysFromNow(11), category: 'STREAMING' as const, status: 'ACTIVE' as const, confidence: 0.94, narration: 'SPOTIFY P17A9C NGN' },
    { merchant: 'mtn', displayName: 'MTN Data Plan', amount: 10000, cycle: 'MONTHLY' as const, nextChargeDate: daysFromNow(1), category: 'TELECOM' as const, status: 'ACTIVE' as const, confidence: 0.91, narration: 'MTNNG DATA AUTORENEW' },
    { merchant: 'openai', displayName: 'ChatGPT Plus', amount: 32000, cycle: 'MONTHLY' as const, nextChargeDate: daysFromNow(9), category: 'SOFTWARE' as const, status: 'ACTIVE' as const, confidence: 0.89, narration: 'OPENAI *CHATGPT USD' },
    { merchant: 'canva', displayName: 'Canva Pro', amount: 64000, cycle: 'YEARLY' as const, nextChargeDate: daysFromNow(41), category: 'SOFTWARE' as const, status: 'ACTIVE' as const, confidence: 0.87, narration: 'CANVA* I05LM2 SYDNEY AU' },
    { merchant: 'ifitness', displayName: 'i-Fitness Gym', amount: 25000, cycle: 'MONTHLY' as const, nextChargeDate: daysFromNow(17), category: 'FITNESS' as const, status: 'UNREVIEWED' as const, confidence: 0.72, narration: 'IFITNESS LEKKI POS' },
    { merchant: 'showmax', displayName: 'Showmax', amount: 3500, cycle: 'MONTHLY' as const, nextChargeDate: daysFromNow(22), category: 'STREAMING' as const, status: 'UNREVIEWED' as const, confidence: 0.66, narration: 'SHOWMAX NG RECURRING' },
    { merchant: 'apple', displayName: 'Apple iCloud', amount: 1100, cycle: 'MONTHLY' as const, nextChargeDate: daysFromNow(14), category: 'SOFTWARE' as const, status: 'CANCELLED' as const, confidence: 0.93, narration: 'APPLE.COM/BILL ITUNES' },
  ];

  console.log('Seeding subscriptions...');
  for (const mock of mockSubscriptions) {
    const merchant = bySlug[mock.merchant];
    if (!merchant) throw new Error(`Seed error: merchant "${mock.merchant}" was not created`);

    const [sub] = await db
      .insert(subscriptions)
      .values({
        userId: devUser.id,
        merchantId: merchant.id,
        displayName: mock.displayName,
        amount: mock.amount.toString(),
        previousAmount: 'previousAmount' in mock ? mock.previousAmount.toString() : null,
        cycle: mock.cycle,
        nextChargeDate: mock.nextChargeDate,
        category: mock.category,
        status: mock.status,
        confidence: mock.confidence,
      })
      .returning();
    if (!sub) throw new Error('Seed error: failed to create subscription');

    await db.insert(chargeRecords).values(
      Array.from({ length: 5 }, (_, i) => ({
        subscriptionId: sub.id,
        date: monthsAgo(i),
        amount: mock.amount.toString(),
        narration: mock.narration,
      })),
    );
  }

  console.log(
    `Seeded ${merchantSeeds.length} merchants and ${mockSubscriptions.length} subscriptions for ${devEmail} (password: password123).`,
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
