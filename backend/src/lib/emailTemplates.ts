/**
 * HTML email templates.
 *
 * Structure: tables as the backbone, inline styles for anything that has to
 * survive Outlook's Word rendering engine (which ignores <style> blocks,
 * flexbox, grid and most CSS shorthand), plus one small <style> block for the
 * two things inline styles cannot express: a responsive width and a
 * prefers-color-scheme override. That hybrid is what Stripe, Postmark and
 * Resend's own docs converge on, because it is the one combination that
 * survives Gmail, Outlook desktop, Outlook.com, Apple Mail and Yahoo intact.
 *
 * Design follows the app and the marketing site rather than generic email
 * convention. Three things carry the brand:
 *
 *   1. The lockup. A 32px mark beside "recur" set in the sans at weight 800
 *      with the same negative tracking the app uses, which is the same
 *      lockup RecurWordmark renders in Flutter. It used to be a 22px mark
 *      beside a monospace wordmark, which matched nothing in the product.
 *   2. Monospace as the ledger face. Eyebrows, the code, the period label,
 *      the IP and the footer are all mono; prose is not. That split is the
 *      app's own typographic thesis (see AppTypography): a machine wrote the
 *      number, a person wrote the sentence.
 *   3. Restraint everywhere else. The card previously opened with a
 *      full-width three-stop gradient rule, which is the single most
 *      template-looking element an email can have. The logo carries the
 *      brand; the card does not need to shout underneath it.
 *
 * Copy contains no em dashes anywhere, in either the HTML or the plain-text
 * alternative. Sentences are split or re-joined with commas and periods
 * instead.
 */

import { RECUR_MARK_PNG_BASE64 } from './emailAssets.js';

/** Mirrors the Flutter app's AppColors light theme and the website's tokens. */
const light = {
  bg: '#FAF9F4',
  card: '#FFFFFF',
  codeBg: '#FAF9F4',
  border: '#E8E9E0',
  borderStrong: '#D2D4C9',
  ink900: '#171A14',
  ink600: '#5E6255',
  // Darker than the app's neutral500 for the same reason the website's
  // --ink-faint was raised: every use of this is 11px to 13px text, which
  // needs AA's 4.5:1 rather than the 3:1 large text gets.
  ink500: '#6E7166',
  primary: '#0B6E4F',
} as const;

/** Mirrors AppColors' dark theme. */
const dark = {
  bg: '#10130F',
  card: '#191D16',
  codeBg: '#14180F',
  border: '#2C3127',
  borderStrong: '#3E4238',
  ink900: '#F2F2EA',
  ink600: '#C7CABC',
  ink500: '#9A9D91',
  // primary is tuned for paper and drops to roughly 2:1 on these surfaces,
  // so the dark set steps up, exactly as AppColors.primaryInk does in the app.
  primary: '#3DBE8B',
} as const;

const sansFont =
  "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
const monoFont = "'SF Mono', 'SFMono-Regular', 'Roboto Mono', 'Courier New', Courier, monospace";

const MARK_SRC = `data:image/png;base64,${RECUR_MARK_PNG_BASE64}`;

