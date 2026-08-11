import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Circular avatar with image + graceful initials fallback. Deterministic
/// background color from the name so the same person always gets the same
/// color, even without a photo.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.imageUrl, this.size = 40});

  final String name;
  final String? imageUrl;
  final double size;

  static const _palette = [
    AppColors.primary,
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFD97706),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Color get _bgColor => _palette[name.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: _bgColor,
        alignment: Alignment.center,
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _InitialsText(text: _initials, size: size),
              )
            : _InitialsText(text: _initials, size: size),
      ),
    );
  }
}

class _InitialsText extends StatelessWidget {
  const _InitialsText({required this.text, required this.size});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.38),
    );
  }
}
