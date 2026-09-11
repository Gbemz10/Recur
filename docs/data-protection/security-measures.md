# Recur, technical and organisational measures

**Controller:** Damprose Innovations Limited
**Prepared:** 11 September 2026

Every claim below was checked against the code on the date of writing, with the
file it lives in named so an auditor can verify rather than take it on trust.

## Authentication

| Measure | Detail | Where |
| --- | --- | --- |
| Password storage | argon2id, one-way. Plaintext is never stored and cannot be recovered | `backend/src/lib/password.ts` |
| One-time codes | argon2id hashed, 6 digits, expire in 10 minutes, 5 attempts maximum | `backend/src/lib/otp.ts` |
| Access tokens | Stateless JWT, 15-minute lifetime | `backend/src/config/env.ts` |
| Refresh tokens | Stored hashed, 30-day lifetime, individually revocable, rotated on use | `refresh_tokens` table |
| New-device alerts | A sign-in from an unrecognised device emails the account holder. Keyed to the device, not the IP, so a change of network does not cry wolf | `known_devices` table |
| Rate limiting | Applied to auth endpoints. Account deletion is capped at 5 attempts per hour | `backend/src/modules/auth/routes.ts` |

## Data protection

| Measure | Detail |
| --- | --- |
| Bank credentials | Never received, transmitted or stored. Authentication happens inside Mono's hosted flow |
| Account numbers | Only a masked form is stored. The full number is never persisted |
| Provider secrets | Encrypted at rest with AES-256-GCM, authenticated encryption so tampering fails loudly | `backend/src/lib/encryption.ts` |
| Transport | HTTPS throughout. The API, the website and every provider call |
| Secrets management | Environment variables, validated at boot so the service refuses to start rather than failing on the first request that needs them |
| Read-only access | Recur holds no payment capability of any kind. There is no code path that can move money |

## Deletion

`DELETE /auth/me` requires the account password to be entered again, makes a
best-effort call to unlink the account at Mono, then deletes the user row.
Linked banks, subscriptions, raw transactions, charge records, refresh tokens
and OTP codes are removed with it by foreign-key cascade.

## Organisational

| | |
| --- | --- |
| Team size | Three |
| Data Protection Officer | **Not yet designated.** To be resolved during this engagement |
| Access to production data | Currently every developer with the repository and a local environment file, because production and development share one database. This is the company's own recorded hard blocker and is being separated |
| Breach response | **Not yet documented.** Needs writing |
| Staff training | **Not yet carried out** |

## Summary for the auditor

The technical measures are in reasonable shape for a product of this age:
modern password hashing, short-lived tokens, encryption at rest for provider
secrets, no payment capability, and a working erasure path.

The gaps are organisational and structural rather than cryptographic: no DPO,
no documented breach procedure, no staff training, no established basis for
cross-border transfer, and a shared production and development database. All
five are known and none is disputed.
