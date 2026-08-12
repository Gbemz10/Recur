import { randomBytes, createHash } from 'node:crypto';

/**
 * Refresh tokens are opaque, high-entropy random strings — not JWTs. A JWT
 * would defeat the point (it'd be self-validating and unrevocable, same
 * problem as the access token). Only the SHA-256 hash is ever stored, same
 * reasoning as OTPs/passwords, but a fast hash is fine here (unlike
 * passwords) because the token itself has 384 bits of entropy — nothing
 * short of stealing the DB and the raw token gets you in, and if you have
 * the raw token you don't need to attack the hash at all.
 */
export function generateRefreshToken(): string {
  return randomBytes(48).toString('base64url');
}

export function hashRefreshToken(raw: string): string {
  return createHash('sha256').update(raw).digest('hex');
}
