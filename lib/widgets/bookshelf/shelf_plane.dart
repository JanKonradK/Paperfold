import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paperfold/widgets/book_model/book_model.dart';
import 'package:paperfold/widgets/book_model/book_model_builder.dart';
import 'package:paperfold/widgets/book_model/book_model_scene.dart';

/// Where a book standing further along the shelf lands on the screen.
///
/// The row and the board have to share one vanishing point or the books walk
/// off their own shelf: a row stepped back by a fixed number of pixels recedes
/// in one direction while a board drawn by projection recedes in another, and
/// no amount of tuning the pixels reconciles them. So the step is not in
/// pixels. Each book stands at a real offset along the shelf in book space,
/// and where that lands, and how much smaller it gets, is whatever the camera
/// says. Books far down the row then converge on the vanishing point by
/// themselves, which is also what stops a hundred of them running off the edge.
class ShelfProjection {
  ShelfProjection({required this.spec, required this.box});

  final BookModelSpec spec;
  final Size box;

  /// How far along the shelf one place is, in book units, when nobody has said
  /// how thick the books actually are.
  ///
  /// Along `z`, which is the book's own thickness. Two books standing on a
  /// shelf touch cover to back board, so the row runs the way the books are
  /// thick and not the way they are wide. Stepping along `x` instead slides
  /// them across their own faces, which is not a row of anything.
  ///
  /// One fixed step for every book is what made thick books grow through their
  /// neighbours: a fat hardback measures more than this across, so the book
  /// behind it stood inside it. Callers that know the real thicknesses should
  /// use [slotAlong] and step by those instead.
  static const BookVector step = BookVector(0, 0, -0.145);

  Matrix4? _cached;
  double? _scale;
  bool _resolved = false;

  Matrix4? get view {
    if (_resolved) return _cached;
    _resolved = true;
    final fit = _fit(spec, box);
    _cached = fit?.view;
    _scale = fit?.scale;
    return _cached;
  }

  /// The one scale every book on this shelf is drawn at.
  ///
  /// Measured from the book at the front, the same one the row is stepped back
  /// from. Handed to each book as [BookModelSpec.rowScale] so that none of
  /// them measures itself: a book that fits its own outline to the box stands
  /// a few pixels off the slot the projection gave it, and on a shelf that is
  /// half a title disappearing behind the next book along.
  double? get scale {
    view;
    return _scale;
  }

  /// The point on the front book that stands on the board: the middle of its
  /// tail, half way through its thickness.
  BookVector get _anchor {
    final metrics = BookMetrics.from(spec.profile, spec.seed);
    return BookVector(
      metrics.boardWidth / 2,
      metrics.blockBottom,
      metrics.totalDepth / 2,
    );
  }

  /// The screen offset and the foreshortening of a book standing [along] book
  /// units further down the shelf than the one at the front.
  ///
  /// Distance rather than place, because the places are not evenly spaced: a
  /// book takes up as much of the row as it is thick, and a row that pretends
  /// otherwise has its fat books standing inside their neighbours.
  ///
  /// Null when the slot has gone behind the camera, which is the point past
  /// which there is nothing to draw.
  ({Offset offset, double scale})? slotAlong(double along) {
    final matrix = view;
    if (matrix == null) return null;
    final anchor = _anchor;
    final here = applyMatrix(matrix, anchor);
    final there = applyMatrix(matrix, anchor + const BookVector(0, 0, -1) * along);
    if (here.w <= 0 || there.w <= 0) return null;
    return (
      offset: Offset(
        there.x / there.w - here.x / here.w,
        there.y / there.w - here.y / here.w,
      ),
      // Perspective already knows how much smaller a thing further away is.
      scale: here.w / there.w,
    );
  }
}

/// The fit one book is drawn with: the same measure-and-centre the renderer
/// does, so anything else drawn through it lands in the book's own space.
({Matrix4 view, double scale})? _fit(BookModelSpec spec, Size size) {
  if (size.isEmpty) return null;
  final faces = BookModelBuilder.build(spec);
  if (faces.isEmpty) return null;
  final projection = BookModelRenderer.viewOf(spec);
  final extent = BookModelRenderer.extentOf(faces, projection);
  if (extent.isEmpty) return null;
  final scale = math.min(
    size.width / (extent.width * BookModelRenderer.fitSlack),
    size.height / (extent.height * BookModelRenderer.fitSlack),
  );
  // Placed by the book's own middle, which is where [BookModelRenderer] puts a
  // book drawn at a row scale. The board and the row have to agree with the
  // books, and the books no longer centre their own outlines.
  return (
    view: Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1)
      ..multiply(projection),
    scale: scale,
  );
}

