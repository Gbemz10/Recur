import 'package:flutter/material.dart';

/// A circular initial avatar for a human counterparty — the person on the
/// other end of a transfer.
///
/// The shape is the whole point. Brands render as rounded squares via
/// [BrandMark]; people render as circles. Every banking app the user
/// already has follows that convention, so a circle reads as "a person"
/// before they've processed the letter inside it. Using a brand tile for
/// "Transfer to Tunde" would quietly suggest Tunde is a company.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  /// Muted, deliberately un-brandlike tones. Picked by name so the same
  /// person is always the same colour, which makes a statement scannable.
  static const List<Color> _palette = [
    Color(0xFF5B7C99),
    Color(0xFF7D6B94),
    Color(0xFF4F8A78),
    Color(0xFF97705A),
    Color(0xFF6B7A8F),
    Color(0xFF8A6E8E),
  ];

  Color get _color {
    if (name.isEmpty) return _palette.first;
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.40,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}
