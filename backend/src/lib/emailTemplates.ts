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


/** Mirrors the Flutter app's AppColors light theme and the website's tokens. */
const light = {
  bg: '#FAF9F4',
  card: '#FFFFFF',
  codeBg: '#FAF9F4',
  // The code is the one thing in the email worth colouring: it is what the
  // reader came for, and a tinted cell finds it faster than a grey one.
  codeTint: '#EFF7F2',
  codeBorder: '#BFE0CE',
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
  codeTint: '#12241B',
  codeBorder: '#2F5E46',
  border: '#2C3127',
  borderStrong: '#3E4238',
  ink900: '#F2F2EA',
  ink600: '#C7CABC',
  ink500: '#9A9D91',
  // primary is tuned for paper and drops to roughly 2:1 on these surfaces,
  // so the dark set steps up, exactly as AppColors.primaryInk does in the app.
  primary: '#3DBE8B',
} as const;

/**
 * The app's brand gradient, flattened to three stops an email can use. `deep`
 * doubles as the solid fallback: white text sits on it at better than 7:1,
 * which the mid and warm stops cannot promise.
 */
const brand = {
  deep: '#0B6E4F',
  mid: '#2E8B57',
  warm: '#C8A03A',
} as const;

const sansFont =
  "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
const monoFont = "'SF Mono', 'SFMono-Regular', 'Roboto Mono', 'Courier New', Courier, monospace";

/**
 * Hosted on the marketing site, not inlined and not on this backend.
 *
 * Three hosts were possible and only one of them works:
 *
 *   - A `data:` URI, which is what this used to be. Apple Mail renders it;
 *     Gmail, Outlook.com and Yahoo strip it. Most recipients saw a broken
 *     image where the logo should be.
 *   - This API, which is on a free Render instance that sleeps after 15
 *     idle minutes. Gmail fetches images through its own proxy exactly once
 *     and caches the result — if that single fetch hits a cold start, the
 *     logo is broken for that recipient for good.
 *   - The website, which is static, on a CDN, and always warm.
 *
 * `www` rather than the apex, because the apex answers 308 and there is no
 * reason to spend a redirect inside an image proxy.
 */
const MARK_SRC = 'https://www.recur.website/assets/brand/mark.png';

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
 * The masthead: the mark and wordmark in white on the brand gradient, across
 * the top of the card.
 *
 * The old header was a 34px mark on the page background, which meant every
 * email opened on a cream rectangle with a small grey lockup and no colour
 * anywhere — correct, and completely forgettable. A gradient band costs
 * nothing in deliverability and is the one place the brand can actually
 * appear.
 *
 * Gradients are a background-image, so anything that cannot render one falls
 * back to `background-color` — deliberately the darker end of the gradient
 * rather than a midpoint, since white text has to stay legible on it. Outlook
 * on Windows gets the same treatment through the solid colour; no VML, which
 * is a lot of markup to maintain for a decoration.
 */
