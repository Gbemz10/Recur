# Recur — handoff

Written 2 September 2026, at the end of a long working session, so another
assistant can pick the project up without re-deriving any of it. Everything
below was verified against the code, the running services or DNS at the time of
writing; where something is assumed rather than checked, it says so.

---

## 0. Do this first — the domain is suspended

`recur.website` is currently **suspended by Namecheap for failed ICANN WHOIS
contact verification**. Verified 2 Sept 2026:

```
dig +short NS recur.website
  failed-whois-verification.namecheap.com.
  verify-contact-details.namecheap.com.

dig +short MX recur.website        -> (nothing)
dig +short TXT recur.website       -> (nothing)
dig +short TXT _dmarc.recur.website -> (nothing)
https://www.recur.website/         -> connection refused
http://recur.website/              -> 200, Namecheap holding page
```

Every DNS record for the domain is gone while this holds. Consequences, in
order of severity:

1. **Signup is broken.** Transactional mail is sent from
   `noreply@recur.website` through Resend. With no SPF or DKIM published,
   receivers cannot authenticate it, so OTP codes bounce or land in spam.
   Nobody can complete signup.
2. **The marketing site is offline**, which also 404s the logo now embedded in
   every email (see §5).
3. `MONO_REDIRECT_URL` is `https://recur.website/mono/callback`.
4. BIMI (blocker 10) cannot be started until DNS exists again.

**Fix:** Namecheap dashboard → resend the contact-verification email → click the
link. Restoration is usually under an hour. Afterwards **check the records came
back**: Vercel's A/CNAME for the site, Resend's DKIM selector, and SPF. They may
need re-adding.

Nothing else in this document matters as much as this.

---

## 1. What Recur is

A Nigerian consumer app that links read-only to a bank through **Mono**,
detects recurring charges from transaction history (subscriptions, data plans,
trials), and warns before the next charge lands. It never holds or moves money.

- **Flutter app** (iOS-first, tested on the simulator).
- **Node/TypeScript/Fastify/Drizzle backend** on Postgres (Supabase), deployed
  to Render at `https://recur-z7q0.onrender.com`.
- **Static marketing site** on Vercel at `recur.website`.

Gbemiga wrote all the code. The company has **three founders** as of 1 Sept
2026 — "solo" describes the codebase, not the cap table.

---

## 2. Repos and where things live

Three directories, all under `~/Downloads`:

| Directory | What it is |
|---|---|
| `recur-frontend` | **The git repo used for everything.** Flutter app in `lib/`, plus a mirrored copy of the backend in `backend/`. This is what "the repo" means. |
| `recur-backend` | An **unversioned** copy that holds the real `.env` and is what the local server actually runs. |
| `recur-website` | The static site (also mirrored at `recur-frontend/website/`). |

**The trap:** editing `recur-frontend/backend/...` changes nothing at runtime.
Copy the file across to `~/Downloads/recur-backend/`, `touch src/server.ts` to
trigger the watcher, wait ~10s, then curl. This bit me twice this session.

Deployment is by push to `main`:

- **Render** deploys the backend and runs `db:migrate` in its build. A failing
  migration means no deploy and the old build keeps serving. Symptom of a stale
  deploy: `/health` 200 while a new route 404s.
- **Vercel** deploys `website/`.

---

## 3. Running and verifying

```bash
# Flutter
flutter test                     # 52 tests, all passing as of this handoff
flutter analyze lib test         # clean (14 pre-existing infos elsewhere)
flutter build ios --simulator --debug

# Backend
cd backend && npx tsc --noEmit
npx tsx scripts/render-emails.ts <outdir>   # renders all 6 emails to HTML
```

**Simulator:** device `6B4D0377-46E6-458B-9C96-6D3434E2D417` (iPhone 15).
Install with the iOS control tool's `launch` and
`build/ios/iphonesimulator/Runner.app`. Tab bar is at y≈790 in device points;
the five tabs sit near x = 39 / 118 / 196 / 277 / 353. Screenshots at
`scale: 0.4–0.5` are legible and much cheaper than full size.

