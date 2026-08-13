import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';

/// The first book on a shelf, stood face out.
///
/// The rest of the row is spine-on, because that is how books are kept and it
/// is how you find one you already know. But a row of nothing but spines gives
/// the reader no cover art at all, and cover art is most of how a book is
/// recognised. Bookshops solve this the same way: the first copy on the shelf
/// is turned out.
///
/// It is drawn as a real corner view - the front cover, a narrow slice of the
/// spine beside it, and the top board across both - rather than as a flat
/// thumbnail. Three parallelograms sharing one near vertical edge.
///
/// The projection is oblique, not perspective: each face is an affine shear, so
/// the two faces meet along their shared edge exactly rather than to within a
/// pixel. It also keeps the whole thing to one transform per face, which is
/// what makes it cheap enough to sit in a scrolling row.
class LeadingBook extends StatelessWidget {
  const LeadingBook({
    super.key,
    required this.book,
    required this.semanticLabel,
    required this.onTap,
    this.onLongPress,
    this.longPressHint,
  });

  final Book book;
  final String semanticLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? longPressHint;

  /// The cover, foreshortened. Wide enough to read the art and the title.
  static const double coverWidth = 82;

  /// The spine slice beside it. It carries no title - there is no room, and
  /// the cover already says what the book is - only the cloth and the bands.
  static const double spineWidth = 20;

  /// How far the far edge of each face rises. The spine is turned further from
  /// the reader than the cover, so it climbs faster over its own width.
  static const double coverRise = 13;
  static const double spineRise = 15;

  static const double width = coverWidth + spineWidth;

  /// How far down the box the near corner sits.
  ///
  /// Both far edges climb from it, and the top board's outermost corner climbs
  /// by both rises at once, so that total is the headroom the object needs. Get
  /// this wrong and the far corner of the board is simply cut off.
  static const double cornerDrop = coverRise + spineRise;

  /// The whole object: the headroom above the near corner, the book, and the
  /// reflection below.
  ///
  /// The distance from the book's base to the bottom of the box is
  /// [BookSpine.reflectionDepth], the same as a plain spine, so a row that
  /// bottom-aligns its children stands them all on one line.
  static double heightFor(double bookHeight) =>
      cornerDrop + bookHeight + BookSpine.reflectionDepth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final textScaler = MediaQuery.textScalerOf(context);
    final scale = BookSpine.layoutScale(textScaler);
    final visual = BookSpine.resolveVisual('book-${book.id}', theme.colorScheme);
    final bookHeight = BookSpine.uniformHeight * scale;

