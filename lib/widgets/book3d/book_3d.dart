import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:paperfold/widgets/book3d/book_geometry.dart';
import 'package:paperfold/widgets/book3d/book_model.dart';

/// What a book is covered in.
@immutable
class BookMaterials {
  const BookMaterials({
    required this.cloth,
    required this.foil,
    this.paper = const Color(0xFFF2EADA),
    this.board = const Color(0xFF2B2521),
    this.headband = const Color(0xFFB8484A),
    this.coverArt,
  });

  /// The covering material, on both boards and the spine.
  final Color cloth;

  /// Blocking on the spine and the front board.
  final Color foil;

  /// The leaves.
  final Color paper;

  /// Greyboard, seen only on the cut edges of the boards.
  final Color board;

  final Color headband;

  /// The jacket, if the book has one. Drawn onto the front board and wrapped
  /// around the spine.
  final ui.Image? coverArt;

  BookMaterials copyWith({Color? cloth, ui.Image? coverArt}) => BookMaterials(
        cloth: cloth ?? this.cloth,
        foil: foil,
        paper: paper,
        board: board,
        headband: headband,
        coverArt: coverArt ?? this.coverArt,
      );
}

/// A hardback book, drawn in three dimensions.
///
/// One book, described once. Everything that varies between books on a shelf -
/// how tall, how deep, how thick, what it is covered in, whether it is open -
/// is a parameter, so the shelf can hold a hundred of these without a hundred
/// special cases.
///
/// The model is a real one: boards that overhang the page block by the square,
/// a rounded back faceted so the light travels round it, a groove at the joint
/// for the boards to hinge on, headbands, and a page block whose fore-edge is
/// hollowed to match the round. See [BookGeometry] for what each of those is.
class Book3D extends StatelessWidget {
  const Book3D({
    super.key,
    required this.materials,
    this.geometry = const BookGeometry(),
    this.camera = const BookCamera(),
    this.openAmount = 0,
    this.reserveOpenSpace = false,
    this.title,
    this.author,
    this.titleStyle,
    this.semanticLabel,
  });

  final BookGeometry geometry;
  final BookCamera camera;
  final BookMaterials materials;

  /// 0 closed, 1 open.
  final double openAmount;

  /// Whether to reserve the room the cover needs to swing. See [sizeFor].
  final bool reserveOpenSpace;

  final String? title;
  final String? author;

  /// The face the spine is blocked in. A `TextPainter` does not inherit the
  /// theme, so without this the title comes out in the platform fallback -
  /// which in a widget test is no font at all, and renders as tofu.
  final TextStyle? titleStyle;

  final String? semanticLabel;

  /// The size this book needs at a given camera, in logical pixels.
  ///
  /// With [reserveOpenSpace] the box also covers the arc the cover sweeps, so
  /// a book that is animating never resizes halfway through and never jumps.
  /// Without it the box is only as big as the closed book, which is what a
  /// shelf wants: a row of books that each reserved room to fling their covers
  /// open would stand a cover's width apart.
  static Size sizeFor(
    BookGeometry geometry,
    BookCamera camera, {
    bool reserveOpenSpace = false,
  }) {
    final points = <V3>[];
    for (final x in [0.0, geometry.thickness]) {
      for (final y in [0.0, geometry.height]) {
        for (final z in [-geometry.spineBulge, geometry.depth]) {
          points.add(V3(x, y, z));
        }
      }
    }
    // Where the fore-edge of the cover reaches at several points through the
    // swing. The extremes are not always at either end of it.
    for (var step = 0; reserveOpenSpace && step <= 8; step++) {
      final angle = BookModel.fullOpen * step / 8;
      for (final y in [0.0, geometry.height]) {
        points.add(
          V3(geometry.thickness, y, geometry.depth)
              .rotateAboutVertical(geometry.thickness, geometry.groove, angle),
        );
      }
    }

    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final point in points) {
      final projected = camera.project(point);
      minX = math.min(minX, projected.dx);
      maxX = math.max(maxX, projected.dx);
      minY = math.min(minY, projected.dy);
      maxY = math.max(maxY, projected.dy);
    }
    return Size(maxX - minX, maxY - minY);
  }

  @override
  Widget build(BuildContext context) {
    final size = sizeFor(
      geometry,
      camera,
      reserveOpenSpace: reserveOpenSpace || openAmount > 0,
    );
    final child = SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(
        painter: _Book3DPainter(
          model: BookModel(geometry: geometry, openAmount: openAmount),
          camera: camera,
          materials: materials,
          title: title,
          author: author,
          titleStyle: titleStyle ??
              Theme.of(context).textTheme.titleSmall ??
              const TextStyle(),
          textDirection: Directionality.of(context),
        ),
      ),
    );
    final label = semanticLabel;
    if (label == null) return child;
    return Semantics(label: label, child: ExcludeSemantics(child: child));
  }
}

