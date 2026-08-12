import argon2 from 'argon2';

/**
 * Argon2id — the current OWASP recommendation for password hashing, and
 * the default variant `argon2` ships. Thin wrapper so call sites never
 * import the library directly, in case the algorithm ever changes.
 *
 * Params are OWASP's documented minimum for an *interactive* login path
 * (19 MiB memory, timeCost 2, parallelism 1) rather than the `argon2`
 * package's own defaults (64 MiB, timeCost 3, parallelism 4), which are
 * tuned for offline/background hashing and can take several seconds per
 * call on modest hardware — every signup, login, and password reset pays
 * that cost synchronously in the request path. Still well above what's
 * crackable at scale; just not sized for a background batch job.
 */
const ARGON2_OPTIONS = {
  type: argon2.argon2id,
  memoryCost: 19_456,
  timeCost: 2,
  parallelism: 1,
} as const;

export async function hashPassword(plain: string): Promise<string> {
  return argon2.hash(plain, ARGON2_OPTIONS);
}

export async function verifyPassword(hash: string, plain: string): Promise<boolean> {
  try {
    return await argon2.verify(hash, plain);
  } catch {
    // A malformed hash should fail closed, not throw past the caller.
    return false;
  }
}