**A trap that cost an hour this session:** stale `flutter run` sessions
reinstall their own week-old compilation over yours. I found three still alive
(one since 17 Aug) and killed them. If a change "isn't showing", check
`ps -Ao pid,lstart,args | grep flutter_tools` before doubting the code, and
verify what is actually on the device:

```bash
APP=$(xcrun simctl get_app_container <udid> com.example.recur)
grep -a "some new string" "$APP/Frameworks/App.framework/flutter_assets/kernel_blob.bin"
```

**Local bank linking needs a tunnel.** Mono confirms a link by webhook, and
Mono cannot reach `localhost`. Without ngrok the app polls for 40s
(20 attempts × 2s) and shows "Taking longer than usual". Gbemiga has ngrok
working; that is the supported local path.

**Email in local dev sends for real.** `~/Downloads/recur-backend/.env` has
`EMAIL_PROVIDER="resend"`. I caused one bounce this session by typing a bad
address into a signup test. For end-to-end auth testing set
`EMAIL_PROVIDER=console`, which prints the OTP to the backend terminal, or add
the test address to `EMAIL_SUPPRESS_LIST`.

**Demo account:** `npm run db:seed-demo` builds `demo@recur.website` /
`RecurDemo2026`. It rebuilds only that user's rows and runs the real detector.
Do **not** import `seed.ts` from another script — it calls `main()` at import
time and will re-seed the dev user.

---

## 4. What changed this session (14 commits, all pushed to `main`)

Newest last. Every one has a full rationale in its commit message; this is the
index.

| Commit | Change |
|---|---|
| `7a63333` | Bounded the keep-alive and notification crons; `*/30` schedule |
| `a93bfd4` | Undo stopped double-toasting and stopped being swallowed |
| `64c970e` | Trial restore is optimistic instead of reloading the tab |
| `a270f9b` | Email: hosted logo, gradient masthead, digest trimmed |
| `b907266` | Dialogs became floating bottom sheets |
| `5513d01` | Alerts moved behind a notification bell, with read state |
| `db33b47` | Trial expiry, date wording, midnight rebuild |
| `b9bb536` | Signup rebuilt as one question per screen |
| `6b9ff18` | Profile stops repeating itself |
| `32d1ebc` | Password → name handoff, no bounce back to the email screen |
| `8e50cbb` | Home has an empty state before anything is detected |
| `7ba59ca` | That prompt sits under the total, not instead of it |
| `ade1cb2` | And centred in the space it has |
| `ea4698c` | The brand mark as a vector |

### The substantive pieces

**Undo (`a93bfd4`).** Undo used to call the same method that raised the first
toast, so reversing an action produced a second toast worded like a fresh
action and carrying its own Undo. Worse, that method opens with a per-row
in-flight guard, and the toast appears when the change is applied rather than
when the PATCH lands — so Undo tapped quickly was silently dropped. Undo now
skips the guard and the toast.

**Trial restore (`64c970e`).** `TrialStore.restore` PATCHed and then called
`load()`, flipping `isLoading` and refetching everything to return a row the app
was still holding. The tab blinked into skeletons for one undo. It is optimistic
now, mirroring `dismiss`.

**Email (`a270f9b`).** The logo had never rendered for most recipients: it was a
base64 `data:` URI, which Apple Mail shows and **Gmail, Outlook.com and Yahoo
strip**. It is now hosted on the marketing site. Hosting it on the API was
rejected deliberately — the free Render instance sleeps, Gmail fetches an image
through its proxy exactly once and caches the result, so one cold start breaks
the logo permanently for that recipient. Also added a brand gradient masthead,
brand-tinted OTP digits, and removed "August so far" from the weekly digest.
`backend/scripts/render-emails.ts` renders all six templates to disk — that is
how the green-on-green mark was caught.

