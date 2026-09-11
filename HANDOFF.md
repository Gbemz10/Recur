# Recur — handoff

Written 2 September 2026 so another assistant can pick this project up without
re-deriving any of it. Everything below was checked against the code, the
running services or DNS at the time of writing. Where something is assumed
rather than verified, it says so.

---

## 0. The domain suspension is cleared (was the hard blocker)

`recur.website` was suspended by Namecheap for failed ICANN WHOIS contact
verification, which took every DNS record with it and broke signup. **Resolved.**
Verified 11 Sept 2026:

```
dig +short NS recur.website
  ns1.vercel-dns.com.
  ns2.vercel-dns.com.

dig +short A recur.website           -> 64.29.17.65, 216.198.79.1
```

DNS now runs on Vercel, and the records Resend needs were re-added by hand on
11 Sept 2026 because the suspension had taken them:

| Type | Host | Value |
| --- | --- | --- |
| `TXT` | `resend._domainkey` | `p=MIGfMA0...IDAQAB` (DKIM) |
| `TXT` | `send` | `v=spf1 include:amazonses.com ~all` |
| `MX` | `send` | `feedback-smtp.eu-west-1.amazonses.com` (priority 10) |
| `TXT` | `_dmarc` | `v=DMARC1; p=none;` |

All four confirmed resolving from public DNS, with the DKIM key compared byte
for byte against the dashboard. Resend's own status still read **Pending** at
the time of writing: the records are published, but someone has to press
**Verify DNS Records** in the Resend dashboard (Domains -> recur.website) to
make it re-check.

Two things to know about this domain's mail setup:

- **The root `MX` is deliberately empty.** Resend sends from the `send.`
  subdomain; the root is reserved for whatever mailbox provider serves
  `support@recur.website`. Do not turn on **Enable Receiving** in Resend, which
  claims the root `MX` and would collide with it.
- **DMARC is at `p=none`**, which is monitoring only. BIMI (blocker 10) needs
  `p=quarantine` or `p=reject`, so that has to be tightened later, once SPF and
  DKIM alignment has been watched for a while.

Still open from the original fallout: the marketing site has to be deployed for
the email logo at `https://www.recur.website/assets/brand/mark.png` to resolve,
and `MONO_REDIRECT_URL` points at `https://recur.website/mono/callback`.

---

## 1. What to do next, in order

1. **Press Verify in Resend** (§0). The suspension is cleared and the SPF,
   DKIM and DMARC records are published; Resend just has not re-checked them.
2. **Check Render's deploy.** `/health` returns 200 but `/brand/mark.png`
   returns 404, so production is running code older than commit `a270f9b` —
   live emails still have the old design and the broken logo. Look for a failed
   or stuck deploy in the Render dashboard.
3. **Answer the CAC query** (§9). Reword the objects to drop "financial
   management", swap the witness, upload every ID. Do not raise share capital.
4. **Separate production from dev databases** (§8, blocker 1). This is the hard
   blocker and the longest job.
5. **Write the privacy policy and terms**, and point the dead Settings button at
   them (blocker 5). Apple, Google and the NDPA all require it.
6. Then the product queue: pagination, whatever remains of onboarding, and the
   advertising work you have not yet chosen a direction on (§7).

---

## 2. Where everything lives on this Mac

All paths verified to exist on 2 Sept 2026.

| Path | What it is | Git? |
|---|---|---|
| `~/Downloads/recur-frontend` | **The repo you work in.** Flutter app in `lib/`, mirrored backend in `backend/`, mirrored site in `website/`. Remote: `github.com/Gbemz10/Recur`, branch `main`. | **yes** |
| `~/Downloads/recur-backend` | The copy that **actually runs locally**, holds the real `.env`. | **no** |
| `~/Downloads/recur-backend/.env` | Real secrets: database URL, Mono keys, Resend key, JWT secret. Never commit. | — |
| `~/Downloads/flutter` | The Flutter SDK itself. | — |
| `~/.claude/projects/-Users-gbemiga-Downloads-recur-frontend/memory/` | Five memory files: overview, launch blockers, working setup, current queue, incorporation. **Copy these to the new account** — they are the long-term context. | — |
| `~/Downloads/recur-mark-3d.html` | Standalone WebGL 3D brand stage. Double-click to open. | — |
| `~/Downloads/recur-mark.svg` / `.png` | Brand mark, vector and raster. | — |
| `~/Downloads/recur-HANDOFF.md` | A copy of this file. | — |

