import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Entering a sum of money.
///
/// A text field is the wrong instrument for this. It opens a general-purpose
/// keyboard over a form whose only legal input is digits, puts the amount in
/// body-copy size next to a placeholder reading "e.g. 50000", and asks someone
/// to type an unpunctuated number and trust they got the zeroes right.
///
/// So: the figure is the largest thing on screen and grows its own separators
/// as it is typed, the keys are only the keys that can be pressed, and the
/// suggestions are drawn from what this person actually spends rather than
/// from round numbers someone picked.
class AppAmountEntry extends StatelessWidget {
  const AppAmountEntry({
    super.key,
    required this.value,
    required this.onChanged,
    this.presets = const [],
    this.helper,
  });

  /// Digits only, no separators, no currency. Empty means nothing entered.
  final String value;
  final ValueChanged<String> onChanged;

  /// Suggested amounts. Callers should derive these from real figures; four
  /// fits two rows without crowding.
  final List<double> presets;

  /// Sits under the figure. Null falls back to a prompt.
  final String? helper;

  /// Nine digits is ₦999,999,999. Past that the display stops fitting, and a
  /// monthly cap that large is a typo rather than an intention.
  static const int _maxDigits = 9;

  static String format(String digits) {
    if (digits.isEmpty) return '0';
    final n = int.tryParse(digits);
    if (n == null) return '0';
    final s = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  void _press(String key) {
    if (key == '<') {
      if (value.isNotEmpty) {
        HapticFeedback.selectionClick();
        onChanged(value.substring(0, value.length - 1));
      }
      return;
    }
    // A leading zero is never meaningful in an amount, and allowing it makes
    // "0500" look like a real figure.
    if (value.isEmpty && key == '0') return;
    if (value.length >= _maxDigits) return;
    HapticFeedback.selectionClick();
    onChanged(value + key);
  }

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---- the figure ----
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '₦',
                style: AppTypography.money(
                  size: 26,
                  weight: FontWeight.w600,
                  color: AppColors.muted(context),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  format(value),
                  maxLines: 1,
                  style: AppTypography.money(
                    size: 46,
                    color: empty ? AppColors.muted(context) : AppColors.ink(context),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          helper ?? 'Enter an amount',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
        ),

        // ---- suggestions ----
        if (presets.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              for (var i = 0; i < presets.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Preset(
                    amount: presets[i],
                    selected: value == presets[i].round().toString(),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(presets[i].round().toString());
                    },
                  ),
                ),
              ],
            ],
          ),
        ],

        // ---- keys ----
        const SizedBox(height: AppSpacing.lg),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: key.isEmpty
                      ? const SizedBox(height: 52)
                      : _Key(label: key, onTap: () => _press(key)),
                ),
            ],
          ),
      ],
    );
  }
}

class _Preset extends StatelessWidget {
  const _Preset({required this.amount, required this.selected, required this.onTap});

  final double amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryTint(context) : Colors.transparent,
      borderRadius: AppRadius.mdBR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdBR,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdBR,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border(context),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₦${AppAmountEntry.format(amount.round().toString())}',
              style: AppTypography.money(
                size: 13.5,
                weight: FontWeight.w700,
                color: selected ? AppColors.primaryInk(context) : AppColors.ink(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBackspace = label == '<';
    return Semantics(
      button: true,
      label: isBackspace ? 'Delete' : label,
      child: InkResponse(
        onTap: onTap,
        radius: 38,
        child: SizedBox(
          height: 52,
          child: Center(
            child: isBackspace
                ? Icon(Icons.backspace_outlined, size: 21, color: AppColors.ink(context))
                : Text(
                    label,
                    style: AppTypography.money(
                      size: 23,
                      weight: FontWeight.w600,
                      color: AppColors.ink(context),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
