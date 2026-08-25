import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The rules, as one sentence that crosses itself out.
///
/// This was four rows with tick circles, which is a checklist you have to read
/// downward before you can start typing. The reference's idea is better: say
/// the requirement once, in the order you would say it aloud, and strike each
/// part through the moment it is satisfied. Nothing appears, disappears or
/// moves — the line is the same length whether you have met none of it or all
/// of it, so it never pushes the field around while you type.
class AppPasswordRules extends StatelessWidget {
  const AppPasswordRules({
    super.key,
    required this.longEnough,
    required this.hasLetter,
    required this.hasNumber,
  });

  final bool longEnough;
  final bool hasLetter;
  final bool hasNumber;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 13,
      height: 1.45,
      color: AppColors.muted(context),
    );

    TextSpan part(String text, bool met) => TextSpan(
          text: text,
          style: base.copyWith(
            fontWeight: FontWeight.w700,
            color: met ? AppColors.muted(context) : AppColors.ink(context),
            decoration: met ? TextDecoration.lineThrough : null,
            decorationColor: AppColors.muted(context),
            decorationThickness: 2,
          ),
        );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'At least '),
          part('8 characters', longEnough),
          const TextSpan(text: ', containing '),
          part('a letter', hasLetter),
          const TextSpan(text: ' and '),
          part('a number', hasNumber),
        ],
      ),
    );
  }
}
