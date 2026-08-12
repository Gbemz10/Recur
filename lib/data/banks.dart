import 'package:flutter/material.dart';

/// A Nigerian bank or mobile-money operator the user can link.
class Bank {
  const Bank({
    required this.name,
    required this.code,
    required this.logoUrl,
    required this.brandColor,
    this.aliases = const [],
  });

  final String name;

  /// CBN bank code. The same code Mono, Okra, Paystack and Flutterwave use,
  /// so this is what we'll send to the backend once linking is real.
  final String code;

  final String logoUrl;

  /// Approximate brand colour. Only used for the initial-letter fallback
  /// when a logo hasn't loaded — never as a source of truth for branding.
  final Color brandColor;

  /// Alternative names people actually type. "GTB" gets you GTBank.
  final List<String> aliases;

  /// Asset stem, derived from the name: `assets/logos/bank_<slug>.png`.
  String get slug => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q)) return true;
    return aliases.any((a) => a.toLowerCase().contains(q));
  }

  String get initial => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
}

/// Banks available for linking.
///
/// Logos are served from the open [Nigeria Banks Logo API]
/// (https://github.com/jsanwo64/Nigeria-Banks-Logo-API) via Cloudinary.
/// That's fine for building and testing, but before launch these should be
/// downloaded and bundled under `assets/banks/` — shipping a login flow that
/// depends on someone else's CDN staying up is not a risk worth taking, and
/// the list needs to work on a bad connection anyway.
class Banks {
  Banks._();

  static const List<Bank> all = [
    Bank(
      name: 'Access Bank',
      code: '044',
      aliases: ['access', 'diamond'],
      brandColor: Color(0xFFF28A1A),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731835318/access-bank_u0pg90.png',
    ),
    Bank(
      name: 'Guaranty Trust Bank',
      code: '058',
      aliases: ['gtb', 'gtbank', 'gt bank'],
      brandColor: Color(0xFFE04403),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731834954/Guaranty_Trust_Bank_odgbdu.png',
    ),
    Bank(
      name: 'Zenith Bank',
      code: '057',
      aliases: ['zenith'],
      brandColor: Color(0xFFE30613),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731908201/Zenith_Bank_h40m09.png',
    ),
    Bank(
      name: 'First Bank of Nigeria',
      code: '011',
      aliases: ['firstbank', 'fbn', 'first bank'],
      brandColor: Color(0xFF00447C),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731835216/First_Bank_of_Nigeria_drawyb.png',
    ),
    Bank(
      name: 'United Bank For Africa',
      code: '033',
      aliases: ['uba'],
      brandColor: Color(0xFFD71920),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731908162/United_Bank_For_Africa_om7axi.png',
    ),
    Bank(
      name: 'Kuda Bank',
      code: '50211',
      aliases: ['kuda'],
      brandColor: Color(0xFF40196D),
      // Upstream URL carried a red-border/dark-background transform; stripped
      // back to the plain asset.
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731835102/Kuda_Bank_f5nrij.png',
    ),
    Bank(
      name: 'OPay',
      code: '999992',
      aliases: ['opay', 'paycom'],
      brandColor: Color(0xFF1BC47D),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731910673/OPay_Digital_Services_Limited__OPay_zyh5d0.png',
    ),
    Bank(
      name: 'Moniepoint MFB',
      code: '50515',
      aliases: ['moniepoint'],
      brandColor: Color(0xFF0357EE),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731907889/Moniepoint_MFB_hxoelg.png',
    ),
    Bank(
      name: 'PalmPay',
      code: '999991',
      aliases: ['palmpay', 'palm pay'],
      brandColor: Color(0xFF7A3FF2),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731910656/PalmPay_lzs7yt.png',
    ),
    Bank(
      name: 'Sterling Bank',
      code: '232',
      aliases: ['sterling'],
      brandColor: Color(0xFFDB0B24),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731908098/Sterling_Bank_ooipqt.png',
    ),
    Bank(
      name: 'Fidelity Bank',
      code: '070',
      aliases: ['fidelity'],
      brandColor: Color(0xFF1B3A70),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731835222/Fidelity_Bank_lkl2mr.png',
    ),
    Bank(
      name: 'Union Bank of Nigeria',
      code: '032',
      aliases: ['union'],
      brandColor: Color(0xFF00A6DE),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731908157/Union_Bank_of_Nigeria_i8mtrj.png',
    ),
    Bank(
      name: 'Wema Bank',
      code: '035',
      aliases: ['wema', 'alat'],
      brandColor: Color(0xFF72236B),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731908191/Wema_Bank_cr2pvu.png',
    ),
    Bank(
      name: 'Stanbic IBTC Bank',
      code: '221',
      aliases: ['stanbic', 'ibtc'],
      brandColor: Color(0xFF0033A1),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731908079/Stanbic_IBTC_Bank_qjczcl.png',
    ),
    Bank(
      name: 'Ecobank Nigeria',
      code: '050',
      aliases: ['ecobank', 'eco'],
      brandColor: Color(0xFF00539F),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731835234/Ecobank_Nigeria_qdd70j.png',
    ),
    Bank(
      name: 'First City Monument Bank',
      code: '214',
      aliases: ['fcmb'],
      brandColor: Color(0xFF4B2E83),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731835213/First_City_Monument_Bank_aeufbo.png',
    ),
    Bank(
      name: 'Polaris Bank',
      code: '076',
      aliases: ['polaris', 'skye'],
      brandColor: Color(0xFF7A288A),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731907984/Polaris_Bank_irqlkv.png',
    ),
    Bank(
      name: 'Keystone Bank',
      code: '082',
      aliases: ['keystone'],
      brandColor: Color(0xFF003366),
      // Upstream URL carried a red-border/dark-background transform; stripped.
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731835110/Keystone-Bank_cvicmd.png',
    ),
    Bank(
      name: 'Providus Bank',
      code: '101',
      aliases: ['providus'],
      brandColor: Color(0xFFF5A623),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731908004/Providus_Bank_oo0ue2.png',
    ),
    Bank(
      name: 'Jaiz Bank',
      code: '301',
      aliases: ['jaiz'],
      brandColor: Color(0xFF006E51),
      logoUrl:
          'https://res.cloudinary.com/dweovytuc/image/upload/f_auto,q_auto/v1731835113/Jaiz_Bank_fambas.png',
    ),
  ];

  static List<Bank> search(String query) =>
      all.where((b) => b.matches(query)).toList();

  /// Looks up a bank by its CBN code, e.g. to render a real logo for a
  /// [LinkedBank] returned from the backend. Returns null for anything not
  /// in this curated list — Mono's sandbox test banks in particular won't
  /// match, since they're not real CBN-registered institutions.
  static Bank? byCode(String code) {
    for (final bank in all) {
      if (bank.code == code) return bank;
    }
    return null;
  }
}