function masthead(): string {
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="masthead" style="background-color:${brand.deep}; background-image:linear-gradient(120deg, ${brand.deep} 0%, ${brand.mid} 55%, ${brand.warm} 100%); border-radius:18px 18px 0 0;">
<tr>
<td style="padding:22px 30px;">
<table role="presentation" cellpadding="0" cellspacing="0" border="0">
<tr>
<td style="padding-right:11px; vertical-align:middle; line-height:0;">
<!--
  The mark on a white chip, not straight onto the band. It is drawn in the
  brand gradient itself, so green-on-green would have hidden most of it —
  the chip is what makes it readable, and it reads as deliberate rather
  than as a logo that failed to load.
-->
<table role="presentation" cellpadding="0" cellspacing="0" border="0">
<tr><td style="background-color:#FFFFFF; border-radius:10px; padding:6px; line-height:0;">
<img src="${MARK_SRC}" width="26" height="26" alt="Recur" style="display:block; width:26px; height:26px; border:0;" />
</td></tr>
</table>
</td>
<td style="vertical-align:middle; font-family:${sansFont}; font-size:21px; font-weight:800; letter-spacing:-0.95px; line-height:30px; mso-line-height-rule:exactly; color:#FFFFFF;">recur</td>
</tr>
</table>
</td>
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
    .code-cell { background-color: ${dark.codeTint} !important; border-color: ${dark.codeBorder} !important; }
    .accent-ink { color: ${dark.primary} !important; }
    .divider { border-color: ${dark.border} !important; }
    .ink-900, .wordmark { color: ${dark.ink900} !important; }
    .ink-600 { color: ${dark.ink600} !important; }
    .ink-500 { color: ${dark.ink500} !important; }
    .accent { color: ${dark.primary} !important; }
  }
  @media screen and (max-width: 480px) {
    .container { width: 100% !important; }
    .card-pad { padding: 26px 20px 24px !important; }
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
<td class="card" style="background-color:${light.card}; border:1px solid ${light.border}; border-radius:18px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
<tr><td style="line-height:0; font-size:0;">${masthead()}</td></tr>
<tr><td class="card-pad" style="padding:34px 30px 32px;">
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
      (digit) => `<td class="code-cell" width="48" style="width:48px; height:60px; background-color:${light.codeTint}; border:1.5px solid ${light.codeBorder}; border-radius:14px; text-align:center; vertical-align:middle;">
<span class="accent-ink" style="font-family:${monoFont}; font-size:27px; font-weight:700; letter-spacing:0.5px; color:${light.primary};">${escapeHtml(digit)}</span>
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

// ------------------------------------------------------------ notifications

/** Naira, grouped, no decimals. Matches the app's formatNaira. */
function naira(amount: number): string {
  return `₦${Math.round(amount).toLocaleString('en-NG')}`;
}

/** "Tue 4 Nov". Weekday included, because these emails are about *when*. */
function shortDay(date: Date): string {
  // Lagos time, not the server's. A charge lands on the day the account
  // holder is living in, and Render runs in UTC.
  const parts = new Intl.DateTimeFormat('en-NG', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    timeZone: 'Africa/Lagos',
  }).formatToParts(date);
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? '';
  return `${get('weekday')} ${get('day')} ${get('month')}`;
}

/** One charge as a row: name on the left, amount on the right. */
function chargeRow(name: string, when: string, amount: number, last: boolean): string {
  return `<tr>
<td style="padding:0 0 ${last ? '0' : '14px'};">
<span class="ink-900" style="font-family:${sansFont}; font-size:14.5px; font-weight:700; color:${light.ink900};">${escapeHtml(name)}</span><br>
<span class="ink-500" style="font-family:${sansFont}; font-size:12.5px; color:${light.ink500};">${escapeHtml(when)}</span>
</td>
<td align="right" style="padding:0 0 ${last ? '0' : '14px'}; vertical-align:top; white-space:nowrap;">
<span class="ink-900" style="font-family:${sansFont}; font-size:14.5px; font-weight:800; color:${light.ink900};">${escapeHtml(naira(amount))}</span>
</td>
</tr>`;
}

/**
 * The closing line on recurring mail, carrying a working unsubscribe link.
 *
 * "You can turn this off in Settings" was true but was not an unsubscribe: it
 * asks someone to open an app, find a screen and flip a switch. The people
 * most likely to want out are the least likely to still have the app.
 */
function unsubscribeFooter(url: string, what: string): string {
  return `<p class="ink-500" style="margin:0; font-family:${sansFont}; font-size:13px; line-height:1.65; color:${light.ink500};">
${escapeHtml(what)} <a href="${escapeHtml(url)}" style="color:${light.ink500}; text-decoration:underline;">Unsubscribe</a>, or manage every notification in the app under Settings.
</p>`;
}

export interface RenewalReminderCharge {
  name: string;
  amount: number;
  chargeDate: Date;
}

/**
 * The heads-up before a charge lands.
 *
 * Batched: one email per user per run, however many charges are inside their
 * lead window. Three separate emails on the same morning is how a useful
 * reminder becomes something people filter, and the whole product is a case
 * against subscriptions nobody notices.
 *
 * Deliberately not a call to action. It states what is about to leave the
 * account and stops, because the only person who knows whether that is fine
 * is the one reading it.
 */
export function renderRenewalReminderEmail(input: {
  charges: RenewalReminderCharge[];
  leadDays: number;
  unsubscribeUrl: string;
}): RenderedEmail {
  const { charges, leadDays, unsubscribeUrl } = input;
  const total = charges.reduce((sum, c) => sum + c.amount, 0);
  const one = charges.length === 1;
  const first = charges[0]!;

  const title = one
    ? `${escapeHtml(first.name)} charges ${escapeHtml(shortDay(first.chargeDate))}`
    : `${charges.length} charges are coming up`;

  const lede = one
    ? `${naira(first.amount)} leaves your account on ${shortDay(first.chargeDate)}.`
    : `${naira(total)} across ${charges.length} subscriptions, all within the next ${leadDays} ${leadDays === 1 ? 'day' : 'days'}.`;

  const rows = charges
    .map((c, i) => chargeRow(c.name, shortDay(c.chargeDate), c.amount, i === charges.length - 1))
    .join('\n');

  const html = emailShell(
    `
${eyebrow('Coming up')}
${headline(title)}
<p class="ink-600" style="margin:0 0 26px; font-family:${sansFont}; font-size:14.5px; line-height:1.65; color:${light.ink600};">${escapeHtml(lede)}</p>

<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="width:100%;">
${rows}
</table>

${divider()}

${unsubscribeFooter(unsubscribeUrl, 'Recur watches your statement, so this is what your bank is about to be asked for. If any of it is a surprise, that is the point of the email.')}
`,
    one
      ? `${naira(first.amount)} to ${first.name} on ${shortDay(first.chargeDate)}.`
      : `${naira(total)} across ${charges.length} subscriptions in the next ${leadDays} days.`,
  );

  const text = [
    one ? 'Coming up' : `${charges.length} charges are coming up`,
    '',
    lede,
    '',
    ...charges.map((c) => `${c.name} · ${shortDay(c.chargeDate)} · ${naira(c.amount)}`),
    '',
    'If any of it is a surprise, that is the point of the email.',
    `Unsubscribe from renewal reminders: ${unsubscribeUrl}`,
    '',
    'Recur, Lagos, Nigeria',
  ].join('\n');

  return {
    subject: one
      ? `${first.name} charges ${shortDay(first.chargeDate)}`
      : `${naira(total)} in subscriptions coming up`,
    text,
    html,
  };
}

export interface DigestCategory {
  label: string;
  spent: number;
}

/**
 * The Monday summary.
 *
 * Leads with the week ahead rather than the week behind, because a total you
 * can still do something about is worth more than one you cannot. What the
 * month has cost so far comes second, as context for it.
 */
export function renderWeeklyDigestEmail(input: {
  weekAhead: RenewalReminderCharge[];
  /**
   * Still accepted, no longer shown. The digest is the week ahead and nothing
   * else: a month-to-date total is a number you cannot act on, and it was
   * doubling the length of the email to say so. The scheduler still computes
   * and passes these, so dropping them from the payload is a separate change
   * from dropping them from the design.
   */
  monthSoFar?: number;
  monthLabel?: string;
  topCategories?: DigestCategory[];
  activeCount: number;
  monthlyTotal: number;
  unsubscribeUrl: string;
}): RenderedEmail {
  const { weekAhead, activeCount, monthlyTotal, unsubscribeUrl } = input;
  const weekTotal = weekAhead.reduce((sum, c) => sum + c.amount, 0);

  const title = weekAhead.length === 0
    ? 'Nothing charges this week'
    : `${naira(weekTotal)} charges this week`;

  const lede = weekAhead.length === 0
    ? `No subscriptions are due in the next seven days. You are tracking ${activeCount} of them, ${naira(monthlyTotal)} a month in total.`
    : `Across ${weekAhead.length} ${weekAhead.length === 1 ? 'subscription' : 'subscriptions'}. You are tracking ${activeCount} in total, ${naira(monthlyTotal)} a month.`;

  const rows = weekAhead
    .map((c, i) => chargeRow(c.name, shortDay(c.chargeDate), c.amount, i === weekAhead.length - 1))
    .join('\n');

  const html = emailShell(
    `
${eyebrow('Your week')}
${headline(title)}
<p class="ink-600" style="margin:0 0 26px; font-family:${sansFont}; font-size:14.5px; line-height:1.65; color:${light.ink600};">${escapeHtml(lede)}</p>

${
  weekAhead.length > 0
    ? `<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="width:100%;">
${rows}
</table>`
    : ''
}

${divider()}

${unsubscribeFooter(unsubscribeUrl, 'Sent every Monday.')}
`,
    weekAhead.length === 0
      ? 'Nothing charges this week.'
      : `${naira(weekTotal)} charges this week.`,
  );

  const text = [
    'Your week',
    '',
    title,
    lede,
    '',
    ...(weekAhead.length > 0
      ? weekAhead.map((c) => `${c.name} · ${shortDay(c.chargeDate)} · ${naira(c.amount)}`)
      : []),
    '',
    'Sent every Monday.',
    `Unsubscribe from the weekly digest: ${unsubscribeUrl}`,
    '',
    'Recur, Lagos, Nigeria',
  ].join('\n');

  return { subject: title, text, html };
}

/**
 * A trial is about to convert.
 *
 * Its own template rather than the renewal one with a zero amount, which read
 * as "Showmax trial ends charges Sun 23 Aug" and put ₦0 next to it. A trial
 * has no amount by definition: nothing has been charged yet, and that is the
 * entire reason this reminder is worth sending.
 */
export function renderTrialReminderEmail(input: {
  label: string;
  endsAt: Date;
  daysAway: number;
  unsubscribeUrl: string;
}): RenderedEmail {
  const { label, endsAt, daysAway, unsubscribeUrl } = input;
  const when =
    daysAway <= 0 ? 'today' : daysAway === 1 ? 'tomorrow' : `in ${daysAway} days`;
  const lede = `Your ${label} trial ends ${when}, on ${shortDay(endsAt)}. If you do nothing, it becomes a paid subscription.`;

  const html = emailShell(
    `
${eyebrow('Trial ending')}
${headline(`${escapeHtml(label)} ends ${escapeHtml(when)}`)}
<p class="ink-600" style="margin:0 0 26px; font-family:${sansFont}; font-size:14.5px; line-height:1.65; color:${light.ink600};">${escapeHtml(lede)}</p>

${divider()}

${unsubscribeFooter(unsubscribeUrl, 'You asked Recur to remind you about this one. Once it charges, it will show up on its own.')}
`,
    lede,
  );

  const text = [
    'Trial ending',
    '',
    lede,
    '',
    'You asked Recur to remind you about this one. Once it charges, it will show up on its own.',
    '',
    'Recur, Lagos, Nigeria',
  ].join('\n');

  return { subject: `${label} trial ends ${when}`, text, html };
}
