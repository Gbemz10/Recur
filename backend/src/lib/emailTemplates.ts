/**
 * HTML email templates.
 *
 * Layout: tables as the structural backbone, inline styles for anything
 * that has to survive Outlook's Word rendering engine (which ignores
 * <style> blocks, flexbox, grid, and most CSS shorthand), plus a small
 * <style> block in <head> purely for the things inline styles can't do —
 * responsive width and a `prefers-color-scheme: dark` override. That's the
 * hybrid approach every major transactional-email guide (Stripe, Postmark,
 * Resend's own docs) converges on for a reason: it's the one combination
 * that survives Gmail, Outlook desktop, Outlook.com, Apple Mail and Yahoo
 * without falling apart somewhere.
 *
 * Brand: the real Recur mark (see emailAssets.ts) sits next to a monospace
 * "recur" wordmark, mirroring the app header. Palette mirrors the Flutter
 * app's light theme (AppColors) — warm paper, deep naira green, ink-dark
 * text — with a matching dark-mode set from the app's dark theme tokens.
 *
 * Content shape follows what OTP emails from well-regarded products
 * (Stripe, Linear, Vercel) all do: state the purpose in one line, make the
 * code the single dominant element on the page, say how long it's valid
 * for, and give an honest way to dismiss it if it wasn't the user. No
 * marketing, no unsubscribe link (this isn't a marketing email — it was
 * triggered by the recipient's own action seconds earlier), no clutter
 * competing with the one thing the reader actually needs.
 */

import { RECUR_MARK_PNG_BASE64 } from './emailAssets.js';

const light = {
  bg: '#FAF9F4',
  card: '#FFFFFF',
  codeBg: '#F2F2EA',
  border: '#E8E9E0',
  borderDashed: '#D2D4C9',
  ink900: '#171A14',
  ink600: '#5E6255',
  ink500: '#83867A',
  primary: '#0B6E4F',
} as const;

const dark = {
  bg: '#10130F',
  card: '#191D16',
  codeBg: '#10130F',
  border: '#2C3127',
  borderDashed: '#333A2C',
  ink900: '#F7F6EF',
  ink600: '#C7CABC',
  ink500: '#A6AC9C',
  primary: '#3FCE93',
} as const;

const sansFont =
  "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
const monoFont = "'SF Mono', 'SFMono-Regular', 'Roboto Mono', 'Courier New', Courier, monospace";

const MARK_SRC = `data:image/png;base64,${RECUR_MARK_PNG_BASE64}`;

