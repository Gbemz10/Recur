import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// A lightweight device frame used to present real Recur UI during
/// onboarding.
///
/// Deliberately not a photorealistic mockup — a thin bezel, soft shadow and
/// a status bar are enough to read as "this is the app", without the frame
/// competing with the content inside it.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({
    super.key,
    required this.child,
    this.width = 232,
    this.height = 300,
    this.statusBarLabel = '9:41',
  });

  final Widget child;
  final double width;
  final double height;
  final String statusBarLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.18),
            blurRadius: 34,
            spreadRadius: -6,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: ColoredBox(
          color: AppColors.background(context),
          child: Column(
            children: [
              _StatusBar(label: statusBarLabel),
              Expanded(
                // Clip so preview content can animate beyond the edges
                // without spilling outside the device.
                child: ClipRect(child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.ink(context),
            ),
          ),
          const Spacer(),
          // Signal bars
          for (var i = 0; i < 3; i++)
            Container(
              width: 2.5,
              height: 4.0 + i * 2,
              margin: const EdgeInsets.only(left: 1.5),
              decoration: BoxDecoration(
                color: AppColors.ink(context),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          const SizedBox(width: 5),
          // Battery
          Container(
            width: 15,
            height: 7.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: AppColors.ink(context).withValues(alpha: 0.55),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(1.2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.72,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.ink(context),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
