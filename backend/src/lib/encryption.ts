import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { env } from '../config/env.js';

/**
 * Symmetric encryption for secrets that have to be stored *reversibly* —
 * unlike a password (hashed one-way with argon2, see lib/password.ts), a
 * provider access token has to come back out in plaintext eventually to
 * actually call the provider's API with it. AES-256-GCM: authenticated
 * encryption, so a tampered or corrupted ciphertext fails to decrypt
 * loudly instead of silently returning garbage.
 *
 * Built ahead of actually needing it: `linkedBanks.providerToken`
 * currently just mirrors `providerAccountId` (Mono authenticates every
 * call with one shared app-level secret key, not a per-account token —
 * see the comment on that column in db/schema.ts), so there's nothing
 * sensitive going through this yet. But the column exists for whichever
 * provider *does* eventually hand out a real per-account secret, and
 * wiring encryption in now means that day is a one-line change at the
 * call site — `encryptSecret(token)` instead of `token` — rather than a
 * migration project once there's already sensitive data sitting in the
 * column in plaintext.
 *
 * ENCRYPTION_KEY is a 32-byte key (64 hex chars), required at boot — see
 * config/env.ts and .env.example for how to generate one. Every other
 * secret this app manages (JWT_SECRET, MONO_SECRET_KEY, ...) is validated
 * the same way: fail loudly at startup, not on the first request that
 * needs it.
 */
const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12; // recommended nonce length for GCM
const KEY = Buffer.from(env.ENCRYPTION_KEY, 'hex');

// Prefixed with a version tag so a future key-rotation or algorithm change
// can tell an old ciphertext apart from a new one and decrypt each
// correctly, instead of every existing encrypted row breaking the moment
// the scheme changes.
const VERSION = 'v1';

/**
 * Encrypts a plaintext secret into a single opaque string safe to store in
 * a `text` column. Format: `v1:<iv>:<authTag>:<ciphertext>`, each part
 * base64-encoded.
 */
export function encryptSecret(plaintext: string): string {
  const iv = randomBytes(IV_LENGTH);
  const cipher = createCipheriv(ALGORITHM, KEY, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return [VERSION, iv.toString('base64'), authTag.toString('base64'), ciphertext.toString('base64')].join(':');
}

/**
 * Reverses `encryptSecret`. Throws on a malformed, tampered, or
 * wrong-key-encrypted value rather than returning something that looks
 * plausible but isn't — a provider token that fails to decrypt cleanly
 * should never be silently treated as usable.
 */
export function decryptSecret(encoded: string): string {
  const parts = encoded.split(':');
  const [version, ivB64, authTagB64, ciphertextB64] = parts;
  if (parts.length !== 4 || version !== VERSION || !ivB64 || !authTagB64 || !ciphertextB64) {
    throw new Error(`Cannot decrypt secret: unrecognized format (expected "${VERSION}:iv:authTag:ciphertext")`);
  }
  const decipher = createDecipheriv(ALGORITHM, KEY, Buffer.from(ivB64, 'base64'));
  decipher.setAuthTag(Buffer.from(authTagB64, 'base64'));
  const plaintext = Buffer.concat([decipher.update(Buffer.from(ciphertextB64, 'base64')), decipher.final()]);
  return plaintext.toString('utf8');
}
