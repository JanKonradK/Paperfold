import 'dart:math' as math;

import 'package:paperfold/widgets/book3d/book_geometry.dart';

/// What a face is made of, so the painter knows how to fill it without
/// knowing what part of the book it belongs to.
enum Surface {
  /// Covering material on the outside of a board.
  frontCover,
  backCover,

  /// Covering material on the spine.
  spine,

  /// The inside of a board: the pastedown.
  pastedown,

  /// The cut edges of the leaves.
  pageBlock,

  /// The first leaf, seen face on when the book is open.
  page,

  /// The board seen edge on - greyboard, darker than its covering.
  boardEdge,

  /// The silk at head and tail of the spine.
  headband,
}

/// One face of the book, ready to draw: where it is, what it is made of, and
/// how much light reaches it.
class BookFacet {
  const BookFacet({
    required this.face,
    required this.surface,
    required this.shade,
    required this.outwardness,
    required this.unitNormal,
    this.imageFraction,
  });

  final Face face;
  final Surface surface;

  /// How far this face sits along its own outward normal.
  ///
  /// A book is full of parallel faces stacked on one another - the front
  /// board, its pastedown, the first page, the top of the block - and sorting
  /// those by average depth gets them wrong, because a face inset from its
  /// neighbour has a smaller average depth even while sitting behind it. That
  /// is not a rounding error: it drew the first page over the cover, so every
  /// closed book came out cream. Among parallel faces this is the tie-breaker
  /// that actually decides which is on top.
  final double outwardness;

  /// How lit this facet is, 0 dark to 1 fully lit. Set from the facet's angle
  /// to the light rather than chosen by eye, so a rounded spine shades
  /// smoothly across its facets instead of in steps someone picked.
  final double shade;

  /// This face's outward normal, normalised.
  final V3 unitNormal;

  /// Which slice of the cover artwork belongs on this facet, as a fraction of
  /// the artwork's width. Null where the facet carries no artwork.
  final (double, double)? imageFraction;
}

/// A hardback, resolved into flat faces at a given open angle.
///
/// Everything the painter needs and nothing about how it looks: this decides
/// where the boards, the spine and the block are in space, and the painter
/// decides what colour they come out.
class BookModel {
  BookModel({
    required this.geometry,
    this.openAmount = 0,
  });

  final BookGeometry geometry;

  /// 0 closed, 1 open. The front board swings on the joint through this range,
  /// and the leaves nearest it follow at a fraction of the angle.
  final double openAmount;

  /// How far the front board swings when fully open.
  ///
  /// Past a right angle, so an open book reads as open rather than as a book
  /// with its cover held up. A real one falls further than this, but the cover
  /// would then be behind the block and there would be nothing to look at.
  static const double fullOpen = math.pi * 0.86;

  /// The light: from above, in front, and off to the side the cover faces.
  ///
  /// The x term has to be positive. Negative, it comes from behind the front
  /// board, so the cover and the first page - the two faces the reader is
  /// actually looking at - are the darkest things on the book, and an opening
  /// book reveals a grey slab where its pages should be.
  static const V3 _light = V3(0.50, 0.70, -0.51);

  double get _coverAngle => openAmount.clamp(0.0, 1.0) * fullOpen;

  /// The hinge: a vertical line in the groove, at the front board's face.
  double get _hingeX => geometry.thickness;
  double get _hingeZ => geometry.groove;

  /// Every facet of the book, in no particular order. The painter sorts them.
  List<BookFacet> facets() {
    return [
      ..._backBoard(),
      ..._spine(),
      ..._pageBlock(),
      ..._leaves(),
      ..._frontBoard(),
    ];
  }

  /// The outward normal of a face.
  ///
  /// Faces are wound counter-clockwise seen from outside, so this points out
  /// of the book. Getting a winding backwards is not a subtle bug - the facet
  /// is culled as a back face and simply vanishes - but it looks like a
  /// painting problem rather than a geometry one, so `book_3d_test.dart`
  /// checks every facet's normal against the book's centre.
  static V3 normalOf(Face face) {
    final u = face.b - face.a;
    final v = face.d - face.a;
    return V3(
      u.y * v.z - u.z * v.y,
      u.z * v.x - u.x * v.z,
      u.x * v.y - u.y * v.x,
    );
  }