/// The board the books stand on.
///
/// The angle is not a number anybody chose. The board is a rectangle in book
/// space, at the height of the tail of the books, put through the same camera
/// and the same fit as the book standing on it. A shelf drawn by eye and a book
/// drawn by projection disagree at every camera except the one they were
/// matched at, and the disagreement is what makes a shelf look like a sticker
/// under a photograph. This one cannot disagree: change the camera and the
/// board turns with the books, because it is the same matrix.
class ShelfPlanePainter extends CustomPainter {
  ShelfPlanePainter({
    required this.spec,
    required this.surface,
    required this.sheen,
    required this.shadow,
    this.label,
    this.labelStyle,
    this.thickness = 0.075,
    this.leading = 3.4,
    this.trailing = 1.1,
    // A shelf is about as deep as the books on it, plus enough to get a finger
    // behind them. A deeper board reads as a table with books at the back of
    // it, and it swallows the screen a phone has not got to spare.
    this.behind = 0.10,
    this.front = 0.14,
    this.zoom = 1,
  });

  /// The factor whatever draws this painter will scale its output by.
  ///
  /// The board is drawn small, with the row it carries, and then scaled up
  /// with it. Everything geometric survives that, because it is all in book
  /// units. The name engraved on the front edge does not: it is type, and type
  /// scaled to 42 per cent is unreadable. The painter needs the number so it
  /// can lay the name out large enough to come back the right size, and so it
  /// can put it where the edge crosses the screen rather than where the edge
  /// crosses this box.
  final double zoom;

  /// The name of this shelf, printed on the front edge of the board.
  ///
  /// On the edge, not floating above the books. A shelf in a house is labelled
  /// where the label can be read without moving anything, and putting it on the
  /// board is also what stops the name being one more piece of chrome laid over
  /// the world.
  final String? label;
  final TextStyle? labelStyle;

  /// How deep the board is, in book units. A shelf with no thickness is a line,
  /// and a line is not something a book can stand on.
  final double thickness;

  /// The book whose camera and fit the board is drawn in. This is the book at
  /// the front of the row: everything behind it is stepped back along the
  /// board, so the board has to be right for that one.
  final BookModelSpec spec;

  final Color surface;
  final Color sheen;
  final Color shadow;

  /// How far the board runs along the row past the book, in book units. The
  /// row recedes toward the far side, so the board is long that way and short
  /// at the near end.
  final double leading;
  final double trailing;

  /// How far the board reaches past the fore-edges of the books, and how far
  /// it stands proud in front of their spines.
  final double behind;
  final double front;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final view = _view(size);
    if (view == null) return;

    final metrics = BookMetrics.from(spec.profile, spec.seed);
    // The tail of the paper is where a book meets the shelf.
    final y = metrics.blockBottom;

    // The board runs along the row, which is `z`, and is deep across the books,
    // which is `x`. Its near edge stands a little in front of the spines,
    // because that is the edge the reader is looking at and the one the shelf
    // is named on.
    final xNear = -front;
    final xFar = metrics.boardWidth + behind;
    final zFar = -leading;
    final zNear = metrics.totalDepth + trailing;

    final nearLeading = _project(view, xNear, y, zFar);
    final nearTrailing = _project(view, xNear, y, zNear);
    final farTrailing = _project(view, xFar, y, zNear);
    final farLeading = _project(view, xFar, y, zFar);
    if (nearLeading == null ||
        nearTrailing == null ||
        farTrailing == null ||
        farLeading == null) {
      return;
    }

    final board = Path()
      ..moveTo(farLeading.dx, farLeading.dy)
      ..lineTo(farTrailing.dx, farTrailing.dy)
      ..lineTo(nearTrailing.dx, nearTrailing.dy)
      ..lineTo(nearLeading.dx, nearLeading.dy)
      ..close();

    final top = math.min(farLeading.dy, farTrailing.dy);
    final bottom = math.max(nearLeading.dy, nearTrailing.dy);
    if (bottom <= top) return;

