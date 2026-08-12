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

async function monoRequest<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(`${MONO_BASE_URL}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      accept: 'application/json',
      'mono-sec-key': env.MONO_SECRET_KEY,
      ...init.headers,
    },
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new Error(`Mono API ${init.method ?? 'GET'} ${path} failed: ${response.status} ${body}`);
  }

  return (await response.json()) as T;
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