class _Book3DPainter extends CustomPainter {
  _Book3DPainter({
    required this.model,
    required this.camera,
    required this.materials,
    required this.textDirection,
    required this.titleStyle,
    this.title,
    this.author,
  });

  final BookModel model;
  final BookCamera camera;
  final BookMaterials materials;
  final TextDirection textDirection;
  final TextStyle titleStyle;
  final String? title;
  final String? author;

  @override
  void paint(Canvas canvas, Size size) {
    // The model is in book space with its origin at the spine's bottom corner.
    // Centre whatever that projects to inside the box we were given.
    final facets = model.facets();
    if (facets.isEmpty) return;

    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final facet in facets) {
      for (final corner in facet.face.corners) {
        final point = camera.project(corner);
        minX = math.min(minX, point.dx);
        maxX = math.max(maxX, point.dx);
        minY = math.min(minY, point.dy);
        maxY = math.max(maxY, point.dy);
      }
    }
    canvas.save();
    canvas.translate(
      (size.width - (maxX - minX)) / 2 - minX,
      (size.height - (maxY - minY)) / 2 - minY,
    );

    final visible = facets
        .where((facet) => facet.face.facesCamera(camera))
        .toList();
    _sortFarToNear(visible, camera);

    for (final facet in visible) {
      _paintFacet(canvas, facet);
    }