    // The board catches the light where it comes forward and falls away into
    // the dark at the back, which is the only cue that says the surface is
    // going away from the reader rather than standing up behind them.
    canvas.drawPath(
      board,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surface.withValues(alpha: 0.02),
            surface.withValues(alpha: 0.16),
          ],
        ).createShader(Rect.fromLTRB(0, top, size.width, bottom)),
    );

    // The contact shade: the books press a line of dark into the board where
    // they touch it. Without it they hover a hair above their own shelf.
    canvas.drawPath(
      board,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            shadow.withValues(alpha: 0.34),
            shadow.withValues(alpha: 0),
          ],
          stops: const [0, 0.42],
        ).createShader(Rect.fromLTRB(0, top, size.width, bottom)),
    );

    // The front edge: the thickness of the board, seen face on. This is the
    // face the shelf is named on, and it is the whole difference between a
    // shelf and a line ruled across the screen.
    final lipLeading = _project(view, xNear, y + thickness, zFar);
    final lipTrailing = _project(view, xNear, y + thickness, zNear);
    if (lipLeading == null || lipTrailing == null) return;

    final lip = Path()
      ..moveTo(nearLeading.dx, nearLeading.dy)
      ..lineTo(nearTrailing.dx, nearTrailing.dy)
      ..lineTo(lipTrailing.dx, lipTrailing.dy)
      ..lineTo(lipLeading.dx, lipLeading.dy)
      ..close();

    final lipTop = math.min(nearLeading.dy, nearTrailing.dy);
    final lipBottom = math.max(lipLeading.dy, lipTrailing.dy);
    canvas.drawPath(
      lip,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surface.withValues(alpha: 0.20),
            surface.withValues(alpha: 0.07),
          ],
        ).createShader(
          Rect.fromLTRB(0, lipTop, size.width, math.max(lipBottom, lipTop + 1)),
        ),
    );

    // The arris, where the light runs along the top edge of the board.
    canvas.drawLine(
      nearLeading,
      nearTrailing,
      Paint()
        ..color = sheen.withValues(alpha: 0.30)
        ..strokeWidth = 1.2,
    );

    _paintLabel(canvas, size, nearLeading, nearTrailing, lipLeading);
  }

  /// The shelf's name, laid along the front edge and turned with it.
  ///
  /// The edge is a receding quadrilateral, so the name is laid out flat and
  /// then put on the board with the same rotation the edge itself has. Drawn
  /// upright it would sit on the board like a label stuck to a photograph.
  void _paintLabel(
    Canvas canvas,
    Size size,
    Offset nearLeading,
    Offset nearTrailing,
    Offset lipLeading,
  ) {
    final text = label?.trim();
    if (text == null || text.isEmpty) return;

    final along = nearTrailing - nearLeading;
    final length = along.distance;
    if (length * zoom < 24) return;
    final depth = (lipLeading - nearLeading).distance;
    if (depth * zoom < 6) return;

    // The board runs a long way past both edges of the screen, so neither end
    // of its front edge is anywhere the reader can see, and the name has to be
    // set against the screen rather than against the board or the box. Ranged
    // to the near end, past where the books stand: the row fills the far half
    // of the board, and a name set there is read four letters at a time
    // between the spines.
    final visible = size.width / zoom;
    final rightEdge = size.width / 2 + visible / 2;
    final margin = visible * 0.06;
    // Where the name begins, in this painter's own coordinates: a little left
    // of the middle of the screen, which is past the near end of the row.
    final target = size.width / 2 - visible * 0.02;
    final start = along.dx.abs() < 0.001
        ? 0.0
        : ((target - nearLeading.dx) / along.dx).clamp(0.0, 0.98);
    final anchor = nearLeading + along * start;
    // And it can run to the edge of the screen and no further, whatever it
    // says. Cut off there rather than written off the side of the phone.
    final room = math.max(rightEdge - margin - anchor.dx, 24.0);

    final painter = TextPainter(
      text: TextSpan(
        text: text.toUpperCase(),
        style: (labelStyle ?? const TextStyle()).copyWith(
          // Set to the board, and set wide. The name is engraved on a strip a
          // few millimetres deep, so it needs the letter spacing a label on a
          // spine or a plaque gets, not the spacing of running text.
          //
          // Divided by the zoom, so that what the reader ends up looking at is
          // the size below however small the board itself is drawn.
          fontSize: math.min(depth * 0.52, 13 / zoom),
          height: 1,
          letterSpacing: 2.6 / zoom,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: room);

    canvas
      ..save()
      ..translate(anchor.dx, anchor.dy)
      ..rotate(math.atan2(along.dy, along.dx));
    painter.paint(canvas, Offset(0, (depth - painter.height) / 2));
    canvas.restore();
  }

  /// The same fit the book itself is drawn with.
  ///
  /// Rebuilt rather than passed in, because the fit depends on the outline the
  /// object casts, and that changes with the camera and with how far open the
  /// book is.
  Matrix4? _view(Size size) => _fit(spec, size)?.view;

  Offset? _project(Matrix4 view, double x, double y, double z) {
    final point = applyMatrix(view, BookVector(x, y, z));
    if (point.w <= 0) return null;
    return Offset(point.x / point.w, point.y / point.w);
  }

  @override
  bool shouldRepaint(covariant ShelfPlanePainter oldDelegate) =>
      oldDelegate.spec.camera.yaw != spec.camera.yaw ||
      oldDelegate.spec.camera.pitch != spec.camera.pitch ||
      oldDelegate.spec.binding != spec.binding ||
      oldDelegate.spec.seed != spec.seed ||
      oldDelegate.label != label ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.thickness != thickness ||
      oldDelegate.zoom != zoom ||
      oldDelegate.leading != leading ||
      oldDelegate.trailing != trailing ||
      oldDelegate.surface != surface ||
      oldDelegate.sheen != sheen ||
      oldDelegate.shadow != shadow;
}