function escapeHtml(value: string): string {
  return value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

/**
 * Hidden preview text, the line inbox lists show beside the subject.
 * Padded with zero-width joiners and non-breaking spaces so Gmail and Apple
 * Mail do not fall through to the visible body once the preheader runs out,
 * which is the usual cause of a preview line that reads like garbled markup.
 */
function preheader(text: string): string {
  const padding = '&zwnj;&nbsp;'.repeat(40);
  return `<div style="display:none; max-height:0; overflow:hidden; mso-hide:all; font-size:1px; line-height:1px; color:${light.bg};">${escapeHtml(
    text,
  )}${padding}</div>`;
}

/**
 * The lockup. Rendered as a two-cell table rather than an inline-block pair,
 * because Outlook collapses inline-block and would stack the mark above the
 * wordmark. `mso-line-height-rule:exactly` stops Word from adding its own
 * leading around the wordmark and knocking it off the mark's centre line.
 */
function lockup(): string {
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0">
<tr>
<td style="padding-right:10px; vertical-align:middle; line-height:0;">
<img src="${MARK_SRC}" width="34" height="34" alt="Recur" style="display:block; width:34px; height:34px; border:0;" />
</td>
<td class="wordmark ink-900" style="vertical-align:middle; font-family:${sansFont}; font-size:24px; font-weight:800; letter-spacing:-1.08px; line-height:34px; mso-line-height-rule:exactly; color:${light.ink900};">recur</td>
</tr>
</table>`;
}

/** Shared shell every transactional email renders inside. */
function emailShell(bodyHtml: string, preheaderText: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<meta name="color-scheme" content="light dark" />
<meta name="supported-color-schemes" content="light dark" />
<title>Recur</title>
<style>
  @media (prefers-color-scheme: dark) {
    .bg { background-color: ${dark.bg} !important; }
    .card { background-color: ${dark.card} !important; border-color: ${dark.border} !important; }
    .code-cell { background-color: ${dark.codeBg} !important; border-color: ${dark.border} !important; }
    .divider { border-color: ${dark.border} !important; }
    .ink-900, .wordmark { color: ${dark.ink900} !important; }
    .ink-600 { color: ${dark.ink600} !important; }
    .ink-500 { color: ${dark.ink500} !important; }
    .accent { color: ${dark.primary} !important; }
  }
  @media screen and (max-width: 480px) {
    .container { width: 100% !important; }
    .card-pad { padding: 28px 22px !important; }
  }
</style>
</head>
<body style="margin:0; padding:0; background-color:${light.bg}; font-family:${sansFont};">
${preheader(preheaderText)}
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="bg" style="background-color:${light.bg};">
<tr>
<td align="center" style="padding:44px 20px;">

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="container" style="max-width:472px;">

<tr>
<td style="padding-bottom:26px;">
${lockup()}
</td>
</tr>

<tr>
<td class="card" style="background-color:${light.card}; border:1px solid ${light.border}; border-radius:18px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
<tr><td class="card-pad" style="padding:36px;">
${bodyHtml}
</td></tr>
</table>
</td>
</tr>

<tr>
<td style="padding-top:22px;">
<p class="ink-500" style="margin:0; font-family:${monoFont}; font-size:11px; line-height:1.7; letter-spacing:0.3px; color:${light.ink500};">
RECUR &middot; LAGOS, NIGERIA
</p>
<p class="ink-500" style="margin:6px 0 0; font-family:${sansFont}; font-size:12px; line-height:1.6; color:${light.ink500};">
Sent because someone requested it from the Recur app. If that was not you, no action is needed.
</p>
</td>
</tr>

</table>

</td>
</tr>
</table>
</body>
</html>`;
}

export interface RenderedEmail {
  subject: string;
  text: string;
  html: string;
}

/** Small uppercase mono label above a headline, matching the site's eyebrow. */
function eyebrow(label: string): string {
  return `<p class="ink-500" style="margin:0 0 10px; font-family:${monoFont}; font-size:11px; font-weight:600; letter-spacing:1.4px; text-transform:uppercase; color:${light.ink500};">${escapeHtml(
    label,
  )}</p>`;
}

function headline(text: string): string {
  return `<h1 class="ink-900" style="margin:0 0 12px; font-family:${sansFont}; font-size:24px; font-weight:800; letter-spacing:-0.5px; line-height:1.25; color:${light.ink900};">${text}</h1>`;
}

function divider(): string {
  return `<div class="divider" style="border-top:1px solid ${light.border}; margin:30px 0 22px; font-size:0; line-height:0;">&nbsp;</div>`;
}

/**
 * The code as individually boxed digits rather than one spaced string. Reads
 * as deliberate UI, and the spacing stays exact in clients that otherwise
 * collapse or strip runs of whitespace, which Gmail does.
 */
function codeDigits(code: string): string {
  const cells = code
    .split('')
    .map(
      (digit) => `<td class="code-cell" width="46" style="width:46px; height:56px; background-color:${light.codeBg}; border:1px solid ${light.border}; border-radius:12px; text-align:center; vertical-align:middle;">
<span class="ink-900" style="font-family:${monoFont}; font-size:25px; font-weight:700; letter-spacing:0.5px; color:${light.ink900};">${escapeHtml(digit)}</span>
</td>`,
    )
    .join('<td width="7" style="width:7px; line-height:1px; font-size:0;">&nbsp;</td>');

  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="margin:0 auto;">
<tr>${cells}</tr>
</table>`;
}

/** A labelled key/value block, used for the sign-in details. */
function detailRow(label: string, value: string, mono = false): string {
  return `<p class="ink-500" style="margin:0 0 3px; font-family:${monoFont}; font-size:10.5px; font-weight:600; letter-spacing:1px; text-transform:uppercase; color:${light.ink500};">${escapeHtml(
    label,
  )}</p>
<p class="ink-900" style="margin:0; font-family:${mono ? monoFont : sansFont}; font-size:14px; font-weight:600; color:${light.ink900};">${escapeHtml(value)}</p>`;
}

export function renderOtpEmail(
  code: string,
  purpose: 'SIGNUP' | 'RESET_PASSWORD',
  ttlMinutes: number,
): RenderedEmail {
  const isReset = purpose === 'RESET_PASSWORD';
  const label = isReset ? 'Reset your password' : 'Verify your email';
  const title = isReset ? 'Confirm it&rsquo;s you' : 'One more step';
  const body = isReset
    ? 'Enter this code in the app to carry on resetting your Recur password.'
    : 'Enter this code in the app to finish creating your Recur account.';
  const preheaderText = `${code} is your Recur verification code. It expires in ${ttlMinutes} minutes.`;

  const html = emailShell(
    `
${eyebrow(label)}
${headline(title)}
<p class="ink-600" style="margin:0 0 30px; font-family:${sansFont}; font-size:14.5px; line-height:1.65; color:${light.ink600};">${body}</p>

${codeDigits(code)}

<p class="ink-500" style="margin:18px 0 0; text-align:center; font-family:${monoFont}; font-size:11px; letter-spacing:0.6px; color:${light.ink500};">EXPIRES IN ${ttlMinutes} MINUTES</p>

${divider()}

<p class="ink-500" style="margin:0; font-family:${sansFont}; font-size:13px; line-height:1.65; color:${light.ink500};">
Did not request this? You can safely ignore this email. Nothing has changed on your account, and the code expires on its own.
</p>
`,
    preheaderText,
  );

  const text = [
    label,
    '',
    body,
    '',
    `Your code: ${code}`,
    `Expires in ${ttlMinutes} minutes.`,
    '',
    'Did not request this? You can safely ignore this email. Nothing has changed on your account, and the code expires on its own.',
    '',
    'Recur, Lagos, Nigeria',
  ].join('\n');

  return { subject: `${code} is your Recur code`, text, html };
}

/**
 * Sent the moment someone joins the waitlist from recur.website. A short,
 * honest confirmation rather than a pitch. No unsubscribe link, for the same
 * reason the OTP email has none: this was triggered by the recipient's own
 * action seconds earlier, not by an ongoing marketing list.
 */
export function renderWaitlistEmail(): RenderedEmail {
  const preheaderText = 'You are on the Recur waitlist. We will email you the moment it is your turn.';

  const html = emailShell(
    `
${eyebrow('Waitlist confirmed')}
${headline('You are on the list')}
<p class="ink-600" style="margin:0; font-family:${sansFont}; font-size:14.5px; line-height:1.65; color:${light.ink600};">
Thanks for signing up. We are opening Recur city by city, so you will get exactly one email, right when it is your turn, with a link to get started. Nothing before then.
</p>

${divider()}

<p class="ink-500" style="margin:0; font-family:${sansFont}; font-size:13px; line-height:1.65; color:${light.ink500};">
Did not sign up for this? You can safely ignore this email. No account was created, and you will not hear from us again.
</p>
`,
    preheaderText,
  );

  const text = [
    'Waitlist confirmed',
    '',
    'Thanks for signing up. We are opening Recur city by city, so you will get exactly one email, right when it is your turn, with a link to get started. Nothing before then.',
    '',
    'Did not sign up for this? You can safely ignore this email. No account was created.',
    '',
    'Recur, Lagos, Nigeria',
  ].join('\n');

  return { subject: 'You are on the Recur waitlist', text, html };
}

/**
 * Formats a timestamp the way a person reads it, with the zone spelled out.
 * The server has no idea what timezone the recipient is in, so this states
 * UTC rather than guessing.
 */
function formatWhen(date: Date): string {
  const formatted = date.toLocaleString('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'UTC',
  });
  return `${formatted} UTC`;
}

/**
 * Sent when a sign-in is seen from a device Recur has never recorded for this
 * account (see deviceTrust.ts). Deliberately does not call this a new
 * location: there is no geo-IP lookup behind it, only the raw address, so the
 * copy promises exactly what it can back up.
 */
export function renderNewDeviceEmail(input: { ip: string | null; when: Date }): RenderedEmail {
  const whenText = formatWhen(input.when);
  const ipText = input.ip ?? 'an unknown address';
  const preheaderText = `New sign-in to your Recur account on ${whenText}.`;

  const html = emailShell(
    `
${eyebrow('Security')}
${headline('New sign-in to your account')}
<p class="ink-600" style="margin:0 0 24px; font-family:${sansFont}; font-size:14.5px; line-height:1.65; color:${light.ink600};">
Recur saw a sign-in to your account from a device it has not seen before.
</p>

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="code-cell" style="background-color:${light.codeBg}; border:1px solid ${light.border}; border-radius:12px;">
<tr><td style="padding:18px 20px;">
${detailRow('Time', whenText)}
</td></tr>
<tr><td style="padding:0 20px 18px;">
${detailRow('IP address', ipText, true)}
</td></tr>
</table>

${divider()}

<p class="ink-600" style="margin:0 0 10px; font-family:${sansFont}; font-size:14px; line-height:1.65; color:${light.ink600};">
<strong class="ink-900" style="color:${light.ink900};">Was this you?</strong> Then there is nothing to do.
</p>
<p class="ink-500" style="margin:0; font-family:${sansFont}; font-size:13px; line-height:1.65; color:${light.ink500};">
If it was not, open Recur and change your password from Settings straight away. That also signs every other device out.
</p>
`,
    preheaderText,
  );

  const text = [
    'Security',
    '',
    'Recur saw a sign-in to your account from a device it has not seen before.',
    '',
    `Time: ${whenText}`,
    `IP address: ${ipText}`,
    '',
    'Was this you? Then there is nothing to do.',
    'If it was not, open Recur and change your password from Settings straight away. That also signs every other device out.',
    '',
    'Recur, Lagos, Nigeria',
  ].join('\n');

  return { subject: 'New sign-in to your Recur account', text, html };
}

// Exported for anything that wants the shell for a future email type (a
// renewal reminder, a budget alert) without duplicating the header and footer.
export {
  emailShell,
  escapeHtml,
  eyebrow,
  headline,
  divider,
  light as emailColorsLight,
  dark as emailColorsDark,
  sansFont,
  monoFont,
};
