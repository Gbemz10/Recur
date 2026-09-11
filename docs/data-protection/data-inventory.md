# Recur, record of processing activities

**Controller:** Damprose Innovations Limited
**Product:** Recur (iOS and Android application)
**Prepared:** 11 September 2026
**Status:** pre-launch. No member of the public has an account. The only live
records belong to the founder and to seeded demo fixtures.

> Drafted from the database schema and application code, not from memory, so
> every row below can be checked against `backend/src/db/schema.ts`. It is a
> working document for the appointed DPCO to review and correct. It is not
> legal advice and has not been reviewed by a lawyer.

---

## 1. What Recur does, in one paragraph

Recur reads a user's bank transaction history, read-only, through Mono, a
CBN-licensed open banking provider. It groups debits by merchant and narration,
clusters them by amount, works out how often they repeat, and tells the user
what is due next. Recur never holds, moves or transmits funds, and never sees
the user's bank credentials: the login happens inside a flow hosted by Mono.

## 2. Categories of data subject

- **Account holders.** People who sign up and use the app.
- **Waitlist subscribers.** People who submitted an email address on
  recur.website and have no account.

## 3. Record of processing

Lawful bases are stated per the Nigeria Data Protection Act 2023.

### 3.1 Identity and account

| Data | Stored in | Purpose | Lawful basis |
| --- | --- | --- | --- |
| Email address | `users.email` | Identifies the account, delivers OTP codes and service mail | Performance of a contract |
| Password | `users.passwordHash` | Authentication. Hashed with argon2id, never stored or recoverable in plaintext | Performance of a contract |
| Display name | `users.displayName` | Addressing the user in the app and in email | Performance of a contract |
| Avatar image | `users.avatarUrl` | Optional profile picture, supplied by the user | Consent |
| Email verification timestamp | `users.emailVerifiedAt` | Proof the address was confirmed | Performance of a contract |

### 3.2 Authentication and session

| Data | Stored in | Purpose | Lawful basis |
| --- | --- | --- | --- |
| One-time codes | `otp_codes.codeHash` | Signup and password reset. Hashed with argon2id, expire after 10 minutes, capped at 5 attempts | Performance of a contract |
| Refresh tokens | `refresh_tokens.tokenHash` | Keeps a session alive for up to 30 days. Stored hashed, individually revocable | Performance of a contract |
| Device identifier | `known_devices.deviceId` | Recognises a device so a sign-in from a new one can be flagged to the user | Legitimate interest (account security) |
| IP address | `known_devices.lastIp` | Same | Legitimate interest (account security) |
| User agent | `known_devices.lastUserAgent` | Same | Legitimate interest (account security) |

### 3.3 Bank connection

| Data | Stored in | Purpose | Lawful basis |
| --- | --- | --- | --- |
| Bank name and code | `linked_banks.bankName`, `bankCode` | Shows the user which account is connected | Consent |
| Masked account number | `linked_banks.accountNumberMask` | Same. Last digits only; the full number is never stored | Consent |
| Mono account identifier | `linked_banks.providerAccountId` | Addresses the account when calling Mono | Consent |
| Provider secret | `linked_banks.providerToken` | Encrypted at rest with AES-256-GCM. Currently mirrors the account identifier, because Mono authenticates with one application-level key rather than per-account tokens | Consent |

**Bank credentials are never received, transmitted or stored by Recur.** The
user authenticates inside Mono's hosted flow and the link is confirmed to Recur
by webhook.

### 3.4 Financial transaction data

This is the most sensitive category Recur handles.

| Data | Stored in | Purpose | Lawful basis |
| --- | --- | --- | --- |
| Transaction narration, amount, type, date, payee | `raw_transactions` | The raw material the detection engine reads | Consent |
| Mono transaction identifier | `raw_transactions.monoTransactionId` | Deduplication across syncs | Consent |
| Spending category | `raw_transactions.spendCategory`, `monoCategory`, `categorySource` | Spending breakdown by category | Consent |
| Detected subscriptions | `subscriptions` | Amount, cycle, next charge date, confidence score and detection key for each recurring charge found | Consent |
| Charge history | `charge_records` | The individual debits behind each detected subscription | Consent |
| User category rules | `user_category_rules` | Remembers a correction when the user recategorises a merchant | Consent |
| Budgets | `budgets` | Monthly limit per category, and whether 80% and 100% alerts have fired | Consent |
| Trials | `trial_reminders` | A trial the user logged manually, and when it ends | Consent |

### 3.5 Communication preferences

| Data | Stored in | Purpose | Lawful basis |
| --- | --- | --- | --- |
| Renewal reminders on/off, lead days | `notification_preferences` | Whether and when to email before a charge | Consent |
| Weekly digest on/off | `notification_preferences.weeklyDigest` | Whether to send the weekly summary | Consent |

Every email carries a per-channel unsubscribe link signed with an HMAC token,
plus `List-Unsubscribe` headers so a mail client can offer its own control.

### 3.6 Waitlist

| Data | Stored in | Purpose | Lawful basis |
| --- | --- | --- | --- |
| Email address, source | `waitlist_signups` | Notifying the person when Recur opens | Consent |

## 4. Rights of the data subject

| Right | How it is served today |
| --- | --- |
| Access | `GET /auth/me` returns the profile. A full export is **not yet implemented**, see section 6 |
| Rectification | Name, avatar, password, budgets, categories and subscription statuses are all editable in the app |
| Erasure | `DELETE /auth/me` requires the password to be re-entered, best-effort unlinks the account at Mono, then deletes the user row. Linked banks, subscriptions, raw transactions, charge records, refresh tokens and OTP codes cascade with it |
| Withdrawal of consent | Unlinking a bank (`DELETE /banking/accounts/:id`) stops all further reading. Notification consent is per-channel in settings and in every email |
| Objection and restriction | By request to support@recur.website |

## 5. Retention

Intended policy, to be confirmed with the DPCO:

| Data | Retention |
| --- | --- |
| Account and transaction data | For the life of the account. Deleted on erasure, immediately and by cascade |
| One-time codes | 10 minutes, then expired. Rows are consumed on use |
| Refresh tokens | 30 days, or until revoked at sign-out |
| Known devices | For the life of the account |
| Waitlist entries | Until launch, or until the person asks to be removed |

## 6. Known gaps, stated honestly

An audit will surface these, so they are listed rather than left to be found.

1. **No data export endpoint.** The right of access is served by the app's own
   screens, not by a portable download. This should be built.
2. **Expired OTP rows and revoked refresh tokens are not swept.** They stop
   working on time, but the rows persist until the account is deleted. A
   scheduled purge would match practice to the retention table above.
3. **Production and development share one database.** Recorded as the hard
   blocker in the project's own pre-ship list. Until it is separated, a
   development environment has access to live records. No member of the public
   has an account yet, which is the only reason this is not already an incident.
4. **No published privacy notice at the time of writing.** Being drafted
   alongside this document.
5. **No Data Protection Officer designated.** To be resolved during the
   engagement.
