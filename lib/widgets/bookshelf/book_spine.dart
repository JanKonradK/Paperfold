import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
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

/// Stable bookcloth colours shared by flat spines and cover fallbacks.
abstract final class BookSpine {
  /// One bay of the bookcase, and how much of that bay is book.
  ///
  /// Only the loading skeleton reads this now. It has to stand as tall as the
  /// shelf it stands in for, or the screen jumps when the books arrive.
  static const double _bayHeight = 318;
  static const double _bookHeight = 280;

  static final List<Color> _bookclothBackgrounds = List<Color>.unmodifiable([
    PaperfoldTokens.darkSienna,
    PaperfoldTokens.softDove,
    const Color(0xFF78434B),
    const Color(0xFF5A2636),
    PaperfoldTokens.spicedHotChocolate,
    const Color(0xFFE8D8BC),
    PaperfoldTokens.blackRaspberry,
    const Color(0xFFAD8C66),
    PaperfoldTokens.moonRock,
    const Color(0xFFB89B91),
  ]);

  static final Map<(String, Color, Color, Color, Color, Color), BookSpineVisual>
  _visualCache = {};

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

  /// A book keeps its binding in both themes.
  static List<Color> backgroundsFor(Brightness brightness) =>
      _bookclothBackgrounds;

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

      final foilContrast = contrast(PaperfoldTokens.cover.foil, background);
      if (foilContrast >= 4.5) {
        foreground = PaperfoldTokens.cover.foil;
        bestContrast = foilContrast;
      }

      if (bestContrast < 4.5) {
        background = PaperfoldTokens.light.ground;
        foreground = PaperfoldTokens.light.ink;
        bestContrast = contrast(foreground, background);
        AnxLog.warning('Spine $stableId used the safe paper and ink fallback.');
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
