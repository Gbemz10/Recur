import { randomInt } from 'node:crypto';
import argon2 from 'argon2';
import { env } from '../config/env.js';

// Same reasoning as password.ts: OWASP's interactive-login params, not the
// `argon2` package's heavier offline-hashing defaults. An OTP is a 6-digit
// code with a short TTL, a resend cooldown, and a max-attempts lockout
// already doing the heavy lifting against brute force — it doesn't need
// password-grade hashing cost on top, and every signup/verify call pays
// this synchronously.
const ARGON2_OPTIONS = {
  type: argon2.argon2id,
  memoryCost: 19_456,
  timeCost: 2,
  parallelism: 1,
} as const;

/** Generates a numeric code, e.g. "482913" for OTP_LENGTH=6. */
export function generateOtpCode(): string {
  const max = 10 ** env.OTP_LENGTH;
  const value = randomInt(0, max);
  return value.toString().padStart(env.OTP_LENGTH, '0');
}

/**
 * Codes are hashed at rest with the same algorithm as passwords — a
 * database leak shouldn't hand out live OTP codes any more than it should
 * hand out live passwords. The window is short (OTP_TTL_MINUTES) but the
 * habit is what matters.
 */
export async function hashOtp(code: string): Promise<string> {
  return argon2.hash(code, ARGON2_OPTIONS);
}

export async function verifyOtp(hash: string, code: string): Promise<boolean> {
  try {
    return await argon2.verify(hash, code);
  } catch {
    return false;
  }
}

export function otpExpiryDate(): Date {
  return new Date(Date.now() + env.OTP_TTL_MINUTES * 60_000);
}