function escapeHtml(value: string): string {
  return value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

/**
 * Hidden preview text — the line inbox lists show next to the subject.
 * Padded with zero-width joiners + non-breaking spaces so Gmail/Apple Mail
 * don't fall through to the visible body copy once the preheader text runs
 * out, which is the usual cause of a preview line that reads like garbled
 * boilerplate.
 */
function preheader(text: string): string {
  const padding = '&zwnj;&nbsp;'.repeat(40);
  return `<div style="display:none; max-height:0; overflow:hidden; mso-hide:all; font-size:1px; line-height:1px; color:${light.bg};">${escapeHtml(
    text,
  )}${padding}</div>`;
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
    .divider { border-color: ${dark.borderDashed} !important; }
    .ink-900 { color: ${dark.ink900} !important; }
    .ink-600 { color: ${dark.ink600} !important; }
    .ink-500 { color: ${dark.ink500} !important; }
    .wordmark { color: ${dark.ink900} !important; }
  }
  @media screen and (max-width: 480px) {
    .container { width: 100% !important; }
    .card-pad { padding: 28px 20px !important; }
  }
</style>
</head>
<body style="margin:0; padding:0; background-color:${light.bg}; font-family:${sansFont};">
${preheader(preheaderText)}
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" class="bg" style="background-color:${light.bg};">
<tr>
<td align="center" style="padding:40px 20px;">

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" class="container" style="max-width:460px;">

<tr>
<td style="padding-bottom:24px;">
<table role="presentation" cellpadding="0" cellspacing="0">
<tr>
<td style="padding-right:8px; vertical-align:middle;">
<img src="${MARK_SRC}" width="22" height="22" alt="" style="display:block; width:22px; height:22px;" />
</td>
<td class="wordmark ink-900" style="vertical-align:middle; font-family:${monoFont}; font-size:15px; font-weight:700; letter-spacing:0.2px; color:${light.ink900};">recur</td>
</tr>
</table>
</td>
</tr>

<tr>
<td class="card" style="background-color:${light.card}; border:1px solid ${light.border}; border-radius:16px; overflow:hidden;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0">
<tr><td height="4" style="line-height:4px; font-size:0; background-color:${light.primary}; background-image:linear-gradient(90deg, #0B6E4F, #6E8F45, #D9A441);">&nbsp;</td></tr>
<tr><td class="card-pad" style="padding:32px;">
${bodyHtml}
</td></tr>
</table>
</td>
</tr>

<tr>
<td style="padding-top:24px;">
<p class="ink-500" style="margin:0; font-family:${sansFont}; font-size:12px; line-height:1.6; color:${light.ink500};">
Recur &middot; Lagos, Nigeria<br />
Sent because someone requested this from the Recur app. If that wasn&rsquo;t you, no action is needed.
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

/** Renders the OTP as individually boxed digits rather than a single spaced
 *  string — reads as intentional UI rather than plain text, and spacing
 *  between digits stays exact across clients that otherwise collapse or
 *  strip runs of whitespace (Gmail in particular). */
function codeDigits(code: string): string {
  const cells = code
    .split('')
    .map(
      (digit) => `<td class="code-cell" width="40" style="width:40px; height:52px; background-color:${light.codeBg}; border:1px solid ${light.border}; border-radius:10px; text-align:center; vertical-align:middle;">
<span class="ink-900" style="font-family:${monoFont}; font-size:26px; font-weight:700; color:${light.ink900};">${escapeHtml(digit)}</span>
</td>`,
    )
    .join('<td width="8" style="width:8px; line-height:1px; font-size:0;">&nbsp;</td>');

  return `<table role="presentation" cellpadding="0" cellspacing="0" align="center" style="margin:0 auto;">
<tr>${cells}</tr>
</table>`;
}

export function renderOtpEmail(
  code: string,
  purpose: 'SIGNUP' | 'RESET_PASSWORD',
  ttlMinutes: number,
): RenderedEmail {
  const isReset = purpose === 'RESET_PASSWORD';
  const eyebrow = isReset ? 'Reset your password' : 'Verify your email';
  const headline = isReset ? 'Confirm it&rsquo;s you' : 'One more step';
  const body = isReset
    ? 'Enter this code in the app to continue resetting your Recur password.'
    : 'Enter this code in the app to finish creating your Recur account.';
  const preheaderText = `${code} is your Recur verification code. It expires in ${ttlMinutes} minutes.`;

  const html = emailShell(
    `
<p class="ink-500" style="margin:0 0 8px; font-family:${sansFont}; font-size:12px; font-weight:700; letter-spacing:0.8px; text-transform:uppercase; color:${light.ink500};">${eyebrow}</p>
<h1 class="ink-900" style="margin:0 0 12px; font-family:${sansFont}; font-size:23px; font-weight:800; letter-spacing:-0.3px; color:${light.ink900};">${headline}</h1>
<p class="ink-600" style="margin:0 0 28px; font-family:${sansFont}; font-size:14px; line-height:1.6; color:${light.ink600};">${body}</p>

${codeDigits(code)}

<p class="ink-500" style="margin:16px 0 0; text-align:center; font-family:${sansFont}; font-size:12px; color:${light.ink500};">Expires in ${ttlMinutes} minutes</p>

<div class="divider" style="border-top:1px dashed ${light.borderDashed}; margin:28px 0;"></div>

<p class="ink-500" style="margin:0; font-family:${sansFont}; font-size:13px; line-height:1.6; color:${light.ink500};">
Didn&rsquo;t request this? You can safely ignore this email &mdash; no changes have been made to your account, and this code will expire on its own.
</p>
`,
    preheaderText,
  );

  const text = [
    eyebrow,
    '',
    body,
    '',
    `Your code: ${code}`,
    `(expires in ${ttlMinutes} minutes)`,
    '',
    "Didn't request this? You can safely ignore this email — no changes have been made to your account.",
    '',
    'Recur · Lagos, Nigeria',
  ].join('\n');

  return {
    subject: `${code} is your Recur code`,
    text,
    html,
  };
}

// Exported for anything that wants the raw shell for a future email type
// (e.g. a renewal reminder) without duplicating the header/footer markup.
export { emailShell, escapeHtml, light as emailColorsLight, dark as emailColorsDark, sansFont, monoFont };
