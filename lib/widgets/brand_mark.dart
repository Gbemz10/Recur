import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// A brand logo — bank or merchant — with a resolution order chosen for a
/// Nigerian connection:
///
///   1. **Bundled asset.** Instant, works offline, survives a CDN going
///      down. This is what should be shipping in production.
///   2. **Network.** Used while assets aren't bundled yet, so the UI is
///      never blank during development.
///   3. **Branded initial.** The letter in the brand's colour.
///
/// Step 3 matters more than it looks. A broken-image icon on a screen about
/// someone's money reads as "something is wrong with my account", not
/// "an image failed to load".
///
/// Run `tool/fetch_logos.sh` to populate `assets/logos/` and step 1 starts
/// doing the work. Until then Flutter logs an "unable to load asset" line
/// per logo in debug — harmless, and it stops once the files exist.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    required this.slug,
    required this.fallbackLabel,
    required this.brandColor,
    this.networkUrl,
    this.size = 44,
    this.radius,
    this.padded = true,
    this.bordered = true,
  });

  /// File stem under `assets/logos/`, e.g. `netflix` → `assets/logos/netflix.png`.
  final String slug;

  /// Text used for the initial fallback.
  final String fallbackLabel;

  final Color brandColor;

  /// Optional remote source, used only until the asset is bundled.
  final String? networkUrl;

  final double size;
  final double? radius;

  /// Logos usually need breathing room inside their tile; flat colour marks
  /// don't.
  final bool padded;

  final bool bordered;

  String get _assetPath => 'assets/logos/$slug.png';

  // Two letters reads as a deliberate monogram rather than "the first
  // letter of a broken image" — first-letter-of-first-two-words for a
  // multi-word name ("i-Fitness Gym" → "IG"), first two letters otherwise.
  String get _initials {
    final words = fallbackLabel
        .replaceAll(RegExp(r'[^A-Za-z ]'), '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return w.length >= 2 ? w.substring(0, 2).toUpperCase() : w.toUpperCase();
    }
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size * 0.24;

    // The white plate belongs to the *logo*, not to the tile. Brand logos are
    // drawn for light backgrounds and mostly ship as transparent PNGs, so they
    // need one. The initials fallback does not, and painting it there put a
    // card-sized near-white block on every dark screen where a payee had no
    // bundled asset. So the plate is applied in frameBuilder, which only runs
    // when an actual image resolved.
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Image.asset(
          _assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, _, __) => _plate(r, child),
          errorBuilder: (context, _, __) => _networkOrInitial(context, r),
        ),
      ),
    );
  }

  Widget _plate(double r, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(r),
        border: bordered ? Border.all(color: AppColors.neutral200) : null,
      ),
      padding: padded ? EdgeInsets.all(size * 0.15) : EdgeInsets.zero,
      child: child,
    );
  }

  Widget _networkOrInitial(BuildContext context, double r) {
    final url = networkUrl;

    // Release builds never touch the network for a logo.
    //
    // This is deliberate. Flutter's Image.network caches in memory only, so
    // every cold start would refetch — the user paying for mobile data to
    // redownload images that never change. Worse, it makes the bank picker
    // depend on someone else's CDN being up, on the one screen where we ask
    // for access to a bank account.
    //
    // So: bundled asset, or the brand's initial in its own colour. Both
    // render instantly, offline, every time. In debug we still fetch, so a
    // missing asset is visible while developing rather than silently
    // degrading to a letter.
    if (url == null || !kDebugMode) return _initial(context, r);

    return Image.network(
      url,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.track(context),
            borderRadius: BorderRadius.circular(r * 0.6),
          ),
        );
      },
      errorBuilder: (context, _, __) => _initial(context, r),
    );
  }

  Widget _initial(BuildContext context, double r) {
    final initials = _initials;
    final ink = _readableBrand(context);
    return Container(
      decoration: BoxDecoration(
        // Opaque, because this now fills the tile: there is no white plate
        // underneath to lift a translucent tint off the page background.
        color: Color.alphaBlend(
          ink.withValues(alpha: 0.16),
          AppColors.surface(context),
        ),
        borderRadius: BorderRadius.circular(r),
        border: bordered ? Border.all(color: AppColors.border(context)) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: initials.length > 1 ? size * 0.3 : size * 0.38,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -0.5,
          height: 1.0,
        ),
      ),
    );
  }

  /// A brand's own colour is picked to read on white. Half of them go muddy or
  /// invisible on a dark surface, so clamp lightness into a band that stays
  /// legible against whichever surface we are actually painting on.
  Color _readableBrand(BuildContext context) {
    final hsl = HSLColor.fromColor(brandColor);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return hsl
        .withLightness(
          isDark ? hsl.lightness.clamp(0.62, 0.92) : hsl.lightness.clamp(0.18, 0.42),
        )
        .toColor();
  }
}
