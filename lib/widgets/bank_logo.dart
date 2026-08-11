import 'package:flutter/material.dart';

import '../data/banks.dart';
import 'brand_mark.dart';

/// A bank's logo. Thin wrapper over [BrandMark] so the bank picker doesn't
/// need to know how logo resolution works.
class BankLogo extends StatelessWidget {
  const BankLogo({super.key, required this.bank, this.size = 44});

  final Bank bank;
  final double size;

  @override
  Widget build(BuildContext context) {
    return BrandMark(
      slug: 'bank_${bank.slug}',
      fallbackLabel: bank.name,
      brandColor: bank.brandColor,
      networkUrl: bank.logoUrl,
      size: size,
    );
  }
}
