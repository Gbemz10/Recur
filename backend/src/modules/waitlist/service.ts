import { db } from '../../db/client.js';
import { waitlistSignups } from '../../db/schema.js';
import { sendEmail, waitlistEmail } from '../../lib/email.js';

export async function joinWaitlist(email: string, source?: string) {
  // onConflictDoNothing + returning() is the whole idempotency story here:
  // a repeat signup (double-click, retry after a flaky connection) hits the
  // unique index on email, inserts nothing, and `inserted` comes back
  // undefined — so the confirmation email only ever fires once per address,
  // and the route can still answer with the same "you're on the list"
  // success either way instead of surfacing a confusing conflict error.
  const [inserted] = await db
    .insert(waitlistSignups)
    .values({ email, source: source ?? null })
    .onConflictDoNothing()
    .returning();

  if (inserted) {
    const { subject, text, html } = waitlistEmail();
    await sendEmail({ to: email, subject, text, html });
  }
}
