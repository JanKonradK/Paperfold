import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';

/// The three materials of Paperfold 3.
enum PaperfoldGlassTier {
  /// Tinted at 0.88 over a 12 px blur. For layers that float over content:
  /// the navigation bar, reader bars, compact sheet headers.
  floating,

  /// Tinted at 0.64, no blur. Only over BookLight, never over covers,
  /// spines, images, or reader pages.
  glassine,

  /// Opaque. Writing, lists, menus, and every fallback.
  solid,
}

/// The colours of the glass for one colour scheme.
@immutable
class PaperfoldGlassStyle {
  const PaperfoldGlassStyle._({
    required this.tint,
    required this.solidTint,
    required this.floatingTint,
    required this.glassineTint,
    required this.foreground,
    required this.edge,
    required this.highlight,
  });

  factory PaperfoldGlassStyle.fromScheme(ColorScheme scheme) {
    final recipe = PaperfoldGlassRecipe.of(scheme);
    final tint = recipe.tint.withValues(alpha: 1);
    final foreground = <Color>[
      scheme.onSurface,
      Colors.black,
      Colors.white,
    ].firstWhere((color) => contrastRatio(color, tint) >= minimumContrast);
    return PaperfoldGlassStyle._(
      tint: tint,
      solidTint: tint,
      floatingTint: recipe.floating,
      glassineTint: recipe.glassine,
      foreground: foreground,
      edge: recipe.edge,
      highlight: recipe.highlight,
    );
  }

  static const double minimumContrast = 4.5;

  /// The opaque colour of the material.
  final Color tint;
  final Color solidTint;
  final Color floatingTint;
  final Color glassineTint;
  final Color foreground;
  final Color edge;
  final Color highlight;

  /// Floating glass is verified at 4.5:1 or better over any backdrop, so the
  /// worst case is bounded by the opaque tint's own contrast at most.
  double get worstCaseContrast => solidContrast;

  double get solidContrast => contrastRatio(foreground, solidTint);

  Color tintFor(PaperfoldGlassTier tier, {required bool live}) {
    if (!live) return solidTint;
    return switch (tier) {
      PaperfoldGlassTier.floating => floatingTint,
      PaperfoldGlassTier.glassine => glassineTint,
      PaperfoldGlassTier.solid => solidTint,
    };
  }

  static double contrastRatio(Color first, Color second) {
    final lighter = math.max(
      first.computeLuminance(),
      second.computeLuminance(),
    );
    final darker = math.min(
      first.computeLuminance(),
      second.computeLuminance(),
    );
    return (lighter + 0.05) / (darker + 0.05);
  }
}

/// A clipped surface in one of the three Paperfold materials.
///
/// Floating glass blurs only what is directly behind its own bounds. When the
/// visual policy forbids glass (eInk, Remove animations, high contrast,
/// battery saver), every tier draws the opaque tint instead.
class PaperfoldGlassSurface extends StatelessWidget {
  const PaperfoldGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = PaperfoldShape.frameRadius,
    this.tier = PaperfoldGlassTier.floating,
    this.blurSigma = PaperfoldGlassRecipe.blurSigma,
    this.allowBlur = true,
    this.shadow = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final PaperfoldGlassTier tier;
  final double blurSigma;

  /// False forces the opaque tint, for a layer with nothing behind it.
  final bool allowBlur;

  /// A soft drop shadow, for layers that float clear of the page.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = PaperfoldGlassStyle.fromScheme(scheme);
    final live =
        allowBlur &&
        tier != PaperfoldGlassTier.solid &&
        PaperfoldVisualPolicy.glassAllowed(context);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);

    Widget surface = Container(
      decoration: BoxDecoration(
        color: style.tintFor(tier, live: live),
        borderRadius: borderRadius,
        border: Border.all(color: style.edge, width: hairline),
      ),
      // The lit top edge of the pane: a static highlight a few pixels deep.
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.05],
          colors: [style.highlight, style.highlight.withValues(alpha: 0)],
        ),
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: style.foreground),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: style.foreground),
          child: child,
        ),
      ),
    );

    if (live && tier == PaperfoldGlassTier.floating) {
      surface = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: surface,
      );
    }

    surface = ClipRRect(borderRadius: borderRadius, child: surface);

    if (shadow) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(
                alpha: scheme.brightness == Brightness.light ? 0.12 : 0.32,
              ),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: surface,
      );
    }

    return RepaintBoundary(
      child: Material(type: MaterialType.transparency, child: surface),
    );
  }
}
