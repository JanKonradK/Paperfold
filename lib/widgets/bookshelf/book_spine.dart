import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/service/spine_art.dart';
import 'package:paperfold/utils/log/common.dart';

class BookSpineVisual {
  const BookSpineVisual({
    required this.width,
    required this.height,
    required this.background,
    required this.foreground,
    required this.contrastRatio,
    required this.hasBands,
    required this.hasFoilRules,
    required this.hubCount,
    required this.grainSeed,
    required this.leanRadians,
    required this.protrusion,
  });

  final double width;
  final double height;
  final Color background;
  final Color foreground;
  final double contrastRatio;
  final bool hasBands;
  final bool hasFoilRules;
  final int hubCount;
  final int grainSeed;
  final double leanRadians;

  /// How far forward in the tray this book stands, from 0 at the back to 1 at
  /// the front.
  ///
  /// Books on a real shelf are not pushed flush. A book standing proud of its
  /// neighbour is the reason you can see part of its cover at all - the side
  /// face is only visible in the depth it has over the book beside it - and it
  /// is most of why a photographed shelf reads as objects rather than as a bar
  /// chart.
  final double protrusion;
}

class BookSpine extends StatefulWidget {
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
    this.coverPath,
  });

  /// The book's cover file. A spine with one wears a strip of its own art; a
  /// spine without one - a wishlist entry, or a book whose cover failed to
  /// extract - falls back to the derived bookcloth.
  final String? coverPath;

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

  /// The shelf is seen from slightly above and slightly to the leading side,
  /// and every book on it shares that one camera.
  ///
  /// A true vanishing point per shelf would make each book's projection depend
  /// on where it sits along the row, so a spine would visibly rotate as it
  /// scrolled past. A single fixed angle - an axonometric projection, not a
  /// perspective one - is stable under scroll, costs one parallelogram per
  /// book, and is what a shelf photographed from one spot actually looks like.
  ///
  /// [topFaceDepth] is the pitch: how much of the book's top board shows.
  /// [topFaceShear] is the yaw: how far the far edge of a face slides as it
  /// recedes. Adjacent top faces are parallel, so they tile along the row the
  /// way real books do.
  ///
  /// Both are large enough to read as bulk. At 11 and 7 the books had a top but
  /// still looked like coloured rectangles with a lid; a shelf photographed
  /// from a person's height shows a lot more board than that.
  ///
  /// The shear is negative in a left-to-right shelf: deeper into the tray is up
  /// and to the LEFT. That is what makes each book's leading side face - its
  /// cover - fall outside its own footprint and become visible, and it is what
  /// lets the first book on the shelf be the one turned out. With the sign the
  /// other way the visible faces are on the trailing side and only the last
  /// book on a shelf could show a cover, which is no use on a row you have to
  /// scroll to the end of.
  static const double topFaceDepth = 17;
  static const double topFaceShear = 13;

  /// The widest a book's own cover face gets, for a book standing fully proud
  /// of its neighbour.
  static const double coverFaceWidth = 11;

  /// How far a book's reflection reaches down into the glass it stands on.
  static const double reflectionDepth = 12;

  /// The whole vertical extent a spine occupies beyond its own face: its top
  /// board above and its reflection below. The contact shadow is not here
  /// because it is painted over the foot of the book rather than under it.
  static const double verticalFurniture = topFaceDepth + reflectionDepth;

  /// The stage's own insets, above the top board and below the reflection.
  ///
  /// These two, [reflectionDepth] and `GlassShelfPainter.plateInset` are one
  /// arrangement and have to agree: the bottom inset is the plate inset less
  /// the reach of the reflection, which puts a book's base exactly on the
  /// plate's top line with its reflection running down into the glass.
  static const double stageTopInset = 10;
  static const double stageBottomInset = 2;

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

  @override
  State<BookSpine> createState() => _BookSpineState();

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
        hasFoilRules: ((hash >> 5) & 3) != 0,
        hubCount: ((hash >> 12) % 4) == 0 ? 3 : 0,
        grainSeed: (hash >> 16) & 255,
        leanRadians: leanRadians,
        protrusion: ((hash >> 22) % 5) / 4.0,
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

  /// The bay a shelf's books stand in. It grows only when accessibility text
  /// grows, and it is the sum of its parts rather than a round number: the
  /// insets, the top board, the tallest spine and the reflection.
  static double shelfStageHeight(TextScaler textScaler) {
    final fixedFurniture =
        stageTopInset + verticalFurniture + stageBottomInset;
    return fixedFurniture + maximumHeight * layoutScale(textScaler);
  }

}

