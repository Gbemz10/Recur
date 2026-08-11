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
    domain: 'chickenrepublic.com',
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
}