**The trap that matters:** editing `recur-frontend/backend/...` changes nothing
at runtime, because the server runs from `~/Downloads/recur-backend`. Copy the
file across, `touch src/server.ts` to trigger the watcher, wait ~10s, then curl.
Two of the three directories are not git repos, so they can silently drift —
that is blocker 8.

### Hosted services

| Service | Where | Notes |
|---|---|---|
| Backend | Render, `https://recur-z7q0.onrender.com` | Deploys `main`, runs `db:migrate` in the build |
| Database | Supabase Postgres | **One instance shared by prod and dev** — blocker 1 |
| Site | Vercel, `recur.website` | Deploys `website/` |
| Email | Resend, from `noreply@recur.website` | |
| Bank data | Mono | Read-only; they hold the licence |
| Repo | `github.com/Gbemz10/Recur` | |
| Crons | GitHub Actions | `keep-alive.yml`, `notifications.yml` |

---

## 3. What Recur is

A Nigerian consumer app that links read-only to a bank through Mono, detects
recurring charges from transaction history (subscriptions, data plans, trials),
and warns before the next charge lands. **It never holds or moves money** — that
framing is legally load-bearing, see §9.

Gbemiga wrote all the code. The company has three founders as of 1 Sept 2026;
"solo" describes the codebase, not the cap table.

---

## 4. Architecture

### Auth

- JWT access token, 15 minutes. Opaque refresh token, hashed at rest, 30 days,
  rotated on use, revocable.
- `ApiClient` (`lib/data/api_client.dart`) attaches the bearer token and an
  `X-Device-Id` header, and handles silent 401 → refresh → retry. Concurrent
  401s are **coalesced** into one refresh so simultaneous requests don't race to
  rotate the same token.
- New-device sign-in email keys off the client-generated device id, deliberately
  not IP — mobile IPs rotate too much to be a signal.
- Tokens live in `flutter_secure_storage` (keychain). The theme choice, the read
  notices and the push-asked flag reuse the same storage rather than adding a
  preferences plugin.

### Bank linking

App calls `/banking/link/initiate` → Mono returns a Connect Link URL → shown in
a webview, so **the app never sees bank credentials** → Mono redirects to
`recur.website/mono/callback`, which the webview intercepts → the app polls
`GET /banking/accounts` for 40s (20 × 2s).

The account only appears once Mono's `account_connected` **webhook** reaches the
backend. **Mono cannot reach `localhost`**, so local testing needs ngrok. Without
it the poll always times out into "Taking longer than usual" — that screen is
correct, not a bug.

The webhook handler's payload shapes were guesses from Mono's docs and had never
seen a live webhook until Gbemiga's ngrok run. The `id`/`_id` fields are kept
optional because the docs disagree. **Worth tightening against a real payload if
he still has that log.**

### Detection engine

`backend/src/modules/detection/service.ts`. Groups debits by merchant match or
normalised narration → clusters by amount → classifies cadence into bands
(WEEKLY / BIWEEKLY / MONTHLY / QUARTERLY / YEARLY / IRREGULAR) → chains amount
clusters over time, so a plan price change (Spotify Individual → Family) updates
the same subscription row instead of creating a duplicate. Merchants flagged
`trialProne` bypass the two-occurrence minimum: one debit is enough to flag a
possible trial.

Sync paginates into `raw_transactions`, capped around 2000 per sync, then
triggers detection.

### Data model

`backend/src/db/schema.ts` is the single source of truth, shaped to mirror the
Flutter models 1:1 (Subscription, ChargeRecord, BillingCycle,
SubscriptionCategory, SubscriptionStatus) so JSON needs no translation layer.