  double _shadeOf(Face face) {
    final normal = normalOf(face);
    final nx = normal.x;
    final ny = normal.y;
    final nz = normal.z;
    final length = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (length == 0) return 0.5;

    final lightLength = math.sqrt(
      _light.x * _light.x + _light.y * _light.y + _light.z * _light.z,
    );
    final dot = (nx * _light.x + ny * _light.y + nz * _light.z) /
        (length * lightLength);
    // Half-Lambert: a surface turned away from the light still catches the
    // room, and a book lit to pure black on one side looks like a hole.
    return (0.5 + 0.5 * dot).clamp(0.12, 1.0);
  }

  BookFacet _facet(
    Face face,
    Surface surface, {
    (double, double)? imageFraction,
  }) {
    final normal = normalOf(face);
    final length = math.sqrt(
      normal.x * normal.x + normal.y * normal.y + normal.z * normal.z,
    );
    final unit = length == 0
        ? const V3(0, 0, 1)
        : V3(normal.x / length, normal.y / length, normal.z / length);
    final centre = face.corners.reduce((a, b) => a + b) * 0.25;
    return BookFacet(
      face: face,
      surface: surface,
      shade: _shadeOf(face),
      unitNormal: unit,
      outwardness: centre.x * unit.x + centre.y * unit.y + centre.z * unit.z,
      imageFraction: imageFraction,
    );
  }

  List<BookFacet> _backBoard() {
    final g = geometry;
    const x = 0.0;
    final board = Face(
      V3(x, 0, g.groove),
      V3(x, 0, g.depth),
      V3(x, g.height, g.depth),
      V3(x, g.height, g.groove),
    );
    // The fore-edge of the board, which has real thickness and is the only
    // place you see the greyboard itself.
    final edge = Face(
      V3(x, 0, g.depth),
      V3(x + g.boardThickness, 0, g.depth),
      V3(x + g.boardThickness, g.height, g.depth),
      V3(x, g.height, g.depth),
    );
    return [
      _facet(board, Surface.backCover),
      _facet(edge, Surface.boardEdge),
    ];
  }

  /// The spine, rounded.
  ///
  /// A rounded back is not decoration - it is what a sewn book does when it is
  /// backed, and a flat rectangle where the spine should be is the single
  /// thing that makes a drawn book look printed. It is faceted into strips
  /// across the thickness, each one shaded by its own angle, so the light
  /// travels around it.
  List<BookFacet> _spine() {
    final g = geometry;
    const strips = 9;
    final facets = <BookFacet>[];

    double bulgeAt(double t) {
      // A shallow arc across the thickness: no bulge at the joints, most in
      // the middle.
      return -g.spineBulge * math.sin(t * math.pi);
    }

    for (var index = 0; index < strips; index++) {
      final t0 = index / strips;
      final t1 = (index + 1) / strips;
      final x0 = g.thickness * t0;
      final x1 = g.thickness * t1;
      final z0 = bulgeAt(t0);
      final z1 = bulgeAt(t1);
      facets.add(
        _facet(
          Face(
            V3(x0, 0, z0),
            V3(x0, g.height, z0),
            V3(x1, g.height, z1),
            V3(x1, 0, z1),
          ),
          Surface.spine,
          imageFraction: (t0, t1),
        ),
      );
    }

    // Headbands: the strip of silk glued at head and tail of the spine, which
    // shows as a small band of colour above and below the block.
    for (final y in [0.0, g.height - g.square]) {
      facets.add(
        _facet(
          Face(
            V3(g.boardThickness, y, bulgeAt(0.2) + 0.4),
            V3(g.boardThickness, y + g.square, bulgeAt(0.2) + 0.4),
            V3(g.thickness - g.boardThickness, y + g.square, bulgeAt(0.8) + 0.4),
            V3(g.thickness - g.boardThickness, y, bulgeAt(0.8) + 0.4),
          ),
          Surface.headband,
        ),
      );
    }
    return facets;
  }

