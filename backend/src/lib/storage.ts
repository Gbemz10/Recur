import { env } from '../config/env.js';
import { AppError } from './errors.js';

/**
 * Thin wrapper over Supabase Storage's REST API — deliberately not the
 * `@supabase/supabase-js` SDK, since the only thing this app needs is
 * "upload one file, get a public URL back," and a handful of `fetch` calls
 * covers that without pulling in a client meant for the whole Supabase
 * surface (auth, realtime, etc. this app doesn't use).
 *
 * Docs: https://supabase.com/docs/guides/storage
 */

const MAX_AVATAR_BYTES = 5 * 1024 * 1024; // 5MB
const ALLOWED_TYPES = new Map([
  ['image/jpeg', 'jpg'],
  ['image/png', 'png'],
  ['image/webp', 'webp'],
]);

function assertConfigured() {
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    throw AppError.internal(
      'Avatar upload is not configured on this server yet (missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)',
      'STORAGE_NOT_CONFIGURED',
    );
  }
}

/**
 * Uploads an avatar image for `userId`, always at the same object path so
 * a re-upload overwrites the previous one rather than accumulating orphaned
 * files. Returns a public URL with a cache-busting query param — Supabase's
 * CDN (and phones' own image caches) would otherwise keep serving the old
 * photo from the same URL after an overwrite.
 */
export async function uploadAvatar(userId: string, bytes: Buffer, contentType: string): Promise<string> {
  assertConfigured();

  const extension = ALLOWED_TYPES.get(contentType);
  if (!extension) {
    throw AppError.badRequest('Avatar must be a JPEG, PNG, or WebP image', 'UNSUPPORTED_IMAGE_TYPE');
  }
  if (bytes.byteLength > MAX_AVATAR_BYTES) {
    throw AppError.badRequest('Avatar must be under 5MB', 'IMAGE_TOO_LARGE');
  }

  const path = `${userId}.${extension}`;
  const response = await fetch(
    `${env.SUPABASE_URL}/storage/v1/object/${env.SUPABASE_AVATARS_BUCKET}/${path}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
        apikey: env.SUPABASE_SERVICE_ROLE_KEY,
        'Content-Type': contentType,
        // Overwrite the previous avatar at this path instead of 409-ing on
        // every re-upload after the first.
        'x-upsert': 'true',
      },
      body: bytes,
    },
  );

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new Error(`Supabase Storage upload failed: ${response.status} ${body}`);
  }

  return `${env.SUPABASE_URL}/storage/v1/object/public/${env.SUPABASE_AVATARS_BUCKET}/${path}?v=${Date.now()}`;
}