Fourteen tables: `users`, `refresh_tokens`, `otp_codes`, `known_devices`,
`linked_banks`, `raw_transactions`, `subscriptions`, `charge_records`,
`merchants`, `trial_reminders`, `budgets`, `user_category_rules`,
`notification_preferences`, `waitlist_signups`.

Thirteen migrations, `0001`–`0012`. **They have only ever been applied
incrementally to one database — never run from empty.** That is the step most
likely to surprise during the production split.

---

## 5. API surface

```
Auth        POST   /auth/signup            POST   /auth/login
            POST   /auth/otp/verify        POST   /auth/password
            POST   /auth/forgot-password   POST   /auth/refresh
            POST   /auth/logout
            GET    /auth/me                PATCH  /auth/me
            DELETE /auth/me                POST   /auth/me/password
            POST   /auth/me/avatar

Banking     POST   /banking/link/initiate  GET    /banking/accounts
            POST   /banking/accounts/:id/sync
            DELETE /banking/accounts/:id

Subs        GET    /subscriptions          PATCH  /subscriptions/:id/status
Detection   POST   /detection/run

Trials      GET    /trials                 POST   /trials
            PATCH  /trials/:id/dismiss     PATCH  /trials/:id/restore

Spending    GET    /spending/summary       GET    /spending/categories
            GET    /spending/transactions  POST   /spending/categorize
Budgets     GET    /budgets                PUT    /budgets
            DELETE /budgets/:category

Notifs      POST   /notifications/run      GET    /notifications/preferences
            GET    /notifications/unsubscribe
            POST   /notifications/unsubscribe

Other       GET    /health                 GET    /health/db
            GET    /brand/mark.png         POST   /webhooks/mono
            POST   /waitlist
```

Backend modules: `auth`, `banking`, `brand`, `detection`, `health`,
`notifications`, `spending`, `subscriptions`, `trials`, `waitlist`, `webhooks`.

### Known API wart

`PATCH /subscriptions//status` with an empty id returns **500**, not 400 or 404.
Cosmetic, but a malformed client request reads as a server fault in logs.

Subscription status lives in **three** places that must agree: the pgEnum,
`ALLOWED_STATUSES` in the service, and a `z.enum` in `routes.ts`. Adding
`DISMISSED` needed all three; two passed typecheck while the API still rejected
the value. Derive the zod schema from the enum so it cannot drift.

---

## 6. Environment variables

The backend validates these in `backend/src/config/env.ts`:

```
DATABASE_URL  JWT_SECRET  JWT_EXPIRES_IN  REFRESH_TOKEN_TTL_DAYS
ENCRYPTION_KEY  PORT  NODE_ENV  CORS_ORIGIN  PUBLIC_API_URL
MONO_SECRET_KEY  MONO_WEBHOOK_SECRET  MONO_REDIRECT_URL
RESEND_API_KEY  EMAIL_FROM  EMAIL_PROVIDER  EMAIL_SUPPRESS_LIST
OTP_LENGTH  OTP_TTL_MINUTES  OTP_MAX_ATTEMPTS
NOTIFICATIONS_SCHEDULER  NOTIFICATIONS_INTERVAL_MINUTES  NOTIFICATIONS_RUN_TOKEN
SUPABASE_URL  SUPABASE_SERVICE_ROLE_KEY  SUPABASE_AVATARS_BUCKET
```

**Two gaps found in the local `.env` on 2 Sept 2026:**

- **`EMAIL_SUPPRESS_LIST` is not set locally.** The working notes assume
  `demo@recur.website` is suppressed; it is not, so seeding or testing against
  the demo account **will send real mail to an address with no mailbox**, and
  repeated bounces damage a young sending domain.
- **`PUBLIC_API_URL` is not set locally**, so it defaults to the Render URL.
  Unsubscribe links in locally-sent email therefore point at production.

`EMAIL_PROVIDER` is `"resend"` locally — **local dev sends real email.** For
end-to-end auth testing set `EMAIL_PROVIDER=console`, which prints the OTP to
the backend terminal instead.