  /// The cut edges of the leaves: head, fore-edge and tail.
  ///
  /// Inset from the boards by the square on all three, which is the overhang
  /// that makes a hardback a hardback.
  List<BookFacet> _pageBlock() {
    final g = geometry;
    final x0 = g.boardThickness;
    final x1 = g.thickness - g.boardThickness;
    // The block starts where the boards start. Any nearer and the leaves show
    // through the groove as a bright line down the joint, which no bound book
    // does - the covering material closes that channel.
    final zNear = g.groove;
    final zFar = g.depth - g.square;
    final yLow = g.square;
    final yHigh = g.height - g.square;

    // The fore-edge of a rounded book is hollow - the round at the spine
    // pushes the leaves into a matching curve at the other end.
    final foreFacets = <BookFacet>[];
    const slices = 7;
    double foreAt(double t) => zFar - g.spineBulge * 0.6 * math.sin(t * math.pi);
    for (var index = 0; index < slices; index++) {
      final t0 = index / slices;
      final t1 = (index + 1) / slices;
      foreFacets.add(
        _facet(
          Face(
            V3(x0 + (x1 - x0) * t0, yLow, foreAt(t0)),
            V3(x0 + (x1 - x0) * t1, yLow, foreAt(t1)),
            V3(x0 + (x1 - x0) * t1, yHigh, foreAt(t1)),
            V3(x0 + (x1 - x0) * t0, yHigh, foreAt(t0)),
          ),
          Surface.pageBlock,
        ),
      );
    }

    return [
      // The top of the block: the recto of the first leaf.
      //
      // Not a cut edge like the other three - this is the page itself, and it
      // is what the reader is looking at once the cover swings away. Without
      // it an opening book is a cover lifting off nothing, which is exactly
      // how the first build looked.
      _facet(
        Face(
          V3(x1, yLow, zNear),
          V3(x1, yHigh, zNear),
          V3(x1, yHigh, zFar),
          V3(x1, yLow, zFar),
        ),
        Surface.page,
      ),
      // Head, seen when the book is shelved and you look down on it.
      _facet(
        Face(
          V3(x0, yHigh, zNear),
          V3(x0, yHigh, zFar),
          V3(x1, yHigh, zFar),
          V3(x1, yHigh, zNear),
        ),
        Surface.pageBlock,
      ),
      // Tail.
      _facet(
        Face(
          V3(x0, yLow, zNear),
          V3(x1, yLow, zNear),
          V3(x1, yLow, zFar),
          V3(x0, yLow, zFar),
        ),
        Surface.pageBlock,
      ),
      ...foreFacets,
    ];
  }

  /// The leaves that lift with the cover.
  ///
  /// Only a handful, at fractions of the cover's angle, which is what gives
  /// the fan an opening book has. They are what stops the cover from looking
  /// like a lid on a box.
  List<BookFacet> _leaves() {
    if (_coverAngle <= 0.01) return const [];
    final g = geometry;
    const count = 5;
    final facets = <BookFacet>[];
    final topOfBlock = g.thickness - g.boardThickness;

    for (var index = 0; index < count; index++) {
      // The leaf nearest the cover follows it most closely.
      final follow = math.pow((count - index) / count, 1.7).toDouble();
      final angle = _coverAngle * follow * 0.92;
      final x = topOfBlock - index * 0.5;
      final leaf = Face(
        V3(x, g.square, g.groove),
        V3(x, g.square, g.depth - g.square),
        V3(x, g.height - g.square, g.depth - g.square),
        V3(x, g.height - g.square, g.groove),
      );
      facets.add(
        _facet(
          Face(
            leaf.a.rotateAboutVertical(_hingeX, _hingeZ, angle),
            leaf.b.rotateAboutVertical(_hingeX, _hingeZ, angle),
            leaf.c.rotateAboutVertical(_hingeX, _hingeZ, angle),
            leaf.d.rotateAboutVertical(_hingeX, _hingeZ, angle),
          ),
          Surface.page,
        ),
      );
    }
    return facets;
  }

  List<BookFacet> _frontBoard() {
    final g = geometry;
    final x = g.thickness;
    final angle = _coverAngle;

    V3 swing(V3 point) =>
        point.rotateAboutVertical(_hingeX, _hingeZ, angle);

    final outside = Face(
      swing(V3(x, 0, g.groove)),
      swing(V3(x, g.height, g.groove)),
      swing(V3(x, g.height, g.depth)),
      swing(V3(x, 0, g.depth)),
    );
    final inside = Face(
      swing(V3(x - g.boardThickness, 0, g.depth)),
      swing(V3(x - g.boardThickness, g.height, g.depth)),
      swing(V3(x - g.boardThickness, g.height, g.groove)),
      swing(V3(x - g.boardThickness, 0, g.groove)),
    );
    final edge = Face(
      swing(V3(x - g.boardThickness, 0, g.depth)),
      swing(V3(x, 0, g.depth)),
      swing(V3(x, g.height, g.depth)),
      swing(V3(x - g.boardThickness, g.height, g.depth)),
    );

    return [
      _facet(outside, Surface.frontCover),
      _facet(inside, Surface.pastedown),
      _facet(edge, Surface.boardEdge),
    ];
  }
}