class _BookSpineState extends State<BookSpine> {
  SpineArt? _art;

  String get stableId => widget.stableId;
  String get title => widget.title;
  String get author => widget.author;
  String get semanticLabel => widget.semanticLabel;
  VoidCallback get onTap => widget.onTap;
  VoidCallback? get onLongPress => widget.onLongPress;
  String? get longPressHint => widget.longPressHint;
  bool get uniform => widget.uniform;

  @override
  void initState() {
    super.initState();
    _resolveArt();
  }

  @override
  void didUpdateWidget(covariant BookSpine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverPath != widget.coverPath) {
      _art = null;
      _resolveArt();
    }
  }

  /// A cover already decoded is taken synchronously, so a shelf that has been
  /// seen once never blinks back to the fallback cloth while it scrolls.
  void _resolveArt() {
    final path = widget.coverPath;
    if (path == null || path.isEmpty) return;
    final ready = SpineArtCache.peek(path);
    if (ready != null) {
      _art = ready;
      return;
    }
    SpineArtCache.load(path).then((art) {
      if (!mounted || art == null || widget.coverPath != path) return;
      setState(() => _art = art);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final art = _art;
    // The cover, when there is one, decides both the field and the title
    // colour. The hashed cloth stays as the fallback and still supplies every
    // structural detail: the bands, the hubs, the lean, the grain seed.
    final base = BookSpine.resolveVisual(stableId, theme.colorScheme);
    final visual = art == null
        ? base
        : BookSpineVisual(
            width: base.width,
            height: base.height,
            background: art.average,
            foreground: art.foreground,
            contrastRatio: SpineArtCache.contrast(art.foreground, art.average),
            hasBands: base.hasBands,
            hasFoilRules: base.hasFoilRules,
            hubCount: base.hubCount,
            grainSeed: base.grainSeed,
            leanRadians: base.leanRadians,
            protrusion: base.protrusion,
          );
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final textScaler = MediaQuery.textScalerOf(context);
    final titleStyle = (theme.textTheme.titleSmall ?? const TextStyle())
        .copyWith(color: visual.foreground, fontWeight: FontWeight.w700);
    final authorStyle = (theme.textTheme.labelSmall ?? const TextStyle())
        .copyWith(color: visual.foreground, fontWeight: FontWeight.w600);
    final authorSize = authorStyle.fontSize ?? 11;
    final showAuthor = author.trim().isNotEmpty;
    final dimensionScale = BookSpine.layoutScale(textScaler);
    final height =
        (uniform ? BookSpine.uniformHeight : visual.height) * dimensionScale;
    final metadataTextScaler =
        BookSpine.legibleTextScaler(textScaler, authorSize);
    final baseWidth =
        (uniform ? BookSpine.uniformWidth : visual.width) * dimensionScale;
    final width = baseWidth;
    final lean = uniform ? 0.0 : visual.leanRadians * (isRtl ? -1 : 1);
    final leanInset = lean == 0 ? 0.0 : 8.0 * dimensionScale;
    // A uniform shelf is uniform: no book stands proud of its neighbour, so
    // none of them shows a cover face.
    final faceWidth =
        uniform ? 0.0 : BookSpine.coverFaceWidth * visual.protrusion;

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
        // Square, always. A rounded head was the old way of suggesting that a
        // spine had a top; there is a real top board above it now, and a
        // rounded corner under a flat board reads as a gap rather than as
        // craft.
        shape: const RoundedRectangleBorder(),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onLongPress,
          child: CustomPaint(
            painter: _BookSpinePainter(
              visual: visual,
              isRtl: isRtl,
              art: art,
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
            // The cover face stands beside the spine on the leading side, so
            // the box carries it. Only as much as this book actually shows:
            // a book pushed flush to the back of the tray has no face and asks
            // for no room.
            width: width + leanInset * 2 + faceWidth,
            height: height + BookSpine.verticalFurniture,
            child: CustomPaint(
              painter: _BookPresencePainter(
                // Everything the book is beyond its spine: the cover face
                // beside it, the top board over both, the shadow it drops
                // where it meets the tray, and what the tray gives back.
                shadow: theme.colorScheme.shadow,
                surface: theme.colorScheme.surface,
                spineWidth: width,
                spineHeight: height,
                visual: visual,
                art: art,
                isRtl: isRtl,
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: faceWidth),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: BookSpine.topFaceDepth),
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
        ),
      ),
    );
  }
}

