# Recur — Flutter frontend

See every recurring charge hitting your Nigerian bank account, automatically.

This is the **v1 frontend only**. All data is mocked in `lib/data/mock_data.dart`
so screens can be built and reviewed before the Python backend exists.

---

## Getting it running

The repo ships source only — no `android/`, `ios/`, or `web/` folders yet.
Generate them once, in place:

```bash
cd recur-frontend
flutter create .
flutter pub get
flutter run
```

`flutter create .` fills in the missing platform folders without touching
`lib/` or `pubspec.yaml`.

Requires **Flutter 3.27+ / Dart 3.6+** — the design system uses
`Color.withValues()`.

---

## Structure

```
lib/
├── main.dart                       app entry + splash→onboarding→shell flow
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
│   └── subscription.dart           Subscription, ChargeRecord, cycles, status
├── data/
│   └── mock_data.dart              stand-in subscriptions + formatNaira()
├── widgets/
│   └── subscription_tile.dart      list row w/ staggered entrance
└── screens/
    ├── splash_screen.dart          animated launch sequence
    ├── onboarding_screen.dart      3-slide pitch, animated illustrations
    ├── link_bank_screen.dart       consent → bank → connecting → success
    ├── app_shell.dart              bottom-nav host
    ├── dashboard_screen.dart       totals, due-soon, tabs, list
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

- Real state management (screens pass status back via `Navigator.pop`)
- API layer / Mono or Okra bank-linking SDK integration
- Auth (OTP)
- Renewal calendar and Settings tabs — placeholders in `app_shell.dart`
- Offline font bundling (currently fetched by `google_fonts` at runtime)
- Dark theme pass (wired up, not designed against)
# Recur
