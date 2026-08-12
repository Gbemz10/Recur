# Recur

**See every recurring charge hitting your Nigerian bank account, automatically.**

Old subscriptions, auto-renewing data plans, that free trial from March.
Recur links to your bank read-only, finds the charges that repeat, and warns
you before the next one lands. No manual entry, no receipt scanning.

Nothing like this exists for Nigerian banks — Rocket Money and Trim are built
on US banking infrastructure and don't work here.

---

## Status

**Wired up end to end.** Auth, subscriptions, and bank-linking all talk to
a real backend now — nothing left in `lib/data/mock_data.dart` except the
`formatNaira`/`formatNairaCompact` currency helpers, which are genuinely
just formatters, not mock data.

| | |
|---|---|
| Frontend | Flutter (this repo) |
| Backend | Node.js / TypeScript / Fastify / Drizzle / Postgres (`recur-backend`) |
| Bank data | Mono, via their hosted Connect Link flow (a webview, not a native SDK) |
| Market | Nigeria first |

---

## Getting it running

1. Get `recur-backend` running first (see its own README) — this app has
   nothing to talk to without it. By default it looks for the backend at
   `http://localhost:4000` (`http://10.0.2.2:4000` automatically on an
   Android emulator — see `lib/config/env.dart`). Override with
   `--dart-define=API_BASE_URL=https://your-host` if you're pointing at
   something else (a tunnel, a deployed instance).
2. ```bash
   cd recur-frontend
   flutter pub get
   flutter run
   ```

Requires **Flutter 3.27+ / Dart 3.6+** — the design system uses
`Color.withValues()`.

I couldn't run `flutter pub get` / `flutter analyze` myself while building
this (no Flutter toolchain in the sandbox this was built in) — run both
yourself before trusting anything here compiles cleanly. Three packages
were added and never installed on this end: `http`, `flutter_secure_storage`,
`webview_flutter`.

---

## Structure

```
lib/
├── main.dart                       app entry + splash→onboarding→auth→link→shell flow,
│                                    including session bootstrap (skips to the
│                                    shell if a token is already stored)
├── config/
│   └── env.dart                    backend base URL
├── theme/
│   ├── app_colors.dart             design-system tokens (from perfect-ui kit)
│   ├── app_typography.dart         Plus Jakarta Sans type scale
│   ├── app_spacing.dart            spacing / radius / shadow tokens
│   ├── app_theme.dart              assembled light + dark ThemeData
│   └── recur_brand.dart            brand-only accents (splash, hero card)
├── ui/
│   ├── ui.dart                     barrel — import this for the whole kit
│   └── app_*.dart                  buttons, cards, badges, nav, states, …
├── models/
│   └── subscription.dart           Subscription, ChargeRecord, cycles, status — now with fromJson
├── data/
│   ├── api_client.dart             HTTP wrapper: bearer token, JSON, typed ApiException
│   ├── token_storage.dart          session JWT in the platform keychain/keystore
│   ├── auth_service.dart           /auth/* calls
│   ├── banking_service.dart        /banking/* calls (Mono Connect Link)
│   ├── subscription_store.dart     shared ChangeNotifier, backed by /subscriptions
│   ├── linked_bank.dart            wire model for a linked bank
│   ├── merchants.dart              curated merchant list + logos/colors
│   ├── banks.dart                  curated Nigerian bank list (logos only now — Mono's hosted page does the actual bank picking)
│   └── mock_data.dart              now just formatNaira()/formatNairaCompact()
├── widgets/
│   ├── brand_mark.dart             logo resolution: asset → (debug-only) network → initials
│   └── subscription_tile.dart      list row w/ staggered entrance
└── screens/
    ├── splash_screen.dart          animated launch sequence
    ├── onboarding_screen.dart      3-slide pitch, animated illustrations
    ├── auth_screen.dart            sign in / sign up
    ├── otp_screen.dart             6-digit email code
    ├── create_password_screen.dart set/reset password
    ├── link_bank_screen.dart       consent → Mono webview → confirming → done
    ├── app_shell.dart              bottom-nav host
    ├── dashboard_screen.dart       totals, due-soon, tabs, list
    ├── calendar_screen.dart
    ├── settings_screen.dart        linked bank, sign out
    └── subscription_detail_screen.dart
```

Directory nesting is deliberately shallow (`lib/<area>/<file>.dart`) — keep
it that way.

---

## The splash screen

`lib/screens/splash_screen.dart` runs a 3.2s choreographed sequence off two
controllers: `_main` (one-shot, drives staged `Interval`s) and `_ambient`
(loops forever, drives motion that shouldn't stop).

| Progress | Stage |
|---|---|
| 0.00–0.55 | ink gradient settles, halo blooms from centre |
| 0.15–0.70 | dashed orbit rings draw themselves, counter-rotating |
| 0.30–0.78 | brand mark draws stroke-by-stroke, arrowhead appears |
| 0.55–0.85 | wordmark letters rise in, staggered |
| 0.72–0.92 | tagline fades up |
| 0.88–1.00 | everything lifts, circular wipe hands off |

Ambient extras: drifting particle field, a mint node riding the inner orbit
(reads as "a charge coming around again"), a shimmer sweeping the wordmark,
and a pulsing core.

To retime the whole thing, change `_main`'s duration — every stage is
expressed as a fraction, so they scale together.

---

## Design system rules

From the `perfect-ui-flutter` kit. Worth keeping to:

- Use `AppColors.*`, `AppSpacing.*`, `AppRadius.*` — no raw hex, no magic numbers.
- Use `Theme.of(context).textTheme.*` — extend `app_typography.dart` rather
  than inlining one-off `TextStyle`s.
- One `AppButton` with a `variant`, not bespoke button widgets.
- Flat + 1px border by default; shadow only when something should lift.
- Always wire the empty and loading states — `AppEmptyState`, `AppSkeleton`.

`RecurBrand` is the deliberate exception: gradients and ink tones for the few
expressive surfaces (splash, total card). Don't reach for it in everyday UI.

---

## Not built yet

- Automated tests (none exist on either the Flutter or backend side)
- Refresh tokens / "sign out everywhere" — the session JWT is long-lived
  (30 days) and there's no server-side revocation list yet
- Offline font bundling (currently fetched by `google_fonts` at runtime)
- Dark theme pass (wired up, not designed against)
- Settings only shows one linked bank even though the backend supports
  linking more than one (`SettingsScreen._primaryBank`)
- A real logo for i-Fitness Gym — the only merchant without a bundled
  asset; it falls back to a styled two-letter initial mark by design, not
  a bug (see `lib/widgets/brand_mark.dart`)