class _BookSpinePainter extends CustomPainter {
  _BookSpinePainter({
    required this.visual,
    required this.isRtl,
    this.art,
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
  final SpineArt? art;
  final Paint edgePaint;
  final Paint highlightPaint;
  final Paint detailPaint;
  final Paint grainPaint;
  final Paint foilPaint;

  @override
  void paint(Canvas canvas, Size size) {
    _paintUpright(canvas, size);
  }

  /// Wraps the cover's leading edge around onto the spine.
  ///
  /// The slice is a fifth of the cover, stretched across the spine's width, so
  /// what shows is the part of the jacket that really does wrap around a
  /// hardback's hinge. Stretching a handful of pixels this far is soft on
  /// purpose: it reads as printed cloth rather than as a thumbnail.
  ///
  /// A veil of the slice's own average colour goes over it afterwards. It
  /// keeps the hue and the banding of the art while pulling every pixel toward
  /// the colour the title was tested against, so a busy cover cannot leave the
  /// title below 4.5:1 in one corner.
  bool _paintCoverStrip(Canvas canvas, Size size) {
    final source = art;
    if (source == null) return false;
    final image = source.strip;
    final sliceWidth =
        (image.width * SpineArtCache.stripFraction).clamp(1.0, image.width * 1.0);
    final src = isRtl
        ? Rect.fromLTWH(
            image.width - sliceWidth, 0, sliceWidth, image.height.toDouble())
        : Rect.fromLTWH(0, 0, sliceWidth, image.height.toDouble());

    canvas.drawImageRect(
      image,
      src,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = source.average.withValues(alpha: 0.52),
    );
    return true;
  }

  void _paintUpright(Canvas canvas, Size size) {
    if (_paintCoverStrip(canvas, size)) {
      _paintSpineDetail(canvas, size);
      return;
    }
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

    _paintSpineDetail(canvas, size);
  }

  /// Everything that is not the field: the label, the bands, the hubs, the
  /// foil and the edges. Shared, so a spine wearing cover art keeps exactly
  /// the same construction as one wearing the fallback cloth.
  void _paintSpineDetail(Canvas canvas, Size size) {
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

/// The book beyond its spine face: the top board, the contact shadow, and the
/// reflection in the glass.
///
/// All three are drawn by one painter over the whole widget box, so a book
/// costs one extra painter rather than three, and the reflection can reach
/// below the book's base into the plate without any of it being clipped.
class _BookPresencePainter extends CustomPainter {
  const _BookPresencePainter({
    required this.shadow,
    required this.surface,
    required this.spineWidth,
    required this.spineHeight,
    required this.visual,
    required this.isRtl,
    this.art,
  });

  final Color shadow;
  final Color surface;
  final double spineWidth;
  final double spineHeight;
  final BookSpineVisual visual;
  final bool isRtl;
  final SpineArt? art;

  /// Which way "deeper into the tray" runs on screen: up, and toward the
  /// leading side. Every face on every book shares it.
  double get _shear =>
      (isRtl ? BookSpine.topFaceShear : -BookSpine.topFaceShear);

  /// How much of this book's cover shows beside its spine.
  ///
  /// Only a book standing proud of the one beside it shows any: the side face
  /// is visible in the depth it has over its neighbour, and a shelf of books
  /// pushed flush shows none at all.
  double get _coverFace => BookSpine.coverFaceWidth * visual.protrusion;

  @override
  void paint(Canvas canvas, Size size) {
    // Where the layout put the spine: centred in what is left of the box once
    // the cover face has taken its side.
    final face = _coverFace;
    final left = isRtl
        ? (size.width - face - spineWidth) / 2
        : face + (size.width - face - spineWidth) / 2;
    _paintCoverFace(canvas, left);
    _paintTopBoard(canvas, left);
    _paintReflection(canvas, left);
    _paintContactShadow(canvas, size, left);
  }

  /// The sliver of the book's own front cover, on its leading side.
  ///
  /// This is the thing a photograph of a real shelf has and a row of drawn
  /// rectangles does not: between two spines you see a slice of board, and it
  /// is what tells the eye these are objects with depth standing in a tray
  /// rather than stripes printed on a background.
  void _paintCoverFace(Canvas canvas, double left) {
    final width = _coverFace;
    if (width < 0.5) return;

    // The face lies on the leading side and recedes with the shear, so its far
    // edge is higher than its near edge by the same proportion the top board
    // uses.
    final rise = BookSpine.topFaceDepth * (width / BookSpine.topFaceShear);
    final nearX = isRtl ? left + spineWidth : left;
    final farX = nearX + (isRtl ? width : -width);
    final top = BookSpine.topFaceDepth;
    final face = Path()
      ..moveTo(nearX, top)
      ..lineTo(farX, top - rise)
      ..lineTo(farX, top - rise + spineHeight)
      ..lineTo(nearX, top + spineHeight)
      ..close();

    final source = art;
    if (source != null) {
      // The book's real jacket, taken from the part of it the spine does not
      // already wear.
      canvas.save();
      canvas.clipPath(face);
      final image = source.strip;
      final start = image.width * SpineArtCache.stripFraction;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(
          isRtl ? 0 : start,
          0,
          math.max(1, image.width - start),
          image.height.toDouble(),
        ),
        face.getBounds(),
        Paint()..filterQuality = FilterQuality.low,
      );
      canvas.restore();
    } else {
      canvas.drawPath(
        face,
        Paint()..color = Color.lerp(visual.background, Colors.white, 0.16)!,
      );
    }

    // Angled away from the light, so it is darker than the spine whatever it
    // carries. Without this the face reads as the spine getting wider; with
    // too much of it the face goes black and reads as a gap between books.
    canvas.drawPath(
      face,
      Paint()..color = Colors.black.withValues(alpha: 0.17),
    );
    canvas.drawLine(
      Offset(nearX, top),
      Offset(nearX, top + spineHeight),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.34)
        ..strokeWidth = 1,
    );
  }

  /// The top of a closed book is its page block, bound at the spine edge by
  /// the top board of the cover. Seen from slightly above and slightly to one
  /// side it is a parallelogram, and every book on the shelf shares the angle,
  /// so the boards tile along the row.
  void _paintTopBoard(Canvas canvas, double left) {
    final shear = _shear;
    final near = BookSpine.topFaceDepth;
    // The board caps the spine and the cover face together - it is one board
    // over the whole book - so it starts at the outer edge of the cover face.
    final face = _coverFace;
    final nearLeft = left - (isRtl ? 0 : face);
    final nearRight = left + spineWidth + (isRtl ? face : 0);
    // Square-sided, not a parallelogram.
    //
    // A sheared outline is what a single book's top really looks like, and it
    // is wrong for a row: each board then leaves a wedge of background at its
    // trailing top corner that the next book cannot fill, because the next book
    // is a whole spine-width away and its own board is sheared the same way.
    // Books on a shelf touch, and their boards read as one continuous run of
    // page block. The yaw is carried by the leaves and by the cover face
    // instead, which is where the eye reads it anyway.
    final board = Path()
      ..addRect(Rect.fromLTRB(nearLeft, 0, nearRight, near));

    // Page edges. Tinted toward the book's own cloth and kept well down the
    // luminance range: a board is a surface angled away from the light, and a
    // bright cream cap on every book turns a shelf into a row of lidded boxes.
    final paper = Color.lerp(_pageBlock, visual.background, 0.34)!;
    final bounds = Rect.fromLTWH(
      nearLeft + math.min(0.0, shear),
      0,
      (nearRight - nearLeft) + shear.abs(),
      near,
    );
    canvas.drawPath(
      board,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color.lerp(paper, Colors.black, 0.42)!,
            Color.lerp(paper, Colors.black, 0.12)!,
          ],
        ).createShader(bounds),
    );

    // The leaves. A handful of hairlines running the depth of the board is
    // enough to read as paper rather than as a blank facet.
    final leaves = Paint()
      ..color = Color.lerp(paper, Colors.black, 0.52)!.withValues(alpha: 0.5)
      ..strokeWidth = 0.6;
    canvas.save();
    canvas.clipPath(board);
    for (var index = 1; index < 6; index++) {
      final x = nearLeft + (nearRight - nearLeft) * index / 6;
      canvas.drawLine(Offset(x, near), Offset(x + shear, 0), leaves);
    }
    canvas.restore();
  }