A release build of the app needs `--dart-define=API_BASE_URL=...` or it talks to
`localhost` (blocker 6).

---

## 7. The Flutter app

86 Dart files. `lib/main.dart` owns the root flow; `lib/screens/app_shell.dart`
owns the tab shell and every shared store.

### Navigation

```
splash → onboarding (3 slides, skippable) → auth
  auth: email → OTP code → create password
  → chooseName    (stage: only if the profile has no display name)
  → pushAsk       (stage: only if never asked, flag in SetupFlags)
  → linkBank      (stage: only if no active bank)
  → app shell
```

The name and notification screens are **root-flow stages driven by state**, not
steps in the signup chain — anyone who already had a password never saw them
otherwise. That was a real bug, fixed in `b9bb536`.

Tabs: **Home · Recurring · Spending · Trials · Settings**.

### Stores (all `ChangeNotifier`, created once in `AppShell`)

`SubscriptionStore`, `TrialStore`, `ProfileStore`, `BankStore`,
`SpendingStore`, `NoticeReadStore`. They are passed down rather than looked up,
so every tab reads the same instance — `AppShell` keeps tabs alive in an
`IndexedStack`, and a tab already mounted never learns about a change made
elsewhere unless it shares the store.

Optimistic writes are the pattern: mutate locally, notify, then call the API,
and revert on failure. `SubscriptionStore.updateStatus` is the reference
implementation.

### Design system (`lib/ui/`, exported through `ui.dart`)

Tokens in `lib/theme/`:

- **Colour** — `primary #0B6E4F`, `primaryDark #084F39`, `primaryLight #DCF2E7`.
  Neutral ramp `neutral50 #FAF9F4` → `neutral900 #171A14`. Semantic:
  `success #1FAE73`, `warning #E4572E`, `danger #A6291D`, `info #2C6FA6`, each
  with a `*Bg` tint. Theme-aware helpers take a context:
  `background() surface() border() ink() inkSoft() muted() track()
  successTint() primaryTint() primaryInk()`. **Use the helpers, not raw
  constants**, or dark mode breaks.
- **Brand gradient** — `#0B6E4F → #6E8F45 → #D9A441`, top-left to bottom-right.
- **Spacing** — 4px base: `xs 4, sm 8, md 12, lg 16, xl 20, xxl 24, xxxl 32,
  huge 48, massive 64`.
- **Radius** — `sm 6, md 9, lg 12, xl 16, full 999`. Buttons are a hardcoded 10.
- **Typography** — `AppTypography.money` for every amount;
  `AppTypography.mono` only for narrations, account masks and small-caps meta
  labels.

Components worth knowing: `AppButton` (variants `primary, secondary, outline,
ghost, destructive, destructiveOutline`; sizes `sm, md, lg`), `AppCard`,
`AppSheet`, `AppTextField`, `AppTabs`, `AppAvatar`, `AppEmptyState`,
`AppProgressRing`, `AppMeter`, `AppCharts`, `AppPasswordRules`,
`AppPagination` (**exists, nothing uses it — this is the next queue item**).

### Modals and sheets

One shape, in `lib/ui/app_modal.dart` on top of `lib/ui/app_sheet.dart`:

- Floating bottom sheet, clear of the screen on three sides by `AppSpacing.md`.
- **Corner radius 42**, because nested rounded rectangles need inner = outer −
  gap, and the iPhone display corner is about 55.
- Stacked full-width buttons, action first, way-out second.
- `showAppConfirmDialog` (title defaults to "Are you sure?"),
  `showAppSuccessDialog`. `showAppDeleteDialog` was removed — unlinking a bank
  was its only caller and unlinking destroys nothing.
- Form sheets pass `inset: true, showClose: true, closeResult: false`.

---

## 8. Emails

Six templates in `backend/src/lib/emailTemplates.ts`: **OTP, new-device
sign-in, renewal reminder, trial reminder, weekly digest, waitlist.**

