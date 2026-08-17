import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/service/book_art.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';

/// A point or a direction in book space.
///
/// Book space puts the origin on the hinge, at the head of the book:
///
/// * `x` runs from the spine (0) to the fore-edge.
/// * `y` runs from the head (negative) to the tail (positive), matching the
///   canvas, where down is positive.
/// * `z` runs from the back board (0) out through the front board.
///
/// One unit is one page-block height, so every proportion below reads as a
/// fraction of the book's height and stays true at any size.
@immutable
class BookVector {
  const BookVector(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  BookVector operator +(BookVector other) =>
      BookVector(x + other.x, y + other.y, z + other.z);

  BookVector operator -(BookVector other) =>
      BookVector(x - other.x, y - other.y, z - other.z);

  BookVector operator *(double scalar) =>
      BookVector(x * scalar, y * scalar, z * scalar);

  double get length => math.sqrt(x * x + y * y + z * z);

  BookVector get normalized {
    final magnitude = length;
    if (magnitude == 0) return const BookVector(0, 0, 1);
    return BookVector(x / magnitude, y / magnitude, z / magnitude);
  }

  double dot(BookVector other) => x * other.x + y * other.y + z * other.z;

  BookVector cross(BookVector other) => BookVector(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  @override
  String toString() =>
      'BookVector(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)}, '
      '${z.toStringAsFixed(4)})';
}

/// The proportions of one binding.
///
/// A hardback and a softback are not one shape with two paint jobs. A hardback
/// is a case: two stiff boards joined by a strip, with the paper hung inside
/// it, so the boards stand proud of the paper on three edges and the spine is
/// rounded over. A softback is one piece of card wrapped round the block and
/// trimmed with it, so nothing overhangs and the spine is flat with a score
/// line at each joint. Every number here follows from that.
@immutable
class BookBindingProfile {
  const BookBindingProfile({
    required this.trim,
    required this.squares,
    required this.boardThickness,
    required this.spineRound,
    required this.foreEdgeRound,
    required this.minimumDepth,
    required this.maximumDepth,
    required this.cornerRadius,
    required this.grooveWidth,
    required this.headbands,
    required this.endpapers,
    required this.raisedHubs,
    required this.laminate,
    required this.spineCreases,
    required this.printedBack,
    required this.turnIn,
    required this.coverMargin,
  });

  /// Page-block width divided by page-block height.
  ///
  /// A cased book is cut a little narrower than a trade paperback, and its
  /// boards then add the squares back, so the two bindings end up looking like
  /// different objects rather than one object at two widths.
  final double trim;

  /// How far the boards overhang the paper at the head, the tail and the
  /// fore-edge. Bookbinders call this the squares. Zero for a softback,
  /// because a softback is trimmed flush with its block.
  final double squares;

  /// The thickness of one board or one cover card.
  final double boardThickness;

  /// How far the spine bows outward, as a share of the total thickness.
  final double spineRound;

  /// How far the fore-edge is hollowed inward. Rounding a spine pushes the
  /// paper into a matching concave fore-edge; this keeps the two agreeing.
  final double foreEdgeRound;

  /// The range of page-block thickness. The book's own seed picks a value in
  /// the range, so a shelf has thick books and thin books.
  final double minimumDepth;
  final double maximumDepth;

  /// The rounding of the board corners.
  final double cornerRadius;

  /// The distance from the spine to the joint the board swings on. A cased
  /// book has a groove there; a softback creases against its own spine.
  final double grooveWidth;

  /// A cased book has a coloured silk roll at the head and the tail.
  final bool headbands;

  /// A cased book's boards are lined with endpapers, and the paper block is
  /// pasted to them.
  final bool endpapers;

  /// Some cased books carry raised bands across the spine.
  final bool raisedHubs;

  /// A softback's cover is laminated and takes a broad highlight.
  final bool laminate;

  /// A softback is scored twice near the spine so the cover folds cleanly.
  final bool spineCreases;

  /// A softback prints its blurb, its mark and its barcode on the back. A
  /// cased book's back board is plain cloth: the blurb lives on a jacket the
  /// file does not have.
  final bool printedBack;

  /// The cover material folded over the board edge and visible inside it.
  final double turnIn;

  /// How much binding is left showing all the way round a printed cover.
  ///
  /// A cover picture is a sheet pasted onto the board, not the board itself, so
  /// the binding runs round it. A cased book leaves a wide margin, the way a
  /// picture is mounted; a laminated card leaves the trim of its own printing
  /// and little else.
  final double coverMargin;

  static const BookBindingProfile hardback = BookBindingProfile(
    trim: 0.645,
    // The squares: a cased board stands proud of the paper it protects. Widened
    // from 0.017, which read as a board cut flush with its own block.
    squares: 0.023,
    boardThickness: 0.011,
    // A near-flat back, not a full bow.
    //
    // A deeply rounded spine is correct for a sewn book and wrong for this
    // screen. The title is painted onto the bow, so a third of every spine
    // turns away from the reader: the type compresses into the shadow at both
    // joints, a word can fall off the curve entirely, and where two rounded
    // spines meet on a shelf the two bows read as one continuous tube with the
    // books stitched into it. Modern cased books are largely flat-backed
    // anyway. What is left here is a hint of round at the joints, enough for
    // the light to travel across, and a flat centre panel for the title.
    spineRound: 0.08,
    foreEdgeRound: 0.07,
    minimumDepth: 0.085,
    maximumDepth: 0.185,
    cornerRadius: 0.012,
    grooveWidth: 0.017,
    headbands: true,
    endpapers: true,
    raisedHubs: true,
    laminate: false,
    spineCreases: false,
    printedBack: false,
    turnIn: 0.030,
    coverMargin: 0.042,
  );

  static const BookBindingProfile softback = BookBindingProfile(
    trim: 0.680,
    squares: 0,
    boardThickness: 0.0035,
    spineRound: 0.06,
    foreEdgeRound: 0.05,
    minimumDepth: 0.055,
    maximumDepth: 0.135,
    cornerRadius: 0.006,
    grooveWidth: 0,
    headbands: false,
    endpapers: false,
    raisedHubs: false,
    laminate: true,
    spineCreases: true,
    printedBack: true,
    turnIn: 0,
    coverMargin: 0.014,
  );

  static BookBindingProfile of(BookBinding binding) => switch (binding) {
        BookBinding.hardback => hardback,
        BookBinding.softback => softback,
      };
}

/// Every measurement of one book, in book units.
@immutable
class BookMetrics {
  const BookMetrics({
    required this.profile,
    required this.blockWidth,
    required this.blockHeight,
    required this.blockDepth,
  });

  factory BookMetrics.from(BookBindingProfile profile, int seed) {
    // The same book is always the same thickness, and two neighbours are not.
    final spread = profile.maximumDepth - profile.minimumDepth;
    final depth = profile.minimumDepth + spread * ((seed >> 7) % 64) / 63;
    return BookMetrics(
      profile: profile,
      blockWidth: profile.trim,
      blockHeight: 1,
      blockDepth: depth,
    );
  }

  final BookBindingProfile profile;

  /// The paper block: what a printer trims.
  final double blockWidth;
  final double blockHeight;
  final double blockDepth;

  /// The board: the paper plus the squares.
  double get boardWidth => blockWidth + profile.squares;
  double get boardHeight => blockHeight + profile.squares * 2;

  /// The complete object, front board face to back board face.
  double get totalDepth => blockDepth + profile.boardThickness * 2;

  /// z of the block's back face and front face.
  double get blockBackZ => profile.boardThickness;
  double get blockFrontZ => profile.boardThickness + blockDepth;

  /// z of the front board's inner and outer faces.
  double get frontBoardInnerZ => blockFrontZ;
  double get frontBoardOuterZ => totalDepth;

  /// y of the head and the tail of the boards.
  double get boardTop => -boardHeight / 2;
  double get boardBottom => boardHeight / 2;

  /// y of the head and the tail of the paper.
  double get blockTop => -blockHeight / 2;
  double get blockBottom => blockHeight / 2;

  /// How far the spine bows out past the boards.
  double get spineBulge => totalDepth * profile.spineRound;

  /// How far the fore-edge is hollowed in.
  double get foreEdgeHollow => blockDepth * profile.foreEdgeRound;
}

/// The colours the model paints with.
@immutable
class BookModelPalette {
  const BookModelPalette({
    required this.cloth,
    required this.clothDeep,
    required this.clothLight,
    required this.ink,
    required this.foil,
    required this.paper,
    required this.paperInk,
    required this.pageEdge,
    required this.endpaper,
    required this.headband,
    required this.boardCore,
    required this.shadow,
  });

  /// Resolves the colours for one book.
  ///
  /// A book with artwork takes its cloth from the artwork, so the spine, the
  /// board edges and the back board all agree with the front. A book without
  /// artwork takes the same bookcloth its spine wears on the shelf, from the
  /// same table and the same hash, so one book is one colour everywhere in
  /// the application.
  ///
  /// The paper is warm paper in both themes. The book is an object in the
  /// world, not a surface the interface sits on, and paper does not turn black
  /// at night.
  /// The last few palettes resolved, by the four things that decide one.
  ///
  /// Resolving takes a dozen colour blends and four luminances, and the shelf
  /// asks for one per book on every frame of a scroll. The answer only changes
  /// when the theme, the binding, the seed or the artwork does.
  static final Map<Object, BookModelPalette> _resolved = {};

  @visibleForTesting
  static void debugClear() => _resolved.clear();

  @visibleForTesting
  static int get debugCount => _resolved.length;

  @visibleForTesting
  static int get debugLimit => _resolvedLimit;

  /// One per book on the screen, several screens over. Sixty-four is three
  /// shelves' worth, which a library passes on its first day.
  static const int _resolvedLimit = 320;

  factory BookModelPalette.resolve({
    required ColorScheme scheme,
    required BookBinding binding,
    required int seed,
    BookArt? art,
  }) {
    final key = Object.hash(
      scheme.brightness,
      binding,
      seed,
      art == null ? 0 : identityHashCode(art),
    );
    final cached = _resolved.remove(key);
    if (cached != null) {
      // Back to the young end: least-recently-used, on the insertion order a
      // Dart map already keeps.
      _resolved[key] = cached;
      return cached;
    }
    final palette = BookModelPalette._resolve(
      scheme: scheme,
      binding: binding,
      seed: seed,
      art: art,
    );
    // The oldest goes, not all of them. Emptying the whole table on overflow
    // meant that on any shelf past the limit, every book in view missed at
    // once and re-resolved a dozen colour blends and four luminances apiece —
    // over and over, for as long as the reader kept scrolling.
    while (_resolved.length >= _resolvedLimit) {
      _resolved.remove(_resolved.keys.first);
    }
    _resolved[key] = palette;
    return palette;
  }

  factory BookModelPalette._resolve({
    required ColorScheme scheme,
    required BookBinding binding,
    required int seed,
    BookArt? art,
  }) {
    final cloths = BookSpine.backgroundsFor(scheme.brightness);
    final cloth = art?.coverAverage ?? cloths[seed % cloths.length];
    final ink = BookArtCache.inkOver(cloth);
    final foil = PaperfoldTokens.cover.foil;
    const paper = Color(0xFFF6F0E2);
    const paperInk = Color(0xFF3A2E28);

    return BookModelPalette(
      cloth: cloth,
      clothDeep: Color.lerp(cloth, Colors.black, 0.22)!,
      clothLight: Color.lerp(cloth, Colors.white, 0.12)!,
      ink: ink,
      // Foil is only worth having when it can be seen. Over a pale cloth it
      // falls back to the tested ink.
      foil: BookArtCache.contrast(foil, cloth) >= 2.6 ? foil : ink,
      paper: paper,
      paperInk: paperInk,
      pageEdge: const Color(0xFFE0D6C0),
      endpaper: binding == BookBinding.hardback
          ? Color.lerp(cloth, const Color(0xFFEDE1CB), 0.66)!
          : const Color(0xFFEFEBE2),
      headband: Color.lerp(
        PaperfoldTokens.cover.ground,
        PaperfoldTokens.cover.foil,
        0.35,
      )!,
      boardCore: const Color(0xFF6B6155),
      shadow: scheme.shadow,
    );
  }

  /// The cover field, when there is no artwork to put there.
  final Color cloth;
  final Color clothDeep;
  final Color clothLight;

  /// Printed matter on the cloth. Tested to 4.5:1 over [cloth].
  final Color ink;

  /// Stamped detail. Fine rules and devices only, never a fill.
  final Color foil;

  /// The paper of the block and of the pages.
  final Color paper;
  final Color paperInk;

  /// The colour of the paper seen edge on, which is darker than the paper.
  final Color pageEdge;

  /// The lining inside a cased board.
  final Color endpaper;

  /// The silk roll at the head and the tail of a cased spine.
  final Color headband;

  /// The grey board under the cloth, seen on a cut edge.
  final Color boardCore;

  final Color shadow;

  @override
  bool operator ==(Object other) =>
      other is BookModelPalette &&
      other.cloth == cloth &&
      other.clothDeep == clothDeep &&
      other.clothLight == clothLight &&
      other.ink == ink &&
      other.foil == foil &&
      other.paper == paper &&
      other.paperInk == paperInk &&
      other.pageEdge == pageEdge &&
      other.endpaper == endpaper &&
      other.headband == headband &&
      other.boardCore == boardCore &&
      other.shadow == shadow;

  @override
  int get hashCode => Object.hash(
        cloth,
        clothDeep,
        clothLight,
        ink,
        foil,
        paper,
        paperInk,
        pageEdge,
        endpaper,
        headband,
        boardCore,
        shadow,
      );
}

/// One flat quadrilateral of the model.
///
/// A face carries its own placement in book space and its own painter. The
/// renderer sorts every face by depth, hides the ones turned away, lights them
/// from one direction, and draws them back to front. That is what makes the
/// object read as one solid book rather than a stack of pictures: the spine
/// really is behind the boards, and the boards really do hide the paper.
class BookFace {
  BookFace({
    required this.origin,
    required this.u,
    required this.v,
    required this.width,
    required this.height,
    required this.paint,
    this.bleed,
    this.depthAnchor,
    this.normalAtStart,
    this.normalAtEnd,
    this.doubleSided = false,
    this.lit = true,
    this.depthBias = 0,
    this.seam = 0,
    this.debugName = '',
  });

  /// The face's top-leading corner in book space.
  final BookVector origin;

  /// Unit directions of the face's own local x and y axes.
  final BookVector u;
  final BookVector v;

  /// The face's size in book units.
  final double width;
  final double height;

  /// Draws the face's content in its own coordinates, where (0,0) is [origin]
  /// and the rectangle is [width] by [height] book units. [shade] is the
  /// lighting term, 1 for fully lit and 0 for fully turned away.
  final void Function(Canvas canvas, Size size, double shade) paint;

  /// A flat colour laid down just outside the face before its content.
  ///
  /// Two faces that meet along an edge are rasterised independently, and
  /// antialiasing leaves a hairline of whatever is behind them between the
  /// two. On this object what is behind is the white of the paper, so the
  /// hairline reads as a crack in the board. Each face paints a little past
  /// its own edge in its own colour, and the crack has nothing to show.
  final Color? bleed;

  /// The point the renderer measures this face's depth at.
  ///
  /// A stack of nearly flat sheets cannot be sorted by any point on the sheets
  /// themselves. Turn the book far enough and the distance across a sheet
  /// counts for more than the paper-thin gap between two of them, so a page
  /// wide enough to reach the fore-edge sorts behind a leaf that only reaches
  /// halfway. Every sheet in the stack is anchored at the spine instead, where
  /// the only thing that separates them is the thing that should: which one is
  /// on top.
  final BookVector? depthAnchor;

  /// The normals the real surface has at this face's two ends along [u].
  ///
  /// A rounded spine is drawn as a run of flats, and a run of flats is lit flat
  /// by flat: every joint between two of them becomes a visible line, and the
  /// bow reads as a folded strip rather than as a curve. These are the normals
  /// the curve itself has where this facet begins and ends, so the renderer can
  /// run the light *across* the facet instead of holding it constant over it.
  /// Both null on a face that is genuinely flat, which is most of them.
  final BookVector? normalAtStart;
  final BookVector? normalAtEnd;

  /// Paper is visible from both sides. Boards and the page block are not.
  final bool doubleSided;

  /// Whether the renderer's light touches this face. A shadow is already the
  /// absence of light; shading it again would only make it a grey rectangle.
  final bool lit;

  /// Breaks depth ties. A cast shadow uses a small positive bias so it lands
  /// on the page it belongs to rather than fighting it.
  final double depthBias;

  /// How far past both of its own ends along [u] this face's painter draws, in
  /// book units.
  ///
  /// One facet of a curve deliberately paints a sliver of its neighbours, so
  /// that the hairline antialiasing leaves between two clipped quads has real
  /// content behind it rather than the paper of the block. The light has to
  /// reach the same sliver: washed only to its own ends, every facet left its
  /// neighbour's overlap unlit, and a spine cut into twenty facets came out
  /// with twenty pinstripes down it — which is exactly what the seam was added
  /// to cure at the other end.
  final double seam;

  final String debugName;

  BookVector get normal => u.cross(v).normalized;

  BookVector get centre => origin + u * (width / 2) + v * (height / 2);

  /// The face placed by [transform], keeping its own content painter.
  BookFace transformedBy(BookTransform transform) => BookFace(
        origin: transform.point(origin),
        u: transform.direction(u),
        v: transform.direction(v),
        width: width,
        height: height,
        paint: paint,
        bleed: bleed,
        depthAnchor: depthAnchor == null ? null : transform.point(depthAnchor!),
        normalAtStart:
            normalAtStart == null ? null : transform.direction(normalAtStart!),
        normalAtEnd:
            normalAtEnd == null ? null : transform.direction(normalAtEnd!),
        doubleSided: doubleSided,
        lit: lit,
        depthBias: depthBias,
        seam: seam,
        debugName: debugName,
      );

  /// The 4x4 that maps this face's local coordinates into book space.
  Matrix4 get modelMatrix {
    final n = normal;
    return Matrix4(
      u.x, u.y, u.z, 0, //
      v.x, v.y, v.z, 0, //
      n.x, n.y, n.z, 0, //
      origin.x, origin.y, origin.z, 1,
    );
  }
}

/// A face the camera can see, with where it sits and how hard the light hits.
@immutable
class BookDrawable {
  const BookDrawable({
    required this.face,
    required this.depth,
    required this.shade,
    double? shadeStart,
    double? shadeEnd,
  })  : shadeStart = shadeStart ?? shade,
        shadeEnd = shadeEnd ?? shade;

  final BookFace face;

  /// Distance toward the camera. Larger is nearer.
  final double depth;

  /// 0 is fully turned away from the light, 1 is square on to it.
  final double shade;

  /// The light at the face's two ends along its own `u`.
  ///
  /// They are both [shade] on a flat face. On one facet of a curve they are the
  /// light the curve really takes where the facet begins and ends, and the
  /// renderer runs the one into the other so the joints between the facets stop
  /// showing.
  final double shadeStart;
  final double shadeEnd;

  /// Whether the light changes across this face.
  bool get isShaded => shadeStart != shadeEnd;
}

/// A rotation about a vertical axis, which is the only rigid motion a book
/// makes: a board swinging on its joint, or a leaf lifting off the block.
@immutable
class BookTransform {
  const BookTransform.identity()
      : axisX = 0,
        axisZ = 0,
        angle = 0;

  /// A rotation of [angle] radians about the vertical line through
  /// ([axisX], [axisZ]). A positive angle lifts the fore-edge toward the
  /// reader and carries it over the spine.
  const BookTransform.hinge({
    required this.axisX,
    required this.axisZ,
    required this.angle,
  });

  final double axisX;
  final double axisZ;
  final double angle;

  bool get isIdentity => angle == 0;

  BookVector point(BookVector p) {
    if (isIdentity) return p;
    final dx = p.x - axisX;
    final dz = p.z - axisZ;
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return BookVector(
      axisX + dx * cos - dz * sin,
      p.y,
      axisZ + dx * sin + dz * cos,
    );
  }

  BookVector direction(BookVector d) {
    if (isIdentity) return d;
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return BookVector(
      d.x * cos - d.z * sin,
      d.y,
      d.x * sin + d.z * cos,
    );
  }
}

/// Where the camera stands.
///
/// The book turns, not the camera. [yaw] swings the fore-edge away so the
/// spine comes into view, [pitch] looks a little down onto the head, and
/// [focalLength] decides how strong the perspective is. A short focal length
/// makes a small book look like a wide-angle photograph of a large one.
@immutable
class BookCamera {
  const BookCamera({
    this.yaw = 0.38,
    this.pitch = -0.26,
    this.focalLength = 5.0,
  });

  /// A book turned well round toward its spine and looked down on from above.
  ///
  /// The default is a hero view of a cover. This is a working view, and one of
  /// the two the geometry has to be watertight at.
  ///
  /// It used to be called `shelf`, and it is not the shelf's camera: the shelf
  /// stands its books at `ShelfStage.camera`, yaw 1.30 on a much longer lens.
  /// This is the mid-turn angle, worth keeping because a solid that is
  /// watertight at both is watertight between them.
  static const BookCamera threeQuarter = BookCamera(yaw: 0.92, pitch: -0.40);

  final double yaw;
  final double pitch;
  final double focalLength;

  BookCamera copyWith({double? yaw, double? pitch, double? focalLength}) =>
      BookCamera(
        yaw: yaw ?? this.yaw,
        pitch: pitch ?? this.pitch,
        focalLength: focalLength ?? this.focalLength,
      );

  /// The rotation part only. Normals and depths use this; the perspective
  /// divide would make both meaningless.
  Matrix4 get rotation =>
      Matrix4.rotationX(pitch)..multiply(Matrix4.rotationY(yaw));

  /// The perspective part only.
  Matrix4 get projection =>
      Matrix4.identity()..setEntry(3, 2, -1 / focalLength);
}

/// The lighting direction, in camera space: high, leading, and in front.
const BookVector kBookLight = BookVector(-0.42, -0.60, 0.68);

/// Applies a 4x4 to a point and returns the divided result plus its w.
({double x, double y, double z, double w}) applyMatrix(
  Matrix4 matrix,
  BookVector point,
) {
  final s = matrix.storage;
  final x = s[0] * point.x + s[4] * point.y + s[8] * point.z + s[12];
  final y = s[1] * point.x + s[5] * point.y + s[9] * point.z + s[13];
  final z = s[2] * point.x + s[6] * point.y + s[10] * point.z + s[14];
  final w = s[3] * point.x + s[7] * point.y + s[11] * point.z + s[15];
  return (x: x, y: y, z: z, w: w);
}
