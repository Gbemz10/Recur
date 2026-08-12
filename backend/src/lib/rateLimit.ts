import type { FastifyRequest } from 'fastify';
import { AppError } from './errors.js';

/**
 * Minimal in-memory sliding-window rate limiter. No Redis, no external
 * dependency — deliberately, so this doesn't add a new native/platform-
 * specific package to a `node_modules` that's already been fragile across
 * this project's Mac/Linux split.
 *
 * Good enough for a single-instance deployment. The moment this runs
 * behind more than one server process, swap the `buckets` Map for a
 * shared store (Redis, most likely) — otherwise each instance tracks its
 * own counters independently and the effective limit becomes
 * `max * instanceCount`, which quietly defeats the point.
 */
interface Bucket {
  count: number;
  resetAt: number;
}

const buckets = new Map<string, Bucket>();

// Sweep expired buckets periodically so long-running processes don't leak
// memory under sustained traffic from many distinct keys (IPs, emails).
const sweepInterval = setInterval(() => {
  const now = Date.now();
  for (const [key, bucket] of buckets) {
    if (bucket.resetAt <= now) buckets.delete(key);
  }
}, 60_000);
sweepInterval.unref();

export interface RateLimitOptions {
  /** Bucket namespace — keep unique per call site, e.g. "auth:login:ip". */
  name: string;
  windowMs: number;
  max: number;
  /** Defaults to client IP. Override to scope the limit differently, e.g. by email. */
  keyGenerator?: (request: FastifyRequest) => string;
}

export function rateLimit({ name, windowMs, max, keyGenerator }: RateLimitOptions) {
  return async function rateLimitHook(request: FastifyRequest) {
    const identity = keyGenerator ? keyGenerator(request) : request.ip;
    // An empty identity (e.g. no email in the body yet) would collapse
    // every caller onto one shared bucket — skip limiting rather than
    // accidentally rate-limit everyone as a single client.
    if (!identity) return;

    const key = `${name}:${identity}`;
    const now = Date.now();
    const bucket = buckets.get(key);

    if (!bucket || bucket.resetAt <= now) {
      buckets.set(key, { count: 1, resetAt: now + windowMs });
      return;
    }

    bucket.count += 1;
    if (bucket.count > max) {
      const retryAfterSeconds = Math.ceil((bucket.resetAt - now) / 1000);
      throw AppError.tooManyRequests(`Too many requests — try again in ${retryAfterSeconds}s`);
    }
  };
}

/** Pulls a lowercased email out of a JSON body for email-scoped limiters, defensively. */
export function emailKey(request: FastifyRequest): string {
  const body = request.body as { email?: unknown } | undefined;
  return typeof body?.email === 'string' ? body.email.trim().toLowerCase() : '';
}
