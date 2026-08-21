import type { UnsubscribeChannel } from './unsubscribeToken.js';

const LABELS: Record<UnsubscribeChannel, string> = {
  reminders: 'renewal reminders',
  digest: 'the weekly digest',
};

/**
 * The page someone lands on after clicking unsubscribe.
 *
 * Self-contained: no stylesheet, no script, no font request. It is opened from
 * a mail client on an unknown device and often a bad connection, and it has
 * one job, which is to confirm the thing already happened.
 *
 * It does not offer a re-subscribe button. Turning something back on is a
 * change to an account, and doing that from an unauthenticated link would make
 * the token a two-way switch rather than a one-way opt-out. The app is one tap
 * away and already has the setting.
 */
export function renderUnsubscribePage(channel: UnsubscribeChannel | null): string {
  const ok = channel !== null;
  const title = ok ? 'Unsubscribed' : 'That link did not work';
  const body = ok
    ? `You will not get ${LABELS[channel]} from Recur any more. Everything else, including anything you asked for directly, is unaffected.`
    : 'The link may have been altered, or it may be from before a security change on your account. Nothing has been changed.';
  const note = ok
    ? 'Changed your mind? Turn it back on in the Recur app under Settings, Notifications.'
    : 'You can manage every notification in the Recur app under Settings, Notifications.';

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${title} · Recur</title>
</head>
<body style="margin:0; padding:0; background-color:#F7F6F1;">
<div style="max-width:460px; margin:0 auto; padding:72px 24px; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <p style="margin:0 0 28px; font-size:19px; font-weight:800; letter-spacing:-0.6px; color:#0B3B2E;">recur</p>
  <h1 style="margin:0 0 12px; font-size:25px; font-weight:800; letter-spacing:-0.6px; line-height:1.25; color:#14171A;">${title}</h1>
  <p style="margin:0 0 22px; font-size:15px; line-height:1.6; color:#4A4F45;">${body}</p>
  <p style="margin:0; font-size:13.5px; line-height:1.6; color:#6E7166;">${note}</p>
</div>
</body>
</html>`;
}
