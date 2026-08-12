# Recur backend

Node.js + TypeScript + Fastify + Drizzle ORM + PostgreSQL. Serves the
Flutter app in `recur-frontend` — response shapes mirror the client's
models (`Subscription`, `ChargeRecord`, `BillingCycle`,
`SubscriptionCategory`, `SubscriptionStatus`) so there's minimal
translation on either side.

> Originally scaffolded on Prisma. Switched to Drizzle after Prisma's
> query-engine binary download turned out to be blocked in the sandbox
> this was built in (403 from `binaries.prisma.sh`) — Drizzle is pure
> TypeScript with no native binary step, so it isn't at risk of the same
> class of problem on a locked-down network. Worth knowing if you ever
> reach for Prisma again on a similarly restricted machine or CI runner.

## Setup

1. Have Postgres running locally (or point `DATABASE_URL` at one). Easiest
   local option:
   ```
   docker run --name recur-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=recur -p 5432:5432 -d postgres:16
   ```
2. `cp .env.example .env` and fill in `JWT_SECRET` (see the comment in that
   file for how to generate one). Leave `EMAIL_PROVIDER=console` for local
   dev — OTP codes print to the terminal instead of sending real email.
3. `npm install`
4. `npm run db:generate` — writes SQL migration files from `src/db/schema.ts`
   into `drizzle/`.
5. `npm run db:migrate` — applies them to the database in `DATABASE_URL`.
6. `npm run db:seed` — loads the merchant reference table (Netflix, DStv,
   Spotify, etc., mirroring `lib/data/merchants.dart` on the client) plus a
   dev user (`dev@recur.app` / `password123`) with mock subscriptions, so
   the app has something real to show without waiting on bank-linking to
   be wired up.
7. `npm run dev` — starts the API on `http://localhost:4000` with hot reload.

`npm run db:studio` opens Drizzle Studio, a browser UI for poking at the
data directly — handy instead of a raw `psql` session while developing.

## Structure

```
drizzle/                generated SQL migrations (committed, not written by hand)
drizzle.config.ts        tells drizzle-kit where the schema and DB are
src/
  config/                 env loading + validation (zod)
  db/
    schema.ts              the whole data model, one file
    client.ts               pg Pool + Drizzle instance (singleton)
    seed.ts                  merchant table + dev fixtures
  lib/                    cross-cutting: errors, email, otp, password helpers, Mono API client
  modules/
    auth/                   signup, OTP verify, set/reset password, login
    subscriptions/           list, confirm/dismiss/reactivate
    banking/                 Mono Connect link, list/unlink accounts, transaction sync
    webhooks/                 Mono webhook receiver (account connected/updated/unlinked)
    detection/               recurring-charge detection engine
    health/                  liveness check
  app.ts                  builds the Fastify instance, registers everything
  server.ts               entry point, graceful shutdown
```

## Auth flow (matches the Flutter client exactly)

- **Sign up**: `POST /auth/signup` (email) → `POST /auth/otp/verify` (email
  + code, purpose `SIGNUP`) → `POST /auth/password` (email + new password,
  only valid right after a verified OTP) → client gets a session token back.
- **Sign in**: `POST /auth/login` (email + password) → session token.
- **Forgot password**: `POST /auth/forgot-password` (email) →
  `POST /auth/otp/verify` (purpose `RESET_PASSWORD`) → `POST /auth/password`.

OTP codes are hashed at rest (never stored raw), expire after
`OTP_TTL_MINUTES`, lock out after `OTP_MAX_ATTEMPTS` wrong guesses, and a
fresh code can't be requested more than once every 60 seconds for the same
address — closes the "unauthenticated OTP endpoint as a free email bomb"
gap that was flagged during the frontend build.

## Routes

