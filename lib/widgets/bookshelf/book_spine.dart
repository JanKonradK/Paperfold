import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/utils/log/common.dart';

class BookSpineVisual {
  const BookSpineVisual({
    required this.width,
    required this.height,
    required this.background,
    required this.foreground,
    required this.contrastRatio,
    required this.hasBands,
    required this.hasRoundedHead,
    required this.hasFoilRules,
    required this.hubCount,
    required this.grainSeed,
    required this.leanRadians,
  });

  final double width;
  final double height;
  final Color background;
  final Color foreground;
  final double contrastRatio;
  final bool hasBands;
  final bool hasRoundedHead;
  final bool hasFoilRules;
  final int hubCount;
  final int grainSeed;
  final double leanRadians;
}

class BookSpine extends StatelessWidget {
  const BookSpine({
    super.key,
    required this.stableId,
    required this.title,
    required this.author,
    required this.semanticLabel,
    required this.onTap,
    this.onLongPress,
    this.longPressHint,
    this.uniform = false,
  });

  static const double minimumWidth = 48;
  static const double maximumWidth = 64;

  /// Books on a real shelf touch. An 8 dp gap between every spine is what made
  /// the first two builds read as a bar chart rather than a bookcase, so the
  /// gap is a hairline instead.
  ///
  /// This is a deliberate, narrow departure from the "48 dp targets, 8 dp
  /// apart" rule in PRODUCT.md. The TARGET itself is untouched: every spine is
  /// still at least [minimumWidth] = 48 dp wide and at least [minimumHeight]
  /// tall, so no target is small. The 8 dp separation guidance exists to stop
  /// mis-taps between SMALL adjacent targets; between two 48 dp-wide ones it
  /// costs the whole metaphor and buys very little.
  static const double spacing = 2;
  static const double minimumHeight = 220;
  static const double maximumHeight = 280;
  static const double fullLengthMinimumHeight = 264;
  static const double uniformWidth = maximumWidth;
  static const double uniformHeight = maximumHeight;
  static const double contactShadowDepth = 6;
  static const double minimumEffectiveTextSize = 11;
  static const double _baseShelfStageHeight = 318;

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

  final String stableId;
  final String title;
  final String author;
  final String semanticLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? longPressHint;
  final bool uniform;

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

  /// The table is built once. Calls return the same immutable instance.
  static List<Color> backgrounds() => _bookclothBackgrounds;

  /// The bookcloth set for [brightness]. Light is the pale keepsake row; dark
  /// is the saturated cover world. Both tables are built once.
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

      final width = minimumWidth + (hash % 17);
      final variedHeight = fullLengthMinimumHeight + ((hash >> 8) % 17);
      final height = variedHeight
          .clamp(
            math.max(fullLengthMinimumHeight, width * 4),
            math.min(maximumHeight, width * 6),
          )
          .toDouble();
      final leanStep = (hash >> 19) % 7;
      final leanRadians = leanStep == 0 || leanStep == 6
          ? (leanStep == 0 ? -1 : 1) * math.pi / 144
          : 0.0;

