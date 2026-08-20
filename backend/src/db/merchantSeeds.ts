import { db } from './client.js';
import { merchants } from './schema.js';

// Mirrors lib/data/merchants.dart on the client — same slugs, same colors,
// so a bundled logo asset on either side resolves the same way.
// `trialProne: true` marks merchants known to run free-trial-then-charge
// signups — the detection engine's single-occurrence trial heuristic (see
// detection/service.ts) only ever fires for these, so it doesn't start
// flagging every one-off debit as a "possible trial."
export const merchantSeeds = [
  { slug: 'netflix', name: 'Netflix', domain: 'netflix.com', brandColor: '#E50914', category: 'STREAMING' as const, trialProne: true, cancellationSteps: ['Open the Netflix app or netflix.com and sign in.', 'Go to Account, then Membership & Billing.', 'Tap Cancel Membership and confirm.', 'You keep access until the end of the current billing period.'] },
  { slug: 'dstv', name: 'DStv', domain: 'dstv.com', brandColor: '#0072CE', category: 'STREAMING' as const, trialProne: false, cancellationSteps: ['Dial *288# from the phone number linked to your DStv account.', 'Select Manage Subscription, then Cancel Auto-renew.', 'Alternatively use the MyDStv app under Manage Account.'] },
  { slug: 'mtn', name: 'MTN', domain: 'mtn.ng', brandColor: '#FFCB05', category: 'TELECOM' as const, trialProne: false, cancellationSteps: ['Dial *312# and select Manage Auto-renewal.', 'Choose the active data plan and select Turn off auto-renew.', 'You can also do this in the MyMTN app under Data.'] },
  { slug: 'spotify', name: 'Spotify', domain: 'spotify.com', brandColor: '#1DB954', category: 'STREAMING' as const, trialProne: true, cancellationSteps: ['Go to spotify.com/account in a browser (not the app).', 'Select Manage your plan, then Change plan.', 'Scroll to Spotify Free and choose Cancel Premium.'] },
  { slug: 'openai', name: 'ChatGPT Plus', domain: 'openai.com', brandColor: '#10A37F', category: 'SOFTWARE' as const, trialProne: true, cancellationSteps: ['Open ChatGPT and click your profile, then Settings.', 'Go to Subscription, then Manage my subscription.', 'Select Cancel plan and confirm.'] },
  { slug: 'canva', name: 'Canva', domain: 'canva.com', brandColor: '#7D2AE8', category: 'SOFTWARE' as const, trialProne: true, cancellationSteps: ['Open Canva and go to Account settings, then Billing & plans.', 'Select your Canva Pro plan, then Cancel subscription.'] },
  { slug: 'showmax', name: 'Showmax', domain: 'showmax.com', brandColor: '#E10098', category: 'STREAMING' as const, trialProne: true, cancellationSteps: ['Sign in at showmax.com and open My account.', 'Select Manage subscription, then Cancel.'] },
  { slug: 'apple', name: 'Apple iCloud', domain: 'apple.com', brandColor: '#555555', category: 'SOFTWARE' as const, trialProne: false, cancellationSteps: ['Open Settings, tap your name, then Subscriptions.', 'Select iCloud+ and tap Cancel subscription.'] },
  { slug: 'ifitness', name: 'i-Fitness Gym', domain: 'ifitness.com.ng', brandColor: '#EF6C00', category: 'FITNESS' as const, trialProne: true, cancellationSteps: ['Visit your registered branch, or email support@ifitness.com.ng.', 'Request cancellation at least 7 days before your renewal date.'] },
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

/**
 * Upserts the merchant reference table and nothing else.
 *
 * In its own module with no top-level side effects, because seed.ts calls
 * main() at import time: importing that file to reuse one function runs the
 * entire dev-user seed, which deletes and recreates that user's
 * subscriptions. Reference data and fixture data must not travel together,
 * least of all while dev and production share a database.
 */
export async function seedMerchants() {
  for (const merchant of merchantSeeds) {
    await db
      .insert(merchants)
      .values(merchant)
      .onConflictDoUpdate({ target: merchants.slug, set: merchant });
  }
  return merchantSeeds.length;
}
