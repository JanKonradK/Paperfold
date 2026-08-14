import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// A point in the book's own space, in millimetres.
///
/// Millimetres rather than logical pixels because every proportion in a bound
/// book is a real measurement a binder would recognise - a 2 mm board, a 3 mm
/// square, an 8 mm round - and writing them as pixels means re-deriving them by
/// eye every time a book changes size. [BookCamera] does the one conversion.
///
/// x runs across the thickness of the book, from the back board at 0 to the
/// front board at [BookGeometry.thickness].
/// y runs up the height of the book, from tail at 0 to head at
/// [BookGeometry.height].
/// z runs from the spine at 0 back to the fore-edge at [BookGeometry.depth].
class V3 {
  const V3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  V3 operator +(V3 other) => V3(x + other.x, y + other.y, z + other.z);
  V3 operator -(V3 other) => V3(x - other.x, y - other.y, z - other.z);
  V3 operator *(double scale) => V3(x * scale, y * scale, z * scale);

  /// Rotates about a vertical axis - the book's height - passing through
  /// (`axisX`, `axisZ`).
  ///
  /// This is the only rotation the book itself needs: a cover opens on a
  /// vertical hinge at the joint, and a leaf turns on the same line.
  V3 rotateAboutVertical(double axisX, double axisZ, double radians) {
    final dx = x - axisX;
    final dz = z - axisZ;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return V3(
      axisX + dx * cos - dz * sin,
      y,
      axisZ + dx * sin + dz * cos,
    );
  }
}

/// The dimensions of one hardback, in millimetres.
///
/// Defaults describe an ordinary trade hardback. The three the caller usually
/// varies are [height], [depth] and [thickness]; everything else is binder's
/// craft that stays put whatever size the book is, which is exactly why a
/// bigger book does not get a proportionally bigger groove.
class BookGeometry {
  const BookGeometry({
    this.height = 216,
    this.depth = 138,
    this.thickness = 28,
    this.boardThickness = 2.6,
    this.square = 3.2,
    this.groove = 5.0,
    this.round = 0.34,
  })  : assert(height > 0),
        assert(depth > 0),
        assert(thickness > 0);

  /// Head to tail.
  final double height;

  /// Spine to fore-edge. This is the width of the cover you see when the book
  /// is face out, and the depth of the top board you see when it is shelved.
  final double depth;

  /// Across the boards, including both boards and the page block between them.
  final double thickness;

  /// One cover board. Greyboard in a trade hardback is about 2.5 mm.
  final double boardThickness;

  /// How far the boards overhang the page block at head, tail and fore-edge.
  ///
  /// This is the single detail that most separates a drawn book from a
  /// photographed one. The boards of a hardback are cut larger than the
  /// leaves, and the lip that leaves all round the block is what your eye
  /// reads as "hardback" before it reads anything else.
  final double square;

  /// The channel between the spine and each board, where the covering material
  /// is pressed into the joint. It is what the boards hinge on.
  final double groove;

  /// How far the spine is rounded, as a share of the thickness. Zero is a
  /// flat-back binding; a third is a well-rounded trade hardback.
  final double round;

  /// The page block sits inside the boards, inset by the square on the three
  /// free edges and by the board thickness on each face.
  double get blockThickness =>
      math.max(0.5, thickness - boardThickness * 2);
  double get blockHeight => math.max(1, height - square * 2);
  double get blockDepth => math.max(1, depth - square - groove);

  /// How far the rounded spine bulges beyond the flat back.
  double get spineBulge => thickness * round * 0.5;

  BookGeometry copyWith({
    double? height,
    double? depth,
    double? thickness,
  }) {
    return BookGeometry(
      height: height ?? this.height,
      depth: depth ?? this.depth,
      thickness: thickness ?? this.thickness,
      boardThickness: boardThickness,
      square: square,
      groove: groove,
      round: round,
    );
  }
}

