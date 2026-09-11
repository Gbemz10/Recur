# Recur, sub-processors

**Controller:** Damprose Innovations Limited
**Prepared:** 11 September 2026

Every third party that touches personal data on Recur's behalf. Drafted for
DPCO review; the transfer-safeguard column in particular needs confirming
against each provider's current terms.

| Provider | What it does | Data it sees | Where |
| --- | --- | --- | --- |
| **Mono** | Open banking. Hosts the bank login, returns transaction history | Bank account identity and full transaction history. Also holds the user's consent record | Nigeria |
| **Supabase** | Managed PostgreSQL. The application database | Everything in the inventory | Outside Nigeria |
| **Render** | Runs the API server | All data in transit through the API | Outside Nigeria |
| **Vercel** | Serves recur.website and collects waitlist signups | Waitlist email addresses | Outside Nigeria |
| **Resend** | Sends transactional email: OTP codes, renewal reminders, the weekly digest, new-device alerts | Email address, display name, and the subscription details quoted in a reminder or digest | Outside Nigeria |

## Notes that matter for the audit

**Mono is the licensed party.** Recur is a consumer of Mono's API. The user
authenticates inside Mono's hosted flow, so bank credentials never reach
Recur's servers or Recur's staff.

**Cross-border transfer.** Supabase, Render, Vercel and Resend all process
outside Nigeria. Under the NDPA this needs a lawful transfer basis, and the
adequacy or contractual position for each has **not yet been established**. It
is the largest open question in this document and should be near the top of the
DPCO's list.

**Email content.** Renewal reminders and the weekly digest quote real
subscription names and amounts, so Resend handles financial detail, not just
addresses. Worth flagging explicitly rather than filing Resend under "email".

**Analytics.** There is no third-party analytics, advertising or tracking SDK
in the app or on the website. Nothing is sold or shared for marketing.