- Shared shell with a **brand gradient masthead**, the mark on a white chip
  (it is drawn in the gradient, so green-on-green would hide it), dark-mode
  overrides, a hidden preheader, and table-based layout throughout.
- The mark is hosted at `https://www.recur.website/assets/brand/mark.png`.
  **Never inline it as a `data:` URI** — Apple Mail renders those, Gmail,
  Outlook.com and Yahoo strip them, which is why the logo never appeared for
  most recipients. Do not host it on the API either: Render sleeps, and Gmail
  fetches an image through its proxy exactly once and caches the result, so one
  cold start breaks it permanently for that recipient.
- Unsubscribe is per-channel with an HMAC token, a GET page and an RFC 8058
  POST, plus `List-Unsubscribe` headers. Links are built from `PUBLIC_API_URL`.

**Preview them instead of guessing:**

```bash
cd backend && npx tsx scripts/render-emails.ts /tmp/mail
```

Writes all six to disk as HTML. That is how a green-on-green logo and a washed
out gradient were both caught.

### Crons

Two GitHub Actions workflows, both in `.github/workflows/`:

- `notifications.yml` — hourly at `:17`, POSTs `/notifications/run` with
  `NOTIFICATIONS_RUN_TOKEN`. Render holds the same token plus
  `NOTIFICATIONS_SCHEDULER=off`, so the cron owns the schedule and the
  in-process timer stays out of it.
- `keep-alive.yml` — every 30 minutes, pings `/health`.

Both bound their retries with `--retry-max-time` and `timeout-minutes: 6`.
**`curl` resets `--max-time` on every retry**, so the old
`--retry 5 --max-time 120` was a thirteen-minute worst case — one run hung for
exactly that before reporting the backend was down.

---

## 9. Pre-ship blockers

Ten items, kept deliberately as one pre-production pass.

### 1. Production and dev share one database — HARD BLOCKER

Render's `DATABASE_URL` and the local `.env` point at the same Supabase
instance. Two accidental production writes happened on 20 Aug alone. While this
holds: anyone with the repo has production database access, destructive
migrations cannot be rehearsed because the rehearsal *is* production, and it is
not a defensible NDPA processing arrangement.

**Plan:** new Supabase project for production → run migrations from empty
(never tested) → repoint Render's `DATABASE_URL` → re-link the one real account
(`shogagbemiga@gmail.com`, live Opay and Kuda) against production rather than
copying rows → never put the production URL in a local `.env` → seed only
`db:seed-merchants` there, everything else is fixtures.

**After separation:** the seeder guard matches hostnames and both projects will
be `supabase.co`, so switch it to an explicit `ENVIRONMENT=production` signal
set only on Render.

### 2. The demo seeder's guard misses Supabase

`assertSafeTarget()` in `backend/src/db/seed-demo.ts` blocks render.com,
amazonaws.com, neon.tech, railway.app, heroku, fly.dev, azure.com and
`NODE_ENV=production` — but not Supabase, so given blocker 1 it protects
nothing. One line. The demo password also falls back to a value committed in
that file; `DEMO_PASSWORD` overrides it.

### 3. Dead subscriptions roll forward forever

`projectNextChargeDate` walks forward in whole cycles until it lands in the
future, so `next_charge_date` lies for a stopped subscription. The app no longer
believes it — `hasStopped` reads the charge history and the row says "No charge
since Mar 2026" in the calm muted style, with the detail screen asking "Have you
cancelled this?". **Still open:** the projection itself, and the fact that a
stopped subscription keeps counting toward the monthly total until marked
cancelled. The demo fixture has a stopped Bolt subscription so it is
demonstrable.

### 4. `lastSyncedAt` is written but never read

Reading it would separate "we have not checked since the expected date" from
"we checked and the charge never arrived" — the second being a real finding.
**He declined this deliberately.** Optional, not owed.

### 5. UI promising what the backend does not do