**Sheets (`b907266`).** Confirm/delete/success were three near-identical dialog
bodies; they are one `_SheetBody` now, presented as a floating bottom sheet.
Corner radius is 42 because nested rounded rectangles need inner = outer − gap
(the iPhone display corner is ~55, the margin is 12). `showAppDeleteDialog` was
deleted — unlinking a bank was its only caller and unlinking destroys nothing.

**Notifications (`5513d01`).** Charge/price/trial alerts moved off Home to a
page behind a bell, with per-notice read state stored locally. Notice ids derive
from *what the notice is about* (`due:<sorted sub ids>`, `price:<id>:<amount>`),
never position, so a new charge is a new notice rather than one already read.

**Trials (`db33b47`).** An ended trial used to sit in "Ending soon" forever. It
now leaves the tab three days past its end date, stays on the server, and
becomes a quiet grey mention under the bell for 30 days. Date wording is
"Expires today / tomorrow / Expired yesterday", date beyond that, tense
following the date. `AppShell` rebuilds at midnight and on resume, because
Flutter does not draw a frame just because the clock moved.

**Auth (`b9bb536`, `32d1ebc`).** Email → code → password, one question per
screen, button riding above the keyboard (managed by hand;
`resizeToAvoidBottomInset: false`). The password screen lost its confirm field —
the eye control catches typos better. Name and notification screens are now
**root-flow stages driven by state**, not steps in the signup chain, because
anyone who already had a password never saw them. Sign-out lands on sign-in.

**Home empty state (`8e50cbb`ff).** ₦0 over the gradient with nothing else was
the whole screen for anyone who skipped linking. The total stays; a prompt sits
centred in the space below it, with a button only when no bank is linked (with
one linked and nothing found, there is nothing to press that would help).

### Testing added

From 2 test files to 12, 52 tests. `test/support/fake_api.dart` is a shared
canned-HTTP harness.

> **Harness trap, worth knowing:** `apiClient` is a lazily-built global that
> creates its `http.Client` **once**, so `createHttpClient` runs for the *first*
> test in a file only — every later test is served by the first test's fake.
> Call `setFakeResponses({...})` per test. A fixture that looks correct but is
> never consulted reads exactly like the app failing to parse it.

---

## 5. Deployment state right now

| Thing | State |
|---|---|
| Flutter app | Local only. Not on TestFlight or any store. |
| Backend on Render | `/health` 200, but **~33s cold start** and `/brand/mark.png` **404** — so Render is running code older than `a270f9b`. Check the Render dashboard for a failed or pending deploy. |
| Website on Vercel | **Unreachable** — see §0. It did deploy earlier today (the mark returned 200 before the domain went down). |
| Email templates in production | Whatever Render is running, i.e. probably still the old design. Local dev has the new ones. |

---

## 6. What is next (his stated order)

From the queue, as he gave it:

1. ~~DISMISSED status~~ — done, `89cc8f9`.
2. ~~Success modal~~ — done; it is one of the three sheet variants now.
3. **Pagination** — `lib/ui/app_pagination.dart` exists and nothing uses it.
   Likely candidates: transactions behind a spending category, and charge
   history.
4. **Onboarding changes** — he has been working through these all session
   (auth screens, name, notifications, empty state). Ask what remains.

Also outstanding from this session's conversation:

- **The advertising work.** He asked for a cinematic video and a 3D brand
  model. I cannot generate video or 3D files and said so. Delivered instead:
  `website/assets/brand/mark.svg` (true vector, from the painter's own
  constants) and a WebGL "Recur Mark Studio" page — real 3D geometry, orbit,
  paper/studio stages, depth slider, `H` hides the UI for recording. Saved to
  `~/Downloads/recur-mark-3d.html`. **He has not yet chosen** between an
  animated sequence he can screen-record, or a shot list and script for a
  videographer.
- **Push notifications** are designed but not wired. `PushPermissionScreen`
  reports the answer through `onDecided`; nothing requests the OS permission.
  Needs an Apple Developer account.

---

## 7. Pre-ship blockers