    // The near corner, where the cover meets the spine. Everything is measured
    // from it. In a right-to-left shelf the whole object mirrors, so the spine
    // sits on the other side and the faces lean the other way.
    final totalWidth = width * scale;
    final coverW = coverWidth * scale;
    final spineW = spineWidth * scale;

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
            width: totalWidth,
            height: heightFor(bookHeight),
            child: Directionality(
              // The faces are placed by arithmetic from the near corner, and
              // that arithmetic already accounts for direction. Pinning the
              // subtree to LTR stops the layout mirroring it a second time.
              textDirection: TextDirection.ltr,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _face(
                    context: context,
                    isRtl: isRtl,
                    bookHeight: bookHeight,
                    spineW: spineW,
                    coverW: coverW,
                    visual: visual,
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _LeadingBookPainter(
                          isRtl: isRtl,
                          bookHeight: bookHeight,
                          coverW: coverW,
                          spineW: spineW,
                          visual: visual,
                          shadow: theme.colorScheme.shadow,
                          surface: theme.colorScheme.surface,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: onTap,
                        onLongPress: onLongPress,
                        onSecondaryTap: onLongPress,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The cover itself, sheared onto its face.
  Widget _face({
    required BuildContext context,
    required bool isRtl,
    required double bookHeight,
    required double spineW,
    required double coverW,
    required BookSpineVisual visual,
  }) {
    // The near corner sits inboard of the leading edge by the spine's width.
    final cornerX = isRtl ? coverW : spineW;
    // Positive x moves away from the corner into the cover, and the cover's
    // far edge is higher than its near edge by [coverRise].
    final direction = isRtl ? -1.0 : 1.0;
    final slope = -direction * coverRise / coverW;

    return Positioned(
      left: isRtl ? 0 : cornerX,
      top: cornerDrop,
      child: Transform(
        alignment: Alignment.topLeft,
        transform: Matrix4.identity()
          ..setEntry(1, 0, slope)
          // In right-to-left the cover lies to the left of the corner, so the
          // shear is measured from its own far edge instead.
          ..setEntry(1, 3, isRtl ? coverRise : 0),
        child: SizedBox(
          width: coverW,
          height: bookHeight,
          // Square, and clipped. A board has corners; the rounded card the
          // rest of the application uses for a cover thumbnail would leave
          // four holes where the board meets the spine and the top.
          child: ClipRect(
            child: _coverArt(context, coverW, bookHeight, visual),
          ),
        ),
      ),
    );
  }

  /// The book's own art if it extracted, and the shelf's own cloth if it did
  /// not.
  ///
  /// Deliberately not [BookCover]'s generated cover, which hashes the title
  /// into a colour of its own. That is right in a grid of thumbnails and wrong
  /// here: this book is standing in a row whose every other spine takes its
  /// colour from [BookSpine.resolveVisual], and a hashed yellow among them
  /// belongs to a different palette.
  Widget _coverArt(
    BuildContext context,
    double coverW,
    double bookHeight,
    BookSpineVisual visual,
  ) {
    final path = book.coverFullPath;
    if (path.isNotEmpty && File(path).existsSync()) {
      return Image.file(
        File(path),
        width: coverW,
        height: bookHeight,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            _clothCover(context, coverW, visual),
      );
    }
    return _clothCover(context, coverW, visual);
  }

  Widget _clothCover(
    BuildContext context,
    double coverW,
    BookSpineVisual visual,
  ) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(visual.background, Colors.white, 0.06)!,
            visual.background,
            Color.lerp(visual.background, Colors.black, 0.10)!,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: visual.foreground,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const Spacer(),
            // The same foil rule the spines carry, so the face-out book is
            // obviously one of them rather than a card that wandered in.
            Container(
              height: 1,
              width: coverW * 0.4,
              color: visual.foreground.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 8),
            if (book.author.trim().isNotEmpty)
              Text(
                book.author,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: visual.foreground.withValues(alpha: 0.85),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LeadingBookPainter extends CustomPainter {
  const _LeadingBookPainter({
    required this.isRtl,
    required this.bookHeight,
    required this.coverW,
    required this.spineW,
    required this.visual,
    required this.shadow,
    required this.surface,
  });

  final bool isRtl;
  final double bookHeight;
  final double coverW;
  final double spineW;
  final BookSpineVisual visual;
  final Color shadow;
  final Color surface;

  /// The near corner between the two faces.
  Offset get _corner =>
      Offset(isRtl ? coverW : spineW, LeadingBook.cornerDrop);

  /// Where the spine's far edge sits relative to the corner.
  Offset get _spineAway =>
      Offset(isRtl ? spineW : -spineW, -LeadingBook.spineRise);

  /// Where the cover's far edge sits relative to the corner.
  Offset get _coverAway =>
      Offset(isRtl ? -coverW : coverW, -LeadingBook.coverRise);

  @override
  void paint(Canvas canvas, Size size) {
    _paintSpineFace(canvas);
    _paintTopBoard(canvas);
    _paintCoverEdge(canvas);
    _paintReflection(canvas);
  }

  void _paintSpineFace(Canvas canvas) {
    final corner = _corner;
    final away = _spineAway;
    final face = Path()
      ..moveTo(corner.dx, corner.dy)
      ..lineTo(corner.dx + away.dx, corner.dy + away.dy)
      ..lineTo(corner.dx + away.dx, corner.dy + away.dy + bookHeight)
      ..lineTo(corner.dx, corner.dy + bookHeight)
      ..close();

    // Turned away from the light, so it is the darkest face on the object.
    // Without this the corner disappears and the book flattens into a card.
    final bounds = face.getBounds();
    canvas.drawPath(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: isRtl ? Alignment.centerLeft : Alignment.centerRight,
          end: isRtl ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            Color.lerp(visual.background, Colors.black, 0.30)!,
            Color.lerp(visual.background, Colors.black, 0.58)!,
          ],
        ).createShader(bounds),
    );

    // The bands, so the slice still reads as a bound spine rather than a
    // shaded strip.
    if (visual.hasBands) {
      final band = Paint()
        ..color = visual.foreground.withValues(alpha: 0.30)
        ..strokeWidth = 4;
      for (final t in const [0.05, 0.95]) {
        canvas.drawLine(
          Offset(corner.dx, corner.dy + bookHeight * t),
          Offset(
            corner.dx + away.dx,
            corner.dy + away.dy + bookHeight * t,
          ),
          band,
        );
      }
    }

    // The corner itself. One hairline is what tells the eye the two faces are
    // at an angle to each other rather than printed on one surface.
    canvas.drawLine(
      corner,
      Offset(corner.dx, corner.dy + bookHeight),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
  }

  void _paintTopBoard(Canvas canvas) {
    final corner = _corner;
    final board = Path()
      ..moveTo(corner.dx, corner.dy)
      ..lineTo(corner.dx + _coverAway.dx, corner.dy + _coverAway.dy)
      ..lineTo(
        corner.dx + _coverAway.dx + _spineAway.dx,
        corner.dy + _coverAway.dy + _spineAway.dy,
      )
      ..lineTo(corner.dx + _spineAway.dx, corner.dy + _spineAway.dy)
      ..close();

    final paper = Color.lerp(
      const Color(0xFFEFE6D4),
      visual.background,
      0.30,
    )!;
    canvas.drawPath(
      board,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color.lerp(paper, Colors.black, 0.40)!,
            Color.lerp(paper, Colors.black, 0.10)!,
          ],
        ).createShader(board.getBounds()),
    );

    // Leaves, running the depth of the board from the cover's edge back.
    final leaves = Paint()
      ..color = Color.lerp(paper, Colors.black, 0.50)!.withValues(alpha: 0.45)
      ..strokeWidth = 0.6;
    canvas.save();
    canvas.clipPath(board);
    for (var index = 1; index < 7; index++) {
      final t = index / 7;
      final from = Offset(
        corner.dx + _coverAway.dx * t,
        corner.dy + _coverAway.dy * t,
      );
      canvas.drawLine(from, from + _spineAway, leaves);
    }
    canvas.restore();
  }

  /// A hairline down the cover's outer edge, so the cover reads as a board
  /// with thickness rather than as a picture that stops.
  void _paintCoverEdge(Canvas canvas) {
    final outer = _corner + _coverAway;
    canvas.drawLine(
      outer,
      Offset(outer.dx, outer.dy + bookHeight),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..strokeWidth = 1,
    );
  }

  /// The same treatment the rest of the row gets, over both faces at once.
  void _paintReflection(Canvas canvas) {
    final corner = _corner;
    for (final (away, base) in [
      (_spineAway, corner.dy + bookHeight),
      (_coverAway, corner.dy + bookHeight),
    ]) {
      final nearFoot = Offset(corner.dx, base);
      final farFoot = Offset(corner.dx + away.dx, base + away.dy);
      final depth = BookSpine.reflectionDepth;

      final patch = Path()
        ..moveTo(nearFoot.dx, nearFoot.dy)
        ..lineTo(farFoot.dx, farFoot.dy)
        ..lineTo(farFoot.dx, farFoot.dy + depth)
        ..lineTo(nearFoot.dx, nearFoot.dy + depth)
        ..close();
      final bounds = patch.getBounds();

      canvas.drawPath(
        patch,
        Paint()..color = visual.background.withValues(alpha: 0.34),
      );
      canvas.drawPath(
        patch,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [surface.withValues(alpha: 0), surface],
            stops: const [0.25, 1],
          ).createShader(bounds),
      );
    }

    // Where the book meets the glass.
    final footRect = Rect.fromLTWH(
      math.min(corner.dx + _spineAway.dx, corner.dx + _coverAway.dx),
      corner.dy + bookHeight - BookSpine.contactShadowDepth,
      spineW + coverW,
      BookSpine.contactShadowDepth,
    );
    canvas.drawRect(
      footRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            shadow.withValues(alpha: 0),
            shadow.withValues(alpha: 0.42),
          ],
        ).createShader(footRect),
    );
  }

  @override
  bool shouldRepaint(covariant _LeadingBookPainter oldDelegate) {
    return isRtl != oldDelegate.isRtl ||
        bookHeight != oldDelegate.bookHeight ||
        coverW != oldDelegate.coverW ||
        spineW != oldDelegate.spineW ||
        visual != oldDelegate.visual ||
        shadow != oldDelegate.shadow ||
        surface != oldDelegate.surface;
  }
}