    _paintSpineText(canvas, facets);
    canvas.restore();
  }

  /// Orders the facets far to near.
  ///
  /// Average depth first, which is right for faces at an angle to each other,
  /// and then a settling pass over neighbouring PARALLEL faces, which average
  /// depth gets wrong. A book is mostly parallel faces stacked on one another
  /// and a face inset from the one in front of it - the first page under the
  /// cover, the pastedown under the board - has the smaller average depth
  /// despite sitting behind, so on average depth alone the page drew over the
  /// cover and every closed book came out cream.
  ///
  /// The settling pass is bounded and only ever swaps adjacent pairs that are
  /// both parallel and inverted, so it cannot loop and cannot reorder faces
  /// that average depth already had right.
  static void _sortFarToNear(List<BookFacet> facets, BookCamera camera) {
    facets.sort((a, b) => b.face.depth(camera).compareTo(a.face.depth(camera)));
    for (var pass = 0; pass < facets.length; pass++) {
      var swapped = false;
      for (var index = 0; index + 1 < facets.length; index++) {
        final near = facets[index];
        final far = facets[index + 1];
        final alignment = near.unitNormal.x * far.unitNormal.x +
            near.unitNormal.y * far.unitNormal.y +
            near.unitNormal.z * far.unitNormal.z;
        if (alignment < 0.985) continue;
        // Parallel and facing the same way: the one further along that shared
        // normal is the one on top, so it must be drawn later.
        if (near.outwardness > far.outwardness + 1e-6) {
          facets[index] = far;
          facets[index + 1] = near;
          swapped = true;
        }
      }
      if (!swapped) break;
    }
  }

  void _paintFacet(Canvas canvas, BookFacet facet) {
    final path = facet.face.path(camera);
    final base = _colourOf(facet.surface);
    final lit = _shade(base, facet.shade);

    final art = materials.coverArt;
    final wantsArt = art != null &&
        (facet.surface == Surface.frontCover || facet.surface == Surface.spine);

    if (wantsArt) {
      canvas.save();
      canvas.clipPath(path);
      canvas.transform(facet.face.unitSquareTransform(camera));
      final slice = facet.imageFraction;
      // The spine wears the leading edge of the jacket, sliced across its
      // facets so the artwork wraps the round instead of repeating on each.
      final src = facet.surface == Surface.spine && slice != null
          ? Rect.fromLTWH(
              art.width * 0.02 + art.width * 0.06 * slice.$1,
              0,
              math.max(1, art.width * 0.06 * (slice.$2 - slice.$1)),
              art.height.toDouble(),
            )
          : Rect.fromLTWH(
              art.width * 0.08,
              0,
              art.width * 0.92,
              art.height.toDouble(),
            );
      canvas.drawImageRect(
        art,
        src,
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()..filterQuality = FilterQuality.medium,
      );
      // The light still has to reach it.
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()
          ..color = (facet.shade < 0.5 ? Colors.black : Colors.white)
              .withValues(alpha: (facet.shade - 0.5).abs() * 0.55),
      );
      canvas.restore();
    } else {
      canvas.drawPath(path, Paint()..color = lit);
    }

    if (facet.surface == Surface.pageBlock) {
      _paintLeaves(canvas, facet, lit);
    }

    // Every facet gets its outline in its own darkened colour rather than a
    // shared line: a book has no black wireframe on it, but without something
    // there the seams between facets show as hairline gaps where the
    // antialiasing of two neighbours does not quite meet.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = _shade(base, facet.shade * 0.62),
    );
  }

  /// The cut edges of the leaves.
  ///
  /// Drawn in the projected plane of the facet, so they follow the fore-edge
  /// round as it curves rather than being combed straight across it.
  void _paintLeaves(Canvas canvas, BookFacet facet, Color lit) {
    final a = camera.project(facet.face.a);
    final b = camera.project(facet.face.b);
    final c = camera.project(facet.face.c);
    final d = camera.project(facet.face.d);

    // Leaves run from the a-d edge to the b-c edge.
    final span = (b - a).distance;
    if (span < 1) return;
    final count = math.max(2, (span / 1.15).round());

    canvas.save();
    canvas.clipPath(facet.face.path(camera));
    final leaf = Paint()
      ..strokeWidth = 0.55
      ..color = _shade(materials.paper, facet.shade * 0.52).withValues(alpha: 0.45);
    final heavier = Paint()
      ..strokeWidth = 0.7
      ..color = _shade(materials.paper, facet.shade * 0.34).withValues(alpha: 0.55);
    for (var index = 1; index < count; index++) {
      final t = index / count;
      final from = Offset.lerp(a, b, t)!;
      final to = Offset.lerp(d, c, t)!;
      canvas.drawLine(from, to, index % 6 == 0 ? heavier : leaf);
    }
    canvas.restore();
  }

  /// The title down the spine.
  ///
  /// Placed by projecting the spine's own axis rather than by rotating the
  /// canvas a quarter turn, so it stays on the spine whatever the camera is
  /// doing and leans with it.
  void _paintSpineText(Canvas canvas, List<BookFacet> facets) {
    final text = title;
    if (text == null || text.isEmpty) return;
    final g = model.geometry;
    if (model.openAmount > 0.05) return;

    final middle = g.thickness / 2;
    final z = -g.spineBulge;
    final head = camera.project(V3(middle, g.height - g.square * 3, z));
    final tail = camera.project(V3(middle, g.square * 3, z));
    final along = head - tail;
    if (along.distance < 12) return;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: titleStyle.copyWith(
          color: materials.foil,
          fontSize: math.min(g.thickness * 0.42, 11) * camera.scale,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: along.distance);

    canvas.save();
    canvas.translate(tail.dx, tail.dy);
    // Down the spine, reading head to tail, which is how English-language
    // books are blocked.
    canvas.rotate(math.atan2(along.dy, along.dx));
    canvas.translate(
      (along.distance - painter.width) / 2,
      -painter.height / 2,
    );
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  Color _colourOf(Surface surface) {
    switch (surface) {
      case Surface.frontCover:
      case Surface.backCover:
      case Surface.spine:
        return materials.cloth;
      case Surface.pastedown:
        return Color.lerp(materials.paper, materials.cloth, 0.18)!;
      case Surface.pageBlock:
        return materials.paper;
      case Surface.page:
        return Color.lerp(materials.paper, Colors.white, 0.35)!;
      case Surface.boardEdge:
        return materials.board;
      case Surface.headband:
        return materials.headband;
    }
  }

  /// Applies a facet's light level to its own colour.
  static Color _shade(Color base, double shade) {
    if (shade >= 0.5) {
      return Color.lerp(base, Colors.white, (shade - 0.5) * 0.5)!;
    }
    return Color.lerp(base, Colors.black, (0.5 - shade) * 1.35)!;
  }

  @override
  bool shouldRepaint(covariant _Book3DPainter oldDelegate) {
    return oldDelegate.model.openAmount != model.openAmount ||
        oldDelegate.model.geometry != model.geometry ||
        oldDelegate.camera != camera ||
        oldDelegate.materials != materials ||
        oldDelegate.titleStyle != titleStyle ||
        oldDelegate.title != title;
  }
}
