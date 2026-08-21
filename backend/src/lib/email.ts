import { env } from '../config/env.js';
import { renderOtpEmail, renderWaitlistEmail, renderNewDeviceEmail } from './emailTemplates.js';

interface SendEmailInput {
  to: string;
  subject: string;
  text: string;
  /**
   * Extra SMTP headers. Used for List-Unsubscribe on recurring mail, which is
   * what makes Gmail and Apple Mail show their own unsubscribe control at the
   * top of the message rather than leaving it to a link in the footer.
   */
  headers?: Record<string, string>;
  /** Optional HTML alternative. Resend (and every real mail client) is
   *  happy with text-only, but a branded HTML version is what actually
   *  renders for the person reading it. Text stays as the fallback for
   *  clients/screen readers that prefer it. */
  html?: string;
}

const suppressed = new Set(
  env.EMAIL_SUPPRESS_LIST.split(',')
    .map((address) => address.trim().toLowerCase())
    .filter(Boolean),
);

/**
 * True for an address the app must never actually mail.
 *
 * Exported so a caller can report it honestly; [sendEmail] enforces it either
 * way, so a caller that forgets to check still cannot send.
 */
export function isEmailSuppressed(address: string): boolean {
  return suppressed.has(address.trim().toLowerCase());
}

export async function sendEmail(input: SendEmailInput): Promise<void> {
  if (isEmailSuppressed(input.to)) {
    console.log(`[email] suppressed (${input.to}): ${input.subject}`);
    return;
  }

  if (env.EMAIL_PROVIDER === 'console') {
    console.log('\n────────────────── dev email ──────────────────');
    console.log(`to:      ${input.to}`);
    console.log(`subject: ${input.subject}`);
    console.log(input.text);
    if (input.html) console.log('(html version also generated, rendered in the real inbox, not shown here)');
    console.log('─────────────────────────────────────────────────\n');
    return;
  }

  if (!env.RESEND_API_KEY) {
    throw new Error('EMAIL_PROVIDER=resend but RESEND_API_KEY is not set');
  }

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
    },
    body: JSON.stringify({
      from: env.EMAIL_FROM,
      to: input.to,
      subject: input.subject,
      text: input.text,
      ...(input.html ? { html: input.html } : {}),
      ...(input.headers ? { headers: input.headers } : {}),
    }),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    // OTP delivery failing silently would lock users out of signup/reset
    // with no visible error, so this throws rather than swallowing.
    // Callers (auth/service.ts) already run inside routes that surface
    // a 500 through the centralized error handler if this rejects.
    throw new Error(`Resend API error ${response.status}: ${body}`);
  }
}

/** Branded OTP email. See emailTemplates.ts for the actual markup and design. */
export function otpEmail(code: string, purpose: 'SIGNUP' | 'RESET_PASSWORD') {
  return renderOtpEmail(code, purpose, env.OTP_TTL_MINUTES);
}

/** Branded waitlist-confirmation email. See emailTemplates.ts. */
export function waitlistEmail() {
  return renderWaitlistEmail();
}

/** Branded new-device sign-in notification. See emailTemplates.ts. */
export function newDeviceEmail(ip: string | null) {
  return renderNewDeviceEmail({ ip, when: new Date() });
}
