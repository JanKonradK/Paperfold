import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_tokens.dart';

/// The four corners of Paperfold. Every rounded shape in the app uses one.
///
/// Each step is the one before it plus 8, so a shape inset by 8 inside the
/// next one up has a concentric corner: frame 32, pane 24, control 16.
abstract final class PaperfoldShape {
  /// Books: spines, covers, thumbnails. Nearly square, never sharp.
  static const double object = 4;

  /// Everything a finger presses: buttons, FAB, chips, segments, fields.
  static const double control = 16;

  /// Containers: cards, placards, list groups, the vitrine case.
  static const double pane = 24;

  /// Things that float: sheets, dialogs, the navigation and reader bars.
  static const double frame = 32;

  static const BorderRadius objectRadius = BorderRadius.all(
    Radius.circular(object),
  );
  static const BorderRadius controlRadius = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius paneRadius = BorderRadius.all(
    Radius.circular(pane),
  );
  static const BorderRadius frameRadius = BorderRadius.all(
    Radius.circular(frame),
  );

  /// The top corners of a sheet.
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(frame),
  );

  /// The top corners of a spine standing on a shelf.
  static const BorderRadius spineRadius = BorderRadius.vertical(
    top: Radius.circular(object),
  );

  static const RoundedRectangleBorder controlShape = RoundedRectangleBorder(
    borderRadius: controlRadius,
  );
  static const RoundedRectangleBorder paneShape = RoundedRectangleBorder(
    borderRadius: paneRadius,
  );
  static const RoundedRectangleBorder frameShape = RoundedRectangleBorder(
    borderRadius: frameRadius,
  );
  static const RoundedRectangleBorder sheetShape = RoundedRectangleBorder(
    borderRadius: sheetRadius,
  );

  /// The radius inside a shape of [outer] radius inset by [inset].
  static double nested(double outer, double inset) =>
      (outer - inset).clamp(0, outer).toDouble();
}

/// Spacing. Use these, not literals, for gaps and padding.
abstract final class PaperfoldSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// The side margin of a route on a phone.
  static const double gutter = 16;

  /// The side margin inside a sheet.
  static const double sheetGutter = 20;

  /// The gap between a floating bar and the screen edge.
  static const double floatInset = 12;

  /// The padding inside a pane.
  static const double pane = 14;
}

/// Control sizes. Visual sizes are slim; touch targets stay 48.
abstract final class PaperfoldSize {
  /// The smallest touch target on Android.
  static const double target = 48;

  /// A button, field, or segmented control as drawn.
  static const double control = 40;

  /// The one main action at the foot of a screen or sheet.
  static const double primary = 48;

  /// A chip as drawn. Its touch target is still [target].
  static const double chip = 32;

  /// A floating action button.
  static const double fab = 52;

  /// The floating navigation bar, without the system inset.
  static const double navigationBar = 64;

  /// A top app bar.
  static const double appBar = 56;

  /// A list row with one line of supporting text.
  static const double row = 56;

  static const double icon = 22;
  static const double smallIcon = 18;
}

/// The two glass recipes. Contrast for both was checked against any
/// backdrop for floating glass and the BookLight bands for glassine.
@immutable
class PaperfoldGlassRecipe {
  const PaperfoldGlassRecipe({
    required this.tint,
    required this.edge,
    required this.highlight,
  });

  factory PaperfoldGlassRecipe.of(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    return PaperfoldGlassRecipe(
      tint: scheme.surfaceContainerLow,
      edge: scheme.onSurface.withValues(alpha: 0.16),
      highlight: Colors.white.withValues(alpha: isLight ? 0.18 : 0.08),
    );
  }

  /// Floating glass over any content: 0.88 keeps text at 4.5:1 or better.
  static const double floatingAlpha = 0.88;

  /// Glassine over BookLight only.
  static const double glassineAlpha = 0.64;

  /// The blur behind floating glass, in logical pixels.
  static const double blurSigma = 12;

  final Color tint;
  final Color edge;
  final Color highlight;

  Color get floating => tint.withValues(alpha: floatingAlpha);
  Color get glassine => tint.withValues(alpha: glassineAlpha);
}

/// One theme's band for BookLight, in OKLCH.
@immutable
class BookLightBand {
  const BookLightBand(this.minL, this.maxL, this.maxC);

  final double minL;
  final double maxL;
  final double maxC;
}

/// Brand and BookLight colours that sit outside the Material roles.
abstract final class PaperfoldBrand {
  static const Color creamGold = Color(0xFF9C7A52);
  static const Color burgundyGold = Color(0xFFC8B28F);
  static const Color darkGold = Color(0xFFB7A179);

  /// The wordmark colour on the current ground.
  static Color wordmark(ColorScheme scheme) {
    if (scheme.brightness == Brightness.light) return creamGold;
    return scheme.surface == PaperfoldTokens.burgundy.ground
        ? burgundyGold
        : darkGold;
  }

  static const BookLightBand creamBand = BookLightBand(0.85, 0.88, 0.045);
  static const BookLightBand burgundyBand = BookLightBand(0.32, 0.39, 0.050);
  static const BookLightBand nearBlackBand = BookLightBand(0.26, 0.30, 0.050);
  static const BookLightBand trueBlackBand = BookLightBand(0.18, 0.24, 0.050);

  /// The band that matches the ground of [scheme].
  static BookLightBand band(ColorScheme scheme) {
    if (scheme.brightness == Brightness.light) return creamBand;
    final ground = scheme.surface;
    if (ground == PaperfoldTokens.burgundy.ground) return burgundyBand;
    if (ground == PaperfoldTokens.darkNearBlack.ground) return nearBlackBand;
    return trueBlackBand;
  }
}