      return BookSpineVisual(
        width: width,
        height: height,
        background: background,
        foreground: foreground,
        contrastRatio: bestContrast,
        hasBands: ((hash >> 3) & 1) == 0,
        hasRoundedHead: ((hash >> 4) & 1) == 0,
        hasFoilRules: ((hash >> 5) & 3) != 0,
        hubCount: ((hash >> 12) % 4) == 0 ? 3 : 0,
        grainSeed: (hash >> 16) & 255,
        leanRadians: leanRadians,
      );
    });
  }

  static TextScaler legibleTextScaler(
    TextScaler systemScaler,
    double fontSize,
  ) {
    if (systemScaler.scale(fontSize) >= minimumEffectiveTextSize) {
      return systemScaler;
    }
    return TextScaler.linear(minimumEffectiveTextSize / fontSize);
  }

  /// Spine dimensions grow with accessibility text. This keeps the visible
  /// title at the requested scale instead of shrinking it or clipping it.
  static double layoutScale(TextScaler textScaler) {
    return math.max(1, textScaler.scale(16) / 16);
  }

  /// The standard 318 dp bay grows only when accessibility text grows.
  static double shelfStageHeight(TextScaler textScaler) {
    final fixedFurniture = _baseShelfStageHeight - maximumHeight;
    return fixedFurniture + maximumHeight * layoutScale(textScaler);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = resolveVisual(stableId, theme.colorScheme);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final textScaler = MediaQuery.textScalerOf(context);
    final titleStyle = (theme.textTheme.titleSmall ?? const TextStyle())
        .copyWith(color: visual.foreground, fontWeight: FontWeight.w700);
    final authorStyle = (theme.textTheme.labelSmall ?? const TextStyle())
        .copyWith(color: visual.foreground, fontWeight: FontWeight.w600);
    final authorSize = authorStyle.fontSize ?? 11;
    final showAuthor = author.trim().isNotEmpty;
    final dimensionScale = layoutScale(textScaler);
    final height = (uniform ? uniformHeight : visual.height) * dimensionScale;
    final metadataTextScaler = legibleTextScaler(textScaler, authorSize);
    final baseWidth = (uniform ? uniformWidth : visual.width) * dimensionScale;
    final width = baseWidth;
    final lean = uniform ? 0.0 : visual.leanRadians * (isRtl ? -1 : 1);
    final leanInset = lean == 0 ? 0.0 : 8.0 * dimensionScale;

    final text = Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 14),
      child: RotatedBox(
        quarterTurns: isRtl ? 1 : 3,
        child: Center(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: title, style: titleStyle.copyWith(height: 1)),
                if (showAuthor)
                  TextSpan(
                    text: '\n$author',
                    style: authorStyle.copyWith(height: 1),
                  ),
              ],
            ),
            key: ValueKey('book-spine-metadata-$stableId'),
            textAlign: TextAlign.center,
            softWrap: true,
            textScaler: metadataTextScaler,
          ),
        ),
      ),
    );

    final paintedSpine = SizedBox(
      width: width,
      height: height,
      child: Material(
        key: ValueKey('book-spine-surface-$stableId'),
        color: visual.background,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: visual.hasRoundedHead
              ? const BorderRadius.vertical(top: Radius.circular(5))
              : BorderRadius.zero,
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onLongPress,
          child: CustomPaint(
            painter: _BookSpinePainter(
              visual: visual,
              isRtl: isRtl,
            ),
            child: text,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressHint: onLongPress == null ? null : longPressHint,
      child: ExcludeSemantics(
        child: Tooltip(
          message: semanticLabel,
          child: SizedBox(
            width: width + leanInset * 2,
            height: height + contactShadowDepth,
            child: CustomPaint(
              painter: _BookContactShadowPainter(
                color: PaperfoldTokens.wood(theme.brightness).back,
                spineWidth: width,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform.rotate(
                  angle: lean,
                  alignment: Alignment.bottomCenter,
                  child: paintedSpine,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookSpinePainter extends CustomPainter {
  _BookSpinePainter({
    required this.visual,
    required this.isRtl,
  })  : edgePaint = Paint()
          ..color = visual.foreground.withValues(alpha: 0.14)
          ..strokeWidth = 2,
        highlightPaint = Paint()
          ..color = visual.foreground.withValues(alpha: 0.22)
          ..strokeWidth = 1,
        detailPaint = Paint()
          ..color = visual.foreground.withValues(alpha: 0.56)
          ..strokeWidth = 1,
        grainPaint = Paint()
          ..color = Color.lerp(
            visual.background,
            visual.foreground,
            0.12,
          )!
          ..strokeWidth = 0.7,
        foilPaint = Paint()
          ..color = (BookSpine.contrast(
                    PaperfoldTokens.cover.foil,
                    visual.background,
                  ) >=
                  3
              ? PaperfoldTokens.cover.foil
              : visual.foreground)
          ..strokeWidth = 1;

  final BookSpineVisual visual;
  final bool isRtl;
  final Paint edgePaint;
  final Paint highlightPaint;
  final Paint detailPaint;
  final Paint grainPaint;
  final Paint foilPaint;

  @override
  void paint(Canvas canvas, Size size) {
    _paintUpright(canvas, size);
  }

  void _paintUpright(Canvas canvas, Size size) {
    // A spine is a curved surface, not a card. One gradient across the width
    // does more for that read than any amount of line work: the outer edges
    // fall away, and a soft band of light sits just off centre.
    final sheenRect = Offset.zero & size;
    canvas.drawRect(
      sheenRect,
      Paint()
        ..shader = LinearGradient(
          begin: isRtl ? Alignment.centerRight : Alignment.centerLeft,
          end: isRtl ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            Color.lerp(visual.background, visual.foreground, 0.14)!,
            visual.background,
            Color.lerp(
              visual.background,
              PaperfoldTokens.cover.foil,
              0.06,
            )!,
            Color.lerp(visual.background, visual.foreground, 0.10)!,
          ],
          stops: const [0, 0.3, 0.63, 1],
        ).createShader(sheenRect),
    );

    // A label pasted on the spine, behind the title. Two books in three carry
    // one, chosen from the same stable seed so it never changes between runs.
    if (visual.grainSeed % 3 != 0) {
      final block = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          5,
          size.height * 0.3,
          size.width - 10,
          size.height * 0.4,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        block,
        Paint()
          ..color = Color.lerp(
            visual.background,
            visual.foreground,
            0.035,
          )!,
      );
      canvas.drawRRect(
        block,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = visual.foreground.withValues(alpha: 0.28),
      );
    }

    final shadowX = isRtl ? size.width - 4 : 4.0;
    final highlightX = isRtl ? 4.0 : size.width - 4;
    canvas.drawLine(
        Offset(shadowX, 8), Offset(shadowX, size.height), edgePaint);
    canvas.drawLine(
      Offset(highlightX, 7),
      Offset(highlightX, size.height),
      highlightPaint,
    );

    if (visual.hasBands) {
      canvas.drawRect(Rect.fromLTWH(0, 8, size.width, 5), detailPaint);
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - 10, size.width, 5),
        detailPaint,
      );
    }
    if (visual.hasFoilRules) {
      canvas.drawLine(
        const Offset(7, 20),
        Offset(size.width - 7, 20),
        foilPaint,
      );
      canvas.drawLine(
        Offset(7, size.height - 20),
        Offset(size.width - 7, size.height - 20),
        foilPaint,
      );
    }
    if (visual.hubCount > 0) {
      for (var index = 1; index <= visual.hubCount; index++) {
        final y = size.height * index / (visual.hubCount + 1);
        canvas.drawLine(
          Offset(5, y),
          Offset(size.width - 5, y),
          edgePaint,
        );
        canvas.drawLine(
          Offset(7, y - 2),
          Offset(size.width - 7, y - 2),
          highlightPaint,
        );
      }
    }
    for (var index = 0; index < 4; index++) {
      final x = 9.0 +
          ((visual.grainSeed + index * 13) %
                  math.max(1, (size.width - 18).floor()))
              .toDouble();
      canvas.drawLine(
        Offset(x, 18),
        Offset(x, size.height - 14),
        grainPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BookSpinePainter oldDelegate) {
    return visual != oldDelegate.visual || isRtl != oldDelegate.isRtl;
  }
}

class _BookContactShadowPainter extends CustomPainter {
  const _BookContactShadowPainter({
    required this.color,
    required this.spineWidth,
  });

  final Color color;
  final double spineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - spineWidth) / 2 + 3;
    final rect = Rect.fromLTWH(
      left,
      size.height - BookSpine.contactShadowDepth,
      math.max(0, spineWidth - 6),
      BookSpine.contactShadowDepth,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.5),
            color.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _BookContactShadowPainter oldDelegate) {
    return color != oldDelegate.color || spineWidth != oldDelegate.spineWidth;
  }
}
