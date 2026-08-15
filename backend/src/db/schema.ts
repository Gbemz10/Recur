import { randomUUID } from 'node:crypto';
import { relations } from 'drizzle-orm';
import {
  pgTable,
  pgEnum,
  uuid,
  text,
  timestamp,
  integer,
  numeric,
  doublePrecision,
  boolean,
  unique,
} from 'drizzle-orm/pg-core';

/**
 * Drizzle schema — the whole data model, one file, mirrored deliberately
 * close to the Flutter client's models (Subscription, ChargeRecord,
 * BillingCycle, SubscriptionCategory, SubscriptionStatus) so JSON
 * responses need almost no translation layer on either side.
 */

export const otpPurposeEnum = pgEnum('otp_purpose', ['SIGNUP', 'RESET_PASSWORD']);
export const bankLinkStatusEnum = pgEnum('bank_link_status', ['ACTIVE', 'REVOKED', 'ERROR']);
export const billingCycleEnum = pgEnum('billing_cycle', ['WEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY']);
export const subscriptionCategoryEnum = pgEnum('subscription_category', [
  'STREAMING',
  'TELECOM',
  'SOFTWARE',
  'FITNESS',
  'FINANCE',
  'OTHER',
]);
export const subscriptionStatusEnum = pgEnum('subscription_status', ['UNREVIEWED', 'ACTIVE', 'CANCELLED']);
export const transactionTypeEnum = pgEnum('transaction_type', ['DEBIT', 'CREDIT']);

// ----------------------------------------------------------------- waitlist