Ten items, kept as a deliberate list to be done in one pre-production pass. Full
detail lives in the memory file; this is the working summary.

### 1. Production and dev share one database — HARD BLOCKER

Render's `DATABASE_URL` and the local `.env` point at the same Supabase
instance. Two accidental production writes happened on 20 Aug alone. While this
holds: anyone with the repo has production DB access, destructive migrations
cannot be rehearsed, and it is not a defensible NDPA processing arrangement.

Plan: new Supabase project for production → run migrations from empty (never
tested) → repoint Render → re-link the one real account rather than copying
rows → never put the production URL in a local `.env` → seed only merchants.
After separation the seeder guard must switch from hostname matching to an
explicit `ENVIRONMENT=production` signal, since both projects will be
`supabase.co`.

### 2. The demo seeder's guard misses Supabase

`assertSafeTarget()` in `backend/src/db/seed-demo.ts` blocks render/aws/neon/
railway/heroku/fly/azure but not Supabase, so it currently protects nothing.
One line. Also the demo password falls back to a committed value.

### 3. Dead subscriptions roll forward forever

`projectNextChargeDate` walks forward in whole cycles until it lands in the
future, so `next_charge_date` lies for a stopped subscription. The app no longer
believes it (`hasStopped` reads the charge history), but the projection itself
is unfixed and a stopped subscription still counts toward the monthly total
until marked cancelled.

### 4. `lastSyncedAt` written, never read

Would let the app distinguish "we have not checked" from "we checked and the
charge never came". **He declined this deliberately** — optional, not owed.

### 5. UI promising what the backend does not do

- **Privacy policy is a dead button** (`onTap: () {}`), and `/privacy` and
  `/terms` 404. Apple, Google and the NDPA all require a reachable privacy
  policy for an app reading financial data. **Hard blocker.** He has already
  earmarked the copy.
- **Renewal reminders are email only.** The Settings row's bell icon reads as
  push. Reword to an envelope if launch comes before push.
- Cancellation guidance and unsubscribe links: both done.

### 6. A release build points at localhost

`lib/config/env.dart` falls back to `http://localhost:4000` unless
`--dart-define=API_BASE_URL=...` is passed. Bake it into the build command.

### 7. Thin test coverage where it matters

52 Flutter tests now, but **zero backend tests**. The detection engine and the
categorizer are where a silent regression would be most expensive and least
visible.

### 8. Smaller open items

- Migrations have never run against an empty database.
- `PATCH /subscriptions//status` with an empty id returns 500, not 400.
- Subscription status lives in three lists that must agree (pgEnum,
  `ALLOWED_STATUSES`, route `z.enum`). Derive the zod schema from the enum.
- `PUBLIC_API_URL` must be right per environment; unsubscribe links are built
  from it.
- `recur-backend` is an unversioned parallel tree that can silently drift.

### 9. Render free tier spins down

~33s cold start measured today. A keep-alive workflow pings it, but **measured
this session: the service does not actually sleep** — left alone 22 minutes with
no pings it answered in 0.67s. The cron also only fires about a quarter of its
`*/10` slots (388 runs across 1,559 slots), which is why it is `*/30` now.

### 10. No sender logo in Gmail (BIMI)

Needs DMARC at enforcement, an SVG Tiny PS logo on HTTPS, and a TXT record at
`default._bimi.recur.website`. A VMC (~$1,000–1,500/yr) is what Gmail wants for
the verified check; try without first. **The artwork is done** —
`website/assets/brand/mark.svg` is written to the Tiny PS profile. Blocked on
§0.

---

## 8. Company, legal, compliance

Filed at CAC on 1 Sept 2026, deliberately as a **software company, not
financial services** — category Information & Communication. Recur reads
transactions read-only through Mono, who hold the licence.

**Keep that framing everywhere** — Mono KYB, bank account opening, app store
listings, the site, investor material. Avoid *payments, transfers, remittance,
wallet, lending, credit, banking, financial services* as descriptions of what
the company does.

