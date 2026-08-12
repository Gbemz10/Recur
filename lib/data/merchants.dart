import 'package:flutter/material.dart';

/// A merchant Recur can recognise, with everything needed to render it.
class Merchant {
  const Merchant({
    required this.slug,
    required this.name,
    required this.domain,
    required this.brandColor,
  });

  /// Asset stem: `assets/logos/<slug>.png`.
  final String slug;

  final String name;

  /// Used to fetch a logo until assets are bundled, and useful later for
  /// matching messy bank narrations to a known brand.
  final String domain;

  final Color brandColor;

  /// Temporary source. Google's favicon endpoint is undocumented and only
  /// returns small images, so this is a development stopgap — bundle the
  /// real assets before launch.
  String get logoUrl =>
      'https://www.google.com/s2/favicons?domain=$domain&sz=128';

  /// Builds a [Merchant] from the backend's merchant JSON
  /// (`{ slug, name, domain, brandColor }`, see `serializeSubscription` in
  /// recur-backend). Prefers the curated [Merchants.all] entry by slug when
  /// one exists — same slug, same bundled asset, no lookup needed on the
  /// client — and only falls back to building one from the raw JSON
  /// (parsing `brandColor` as hex) for a merchant the client doesn't know
  /// about yet.
  factory Merchant.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String?;
    final known = slug == null ? null : Merchants.bySlug(slug);
    if (known != null) return known;

    return Merchant(
      slug: slug ?? 'unknown',
      name: json['name'] as String? ?? 'Unknown',
      domain: json['domain'] as String? ?? '',
      brandColor: _parseHexColor(json['brandColor'] as String?) ?? const Color(0xFF6B7280),
    );
  }
}

Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var value = hex.replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

class Merchants {
  Merchants._();

  static const netflix = Merchant(
    slug: 'netflix',
    name: 'Netflix',
    domain: 'netflix.com',
    brandColor: Color(0xFFE50914),
  );
  static const dstv = Merchant(
    slug: 'dstv',
    name: 'DStv',
    domain: 'dstv.com',
    brandColor: Color(0xFF0072CE),
  );
  static const mtn = Merchant(
    slug: 'mtn',
    name: 'MTN',
    domain: 'mtn.ng',
    brandColor: Color(0xFFFFCB05),
  );
  static const spotify = Merchant(
    slug: 'spotify',
    name: 'Spotify',
    domain: 'spotify.com',
    brandColor: Color(0xFF1DB954),
  );
  static const openai = Merchant(
    slug: 'openai',
    name: 'ChatGPT Plus',
    domain: 'openai.com',
    brandColor: Color(0xFF10A37F),
  );
  static const canva = Merchant(
    slug: 'canva',
    name: 'Canva',
    domain: 'canva.com',
    brandColor: Color(0xFF7D2AE8),
  );
  static const showmax = Merchant(
    slug: 'showmax',
    name: 'Showmax',
    domain: 'showmax.com',
    brandColor: Color(0xFFE10098),
  );
  static const apple = Merchant(
    slug: 'apple',
    name: 'Apple iCloud',
    domain: 'apple.com',
    brandColor: Color(0xFF555555),
  );
  static const ifitness = Merchant(
    slug: 'ifitness',
    name: 'i-Fitness Gym',
    domain: 'ifitness.com.ng',
    brandColor: Color(0xFFEF6C00),
  );
  static const bolt = Merchant(
    slug: 'bolt',
    name: 'Bolt',
    domain: 'bolt.eu',
    brandColor: Color(0xFF34D186),
  );
  static const chickenRepublic = Merchant(
    slug: 'chicken_republic',
    name: 'Chicken Republic',
    // Hyphenated. The un-hyphenated domain isn't theirs.
    domain: 'chicken-republic.com',
    brandColor: Color(0xFFE01F26),
  );

  static const List<Merchant> all = [
    netflix,
    dstv,
    mtn,
    spotify,
    openai,
    canva,
    showmax,
    apple,
    ifitness,
    bolt,
    chickenRepublic,
  ];

  static Merchant? bySlug(String slug) {
    for (final merchant in all) {
      if (merchant.slug == slug) return merchant;
    }
    return null;
  }

  /// A detected charge the engine couldn't match to a known merchant —
  /// still needs *something* to carry a name/colour for [BrandMark]'s
  /// initial fallback.
  static Merchant unknown(String name) => Merchant(
        slug: 'unknown',
        name: name,
        domain: '',
        brandColor: const Color(0xFF6B7280),
      );
}
