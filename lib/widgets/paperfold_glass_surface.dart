import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// The resolved material for every Paperfold glass surface.
///
/// The translucent tint is opaque enough to keep [foreground] at 4.5:1 over
/// both black and white. Those two backdrops bound the luminance range of any
/// content that can move behind the glass.
@immutable
class PaperfoldGlassStyle {
  const PaperfoldGlassStyle._({
    required this.tint,
    required this.solidTint,
    required this.foreground,
    required this.edge,
  });

  /// Resolving a style is a twenty-four step binary search, and each step
  /// blends two colours and takes two luminances. That is nothing once and a
  /// great deal on every frame: the shelf rebuilds its chrome as the reader
  /// runs through a row, and the answer depends on the scheme alone.
  static ColorScheme? _lastScheme;
  static PaperfoldGlassStyle? _lastStyle;

  factory PaperfoldGlassStyle.fromScheme(ColorScheme scheme) {
    final cached = _lastStyle;
    if (cached != null && _lastScheme == scheme) return cached;
    final style = PaperfoldGlassStyle._resolve(scheme);
    _lastScheme = scheme;
    _lastStyle = style;
    return style;
  }

  factory PaperfoldGlassStyle._resolve(ColorScheme scheme) {
    final tintBase = scheme.surfaceContainerLow;
    final candidates = <Color>[
      scheme.onSurface,
      Colors.black,
      Colors.white,
    ];

    Color foreground = candidates.first;
    double requiredOpacity = 1;
    for (final candidate in candidates) {
      final opacity = _minimumSafeOpacity(candidate, tintBase);
      if (opacity != null) {
        foreground = candidate;
        requiredOpacity = opacity;
        break;
      }
    }

    // Keep a clear material tint even when the contrast calculation permits a
    // lighter veil. The small guard absorbs floating-point and colour-space
    // rounding at the 4.5:1 boundary.
    final opacity = math.min(1.0, math.max(0.76, requiredOpacity + 0.002));
    return PaperfoldGlassStyle._(
      tint: tintBase.withValues(alpha: opacity),
      solidTint: tintBase,
      foreground: foreground,
      edge: foreground.withValues(alpha: 0.22),
    );
  }

  static const double minimumContrast = 4.5;

  final Color tint;
  final Color solidTint;
  final Color foreground;
  final Color edge;

  double get worstCaseContrast => math.min(
        contrastRatio(
          foreground,
          Color.alphaBlend(tint, Colors.black),
        ),
        contrastRatio(
          foreground,
          Color.alphaBlend(tint, Colors.white),
        ),
      );

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

  static double? _minimumSafeOpacity(Color foreground, Color tint) {
    bool isSafe(double opacity) {
      final translucentTint = tint.withValues(alpha: opacity);
      final overBlack = Color.alphaBlend(translucentTint, Colors.black);
      final overWhite = Color.alphaBlend(translucentTint, Colors.white);
      return contrastRatio(foreground, overBlack) >= minimumContrast &&
          contrastRatio(foreground, overWhite) >= minimumContrast;
    }

    if (!isSafe(1)) {
      return null;
    }

    var low = 0.0;
    var high = 1.0;
    for (var iteration = 0; iteration < 24; iteration++) {
      final midpoint = (low + high) / 2;
      if (isSafe(midpoint)) {
        high = midpoint;
      } else {
        low = midpoint;
      }
    }
    return high;
  }
}

/// A clipped, contrast-safe glass surface shared by Paperfold chrome.
///
/// High-contrast and reduced-motion modes use the opaque path automatically.
/// Every active backdrop filter is clipped to this widget and isolated by a
/// [RepaintBoundary], so callers must keep the widget close to its content.
class PaperfoldGlassSurface extends StatelessWidget {
  const PaperfoldGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.blurSigma = 14,
    this.allowBlur = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;
  final bool allowBlur;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final style = PaperfoldGlassStyle.fromScheme(
      Theme.of(context).colorScheme,
    );
    final useBlur =
        allowBlur && !mediaQuery.highContrast && !mediaQuery.disableAnimations;
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: useBlur ? style.tint : style.solidTint,
        border: Border.all(
          color: style.edge,
          width: 1 / mediaQuery.devicePixelRatio,
        ),
        borderRadius: borderRadius,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: style.foreground),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: style.foreground),
          child: child,
        ),
      ),
    );

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: useBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: body,
              )
            : body,
      ),
    );
  }
}
