/**
 * Renders every transactional email to disk so the design can be looked at in
 * a browser instead of guessed at from source, and so a change can be diffed
 * visually. Not part of the app — run with `npx tsx scripts/render-emails.ts`.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import {
  renderOtpEmail,
  renderNewDeviceEmail,
  renderRenewalReminderEmail,
  renderTrialReminderEmail,
  renderWeeklyDigestEmail,
} from '../src/lib/emailTemplates.js';

const out = process.argv[2] ?? './email-preview';
mkdirSync(out, { recursive: true });

const day = 864e5;
const unsubscribeUrl = 'https://recur.website/unsubscribe?token=preview';

const samples: Record<string, { subject: string; html: string }> = {
  otp: renderOtpEmail('418902', 'SIGNUP', 10),
  'new-device': renderNewDeviceEmail({ ip: '102.89.34.7', when: new Date() }),
  renewal: renderRenewalReminderEmail({
    charges: [{ name: 'Netflix', amount: 7000, chargeDate: new Date(Date.now() + 3 * day) }],
    leadDays: 3,
    unsubscribeUrl,
  }),
  'renewal-many': renderRenewalReminderEmail({
    charges: [
      { name: 'MTN', amount: 10000, chargeDate: new Date(Date.now() + day) },
      { name: 'DStv', amount: 19000, chargeDate: new Date(Date.now() + 2 * day) },
      { name: 'Spotify', amount: 1300, chargeDate: new Date(Date.now() + 3 * day) },
    ],
    leadDays: 3,
    unsubscribeUrl,
  }),
  trial: renderTrialReminderEmail({
    label: 'Showmax Premier League',
    endsAt: new Date(Date.now() + day),
    daysAway: 1,
    unsubscribeUrl,
  }),
  digest: renderWeeklyDigestEmail({
    weekAhead: [
      { name: 'MTN', amount: 10000, chargeDate: new Date(Date.now() + day) },
      { name: 'DStv', amount: 19000, chargeDate: new Date(Date.now() + 2 * day) },
      { name: 'Spotify', amount: 1300, chargeDate: new Date(Date.now() + 4 * day) },
    ],
    monthSoFar: 448100,
    monthLabel: 'August',
    topCategories: [
      { label: 'Food', spent: 121000 },
      { label: 'Transfers', spent: 55000 },
      { label: 'Transport', spent: 54500 },
    ],
    activeCount: 11,
    monthlyTotal: 183233,
    unsubscribeUrl,
  }),
};

for (const [name, email] of Object.entries(samples)) {
  writeFileSync(`${out}/${name}.html`, email.html);
  console.log(`${name.padEnd(12)} ${email.subject}`);
}
