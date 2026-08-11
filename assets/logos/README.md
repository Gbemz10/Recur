# assets/logos

Bank and merchant logos, bundled so the app never depends on a third-party
CDN at runtime.

Populate with:

```bash
chmod +x tool/fetch_logos.sh
./tool/fetch_logos.sh
```

Naming matters — the app resolves logos by filename:

- Banks: `bank_<slug>.png`, where the slug is the bank name lowercased with
  non-alphanumerics collapsed to underscores (`Guaranty Trust Bank` →
  `bank_guaranty_trust_bank.png`). See `Bank.slug` in `lib/data/banks.dart`.
- Merchants: `<slug>.png`, matching `Merchant.slug` in
  `lib/data/merchants.dart` (`netflix.png`, `dstv.png`, …).

If a file is missing, `BrandMark` falls back to the network, then to the
brand's initial. Nothing breaks — it just looks less good.

## Before launch

The merchant logos come from Google's favicon endpoint, which is
undocumented and caps out around 128px. Replace them with official
press-kit assets when there's time. Bank logos come from the open
[Nigeria Banks Logo API](https://github.com/jsanwo64/Nigeria-Banks-Logo-API).

These are third-party trademarks used to identify the services a user
subscribes to. That's normal for this kind of app, but worth a legal
skim before you're on a store listing.