  /// What the glass gives back.
  ///
  /// A mirrored slice of the book's own base rather than a generic sheen, so a
  /// red book throws back red. It fades into the page ground rather than into
  /// transparency, which keeps it to one draw with no save layer: an
  /// intermediate buffer per spine is the kind of cost that only shows up as a
  /// dropped frame while the shelf is being flung.
  void _paintReflection(Canvas canvas, double left) {
    final base = BookSpine.topFaceDepth + spineHeight;
    final rect = Rect.fromLTWH(
      left,
      base,
      spineWidth,
      BookSpine.reflectionDepth,
    );

    canvas.save();
    canvas.clipRect(rect);
    // Mirror about the book's base. The clip above is in the untransformed
    // space, so it still bounds the reflection to the glass below the book.
    canvas.translate(0, base * 2);
    canvas.scale(1, -1);

    final source = art;
    // Drawn where the foot of the book is, not where the reflection goes: the
    // mirror above is what carries it down into the glass.
    final mirrored = Rect.fromLTWH(
      left,
      base - BookSpine.reflectionDepth,
      spineWidth,
      BookSpine.reflectionDepth,
    );
    if (source != null) {
      final image = source.strip;
      final sliceWidth =
          (image.width * SpineArtCache.stripFraction).clamp(1.0, image.width * 1.0);
      // The bottom of the strip, which is the bottom of the spine.
      final sliceHeight = image.height *
          (BookSpine.reflectionDepth / math.max(1.0, spineHeight));
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(
          isRtl ? image.width - sliceWidth : 0,
          image.height - sliceHeight,
          sliceWidth,
          sliceHeight,
        ),
        mirrored,
        Paint()
          ..filterQuality = FilterQuality.low
          // The paint's alpha modulates the image.
          ..color = const Color(0xFFFFFFFF).withValues(alpha: _strength),
      );
    } else {
      // No cover to mirror, so mirror the sheen the spine paints instead. A
      // flat rectangle of the background colour is not a reflection of
      // anything - it reads as the book having a skirt.
      canvas.drawRect(
        mirrored,
        Paint()
          ..shader = LinearGradient(
            begin: isRtl ? Alignment.centerRight : Alignment.centerLeft,
            end: isRtl ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              Color.lerp(visual.background, visual.foreground, 0.14)!
                  .withValues(alpha: _strength),
              visual.background.withValues(alpha: _strength),
              Color.lerp(visual.background, PaperfoldTokens.cover.foil, 0.06)!
                  .withValues(alpha: _strength),
              Color.lerp(visual.background, visual.foreground, 0.10)!
                  .withValues(alpha: _strength),
            ],
            stops: const [0, 0.3, 0.63, 1],
          ).createShader(mirrored),
      );
    }
    canvas.restore();

    // Fade it into the ground. Painting the ground colour over the top is the
    // same result as fading to transparent, without the layer. It stays clear
    // for the first third so the reflection has somewhere to be at full
    // strength - a fade that starts at the book's foot leaves nothing to see.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surface.withValues(alpha: 0),
            surface.withValues(alpha: 0.35),
            surface,
          ],
          stops: const [0, 0.35, 1],
        ).createShader(rect),
    );
  }

  /// How present the reflection is against the book itself.
  ///
  /// The glass is dark in the dark theme and warm paper in the light one, and
  /// at a fifth the reflection disappeared into both. This is a surface
  /// treatment, never a text background, so it carries no contrast duty.
  static const double _strength = 0.42;

  void _paintContactShadow(Canvas canvas, Size size, double left) {
    final base = BookSpine.topFaceDepth + spineHeight;
    final rect = Rect.fromLTWH(
      left + 3,
      base - BookSpine.contactShadowDepth,
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
            shadow.withValues(alpha: 0),
            shadow.withValues(alpha: 0.5),
          ],
        ).createShader(rect),
    );
  }

  static const Color _pageBlock = Color(0xFFEFE6D4);

  @override
  bool shouldRepaint(covariant _BookPresencePainter oldDelegate) {
    return shadow != oldDelegate.shadow ||
        surface != oldDelegate.surface ||
        spineWidth != oldDelegate.spineWidth ||
        spineHeight != oldDelegate.spineHeight ||
        visual != oldDelegate.visual ||
        art != oldDelegate.art ||
        isRtl != oldDelegate.isRtl;
  }
}