/// An orthographic camera looking at the book.
///
/// Orthographic rather than perspective, and that is a load-bearing choice: an
/// orthographic projection maps a rectangle in space to a **parallelogram** on
/// screen, and a parallelogram is an affine transform. That means cover art can
/// be drawn into a face exactly, with one `canvas.transform`, instead of being
/// sliced into strips to fake a perspective quad. It also means a book looks
/// the same wherever it sits on screen, so a row of them does not appear to
/// rotate as it scrolls.
class BookCamera {
  const BookCamera({
    this.yaw = 0.62,
    this.pitch = 0.42,
    this.scale = 1,
  });

  /// Turn about the vertical. Zero looks straight at the spine.
  final double yaw;

  /// Tilt from level. Zero is eye-level with the shelf; larger looks down.
  final double pitch;

  /// Millimetres to logical pixels.
  final double scale;

  BookCamera copyWith({double? yaw, double? pitch, double? scale}) =>
      BookCamera(
        yaw: yaw ?? this.yaw,
        pitch: pitch ?? this.pitch,
        scale: scale ?? this.scale,
      );

  Offset project(V3 point) {
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);

    // Yaw about the vertical, then pitch about the horizontal.
    //
    // The sign on the pitch term is the difference between looking down at the
    // book and looking up at it. Down means a point further into the scene
    // projects HIGHER, which is what reveals the head of the page block and
    // hides its tail. With it the other way the book is seen from underneath,
    // and the tail shows as a wedge below the boards that looks like a
    // painting bug rather than a camera one.
    final cameraX = point.x * cosYaw + point.z * sinYaw;
    final cameraZ = -point.x * sinYaw + point.z * cosYaw;
    final cameraY = point.y * cosPitch + cameraZ * sinPitch;

    // Screen y grows downward.
    return Offset(cameraX * scale, -cameraY * scale);
  }

  /// How far from the camera a point is. Faces are drawn in order of this, far
  /// first, which is all the occlusion a convex-ish object like a book needs.
  double depthOf(V3 point) {
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    final cameraZ = -point.x * sinYaw + point.z * cosYaw;
    return cameraZ * cosPitch + point.y * sinPitch;
  }
}

/// One flat face of the book, as four points in the book's own space.
///
/// Kept as a quad rather than a path so the painter can ask whether it faces
/// the camera and can map an image onto it affinely.
class Face {
  const Face(this.a, this.b, this.c, this.d);

  /// Corners, counter-clockwise seen from outside the book.
  final V3 a;
  final V3 b;
  final V3 c;
  final V3 d;

  List<V3> get corners => [a, b, c, d];

  /// The mean distance from the camera, for sorting.
  double depth(BookCamera camera) =>
      corners.map(camera.depthOf).reduce((x, y) => x + y) / 4;

  Path path(BookCamera camera) {
    final points = corners.map(camera.project).toList();
    return Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();
  }

  /// Whether the outside of this face is turned toward the camera.
  ///
  /// The projected corners wind one way when a face is seen from outside and
  /// the other way when it is seen from behind, so the sign of the polygon's
  /// area answers it. Back faces are simply not drawn, which removes most of
  /// what depth sorting would otherwise have to resolve.
  bool facesCamera(BookCamera camera) => signedArea(camera) > 0;

  double signedArea(BookCamera camera) {
    final points = corners.map(camera.project).toList();
    var total = 0.0;
    for (var index = 0; index < points.length; index++) {
      final current = points[index];
      final next = points[(index + 1) % points.length];
      total += current.dx * next.dy - next.dx * current.dy;
    }
    return total / 2;
  }

  /// The affine transform that maps the unit square onto this face, so an
  /// image drawn into `Rect.fromLTWH(0, 0, 1, 1)` lands on it exactly.
  ///
  /// Only correct because the projection is orthographic. Under perspective
  /// this quad would not be a parallelogram and no affine transform could do
  /// it.
  Float64List unitSquareTransform(BookCamera camera) {
    final origin = camera.project(a);
    final alongU = camera.project(b) - origin;
    final alongV = camera.project(d) - origin;
    return Float64List.fromList(<double>[
      alongU.dx, alongU.dy, 0, 0, //
      alongV.dx, alongV.dy, 0, 0, //
      0, 0, 1, 0, //
      origin.dx, origin.dy, 0, 1, //
    ]);
  }
}
