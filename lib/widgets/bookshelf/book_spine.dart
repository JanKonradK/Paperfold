import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/utils/log/common.dart';

/// The two colours one book wears: its bookcloth and the ink that reads on it.
@immutable
class BookSpineVisual {
  const BookSpineVisual({
    required this.background,
    required this.foreground,
    required this.contrastRatio,
  });

  /// The bookcloth.
  final Color background;

  /// Printed matter on that cloth. Tested to 4.5:1 over [background].
  final Color foreground;

  /// What the pair actually measured, so a test can hold the rule.
  final double contrastRatio;
}

/// How a book's look is derived: which bookcloth it wears, and which ink reads
/// on it.
///
/// A namespace of statics, not a widget. It used to be a painted flat spine,
/// and it carried everything that painter needed: the spine's width, height and
/// lean, its raised bands, its foil rules, its hub count and its grain seed.
/// The library now stands its books on a bookcase as real three-dimensional
/// objects, and those derive their own geometry, so all of it went with the
/// painter. What is left is what the rest of the application still asks for —
/// the same hash and the same cloth table, so that one book is one colour
/// wherever it is drawn.
abstract final class BookSpine {
  /// One bay of the bookcase, and how much of that bay is book.
  ///
  /// Only the loading skeleton reads this now. It has to stand as tall as the
  /// shelf it stands in for, or the screen jumps when the books arrive.
  static const double _bayHeight = 318;
  static const double _bookHeight = 280;

  static final List<Color> _bookclothBackgrounds = List<Color>.unmodifiable([
    PaperfoldTokens.cover.ground,
    Color.lerp(
      PaperfoldTokens.surfaces.dustyRose,
      PaperfoldTokens.cover.ground,
      0.62,
    )!,
    Color.lerp(
      PaperfoldTokens.surfaces.sageGreen,
      PaperfoldTokens.light.ink,
      0.68,
    )!,
    Color.lerp(
      PaperfoldTokens.surfaces.goldenTan,
      PaperfoldTokens.light.ink,
      0.64,
    )!,
    Color.lerp(
      PaperfoldTokens.surfaces.warmBeige,
      PaperfoldTokens.cover.ground,
      0.68,
    )!,
    Color.lerp(
      PaperfoldTokens.surfaces.terracottaBrown,
      PaperfoldTokens.light.ink,
      0.52,
    )!,
    Color.lerp(
      PaperfoldTokens.surfaces.sageGreen,
      PaperfoldTokens.cover.ground,
      0.48,
    )!,
    Color.lerp(
      PaperfoldTokens.surfaces.goldenTan,
      PaperfoldTokens.cover.ground,
      0.58,
    )!,
  ]);

  /// The light theme reads as the owner's printed keepsake page: a close-packed
  /// row of near-uniform pale spines carrying delicate detail, not a row of
  /// saturated covers. The saturated set above is the dark-theme world, where
  /// the books are the only colour on a black screen.
  ///
  /// These are surfaces, never text. Titles take their colour from the
  /// contrast search in [resolveVisual], which still enforces 4.5:1.
  static final List<Color> _bookclothLight = List<Color>.unmodifiable([
    const Color(0xFFF1E8D8),
    Color.lerp(
      const Color(0xFFEDE3D2),
      PaperfoldTokens.surfaces.sageGreen,
      0.18,
    )!,
    Color.lerp(
      const Color(0xFFEDE3D2),
      PaperfoldTokens.surfaces.dustyRose,
      0.14,
    )!,
    const Color(0xFFE7DCC7),
    Color.lerp(
      const Color(0xFFE9DFCC),
      PaperfoldTokens.surfaces.goldenTan,
      0.22,
    )!,
    const Color(0xFFF4EDE0),
  ]);

  static final Map<
      (
        String,
        Color,
        Color,
        Color,
        Color,
        Color,
      ),
      BookSpineVisual> _visualCache = {};

  static int stableHash(String value) {
    var hash = 2166136261;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 4294967295;
    }
    return hash;
  }

  static double contrast(Color foreground, Color background) {
    final foregroundLuminance = foreground.computeLuminance();
    final backgroundLuminance = background.computeLuminance();
    final lighter = math.max(foregroundLuminance, backgroundLuminance);
    final darker = math.min(foregroundLuminance, backgroundLuminance);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// The bookcloth set for [brightness]. Light is the pale keepsake row; dark
  /// is the saturated cover world. Both tables are built once, and every caller
  /// gets the same immutable instance.
  static List<Color> backgroundsFor(Brightness brightness) =>
      brightness == Brightness.light ? _bookclothLight : _bookclothBackgrounds;

  static BookSpineVisual resolveVisual(
    String stableId,
    ColorScheme colorScheme,
  ) {
    final key = (
      stableId,
      colorScheme.onSurface,
      colorScheme.onSurfaceVariant,
      colorScheme.onPrimaryContainer,
      colorScheme.onSecondaryContainer,
      colorScheme.onTertiaryContainer,
    );
    return _visualCache.putIfAbsent(key, () {
      final hash = stableHash(stableId);
      final cloth = backgroundsFor(colorScheme.brightness);
      var background = cloth[hash % cloth.length];
      final foregroundCandidates = <Color>[
        PaperfoldTokens.light.ink,
        PaperfoldTokens.dark.ink,
        colorScheme.onSurface,
        colorScheme.onSurfaceVariant,
        colorScheme.onPrimaryContainer,
        colorScheme.onSecondaryContainer,
        colorScheme.onTertiaryContainer,
      ];

      var foreground = foregroundCandidates.first;
      var bestContrast = contrast(foreground, background);
      for (final candidate in foregroundCandidates.skip(1)) {
        final candidateContrast = contrast(candidate, background);
        if (candidateContrast > bestContrast) {
          foreground = candidate;
          bestContrast = candidateContrast;
        }
      }

      if (bestContrast < 4.5) {
        background = PaperfoldTokens.light.ground;
        foreground = PaperfoldTokens.light.ink;
        bestContrast = contrast(foreground, background);
        AnxLog.warning(
          'Spine $stableId used the safe paper and ink fallback.',
        );
      }

      return BookSpineVisual(
        background: background,
        foreground: foreground,
        contrastRatio: bestContrast,
      );
    });
  }

  /// One bay of the bookcase, grown for accessibility text so a large system
  /// font does not clip the books standing in it.
  static double shelfStageHeight(TextScaler textScaler) {
    final scale = math.max(1, textScaler.scale(16) / 16);
    return (_bayHeight - _bookHeight) + _bookHeight * scale;
  }
}
