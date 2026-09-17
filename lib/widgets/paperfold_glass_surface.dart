import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Opaque paper or cloth for Paperfold chrome. The legacy name is retained
/// for callers; the material no longer blurs the book behind a control.
@immutable
class PaperfoldGlassStyle {
  const PaperfoldGlassStyle._({
    required this.tint,
    required this.solidTint,
    required this.foreground,
    required this.edge,
  });

  factory PaperfoldGlassStyle.fromScheme(ColorScheme scheme) {
    final tint = scheme.surfaceContainerLow.withValues(alpha: 1);
    final foreground = <Color>[
      scheme.onSurface,
      Colors.black,
      Colors.white,
    ].firstWhere((color) => contrastRatio(color, tint) >= minimumContrast);
    return PaperfoldGlassStyle._(
      tint: tint,
      solidTint: tint,
      foreground: foreground,
      edge: foreground.withValues(alpha: 0.16),
    );
  }

  static const double minimumContrast = 4.5;

  final Color tint;
  final Color solidTint;
  final Color foreground;
  final Color edge;

  double get worstCaseContrast => solidContrast;

  double get solidContrast => contrastRatio(foreground, solidTint);

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

/// A clipped, contrast-safe matte surface shared by Paperfold chrome.
class PaperfoldGlassSurface extends StatelessWidget {
  const PaperfoldGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.blurSigma = 14,
    this.allowBlur = false,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Kept for source compatibility. Matte surfaces do not use blur.
  final double blurSigma;
  final bool allowBlur;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final style = PaperfoldGlassStyle.fromScheme(
      Theme.of(context).colorScheme,
    );
    return RepaintBoundary(
      child: Material(
        color: style.solidTint,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: style.edge,
            width: 1 / mediaQuery.devicePixelRatio,
          ),
          borderRadius: borderRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: IconTheme.merge(
          data: IconThemeData(color: style.foreground),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: style.foreground),
            child: child,
          ),
        ),
      ),
    );
  }
}
