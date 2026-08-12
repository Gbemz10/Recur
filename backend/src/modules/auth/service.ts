import { and, desc, eq, isNotNull } from 'drizzle-orm';
import { db } from '../../db/client.js';
import { otpCodes, users, linkedBanks, refreshTokens } from '../../db/schema.js';
import { env } from '../../config/env.js';
import { AppError } from '../../lib/errors.js';
import { sendEmail, otpEmail } from '../../lib/email.js';
import { generateOtpCode, hashOtp, verifyOtp, otpExpiryDate } from '../../lib/otp.js';
import { hashPassword, verifyPassword } from '../../lib/password.js';
import { generateRefreshToken, hashRefreshToken } from '../../lib/tokens.js';
import { unlinkMonoAccount } from '../../lib/mono.js';

type OtpPurpose = 'SIGNUP' | 'RESET_PASSWORD';

/** How long after a verified OTP the paired /auth/password call stays valid. */
const OTP_VERIFIED_GRACE_MINUTES = 15;
/** Minimum gap between two OTP sends to the same email — the actual fix for
 *  "unauthenticated OTP endpoint doubles as a free email bomb". */
const OTP_RESEND_COOLDOWN_SECONDS = 60;

async function assertNotRateLimited(email: string, purpose: OtpPurpose) {
  const [recent] = await db
    .select()
    .from(otpCodes)
    .where(and(eq(otpCodes.email, email), eq(otpCodes.purpose, purpose)))
    .orderBy(desc(otpCodes.createdAt))
    .limit(1);
  if (!recent) return;
  const secondsSinceLastSend = (Date.now() - recent.createdAt.getTime()) / 1000;
  if (secondsSinceLastSend < OTP_RESEND_COOLDOWN_SECONDS) {
    const wait = Math.ceil(OTP_RESEND_COOLDOWN_SECONDS - secondsSinceLastSend);
    throw AppError.tooManyRequests(`Wait ${wait}s before requesting another code`);
  }
}

async function issueOtp(email: string, purpose: OtpPurpose) {
  await assertNotRateLimited(email, purpose);
  const code = generateOtpCode();
  await db.insert(otpCodes).values({
    email,
    purpose,
    codeHash: await hashOtp(code),
    expiresAt: otpExpiryDate(),
  });
  const { subject, text, html } = otpEmail(code, purpose);
  await sendEmail({ to: email, subject, text, html });
}

export async function signup(email: string) {
  const [existing] = await db.select().from(users).where(eq(users.email, email)).limit(1);
  if (existing?.passwordHash) {
    throw AppError.conflict('An account already exists for this email. Sign in instead.', 'ACCOUNT_EXISTS');
  }
  // Either a brand new address, or a previous signup that never finished
  // (email captured, no password set yet) — both cases just resend a code.
  if (!existing) {
    await db.insert(users).values({ email });
  }
  await issueOtp(email, 'SIGNUP');
}

export async function requestPasswordReset(email: string) {
  const [user] = await db.select().from(users).where(eq(users.email, email)).limit(1);
  // Deliberately silent on a miss — a 404 here would let anyone probe
  // which emails have accounts. The client shows the same "check your
  // inbox" message either way.
  if (!user) return;
  await issueOtp(email, 'RESET_PASSWORD');
}

export async function verifyOtpCode(email: string, code: string, purpose: OtpPurpose) {
  const [otp] = await db
    .select()
    .from(otpCodes)
    .where(and(eq(otpCodes.email, email), eq(otpCodes.purpose, purpose)))
    .orderBy(desc(otpCodes.createdAt))
    .limit(1);

  if (!otp || otp.consumedAt) {
    throw AppError.badRequest('No pending code for this email. Request a new one.', 'OTP_NOT_FOUND');
  }
  if (otp.expiresAt < new Date()) {
    throw AppError.badRequest('That code has expired. Request a new one.', 'OTP_EXPIRED');
  }
  if (otp.attempts >= env.OTP_MAX_ATTEMPTS) {
    throw AppError.tooManyRequests('Too many wrong attempts. Request a new code.', 'OTP_LOCKED');
  }

  const valid = await verifyOtp(otp.codeHash, code);
  if (!valid) {
    await db.update(otpCodes).set({ attempts: otp.attempts + 1 }).where(eq(otpCodes.id, otp.id));
    throw AppError.badRequest('That code is incorrect', 'OTP_INCORRECT');
  }

  await db.update(otpCodes).set({ consumedAt: new Date() }).where(eq(otpCodes.id, otp.id));
}

/** Throws unless a code for this email+purpose was verified recently. */
async function assertRecentlyVerified(email: string, purpose: OtpPurpose) {
  const [consumed] = await db
    .select()
    .from(otpCodes)
    .where(and(eq(otpCodes.email, email), eq(otpCodes.purpose, purpose), isNotNull(otpCodes.consumedAt)))
    .orderBy(desc(otpCodes.consumedAt))
    .limit(1);

  const graceMs = OTP_VERIFIED_GRACE_MINUTES * 60_000;
  if (!consumed?.consumedAt || Date.now() - consumed.consumedAt.getTime() > graceMs) {
    throw AppError.unauthorized('Verify your email again before setting a password', 'OTP_NOT_VERIFIED');
  }
}

export async function setPassword(email: string, password: string, purpose: OtpPurpose) {
  await assertRecentlyVerified(email, purpose);
  const passwordHash = await hashPassword(password);
  const [user] = await db
    .update(users)
    .set({ passwordHash, emailVerifiedAt: new Date(), updatedAt: new Date() })
    .where(eq(users.email, email))
    .returning();
  if (!user) throw AppError.notFound('Account not found');
  return user;
}