| Method | Path                          | Auth | Notes                                  |
|--------|-------------------------------|------|-----------------------------------------|
| GET    | `/health`                     | no   | liveness                                |
| GET    | `/health/db`                  | no   | Postgres reachability                   |
| POST   | `/auth/signup`                | no   | body: `{ email }`                       |
| POST   | `/auth/forgot-password`       | no   | body: `{ email }`                       |
| POST   | `/auth/otp/verify`            | no   | body: `{ email, code, purpose }`        |
| POST   | `/auth/password`              | no   | body: `{ email, password, purpose }`    |
| POST   | `/auth/login`                 | no   | body: `{ email, password }`             |
| GET    | `/auth/me`                    | yes  | bearer token                            |
| GET    | `/subscriptions`               | yes  | list, includes merchant + charge history |
| PATCH  | `/subscriptions/:id/status`    | yes  | body: `{ status }`                      |
| POST   | `/banking/link/initiate`       | yes  | returns `{ monoUrl }` — open in a webview |
| GET    | `/banking/accounts`            | yes  | list linked banks                       |
| DELETE | `/banking/accounts/:id`        | yes  | unlink (calls Mono, marks `REVOKED`)    |
| POST   | `/banking/accounts/:id/sync`   | yes  | manual "sync now", also runs detection  |
| POST   | `/webhooks/mono`               | no*  | *guarded by `mono-webhook-secret` header instead of a bearer token |
| POST   | `/detection/run`               | yes  | manual re-scan of a user's transactions |

Protected routes expect `Authorization: Bearer <token>` — the token comes
back from `/auth/password` or `/auth/login`.

## Bank linking + recurring-charge detection

Built against Mono's public API docs (docs.mono.co), using their **Connect
Link** flow (https://docs.mono.co/docs/financial-data/connect-link) rather
than the JS/native Connect widget SDK — deliberately, since the widget SDK
would mean integrating a platform-specific plugin on the Flutter side with
no way to build/test it here. Connect Link is just a hosted URL the client
opens in a webview, so nothing on either side depends on a native plugin
working correctly.

Flow: client calls `POST /banking/link/initiate`, which asks Mono for a
one-time linking URL (`mono_url`) and tags it with `meta.ref` set to the
user's own id. The client opens that URL in a webview; the user picks
their bank and logs in entirely on Mono's hosted page — the app has no
visibility into that step. When they finish, Mono redirects the
webview to `MONO_REDIRECT_URL`; the client watches for that navigation and
closes the webview, but the actual account id isn't known yet at that
point — it arrives moments later via the `mono.events.account_connected`
webhook at `/webhooks/mono`, which uses `meta.ref` to know which user it
belongs to and creates the `linked_banks` row. `mono.events.account_updated`
follows once Mono's data sync finishes, which triggers a transaction sync
(`src/modules/banking/sync.ts`, paginates `GET /v2/accounts/{id}/transactions`
into `raw_transactions`) followed automatically by the detection engine
(`src/modules/detection/service.ts`), which groups debit transactions by
merchant/narration + amount, classifies the interval between charges into
a billing cycle, scores a confidence, and upserts `subscriptions` +
`charge_records`. Detections always land as `UNREVIEWED` — the engine
surfaces candidates, the user confirms them — and a `CANCELLED`
subscription is never resurrected by a later matching transaction.

This means the client has no synchronous "link succeeded, here's your
data" moment — it has to poll `GET /subscriptions` (or `GET
/banking/accounts` for the bank's own status) for a bit after closing the
webview and wait for the async pipeline to catch up. Budget real testing
time against your first real linked account — the exact webhook payload
shapes here are built from documentation, not observed traffic.

### Testing bank-linking against `npm run dev` on your own machine

Mono needs to reach `/webhooks/mono` from the public internet — your local
`localhost:4000` isn't reachable by anything outside your machine, so
without a tunnel the `waiting` step in the Flutter app will time out every
time, even with correct sandbox keys.

1. Install [ngrok](https://ngrok.com) (or any tunnel tool) and run
   `ngrok http 4000`. It gives you a public HTTPS URL like
   `https://abcd1234.ngrok-free.app`.
2. In the [Mono dashboard](https://app.mono.co/apps), open your app →
   Webhooks → add `https://abcd1234.ngrok-free.app/webhooks/mono`. Mono
   generates a webhook secret at that point — copy it into `.env` as
   `MONO_WEBHOOK_SECRET`.
3. Set `MONO_REDIRECT_URL` in `.env` to anything reachable — it doesn't
   need to render anything real, the Flutter client just watches for
   navigation to that exact URL and never actually loads it. The default
   in `.env.example` works fine as-is.
4. Restart `npm run dev` after changing `.env` (env vars are only read at
   boot).
5. Every time you restart ngrok on the free tier, the URL changes — update
   the webhook URL in the Mono dashboard to match, or it'll silently stop
   arriving.

## Not built yet

Nothing structurally — bank linking and detection are both wired up now.
What's untested: the actual Mono API response shapes (this was built
API-docs-first, no live sandbox account was available), and the detection
engine's thresholds (cycle-day bands, amount-clustering tolerance,
confidence weights) are reasonable starting points, not tuned against real
transaction data yet.