- **Privacy policy is a dead button** — `onTap: () {}` in Settings, and
  `/privacy` and `/terms` both 404. Apple, Google and the NDPA all require a
  reachable privacy policy for an app reading financial data. **Hard blocker.**
  The copy is already earmarked (the "never stores your bank password, can never
  move money" line was pulled off the auth screen to live there).
- **Renewal reminders are email only.** No `firebase_messaging`, no device-token
  column. `PushPermissionScreen` exists and records the answer through
  `onDecided`, but nothing requests the OS permission — that needs an Apple
  Developer account. Until then the Settings row's bell icon overpromises;
  reword to an envelope if launch comes first.
- Cancellation guidance and unsubscribe links: **both done**.

### 6. A release build points at localhost

`lib/config/env.dart` falls back to `http://localhost:4000` (`10.0.2.2` on
Android) unless `--dart-define=API_BASE_URL=...` is passed. Bake it into the
build command rather than remembering it.

### 7. Thin test coverage where it matters

52 Flutter tests across 12 files now, up from 2. **Zero backend tests.** The
detection engine and the categorizer are where a silent regression would be most
expensive and least visible.

### 8. Smaller open items

- Migrations have never run against an empty database.
- `PATCH /subscriptions//status` returns 500 on an empty id.
- Status lives in three lists that must agree.
- `PUBLIC_API_URL` must be right per environment.
- `recur-backend` is an unversioned parallel tree that can silently drift from
  the repo. There was a second one, `~/Downloads/recur-website`, holding a copy
  of the static site less than half the size of the live one. It was deleted on
  11 Sept 2026 after confirming it held nothing the repo did not. The site now
  has one source: `website/` in this repo, which deploys to Vercel on push.
- **Backend linting does not run.** `npm run lint` in `backend/` exits before
  linting anything: ESLint 9 wants the flat `eslint.config.js` format and the
  project still has the old `.eslintrc` style. It has been failing silently, so
  no backend code has actually been linted. Migrate the config, then expect a
  first run to surface a backlog. Found 11 Sept 2026.

### 9. Render free tier

A cold start measured **~33s** today. But **the service does not actually
sleep** — left alone 22 minutes with no pings it answered in 0.67s. The
keep-alive cron also only fired about a quarter of its `*/10` slots (388 runs
across 1,559 slots), which is why it is `*/30` now.

### 10. No sender logo in Gmail (BIMI)

Needs all of: **DMARC at enforcement** (`p=quarantine` or `p=reject`; Gmail
ignores BIMI at `p=none`, and moving straight to enforcement can bin legitimate
mail if SPF/DKIM alignment is not clean), an **SVG Tiny PS logo** on HTTPS, and
a **TXT record** at `default._bimi.recur.website`. A **VMC** (~$1,000–1,500/yr,
DigiCert or Entrust) is what Gmail wants for the verified check; some senders
get the logo without one, so try first.

**The artwork is done:** `website/assets/brand/mark.svg` is written to the Tiny
PS profile — square viewBox, `<title>`, no scripts, no external references.
Blocked on §0.

---

## 10. Company, legal, compliance

Filed at CAC on **1 Sept 2026**, deliberately as a **software company, not
financial services** — business category **Information and Communication**.
Recur reads transactions read-only through Mono, who hold the licence; it never
holds, moves or transmits funds. Declaring financial-services objects would have
implied a regulated activity: higher minimum share capital, and CAC commonly
wanting a CBN/SEC no-objection first.

**Keep the framing consistent everywhere** — Mono KYB, bank account opening, app
store listings, the site, investor material. A mismatch is what gets questioned.
Avoid *payments, transfers, remittance, wallet, lending, credit, banking,
financial services* as descriptions of what the company does.

Share capital: **₦1,000,000 in 1,000,000 ordinary shares of ₦1.00**. Articles:
CAC's model articles, which investors replace at a priced round.

### CAC queried it on 2 Sept 2026 — three items

1. **"Financial Management Is 150million Shares"** — the reviewer read the
   objects as **Fund/Portfolio Manager** (₦150m minimum capital) because they
   said software "for personal **financial management**". Two words.
   **Lesson: avoid "financial" as a bare adjective in CAC objects**, even inside
   an obviously software-shaped sentence. Replacement wording describes the
   software by what it does: *"for tracking subscriptions, recurring charges and
   personal expenditure, including spending categorisation, budgeting tools,
   reminders and user notifications."*
   **Do not raise share capital to ₦150m** — about ₦1.1m in stamp duty, and SEC
   evidence would then be demanded. Fix the wording instead. Query resolution
   does not require re-paying stamp duty provided share capital is unchanged.
2. **A director or shareholder cannot be a witness.** One founder witnessed
   another's signature. The witness must be independent, with their own name,
   address, occupation, signature and ID.
3. **Upload IDs** for every director, shareholder, PSC and the witness. Names
   must match the application character-for-character.

### Cap table

**Three founders**, split **not agreed** as of 1 Sept 2026. Advice given: drive
the split off future full-time commitment plus the fact that Gbemiga had already
built and shipped the entire product alone, and treat **vesting as more
important than the split** — shares allotted at CAC are permanently the
holder's, so a shareholders' agreement with a buyback right over unvested shares
(four years, one-year cliff) must be papered separately and close to allotment.
No SHA existed as of that date.

### Open compliance item

Processing Nigerians' financial data likely makes Recur a **data controller of
major importance** under the NDPA, carrying **NDPC registration** and an annual
audit filing. Separate from CAC. Pairs with the privacy-policy blocker.

---

## 11. What changed in the last session (14 commits, all on `main`)

Oldest first.

| Commit | Change |
|---|---|
| `7a63333` | Bounded both crons' retries; keep-alive moved to `*/30` |
| `a93bfd4` | Undo stopped double-toasting and stopped being swallowed |
| `64c970e` | Trial restore is optimistic instead of reloading the tab |
| `a270f9b` | Email: hosted logo, gradient masthead, digest trimmed |
| `b907266` | Dialogs became floating bottom sheets |
| `5513d01` | Alerts moved behind a bell, with read state |
| `db33b47` | Trial expiry, date wording, midnight rebuild |
| `b9bb536` | Signup rebuilt as one question per screen |
| `6b9ff18` | Profile stops repeating itself |
| `32d1ebc` | Password → name handoff, no bounce back to the email screen |
| `8e50cbb` | Home has an empty state before anything is detected |
| `7ba59ca` | The prompt sits under the total, not instead of it |
| `ade1cb2` | And centred in the space it has |
| `ea4698c` | The brand mark as a vector |
| `afae8ee` | This handoff |

**Undo** used to call the method that raised the first toast, so reversing an
action produced a second toast worded like a fresh action and carrying its own
Undo. That method also opens with a per-row in-flight guard, and the toast
appears when the change is applied rather than when the PATCH lands — so Undo
tapped quickly was silently dropped.

**Trial restore** PATCHed and then called `load()`, flipping `isLoading` and
refetching everything to return a row the app was still holding.

**Notifications** moved charge, price-rise and trial alerts off Home. Notice ids
derive from *what the notice is about* (`due:<sorted sub ids>`,
`price:<id>:<amount>`), never position, so a new charge is a new notice rather
than one already read.

**Trials** now leave the tab three days past their end date, stay on the server,
and become a quiet grey mention under the bell for 30 days. `AppShell` rebuilds
at midnight and on resume — Flutter does not draw a frame just because the clock
moved.

**Auth** is email → code → password, one question per screen, the button riding
above the keyboard (`resizeToAvoidBottomInset: false`, inset applied by hand).
The password screen has no confirm field: the eye control catches typos better.

---

## 12. Testing

```bash
flutter test              # 52 tests, 12 files, all passing
flutter analyze lib test  # clean
cd backend && npx tsc --noEmit
```

`test/support/fake_api.dart` is a shared canned-HTTP harness built on
`HttpOverrides`, with a stub for the secure-storage plugin channel.

> **Harness trap:** `apiClient` is a lazily-built global that creates its
> `http.Client` **once**, so `createHttpClient` runs for the *first* test in a
> file only — every later test is served by the first test's fake. Call
> `setFakeResponses({...})` per test. A fixture that is correct but never
> consulted reads exactly like the app failing to parse it. This cost an hour.

---

## 13. Building and verifying

```bash
flutter build ios --simulator --debug
```

Simulator device `6B4D0377-46E6-458B-9C96-6D3434E2D417` (iPhone 15). Install
`build/ios/iphonesimulator/Runner.app`. Tab bar sits at y≈790 in device points;
the five tabs near x = 39 / 118 / 196 / 277 / 353. Screenshots at scale
0.4–0.5 are legible and far cheaper than full size.

**When a change "isn't showing":** stale `flutter run` sessions reinstall their
own old compilation over yours. Three were alive at once during the last
session, one running since 17 August. Check before doubting the code:

```bash
ps -Ao pid,lstart,args | grep flutter_tools     # kill any stale ones
APP=$(xcrun simctl get_app_container <udid> com.example.recur)
grep -a "some new string" "$APP/Frameworks/App.framework/flutter_assets/kernel_blob.bin"
```

That last command tells you what is *actually* on the device, rather than what
you believe you built.

### Seeding

```bash
npm run db:seed-merchants   # reference data, safe anywhere
npm run db:seed-demo        # demo@recur.website / RecurDemo2026
```

`db:seed-demo` rebuilds only that user's rows and runs the real categorizer and
detector, so the demo exercises the real pipeline. **Never import `seed.ts` from
another script** — it calls `main()` at import time and will re-seed the dev
user. That happened once.

---

## 14. How he likes to work

- **Terse copy.** He cuts explanatory paragraphs on sight. Prefer a label over a
  sentence, and never a sentence restating the screen you tapped to reach.
- **No hardcoded data.** Amounts, counts and dates derive from real figures.
- **Money is `AppTypography.money`**; mono is for narrations, account masks and
  small-caps meta labels only.
- **Confirm every change. Offer Undo only where the code can genuinely reverse
  it.** A toast when reversible, a modal when final — never both.
- He pushes back on decoration that is not doing work, and on alarm colours used
  for things that are not alarming.
- **Verify on screen, not in your head.** Screenshot the simulator, render the
  email, measure the layout. Several times last session a change looked right in
  code and was wrong on the device: the centring of the bank prompt, the
  washed-out email gradient, the OTP button that never enabled.
- He is direct when something is wrong ("this is literally still the same
  thing"). He is usually right, and it is usually something stale — check what
  is actually installed or deployed before defending the code.
- Commits are prose: what changed, and why the old behaviour was wrong.

---

## 15. Measured last session, so nobody repeats it

- Render does not spin down — 22 idle minutes, 0.67s response. But a genuine
  cold start is ~33s.
- The keep-alive cron fires ~25% of its scheduled slots; GitHub throttles short
  intervals hardest.
- `curl` resets `--max-time` on every retry.
- Gmail strips `data:` URI images; Apple Mail does not.
- Mono cannot webhook to `localhost`.
- Gmail fetches an email image through its proxy once and caches the result.
- Nested rounded rectangles need inner radius = outer − gap.
- `Center` inside `SliverFillRemaining` does not take the height the sliver
  offers; a `Column` with `mainAxisAlignment: center` does.

---

## 16. Assets and open creative work

- `website/assets/brand/mark.svg` — true vector, generated from
  `_RecurLogoPainter`'s own constants: arc swept 78% of a circle, stroke 15.5%
  of the width, triangular head at the leading tip. BIMI Tiny PS profile.
- `website/assets/brand/mark.png` — 453×453 RGBA, what email embeds.
- `~/Downloads/recur-mark-3d.html` — standalone WebGL 3D stage, no
  dependencies. Drag to orbit, paper/studio stages, depth slider, `H` hides the
  UI for clean screen recording.
- Brand gradient: `#0B6E4F → #6E8F45 → #D9A441`.

**Open:** he asked for a cinematic video and a 3D model. Video and 3D files
cannot be generated here; the SVG and the WebGL stage were delivered instead.
**He has not chosen** between an animated sequence he can screen-record, or a
shot list and script for a videographer. That decision is still outstanding.