**CAC queried it on 2 Sept 2026** with three items:

1. "Financial Management Is 150million Shares" — the reviewer read the objects
   as Fund/Portfolio Manager because they said software "for personal
   **financial management**". Two words. Do not raise share capital to ₦150m to
   satisfy this (~₦1.1m stamp duty, and SEC evidence would follow); fix the
   wording. Replacement describes the software by what it does: "for tracking
   subscriptions, recurring charges and personal expenditure, including spending
   categorisation, budgeting tools, reminders and user notifications."
2. A director/shareholder cannot witness another's signature — the witness must
   be independent, with their own details and ID.
3. Upload IDs for every director, shareholder, PSC and the witness; names must
   match character-for-character.

Share capital filed: ₦1,000,000 in 1,000,000 ordinary shares of ₦1.00. Query
resolution does not require re-paying stamp duty provided this is unchanged.

**Cap table:** three founders, split **not yet agreed** as of 1 Sept. Advice
given: drive it off future full-time commitment plus the fact that Gbemiga
built and shipped the product alone, and treat **vesting as more important than
the split** — shares allotted at CAC are permanently the holder's, so a
shareholders' agreement with a buyback over unvested shares (four years, one
year cliff) must be papered separately and close to allotment. As of 1 Sept no
SHA existed.

**Open compliance item:** processing Nigerians' financial data likely makes
Recur a *data controller of major importance* under the NDPA — NDPC
registration plus an annual audit filing. Pairs with the privacy-policy
blocker.

---

## 9. How he likes to work

Learned across sessions; worth not relearning.

- **Terse copy.** He cuts explanatory paragraphs repeatedly. Prefer a label
  over a sentence, and never a sentence restating the screen you tapped to
  reach. He removed the helper text under the name field and the paragraph
  under the bank prompt on sight.
- **No hardcoded data.** Amounts, counts and dates derive from real figures.
- **Money is `AppTypography.money`**; mono is for narrations, account masks and
  small-caps meta labels only.
- **Confirm every change; offer Undo only where the code can genuinely
  reverse it.** A toast when reversible, a modal when final — never both.
- He pushes back on decoration that is not doing work, and on alarm colours
  used for things that are not alarming.
- **He wants things verified on screen, not asserted.** Screenshot the
  simulator, render the email, measure the layout. Several times this session a
  change "looked right" in code and was wrong on the device — the centring of
  the bank prompt, the washed-out email gradient, the disabled OTP button.
- He is direct when something is wrong ("this is literally still the same
  thing"). Usually he is right and something is stale — check what is actually
  installed or deployed before defending the code.

---

## 10. Things measured this session, so they need not be re-measured

- The Render service **does not spin down** — 22 idle minutes, 0.67s response.
  But a **cold start is ~33s** when it does happen (measured today).
- The keep-alive cron fires **~25% of its scheduled slots**; GitHub throttles
  short intervals hardest.
- `curl` resets `--max-time` on every retry, so `--retry 5 --max-time 120` is a
  13-minute worst case. Both crons now use `--retry-max-time`.
- Gmail strips `data:` URI images. Apple Mail does not.
- Mono cannot webhook to `localhost`; ngrok is required locally.
- The webhook handler's payload shapes were **guesses from Mono's docs and had
  never seen a live webhook** until Gbemiga's ngrok run. Worth tightening the
  optional `id`/`_id` fields against a real payload if he still has the log.

---

## 11. Assets

- `website/assets/brand/mark.svg` — true vector, generated from
  `_RecurLogoPainter`'s own constants (78% sweep, 15.5% stroke, triangular
  head). BIMI Tiny PS profile.
- `website/assets/brand/mark.png` — 453×453 RGBA, what email embeds.
- `~/Downloads/recur-mark-3d.html` — standalone WebGL 3D stage, no
  dependencies, opens by double-click. Also published as an artifact.
- Brand gradient: `#0B6E4F` → `#6E8F45` → `#D9A441`.