export async function login(email: string, password: string) {
  const [user] = await db.select().from(users).where(eq(users.email, email)).limit(1);
  if (!user) throw AppError.unauthorized();
  if (!user.passwordHash) {
    throw AppError.unauthorized('Finish creating your account first', 'SIGNUP_INCOMPLETE');
  }
  const valid = await verifyPassword(user.passwordHash, password);
  if (!valid) throw AppError.unauthorized();
  return user;
}

/** Shape returned to the client for "who am I" — deliberately omits
 *  passwordHash, which the `users` row otherwise carries. */
function serializeProfile(user: typeof users.$inferSelect) {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    avatarUrl: user.avatarUrl,
    memberSince: user.createdAt,
  };
}

export async function getProfile(userId: string) {
  const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!user) throw AppError.notFound('Account not found');
  return serializeProfile(user);
}

export async function updateDisplayName(userId: string, displayName: string) {
  const [user] = await db
    .update(users)
    .set({ displayName, updatedAt: new Date() })
    .where(eq(users.id, userId))
    .returning();
  if (!user) throw AppError.notFound('Account not found');
  return serializeProfile(user);
}

export async function updateAvatarUrl(userId: string, avatarUrl: string) {
  const [user] = await db
    .update(users)
    .set({ avatarUrl, updatedAt: new Date() })
    .where(eq(users.id, userId))
    .returning();
  if (!user) throw AppError.notFound('Account not found');
  return serializeProfile(user);
}

// ------------------------------------------------------------- sessions

/** Issues and stores a new refresh token, returning the raw value — only
 *  this call site ever sees it unhashed. */
export async function issueRefreshToken(userId: string): Promise<string> {
  const raw = generateRefreshToken();
  const expiresAt = new Date(Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000);
  await db.insert(refreshTokens).values({ userId, tokenHash: hashRefreshToken(raw), expiresAt });
  return raw;
}

/** Looks up the presented refresh token and returns the user it belongs to,
 *  or throws if it's missing, expired, or already revoked (logout, password
 *  change, or a previous /auth/refresh that rotated it away). */
export async function validateRefreshToken(raw: string) {
  const tokenHash = hashRefreshToken(raw);
  const [row] = await db.select().from(refreshTokens).where(eq(refreshTokens.tokenHash, tokenHash)).limit(1);
  if (!row || row.revokedAt || row.expiresAt < new Date()) {
    throw AppError.unauthorized('Session expired — sign in again', 'REFRESH_INVALID');
  }
  const [user] = await db.select().from(users).where(eq(users.id, row.userId)).limit(1);
  if (!user) throw AppError.unauthorized();
  return { user, tokenRowId: row.id };
}

/** Rotation on every refresh: the presented token is revoked and a fresh
 *  one issued in its place. A refresh token that leaks is only useful once
 *  — reusing an already-rotated token is a strong signal of theft, not just
 *  a stale client, though this MVP doesn't yet go as far as revoking the
 *  whole family on reuse detection. */
export async function rotateRefreshToken(raw: string) {
  const { user, tokenRowId } = await validateRefreshToken(raw);
  await db.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.id, tokenRowId));
  const nextRefreshToken = await issueRefreshToken(user.id);
  return { user, refreshToken: nextRefreshToken };
}

export async function revokeRefreshToken(raw: string): Promise<void> {
  const tokenHash = hashRefreshToken(raw);
  await db.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.tokenHash, tokenHash));
}

/** Kills every session for a user — used on password change (see
 *  changePassword below) so a leaked/stolen session can't outlive the
 *  password that (presumably) leaked alongside it. */
async function revokeAllRefreshTokens(userId: string): Promise<void> {
  await db.update(refreshTokens).set({ revokedAt: new Date() }).where(eq(refreshTokens.userId, userId));
}

export async function changePassword(userId: string, currentPassword: string, newPassword: string) {
  const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!user?.passwordHash) throw AppError.notFound('Account not found');

  const valid = await verifyPassword(user.passwordHash, currentPassword);
  if (!valid) throw AppError.unauthorized('Current password is incorrect', 'WRONG_PASSWORD');

  const passwordHash = await hashPassword(newPassword);
  const [updated] = await db
    .update(users)
    .set({ passwordHash, updatedAt: new Date() })
    .where(eq(users.id, userId))
    .returning();

  // Every other signed-in device now needs to log in again — the route
  // issues this device a brand new token pair right after this returns, so
  // only *other* sessions actually feel it.
  await revokeAllRefreshTokens(userId);

  return updated!;
}

export async function deleteAccount(userId: string, password: string) {
  const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!user) throw AppError.notFound('Account not found');

  if (user.passwordHash) {
    const valid = await verifyPassword(user.passwordHash, password);
    if (!valid) throw AppError.unauthorized('Incorrect password', 'WRONG_PASSWORD');
  }

  // Best-effort unlink on Mono's side before the row (and everything FK'd
  // to it — linked banks, subscriptions, raw transactions, refresh tokens,
  // OTP codes) cascades away below. A stale Mono-side link outliving a
  // deleted account is a lesser problem than blocking deletion on a flaky
  // third-party call.
  const banks = await db
    .select()
    .from(linkedBanks)
    .where(and(eq(linkedBanks.userId, userId), eq(linkedBanks.status, 'ACTIVE')));
  for (const bank of banks) {
    try {
      await unlinkMonoAccount(bank.providerAccountId);
    } catch (error) {
      console.error(`Mono unlink failed for account ${bank.providerAccountId} during account deletion:`, error);
    }
  }

  await db.delete(users).where(eq(users.id, userId));
}
