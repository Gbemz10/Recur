import { env } from '../config/env.js';

/**
 * Thin wrapper over Mono's Open Banking API (api.withmono.com). Every call
 * authenticates with the app-level secret key — Mono doesn't hand back a
 * separate per-account token the way some providers do, the account id
 * returned from Exchange Token is itself the persistent identifier used
 * with every subsequent call.
 *
 * Docs: https://docs.mono.co/docs/financial-data/overview
 */

const MONO_BASE_URL = 'https://api.withmono.com';

// Node's fetch has no default timeout — a slow or wedged Mono endpoint
// would otherwise hang the request (and whatever awaited it: a webhook
// handler, a user-triggered sync) indefinitely instead of failing. This is
// the same class of bug the "app breaks under load" reels were about:
// nothing here was actually broken under normal conditions, it just had no
// upper bound on how long a bad response from someone else's API could
// hold a request open.
const MONO_TIMEOUT_MS = 10_000;

// Retries are for genuinely transient failures only — a network blip or a
// 5xx from Mono's side is worth one more try; a 4xx (bad request, invalid
// account, etc.) means retrying would just fail the same way three times
// instead of once. 429 is the one 4xx worth retrying, since it means "try
// again shortly" by definition.
const MONO_MAX_RETRIES = 2;
const MONO_RETRY_BASE_DELAY_MS = 300;

function isRetryableStatus(status: number): boolean {
  return status === 429 || status >= 500;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function monoRequest<T>(path: string, init: RequestInit = {}): Promise<T> {
  let lastError: unknown;

  for (let attempt = 0; attempt <= MONO_MAX_RETRIES; attempt++) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), MONO_TIMEOUT_MS);

    try {
      const response = await fetch(`${MONO_BASE_URL}${path}`, {
        ...init,
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          accept: 'application/json',
          'mono-sec-key': env.MONO_SECRET_KEY,
          ...init.headers,
        },
      });
      clearTimeout(timeout);

      if (!response.ok) {
        const body = await response.text().catch(() => '');
        const error = new Error(`Mono API ${init.method ?? 'GET'} ${path} failed: ${response.status} ${body}`);
        if (isRetryableStatus(response.status) && attempt < MONO_MAX_RETRIES) {
          lastError = error;
          await sleep(MONO_RETRY_BASE_DELAY_MS * 2 ** attempt);
          continue;
        }
        throw error;
      }

      return (await response.json()) as T;
    } catch (error) {
      clearTimeout(timeout);
      // AbortError (our own timeout) and network-level failures (DNS,
      // connection reset, etc.) are both worth retrying the same as a 5xx.
      // A thrown !response.ok Error (message starts with "Mono API") was
      // already routed through the retry check above, so only genuinely
      // unexpected failures reach here.
      const retryable = error instanceof Error && (error.name === 'AbortError' || !error.message.startsWith('Mono API'));
      if (retryable && attempt < MONO_MAX_RETRIES) {
        lastError = error;
        await sleep(MONO_RETRY_BASE_DELAY_MS * 2 ** attempt);
        continue;
      }
      throw error;
    }
  }

  // Unreachable in practice — the loop always either returns or throws —
  // but keeps the function's return type honest for TypeScript.
  throw lastError instanceof Error ? lastError : new Error('Mono API request failed');
}

interface MonoInitiateResponse {
  status: string;
  message: string;
  data: {
    mono_url: string;
    customer: string;
    meta: { ref: string };
    scope: string;
    redirect_url: string;
    created_at: string;
  };
}

/**
 * Connect Link flow (https://docs.mono.co/docs/financial-data/connect-link)
 * — chosen over the JS/native Connect *widget* SDK deliberately: it's a
 * hosted URL the client just opens in a webview, with no platform-specific
 * plugin to integrate (and therefore nothing here that can't be verified
 * without a real device/build). The account id itself isn't returned by
 * this call — it arrives later via the `mono.events.account_connected`
 * webhook, correlated back to this request by `ref`.
 */
export async function initiateAccountLinking(input: { customerName: string; customerEmail: string; ref: string; redirectUrl: string }) {
  const result = await monoRequest<MonoInitiateResponse>('/v2/accounts/initiate', {
    method: 'POST',
    body: JSON.stringify({
      customer: { name: input.customerName, email: input.customerEmail },
      scope: 'auth',
      meta: { ref: input.ref },
      redirect_url: input.redirectUrl,
    }),
  });
  return result.data.mono_url;
}

export interface MonoTransaction {
  id: string;
  narration: string;
  amount: number; // lowest denomination — kobo for NGN
  type: 'debit' | 'credit';
  balance: number;
  date: string;
  category: string;
}

interface MonoTransactionsResponse {
  status: string;
  message: string;
  data: MonoTransaction[];
  meta: { total: number; page: number; previous: string | null; next: string | null };
}

/** One page of an account's transaction history, newest details as Mono returns them. */
export async function fetchMonoTransactions(accountId: string, page = 1, limit = 100) {
  const result = await monoRequest<MonoTransactionsResponse>(
    `/v2/accounts/${accountId}/transactions?paginate=true&page=${page}&limit=${limit}`,
  );
  return { transactions: result.data, hasNext: Boolean(result.meta?.next), total: result.meta?.total ?? result.data.length };
}

export async function unlinkMonoAccount(accountId: string): Promise<void> {
  await monoRequest(`/v2/accounts/${accountId}/unlink`, { method: 'POST' });
}