// Pre-launch marketing-site signups (recur.website) — deliberately its own
// table rather than a stub row in `users`, since there's no password/auth
// concept here at all, just an email and where it came from. A signup here
// creates no account; when the app actually launches, converting a waitlist
// row into a real `users` row (if ever needed) is a one-off migration, not
// something this table needs to model up front.
export const waitlistSignups = pgTable('waitlist_signups', {
  id: uuid('id').primaryKey().$defaultFn(() => randomUUID()),
  email: text('email').notNull().unique(),
  // Which form on the page it came from ("hero" | "final_cta") — cheap to
  // capture now, useful later for seeing which CTA actually converts.
  source: text('source'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

// --------------------------------------------------------------------- auth

export const users = pgTable('users', {
  id: uuid('id').primaryKey().$defaultFn(() => randomUUID()),
  email: text('email').notNull().unique(),
  passwordHash: text('password_hash'),
  // Nothing is collected at signup beyond email — both nullable, set later
  // from the profile screen. No name/photo is ever required for the app to
  // function, just optional identity dressing.
  displayName: text('display_name'),
  avatarUrl: text('avatar_url'),
  emailVerifiedAt: timestamp('email_verified_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

// Short-lived codes emailed to prove address ownership before sign-up
// completes or a password resets. Only a hash is ever stored — the same
// way passwords are, never the raw code.
export const otpCodes = pgTable('otp_codes', {
  id: uuid('id').primaryKey().$defaultFn(() => randomUUID()),
  email: text('email').notNull(),
  codeHash: text('code_hash').notNull(),
  purpose: otpPurposeEnum('purpose').notNull(),
  attempts: integer('attempts').notNull().default(0),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  consumedAt: timestamp('consumed_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }),
});

// A JWT access token is short-lived and stateless — nothing here needs to
// track it. A refresh token is the opposite: long-lived, so it has to be
// revocable (sign-out, password change, delete account all need a way to
// actually kill a session, which a stateless JWT alone can never give you)
// — hence one DB row per issued refresh token instead of just trusting a
// blob the client holds. Only the hash is stored, same reasoning as
// otpCodes/passwordHash: a DB leak shouldn't hand out live sessions.
export const refreshTokens = pgTable('refresh_tokens', {
  id: uuid('id').primaryKey().$defaultFn(() => randomUUID()),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  tokenHash: text('token_hash').notNull().unique(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  revokedAt: timestamp('revoked_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

// ------------------------------------------------------------------ banking

// One linked account per row. Mono doesn't issue a separate reusable
// per-account token the way some providers do — the account id itself
// (`providerAccountId`) is the persistent identifier, paired with the
// app-level MONO_SECRET_KEY for every subsequent API call. `providerToken`
// is kept for provider-agnostic shape (a future provider might need one)
// and currently mirrors `providerAccountId`; if it's ever a real secret,
// it must be encrypted at rest before this goes anywhere near production —
// left plain here as an explicit MVP TODO, not an oversight.
export const linkedBanks = pgTable('linked_banks', {
  id: uuid('id').primaryKey().$defaultFn(() => randomUUID()),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  provider: text('provider').notNull().default('mono'),
  bankName: text('bank_name').notNull(),
  bankCode: text('bank_code').notNull(),
  accountNumberMask: text('account_number_mask').notNull(),
  providerAccountId: text('provider_account_id').notNull(),
  providerToken: text('provider_token').notNull(),
  status: bankLinkStatusEnum('status').notNull().default('ACTIVE'),
  linkedAt: timestamp('linked_at', { withTimezone: true }).notNull().defaultNow(),
  lastSyncedAt: timestamp('last_synced_at', { withTimezone: true }),
});

// ------------------------------------------------------------- subscriptions

// The reference table the detection engine matches bank narrations
// against. Mirrors lib/data/merchants.dart on the client.
export const merchants = pgTable('merchants', {
  id: uuid('id').primaryKey().$defaultFn(() => randomUUID()),
  slug: text('slug').notNull().unique(),
  name: text('name').notNull(),
  domain: text('domain').notNull(),
  brandColor: text('brand_color').notNull(),
  category: subscriptionCategoryEnum('category').notNull().default('OTHER'),
  // True for merchants known to run free-trial-then-charge signups
  // (Netflix, Spotify, Showmax, Canva, ChatGPT Plus, iFitness, ...). The
  // detection engine bypasses its usual MIN_OCCURRENCES=2 requirement for
  // these — a single matching debit is enough to flag it, since waiting
  // for a second occurrence would mean waiting for the SECOND real charge,
  // which defeats the point of a trial-forgetting warning.
  trialProne: boolean('trial_prone').notNull().default(false),
});

export const subscriptions = pgTable('subscriptions', {
  id: uuid('id').primaryKey().$defaultFn(() => randomUUID()),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  merchantId: uuid('merchant_id').references(() => merchants.id),

  // What we show the user — often more specific than the merchant name,
  // e.g. merchant "DStv", displayName "DStv Compact".
  displayName: text('display_name').notNull(),
  // Stored (and typed) as a string — Postgres `numeric` has more precision
  // than a JS `number` can safely hold, so Drizzle hands it back as text
  // and conversion happens deliberately at the API boundary, in
  // `serializeSubscription`, rather than silently through a column mode.
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull(),

  // The amount this subscription was charging immediately before its most
  // recent price change, e.g. a Spotify Individual→Family upgrade. Null
  // until the detection engine (or a manual edit) actually observes a
  // change — most subscriptions never have one. Lets the UI show "was
  // ₦1,900, now ₦2,500" instead of just silently updating the number.
  previousAmount: numeric('previous_amount', { precision: 12, scale: 2 }),

  cycle: billingCycleEnum('cycle').notNull(),
  nextChargeDate: timestamp('next_charge_date', { withTimezone: true }).notNull(),
  category: subscriptionCategoryEnum('category').notNull(),
  status: subscriptionStatusEnum('status').notNull().default('UNREVIEWED'),

  // 0–1 detection confidence. Below ~0.6 it should land in Review, not
  // get presented as a firm result.
  confidence: doublePrecision('confidence').notNull().default(1),

  // Stable identity for a detected recurring-charge cluster (normalized
  // narration + amount bucket — see detection/service.ts), so re-running
  // detection updates the same row instead of creating duplicates.
  // Null for manually-added/seeded subscriptions, which never collide
  // with each other since Postgres treats NULL as distinct in a unique
  // constraint.
  detectionKey: text('detection_key'),

  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  uniqueDetectionKey: unique().on(table.userId, table.detectionKey),
}));

// A single historical charge that fed the detection engine. Narration is
// kept verbatim — Nigerian bank narrations are messy, and it's the string
// a user actually recognises their own statement by.
export const chargeRecords = pgTable('charge_records', {
  id: uuid('id').primaryKey().$defaultFn(() => randomUUID()),
  subscriptionId: uuid('subscription_id')
    .notNull()
    .references(() => subscriptions.id, { onDelete: 'cascade' }),
  date: timestamp('date', { withTimezone: true }).notNull(),
  // Stored (and typed) as a string — Postgres `numeric` has more precision
  // than a JS `number` can safely hold, so Drizzle hands it back as text
  // and conversion happens deliberately at the API boundary, in
  // `serializeSubscription`, rather than silently through a column mode.
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull(),
  narration: text('narration').notNull(),

  // Present when this charge was produced by the detection engine rather
  // than seeded/entered manually. Unique so re-running detection over the
  // same raw transaction can't attach it to a subscription twice.
  rawTransactionId: uuid('raw_transaction_id').references(() => rawTransactions.id, { onDelete: 'set null' }).unique(),
});

// One row per transaction pulled from a linked bank via Mono, kept
// verbatim as the durable source of truth. The detection engine (see
// detection/service.ts) reads from this table and never talks to Mono
// directly — re-running detection is just re-scanning what's already here.
export const rawTransactions = pgTable('raw_transactions', {
  id: uuid('id').primaryKey().$defaultFn(() => randomUUID()),
  linkedBankId: uuid('linked_bank_id')
    .notNull()
    .references(() => linkedBanks.id, { onDelete: 'cascade' }),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  // Mono's transaction id — the natural idempotency key for a sync that
  // may re-fetch overlapping pages.
  monoTransactionId: text('mono_transaction_id').notNull(),
  narration: text('narration').notNull(),
  amount: numeric('amount', { precision: 12, scale: 2 }).notNull(),
  type: transactionTypeEnum('type').notNull(),
  category: text('category'),
  date: timestamp('date', { withTimezone: true }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
}, (table) => ({
  uniqueMonoTransaction: unique().on(table.linkedBankId, table.monoTransactionId),
}));

// -------------------------------------------------------------------- trials

// A manually-entered "remind me before this trial converts" note. This is
// deliberately separate from the merchant `trialProne` heuristic below —
// this table is for trials the detection engine has no way to see yet
// (nothing's been charged, so there's no raw transaction to match on),
// entered by the user right after they sign up somewhere. `merchantSlug`
// is optional free text matching, not a foreign key, so a user can log a
// trial for a merchant Recur doesn't know about yet.
export const trialReminders = pgTable('trial_reminders', {
  id: uuid('id').primaryKey().$defaultFn(() => randomUUID()),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  merchantSlug: text('merchant_slug'),
  // What the user typed for it, e.g. "Netflix Premium" — shown verbatim
  // since merchantSlug may be null.
  label: text('label').notNull(),
  trialEndsAt: timestamp('trial_ends_at', { withTimezone: true }).notNull(),
  // Set once a reminder notification has actually gone out, so a
  // scheduled job can find "due and not yet reminded" rows without
  // double-sending.
  remindedAt: timestamp('reminded_at', { withTimezone: true }),
  // Set when the user cancels the trial or dismisses the reminder — kept
  // as a soft flag rather than a delete so past reminders still show up
  // in history.
  dismissedAt: timestamp('dismissed_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

// ------------------------------------------------------------------ relations
//
// Lets service code use Drizzle's relational query API
// (`db.query.subscriptions.findMany({ with: { merchant: true, charges:
// true } })`) instead of hand-rolled joins — one round trip, no N+1, and
// no risk of a join condition that quietly matches more than intended.

export const usersRelations = relations(users, ({ many }) => ({
  subscriptions: many(subscriptions),
  linkedBanks: many(linkedBanks),
  otpCodes: many(otpCodes),
  rawTransactions: many(rawTransactions),
  refreshTokens: many(refreshTokens),
  trialReminders: many(trialReminders),
}));

export const trialRemindersRelations = relations(trialReminders, ({ one }) => ({
  user: one(users, { fields: [trialReminders.userId], references: [users.id] }),
}));

export const refreshTokensRelations = relations(refreshTokens, ({ one }) => ({
  user: one(users, { fields: [refreshTokens.userId], references: [users.id] }),
}));

export const otpCodesRelations = relations(otpCodes, ({ one }) => ({
  user: one(users, { fields: [otpCodes.userId], references: [users.id] }),
}));

export const linkedBanksRelations = relations(linkedBanks, ({ one, many }) => ({
  user: one(users, { fields: [linkedBanks.userId], references: [users.id] }),
  rawTransactions: many(rawTransactions),
}));

export const rawTransactionsRelations = relations(rawTransactions, ({ one }) => ({
  linkedBank: one(linkedBanks, { fields: [rawTransactions.linkedBankId], references: [linkedBanks.id] }),
  user: one(users, { fields: [rawTransactions.userId], references: [users.id] }),
}));

export const merchantsRelations = relations(merchants, ({ many }) => ({
  subscriptions: many(subscriptions),
}));

export const subscriptionsRelations = relations(subscriptions, ({ one, many }) => ({
  user: one(users, { fields: [subscriptions.userId], references: [users.id] }),
  merchant: one(merchants, { fields: [subscriptions.merchantId], references: [merchants.id] }),
  charges: many(chargeRecords),
}));

export const chargeRecordsRelations = relations(chargeRecords, ({ one }) => ({
  subscription: one(subscriptions, { fields: [chargeRecords.subscriptionId], references: [subscriptions.id] }),
  rawTransaction: one(rawTransactions, { fields: [chargeRecords.rawTransactionId], references: [rawTransactions.id] }),
}));
