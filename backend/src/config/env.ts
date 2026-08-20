import 'dotenv/config';
import { z } from 'zod';

/**
 * Fail loudly at boot if the environment is misconfigured, rather than an
 * hour into runtime when the first request that needs a missing value
 * arrives. Every other module imports `env` from here instead of touching
 * `process.env` directly, so this file is the single source of truth for
 * what configuration the app actually needs.
 */
const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(4000),

  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),

  // Now the ACCESS token's lifetime, not the whole session's — kept short
  // because it's stateless and unrevocable by design (see refresh_tokens
  // table). The session itself lives as long as REFRESH_TOKEN_TTL_DAYS,
  // renewed silently by the client via POST /auth/refresh.
  JWT_SECRET: z.string().min(16, 'JWT_SECRET must be at least 16 characters'),
  JWT_EXPIRES_IN: z.string().default('15m'),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),

  // AES-256 key for lib/encryption.ts — encrypts provider secrets (e.g.
  // linkedBanks.providerToken) at rest. 32 raw bytes, hex-encoded. Generate
  // with: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
  ENCRYPTION_KEY: z
    .string()
    .length(64, 'ENCRYPTION_KEY must be a 64-character hex string (32 bytes) — see .env.example')
    .regex(/^[0-9a-fA-F]+$/, 'ENCRYPTION_KEY must be hex-encoded'),

  OTP_LENGTH: z.coerce.number().int().min(4).max(10).default(6),
  OTP_TTL_MINUTES: z.coerce.number().int().positive().default(10),
  OTP_MAX_ATTEMPTS: z.coerce.number().int().positive().default(5),

  // Whether the API process runs the notification timer itself. Off means
  // something external (a platform cron) is expected to POST /notifications/run
  // instead, which is the correct setting the moment there is more than one
  // instance, since the in-process guard against overlap is per-process.
  NOTIFICATIONS_SCHEDULER: z.enum(['on', 'off']).default('on'),
  NOTIFICATIONS_INTERVAL_MINUTES: z.coerce.number().int().positive().default(30),
  // Shared secret for POST /notifications/run. Empty disables the endpoint
  // outright rather than leaving it open, so forgetting to set it fails
  // closed.
  NOTIFICATIONS_RUN_TOKEN: z.string().optional().default(''),

  EMAIL_PROVIDER: z.enum(['console', 'resend']).default('console'),
  // Addresses that must never receive real mail, comma separated.
  //
  // The demo fixture is here by default. It has no mailbox, so every send to
  // it bounces, and a young domain that repeatedly bounces off dead addresses
  // is how recur.website ends up in spam folders for the users who matter.
  // Suppressing at the send layer rather than in one job is deliberate: the
  // fixture also triggers new-device emails on sign-in, and any future path
  // that emails a user would otherwise have to remember this on its own.
  EMAIL_SUPPRESS_LIST: z.string().default('demo@recur.website'),
  EMAIL_FROM: z.string().default('Recur <noreply@recur.website>'),
  RESEND_API_KEY: z.string().optional().default(''),

  // "*" allows any origin (fine in dev; only affects browser clients — see
  // .env.example). In production, set this to a comma-separated allowlist.
  CORS_ORIGIN: z.string().default('*'),

  MONO_SECRET_KEY: z.string().optional().default(''),
  MONO_WEBHOOK_SECRET: z.string().optional().default(''),
  // Where Mono's hosted Connect Link page sends the user's browser/webview
  // after they finish (or abandon) linking. The Flutter client watches for
  // navigation to this URL to know when to close the webview — Mono
  // doesn't pass anything useful in the redirect itself, the actual
  // account id arrives separately via webhook.
  MONO_REDIRECT_URL: z.string().default('https://recur.website/mono/callback'),

  // Avatar uploads go straight to Supabase Storage (same project as
  // DATABASE_URL) via its REST API — no SDK needed, just the project URL
  // and the service_role key (Storage Settings -> API in the Supabase
  // dashboard). Both optional: the app boots fine without them, the
  // avatar-upload endpoint just returns a clear error until they're set.
  SUPABASE_URL: z.string().optional().default(''),
  SUPABASE_SERVICE_ROLE_KEY: z.string().optional().default(''),
  SUPABASE_AVATARS_BUCKET: z.string().default('avatars'),
});

function loadEnv() {
  const parsed = schema.safeParse(process.env);
  if (!parsed.success) {
    console.error('Invalid environment configuration:');
    for (const issue of parsed.error.issues) {
      console.error(`  ${issue.path.join('.')}: ${issue.message}`);
    }
    process.exit(1);
  }
  return parsed.data;
}

export const env = loadEnv();
export type Env = typeof env;
