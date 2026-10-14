import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/service/book_art.dart';
import 'package:paperfold/widgets/book_model/book_model_scene.dart';

/// The type the model prints with. Sizes are set by the model, in book units,
/// so only the family, the weight and the style come from the theme.
@immutable
class BookModelTypography {
  const BookModelTypography({
    required this.title,
    required this.author,
    required this.label,
  });

  factory BookModelTypography.of(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return BookModelTypography(
      title: theme.titleMedium ?? const TextStyle(),
      author: theme.labelMedium ?? const TextStyle(),
      label: theme.labelSmall ?? const TextStyle(),
    );
  }

  final TextStyle title;
  final TextStyle author;
  final TextStyle label;
}

/// Everything the model needs to draw one book.
@immutable
class BookModelSpec {
  const BookModelSpec({
    required this.binding,
    required this.title,
    required this.author,
    required this.palette,
    required this.typography,
    this.blurb,
    this.art,
    this.seed = 0,
    this.open = 0,
    this.openAt = 0,
    this.camera = const BookCamera(),
    this.showDropShadow = true,
    this.detail = BookDetail.full,
    this.rowScale,
    this.dim = 0,
  });

  final BookBinding binding;
  final String title;
  final String author;
  final String? blurb;
  final BookArt? art;
  final BookModelPalette palette;
  final BookModelTypography typography;

  /// Fixes the thickness, the grain, the hubs and the bands for this book.
  final int seed;

  /// 0 is shut, 1 is open at [BookModelBuilder.maximumCoverAngle].
  final double open;

  /// The fraction of the paper block that opens with the front board.
  ///
  /// 0 keeps the complete block at rest. 1 lifts the complete block, so only
  /// the back board remains below it. Values between them split the block at
  /// that depth, measured from the front.
  final double openAt;

  final BookCamera camera;
  final bool showDropShadow;

  /// How finely the curved surfaces are tessellated.
  ///
  /// A book standing four places down a row is a few dozen pixels of spine.
  /// Giving it the same twenty facets as the book in the reader's hand costs
  /// twenty runs of the spine painter - gradients, rules and two lines of type
  /// apiece - for a curve nobody can resolve.
  final BookDetail detail;

  /// One book of a row, drawn at the row's scale instead of its own.
  ///
  /// A book on its own is measured and then centred in the space it was given,
  /// which is right for one object and wrong for eleven standing side by side:
  /// a thick book and a thin one cast different outlines, so each ends up
  /// centred on a different point, and the row that was placed by projection
  /// comes out with its spines a few pixels off their own slots. Half a title
  /// then disappears behind the book in front of it.
  ///
  /// Set, this is the scale every book in the row shares, and the book is
  /// placed by its own middle rather than by the middle of its outline. It is
  /// also cheaper: the outline no longer has to be measured at all.
  final double? rowScale;

  /// How far the book is darkened for standing further down the row, from 0 to
  /// 1.
  ///
  /// Painted into the object rather than laid over it. A scrim has to follow
  /// the book's own silhouette — two books that overlap must not show through
  /// each other — and the obvious way to get that is a `ColorFiltered` over the
  /// widget. It is also the most expensive thing on the screen: it composites
  /// through an offscreen pass, once per book, on every frame of a scroll, and
  /// a shelf with fourteen dimmed books on it was handing the compositor
  /// fourteen render targets a frame. Every face already lays a wash of light
  /// over its own content, so the dark costs one more rectangle on a surface
  /// that was being drawn anyway, and the silhouette is exact because it is the
  /// silhouette.
  ///
  /// Stepped by the caller, because a value that creeps every frame throws away
  /// the book's cached raster every frame.
  final double dim;

  BookBindingProfile get profile => BookBindingProfile.of(binding);

  BookModelSpec copyWith({
    double? open,
    double? openAt,
    BookArt? art,
    BookCamera? camera,
    BookDetail? detail,
  }) =>
      BookModelSpec(
        binding: binding,
        title: title,
        author: author,
        palette: palette,
        typography: typography,
        blurb: blurb,
        art: art ?? this.art,
        seed: seed,
        open: open ?? this.open,
        openAt: openAt ?? this.openAt,
        camera: camera ?? this.camera,
        showDropShadow: showDropShadow,
        detail: detail ?? this.detail,
        rowScale: rowScale,
        dim: dim,
      );
}

/// How finely a book's curves are cut into flats.
enum BookDetail {
  /// Every facet. For the book being looked at, held, or opened.
  full,

  /// Enough facets to keep a silhouette honest at a few dozen pixels wide.
  reduced;

  /// The bow of the spine, across the thickness.
  int get spineSegments => this == BookDetail.full ? 20 : 7;

  /// The hollow of the fore-edge.
  int get foreEdgeSegments => this == BookDetail.full ? 12 : 4;

  /// How many gathered sections of paper follow the cover up.
  int get leaves => this == BookDetail.full ? 6 : 3;
}

/// Lays out one book as a list of flat faces in book space.
///
/// Nothing here paints to the screen. The builder decides where every surface
/// of the object is and what goes on it; the renderer decides which of them
/// the camera can see. Keeping the two apart is what makes the geometry
/// testable: a test can ask for the faces and check that the boards overhang
/// the paper, that the spine bows outward, and that the back board looks away
/// from the reader.
abstract final class BookModelBuilder {
  /// How far a cover swings when it is fully open.
  ///
  /// A little past square, which is where a real cover comes to rest when a
  /// book is held. Laying it flat at 180 degrees would need the block to split
  /// in two, and that is a different picture: a book being read, not a book
  /// being opened.
  static const double maximumCoverAngle = 2.30;

  /// How far past fully open the cover is allowed to swing.
  ///
  /// A board thrown open goes a little past where it settles and comes back.
  /// The animation's curve does the same, so the value it hands the model can
  /// pass 1 for a moment. Anything beyond this is a mistake, not a flourish.
  static const double overshootLimit = 1.10;

  /// The leaves that follow the cover up, as a share of the cover's angle.
  static const List<double> leafFollow = [0.56, 0.42, 0.30, 0.20, 0.12, 0.06];

  static const double leafGap = 0.0018;

  static List<BookFace> build(BookModelSpec spec) {
    final metrics = BookMetrics.from(spec.profile, spec.seed);
    final parts = BookParts(spec, metrics);
    final angle = spec.open.clamp(0.0, overshootLimit) * maximumCoverAngle;
    final openAt = spec.openAt.clamp(0.0, 1.0);

    // Keep the exact old path at zero. Besides preserving the shut book, this
    // keeps the four flyleaves as the top sheets of the one complete block.
    if (openAt == 0) {
      return [
        if (spec.showDropShadow) parts.dropShadow(),
        ...parts.backBoard(),
        ...parts.pageBlock(),
        ...parts.spine(),
        if (angle > 0.001) ...[
          ...parts.leaves(angle),
          parts.castShadow(angle),
        ],
        ...parts.frontBoard(angle),
      ];
    }

    return [
      if (spec.showDropShadow) parts.dropShadow(),
      ...parts.backBoard(),
      ...parts.splitPageBlock(openAt, angle),
      ...parts.spine(),
      if (angle > 0.001 && openAt < 1)
        parts.castShadow(angle, plane: parts.restingTopZ(openAt)),
      ...parts.frontBoard(angle),
    ];
  }

  /// The angle of the cover at this opening, in radians.
  static double coverAngle(double open) =>
      open.clamp(0.0, overshootLimit) * maximumCoverAngle;
}

/// Builds every face of one book and holds every content painter.
///
/// Public so the geometry can be tested one part at a time.
class BookParts {
  BookParts(this.spec, this.metrics);

  /// How far each gathered section of the lifted paper follows the cover.
  ///
  /// Far short of the cover, and spread wide. Paper held up by a board that has
  /// swung a hundred and thirty degrees does not stand where the board stands:
  /// it falls back across the gutter and opens a fan between the board and the
  /// page. Values close to the cover's own angle put the whole lifted half flat
  /// behind the board, where nothing of it can be seen and every opening looks
  /// alike no matter how far through the book it is. [BookModelBuilder.leafFollow]
  /// is the same argument for single leaves, and is spread this wide for the
  /// same reason.
  static const List<double> _liftedStackFollow = [0.54, 0.38, 0.24];

  final BookModelSpec spec;
  final BookMetrics metrics;

  BookBindingProfile get profile => metrics.profile;
  BookModelPalette get palette => spec.palette;
  BookArt? get art => spec.art;

  static const BookVector _across = BookVector(1, 0, 0);
  static const BookVector _back = BookVector(-1, 0, 0);
  static const BookVector _down = BookVector(0, 1, 0);
  static const BookVector _out = BookVector(0, 0, 1);
  static const BookVector _in = BookVector(0, 0, -1);

  /// Where the printed first page sits.
  ///
  /// Under the flyleaves, not on top of them. The leaves that lift with the
  /// cover are the top sheets of the block, so the page they uncover has to be
  /// below every one of them, or the two are at the same depth and the sort
  /// decides between them differently from one angle to the next.
  double get pageTopZ =>
      metrics.blockFrontZ -
      BookModelBuilder.leafGap * BookModelBuilder.leafFollow.length;

  // --------------------------------------------------------------- geometry

  /// The back board: what the reader sees when the book is turned over.
  ///
  /// On the nearest-corner rule, like the front board. It is tempting to anchor
  /// the whole slab at its own thickness, on the grounds that the back board is
  /// the backmost thing in a book — and it is not, because the camera can go
  /// round it. Turned over, an anchored back board sorts behind the front board
  /// it is standing in front of, and the reader is shown the cover again.
  List<BookFace> backBoard() {
    final inner = profile.boardThickness;
    return [
      // Outer face. Its own leading edge is the fore-edge, because turning a
      // book over puts the spine on the other side, and the back cover has to
      // read the right way round when it does.
      BookFace(
        debugName: 'back-board-outer',
        origin: BookVector(metrics.boardWidth, metrics.boardTop, 0),
        u: _back,
        v: _down,
        width: metrics.boardWidth,
        height: metrics.boardHeight,
        bleed: art?.backAverage ?? palette.clothDeep,
        paint: _paintBackCover,
      ),
      BookFace(
        debugName: 'back-board-inner',
        origin: BookVector(0, metrics.boardTop, inner),
        u: _across,
        v: _down,
        width: metrics.boardWidth,
        height: metrics.boardHeight,
        bleed: palette.endpaper,
        // The one face of the board that is a sheet rather than a slab: the
        // block lies on it, so it sorts at its own plane, the way every sheet
        // in the block does. Its nearest corner is the one at the head of the
        // spine, which reaches nearer the camera than the paper resting on it.
        depthAnchor: BookVector(0, 0, inner),
        paint: _paintInsideBoard,
      ),
      ..._boardEdges(zInner: inner, zOuter: 0, name: 'back-board'),
    ];
  }

  /// The front board, swung open by [angle] radians on its joint.
  List<BookFace> frontBoard(double angle) {
    final outer = metrics.frontBoardOuterZ;
    final inner = metrics.frontBoardInnerZ;
    final hinge = BookTransform.hinge(
      axisX: profile.grooveWidth,
      axisZ: (inner + outer) / 2,
      angle: angle,
    );
    final faces = <BookFace>[
      BookFace(
        debugName: 'front-board-outer',
        origin: BookVector(0, metrics.boardTop, outer),
        u: _across,
        v: _down,
        width: metrics.boardWidth,
        height: metrics.boardHeight,
        bleed: art?.coverAverage ?? palette.cloth,
        paint: _paintFrontCover,
      ),
      // The inside of the front board. Its leading edge is the fore-edge for
      // the same reason as the back board's: once it is open, the reader is
      // looking at it from the other side.
      BookFace(
        debugName: 'front-board-inner',
        origin: BookVector(metrics.boardWidth, metrics.boardTop, inner),
        u: _back,
        v: _down,
        width: metrics.boardWidth,
        height: metrics.boardHeight,
        bleed: palette.endpaper,
        paint: _paintInsideBoard,
      ),
      ..._boardEdges(zInner: inner, zOuter: outer, name: 'front-board'),
    ];
    return [for (final face in faces) face.transformedBy(hinge)];
  }

  /// The four cut edges of a board, where its thickness shows.
  ///
  /// All four, including the one at the joint. That edge is buried while the
  /// book is shut, and it is in plain view the moment the board swings; a
  /// board built with three edges is a board with a hole in it.
  List<BookFace> _boardEdges({
    required double zInner,
    required double zOuter,
    required String name,
    BookVector? anchor,
  }) {
    final depth = (zOuter - zInner).abs();
    final zLow = math.min(zInner, zOuter);
    final zHigh = math.max(zInner, zOuter);
    return [
      // Fore-edge, looking away from the spine.
      BookFace(
        debugName: '$name-fore-edge',
        origin: BookVector(metrics.boardWidth, metrics.boardTop, zHigh),
        u: _in,
        v: _down,
        width: depth,
        height: metrics.boardHeight,
        bleed: palette.boardCore,
        depthAnchor: anchor,
        paint: _paintBoardEdge,
      ),
      // The joint edge, looking back toward the spine.
      BookFace(
        debugName: '$name-joint',
        origin: BookVector(0, metrics.boardTop, zLow),
        u: _out,
        v: _down,
        width: depth,
        height: metrics.boardHeight,
        bleed: palette.boardCore,
        depthAnchor: anchor,
        paint: _paintBoardEdge,
      ),
      // Head, looking up.
      BookFace(
        debugName: '$name-head',
        origin: BookVector(0, metrics.boardTop, zLow),
        u: _across,
        v: _out,
        width: metrics.boardWidth,
        height: depth,
        bleed: palette.boardCore,
        depthAnchor: anchor,
        paint: _paintBoardEdge,
      ),
      // Tail, looking down.
      BookFace(
        debugName: '$name-tail',
        origin: BookVector(0, metrics.boardBottom, zHigh),
        u: _across,
        v: _in,
        width: metrics.boardWidth,
        height: depth,
        bleed: palette.boardCore,
        depthAnchor: anchor,
        paint: _paintBoardEdge,
      ),
    ];
  }

  /// The paper: a closed box of six faces.
  ///
  /// Six, not five. The face at the spine is the bound edge, and it is what
  /// stops the reader seeing daylight through the hollow of a cased spine once
  /// the book is turned far enough for the far side of the spine to fall away.
  List<BookFace> pageBlock() {
    return [
      BookFace(
        debugName: 'page-top',
        origin: BookVector(0, metrics.blockTop, pageTopZ),
        u: _across,
        v: _down,
        width: metrics.blockWidth,
        height: metrics.blockHeight,
        bleed: palette.paper,
        depthAnchor: BookVector(0, 0, pageTopZ),
        paint: _paintTopPage,
      ),
      BookFace(
        debugName: 'page-bottom',
        origin: BookVector(
            metrics.blockWidth, metrics.blockTop, metrics.blockBackZ),
        u: _back,
        v: _down,
        width: metrics.blockWidth,
        height: metrics.blockHeight,
        bleed: palette.paper,
        depthAnchor: BookVector(0, 0, metrics.blockBackZ),
        paint: (canvas, size, shade) => canvas.drawRect(
          Offset.zero & size,
          Paint()..color = palette.paper,
        ),
      ),
      // The bound edge, where the sheets are gathered and glued.
      //
      // Anchored, like every other face of the block. It was the one that was
      // not, and it is the one that runs the whole thickness: on the
      // nearest-corner rule its far corner reaches further toward the camera
      // than any single facet of the covering that wraps it, so the paper was
      // painted over the spine. A hardback kept about half its spine that way
      // and a softback about a fifth, which is why a paperback with no cover
      // artwork came out as a blank panel with one stray letter on it — the
      // title was there, printed on facets the block was covering.
      BookFace(
        debugName: 'page-spine',
        origin: BookVector(0, metrics.blockTop, metrics.blockBackZ),
        u: _out,
        v: _down,
        width: metrics.blockDepth,
        height: metrics.blockHeight,
        bleed: palette.pageEdge,
        depthAnchor: BookVector(
          0,
          0,
          (metrics.blockBackZ + metrics.blockFrontZ) / 2,
        ),
        paint: _paintBoundEdge,
      ),
      // The head and the tail, where the block is seen edge on. Local x starts
      // at the spine on both, which is where the headband belongs.
      //
      // Anchored at the spine, like every other face of the block, and for the
      // same reason the bound edge is. Both run the whole width of the book, so
      // on the nearest-corner rule they sort by their fore-edge corner, which
      // at the shelf's angle reaches half way along the bow of the spine: the
      // covering was drawn over the paper for its far ten facets and under it
      // for its near ten, and the head of every book on the shelf came out with
      // a square staircase bitten out of it. Wherever the two overlap on screen
      // the covering is nearer — it wraps the block — so the block goes behind
      // all of it, at one depth, with no facet left to interleave with.
      BookFace(
        debugName: 'page-head',
        origin: BookVector(0, metrics.blockTop, metrics.blockBackZ),
        u: _across,
        v: _out,
        width: metrics.blockWidth,
        height: metrics.blockDepth,
        bleed: palette.pageEdge,
        depthAnchor: BookVector(
          0,
          0,
          (metrics.blockBackZ + metrics.blockFrontZ) / 2,
        ),
        paint: (canvas, size, shade) =>
            _paintPaperEdge(canvas, size, shade, across: true),
      ),
      BookFace(
        debugName: 'page-tail',
        origin: BookVector(0, metrics.blockBottom, metrics.blockFrontZ),
        u: _across,
        v: _in,
        width: metrics.blockWidth,
        height: metrics.blockDepth,
        bleed: palette.pageEdge,
        depthAnchor: BookVector(
          0,
          0,
          (metrics.blockBackZ + metrics.blockFrontZ) / 2,
        ),
        paint: (canvas, size, shade) =>
            _paintPaperEdge(canvas, size, shade, across: true),
      ),
      // The fore-edge. Rounding a spine hollows the fore-edge to match, so it
      // is a curve, not a flat band. Traced from the front board back, which
      // is the direction that makes it look away from the spine.
      ..._curvedStrip(
        name: 'page-fore-edge',
        profilePoints: _foreEdgeProfile(),
        yTop: metrics.blockTop,
        yBottom: metrics.blockBottom,
        bleed: palette.pageEdge,
        paintStrip: (canvas, size, shade) =>
            _paintPaperEdge(canvas, size, shade, across: false),
      ),
    ];
  }

  /// The paper on each side of an opening: closed resting and lifted stacks.
  ///
  /// The lifted paper is divided into gathered sections. The section nearest
  /// the cover follows it most closely, while the deeper sections lag behind.
  /// This keeps the paper visible as a fan instead of hiding it behind the
  /// board as one rigid slab.
  List<BookFace> splitPageBlock(double openAt, double angle) {
    final splitZ = restingTopZ(openAt);
    final resting = splitZ > metrics.blockBackZ
        ? _paperStack(
            name: 'page-resting',
            zBack: metrics.blockBackZ,
            zFront: splitZ,
            paintTop: _paintTopPage,
          )
        : const <BookFace>[];
    final liftedDepth = metrics.blockFrontZ - splitZ;
    final settle = angle <= math.pi / 2
        ? 1.0
        : 1 -
            0.55 *
                ((angle - math.pi / 2) /
                        (BookModelBuilder.maximumCoverAngle - math.pi / 2))
                    .clamp(0.0, 1.0);
    final lifted = <BookFace>[];
    for (var index = 0; index < _liftedStackFollow.length; index++) {
      final zFront =
          metrics.blockFrontZ - liftedDepth * index / _liftedStackFollow.length;
      final zBack = metrics.blockFrontZ -
          liftedDepth * (index + 1) / _liftedStackFollow.length;
      // The fan opens with the depth of the paper that is lifting. A thin
      // section rides with the board and stays close to it; a thick one cannot
      // be held that steeply and falls back across the gutter. Without this
      // the fan is the same three sheets at every split, only thicker, and a
      // book three quarters open looks like a book a quarter open - which is
      // the whole thing the reader is meant to be able to see.
      final spread = openAt.clamp(0.0, 1.0);
      final follow = 0.86 + (_liftedStackFollow[index] - 0.86) * spread;
      final stackAngle = angle * follow * settle;
      final hinge = BookTransform.hinge(
        axisX: profile.grooveWidth,
        axisZ: (metrics.frontBoardInnerZ + metrics.frontBoardOuterZ) / 2,
        angle: stackAngle,
      );
      lifted.addAll(
        _paperStack(
          name: 'page-lifted-$index',
          zBack: zBack,
          zFront: zFront,
          paintTop: _paintPlainPaper,
        ).map((face) => face.transformedBy(hinge)),
      );
    }

    return [
      ...resting,
      ...lifted,
    ];
  }

  /// The z plane exposed when the front fraction of the block lifts.
  double restingTopZ(double openAt) =>
      metrics.blockBackZ + metrics.blockDepth * (1 - openAt.clamp(0.0, 1.0));

  List<BookFace> _paperStack({
    required String name,
    required double zBack,
    required double zFront,
    required void Function(Canvas canvas, Size size, double shade) paintTop,
  }) {
    final depth = zFront - zBack;
    final middleZ = (zBack + zFront) / 2;
    return [
      BookFace(
        debugName: '$name-top',
        origin: BookVector(0, metrics.blockTop, zFront),
        u: _across,
        v: _down,
        width: metrics.blockWidth,
        height: metrics.blockHeight,
        bleed: palette.paper,
        depthAnchor: BookVector(0, 0, zFront),
        paint: paintTop,
      ),
      BookFace(
        debugName: '$name-bottom',
        origin: BookVector(metrics.blockWidth, metrics.blockTop, zBack),
        u: _back,
        v: _down,
        width: metrics.blockWidth,
        height: metrics.blockHeight,
        bleed: palette.paper,
        depthAnchor: BookVector(0, 0, zBack),
        paint: _paintPlainPaper,
      ),
      BookFace(
        debugName: '$name-spine',
        origin: BookVector(0, metrics.blockTop, zBack),
        u: _out,
        v: _down,
        width: depth,
        height: metrics.blockHeight,
        bleed: palette.pageEdge,
        depthAnchor: BookVector(0, 0, middleZ),
        paint: _paintBoundEdge,
      ),
      BookFace(
        debugName: '$name-head',
        origin: BookVector(0, metrics.blockTop, zBack),
        u: _across,
        v: _out,
        width: metrics.blockWidth,
        height: depth,
        bleed: palette.pageEdge,
        depthAnchor: BookVector(0, 0, middleZ),
        paint: (canvas, size, shade) =>
            _paintPaperEdge(canvas, size, shade, across: true),
      ),
      BookFace(
        debugName: '$name-tail',
        origin: BookVector(0, metrics.blockBottom, zFront),
        u: _across,
        v: _in,
        width: metrics.blockWidth,
        height: depth,
        bleed: palette.pageEdge,
        depthAnchor: BookVector(0, 0, middleZ),
        paint: (canvas, size, shade) =>
            _paintPaperEdge(canvas, size, shade, across: true),
      ),
      ..._curvedStrip(
        name: '$name-fore-edge',
        profilePoints: _stackForeEdgeProfile(zBack, zFront),
        yTop: metrics.blockTop,
        yBottom: metrics.blockBottom,
        anchorAtSpine: true,
        bleed: palette.pageEdge,
        paintStrip: (canvas, size, shade) =>
            _paintPaperEdge(canvas, size, shade, across: false),
      ),
    ];
  }

  /// The spine: a bow across the thickness, from the back board to the front.
  ///
  /// The facets are two-sided. A rounded spine turns away from the reader long
  /// before its edge is reached, exactly as a cylinder does, and dropping the
  /// facets that face away opens a gap at the far side of the bow with nothing
  /// behind it. Keeping them costs three or four small quads and closes the
  /// object at every angle.
  List<BookFace> spine() {
    final cased = profile.squares > 0;
    return _curvedStrip(
      name: 'spine',
      profilePoints: _spineProfile(),
      yTop: cased ? metrics.boardTop : metrics.blockTop,
      yBottom: cased ? metrics.boardBottom : metrics.blockBottom,
      doubleSided: true,
      bleed: art?.spineAverage ?? palette.cloth,
      // No anchor. The facets keep the nearest-corner rule, which is what lets
      // the near half of a bow pass in front of the boards while the far half
      // goes behind them. Sorting the whole strip as one surface at the crown
      // of its own bow was tried and is wrong: it puts the far half in front
      // of the board it should be behind, and the spine loses its title to the
      // board instead of to the paper.
      paintStrip: _paintSpine,
    );
  }

  /// The leaves that come up with the cover.
  ///
  /// A board is rigid and a leaf is not, so a leaf is built as a run of panels
  /// that stand steeply at the gutter and lie flatter toward the fore-edge.
  /// That curve is the difference between a book opening and a deck of cards
  /// being cut.
  List<BookFace> leaves(double angle) {
    const panels = 3;
    final count = math.min(
      spec.detail.leaves,
      BookModelBuilder.leafFollow.length,
    );
    final faces = <BookFace>[];
    // Past square the cover is no longer holding the leaves up and they fall
    // back onto the block. A fan that keeps rising to the last degree reads as
    // a deck of cards being cut, and it throws the near corners of the sheets
    // so far toward the reader that they stand above the head of the book.
    final settle = angle <= math.pi / 2
        ? 1.0
        : 1 -
            0.55 *
                ((angle - math.pi / 2) /
                        (BookModelBuilder.maximumCoverAngle - math.pi / 2))
                    .clamp(0.0, 1.0);
    for (var index = 0; index < count; index++) {
      final leafAngle = angle * BookModelBuilder.leafFollow[index] * settle;
      if (leafAngle < 0.02) continue;
      final z = metrics.blockFrontZ - BookModelBuilder.leafGap * index;
      final inset = 0.0007 * index;
      final width = metrics.blockWidth - inset;
      final panelWidth = width / panels;

      var origin = BookVector(0, metrics.blockTop + inset, z);
      for (var panel = 0; panel < panels; panel++) {
        // The tip of a lifted leaf falls back toward the block under its own
        // weight, so each panel stands at a shallower angle than the last.
        final slack = 1 - 0.30 * (panel + 0.5) / panels;
        final panelAngle = leafAngle * slack;
        final direction = BookVector(
          math.cos(panelAngle),
          0,
          math.sin(panelAngle),
        );
        final offset = panelWidth * panel;
        faces.add(
          BookFace(
            debugName: 'leaf-$index-$panel',
            origin: origin,
            u: direction,
            v: _down,
            width: panelWidth,
            height: metrics.blockHeight - inset * 2,
            doubleSided: true,
            bleed: palette.paper,
            // Every panel of one leaf is one sheet, so they share the sheet's
            // place in the stack and then fall inner to outer among
            // themselves, which is the order they curve away in.
            depthAnchor: BookVector(0, 0, z),
            paint: (canvas, size, shade) => _paintLeaf(
              canvas,
              size,
              index,
              offset: offset,
              total: width,
            ),
          ),
        );
        origin = origin + direction * panelWidth;
      }
    }
    return faces;
  }

  /// The shadow the lifted cover throws across the open page.
  BookFace castShadow(double angle, {double? plane}) {
    final hinge = BookTransform.hinge(
      axisX: profile.grooveWidth,
      axisZ: (metrics.frontBoardInnerZ + metrics.frontBoardOuterZ) / 2,
      angle: angle,
    );
    final landingPlane = plane ?? metrics.blockFrontZ;
    final corners = <BookVector>[
      BookVector(0, metrics.boardTop, metrics.frontBoardInnerZ),
      BookVector(
          metrics.boardWidth, metrics.boardTop, metrics.frontBoardInnerZ),
      BookVector(
        metrics.boardWidth,
        metrics.boardBottom,
        metrics.frontBoardInnerZ,
      ),
      BookVector(0, metrics.boardBottom, metrics.frontBoardInnerZ),
    ];
    // The same light the renderer shades with, read in book space.
    const light = BookVector(-0.32, -0.42, 0.85);
    final projected = <Offset>[
      for (final corner in corners)
        () {
          final lifted = hinge.point(corner);
          final landed = lifted + light * ((landingPlane - lifted.z) / light.z);
          return Offset(landed.x, landed.y - metrics.blockTop);
        }(),
    ];

    return BookFace(
      debugName: 'cast-shadow',
      origin: BookVector(0, metrics.blockTop, landingPlane),
      u: _across,
      v: _down,
      width: metrics.blockWidth,
      height: metrics.blockHeight,
      lit: false,
      depthBias: 0.0004,
      paint: (canvas, size, shade) {
        canvas.save();
        canvas.clipRect(Offset.zero & size);
        canvas.drawPath(
          Path()..addPolygon(projected, true),
          Paint()
            ..color = palette.shadow.withValues(alpha: 0.32)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              math.max(0.004, metrics.blockWidth * 0.022),
            ),
        );
        canvas.restore();
      },
    );
  }

  /// A soft shadow behind the object, so it sits on the page instead of
  /// floating over it.
  BookFace dropShadow() {
    final drop = metrics.blockHeight * 0.014;
    return BookFace(
      debugName: 'drop-shadow',
      origin: BookVector(
        -metrics.spineBulge,
        metrics.boardTop + drop,
        -metrics.blockHeight * 0.004,
      ),
      u: _across,
      v: _down,
      width: metrics.boardWidth + metrics.spineBulge + drop,
      height: metrics.boardHeight,
      lit: false,
      depthBias: -1,
      paint: (canvas, size, shade) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            Radius.circular(metrics.blockWidth * 0.03),
          ),
          Paint()
            ..color = palette.shadow.withValues(alpha: 0.32)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              metrics.blockWidth * 0.07,
            ),
        );
      },
    );
  }

  // ------------------------------------------------------------- strip maths

  /// The spine seen from above: a bow from the back board to the front board.
  ///
  /// Traced back to front, which is the direction that leaves the strip
  /// looking away from the book.
  List<Offset> _spineProfile() {
    final depth = metrics.totalDepth;
    final bulge = metrics.spineBulge;
    if (bulge < 0.0005) {
      return [const Offset(0, 0), Offset(0, depth)];
    }
    final segments = spec.detail.spineSegments;
    return [
      for (var index = 0; index <= segments; index++)
        () {
          final t = index / segments;
          // A flat back with rounded joints, not a bow.
          //
          // A plain sine puts its whole travel in the middle of the spine,
          // which is where the title is: the type then sits on the one part of
          // the strip that is turning away from the reader hardest. Raising the
          // sine to a fraction moves all of the travel into the first and last
          // tenth, so the joints are round, the light still runs across them,
          // and the panel the title is printed on is flat.
          final round = math.pow(math.sin(math.pi * t), 0.42).toDouble();
          return Offset(-bulge * round, depth * t);
        }(),
    ];
  }

  /// The fore-edge seen from above: hollowed in to match the rounded spine.
  ///
  /// Traced front to back, so the strip looks away from the spine.
  List<Offset> _foreEdgeProfile() {
    final hollow = metrics.foreEdgeHollow;
    final back = metrics.blockBackZ;
    final depth = metrics.blockDepth;
    if (hollow < 0.0005) {
      return [
        Offset(metrics.blockWidth, back + depth),
        Offset(metrics.blockWidth, back),
      ];
    }
    final segments = spec.detail.foreEdgeSegments;
    return [
      for (var index = 0; index <= segments; index++)
        () {
          final t = index / segments;
          return Offset(
            metrics.blockWidth - hollow * math.sin(math.pi * t),
            back + depth * (1 - t),
          );
        }(),
    ];
  }

  /// One stack gets its own hollow fore-edge between its two paper faces.
  List<Offset> _stackForeEdgeProfile(double back, double front) {
    final depth = front - back;
    final hollow = depth * profile.foreEdgeRound;
    if (hollow < 0.0005) {
      return [
        Offset(metrics.blockWidth, front),
        Offset(metrics.blockWidth, back),
      ];
    }
    final segments = spec.detail.foreEdgeSegments;
    return [
      for (var index = 0; index <= segments; index++)
        () {
          final t = index / segments;
          return Offset(
            metrics.blockWidth - hollow * math.sin(math.pi * t),
            front - depth * t,
          );
        }(),
    ];
  }

  /// Turns a profile in the thickness plane into a run of quads, and gives
  /// every quad the same content painter with its own slice of it.
  ///
  /// Each segment clips to its own length and shifts the whole strip under the
  /// clip, so a title running down a curved spine is one continuous line of
  /// type broken across the facets, not one line per facet.
  List<BookFace> _curvedStrip({
    required String name,
    required List<Offset> profilePoints,
    required double yTop,
    required double yBottom,
    required void Function(Canvas canvas, Size size, double shade) paintStrip,
    bool anchorAtSpine = false,
    bool doubleSided = false,
    Color? bleed,
    BookVector? anchor,
  }) {
    final lengths = <double>[];
    var total = 0.0;
    for (var index = 0; index < profilePoints.length - 1; index++) {
      final length = (profilePoints[index + 1] - profilePoints[index]).distance;
      lengths.add(length);
      total += length;
    }
    if (total <= 0) return const [];

    final height = yBottom - yTop;
    // The normal each facet has, and then the normal the curve itself has at
    // each joint: the average of the two facets that meet there. Handing those
    // to the faces is what lets the renderer light the bow as a curve instead
    // of drawing a crease down every joint.
    final facetNormals = <BookVector>[];
    for (var index = 0; index < lengths.length; index++) {
      final from = profilePoints[index];
      final to = profilePoints[index + 1];
      final length = lengths[index];
      final direction = length <= 0
          ? const BookVector(1, 0, 0)
          : BookVector((to.dx - from.dx) / length, 0, (to.dy - from.dy) / length);
      facetNormals.add(direction.cross(_down).normalized);
    }
    final curved = facetNormals.length > 1;
    final jointNormals = <BookVector>[
      for (var index = 0; index <= facetNormals.length; index++)
        index == 0
            ? facetNormals.first
            : index == facetNormals.length
                ? facetNormals.last
                : (facetNormals[index - 1] + facetNormals[index]).normalized,
    ];

    final faces = <BookFace>[];
    var travelled = 0.0;
    for (var index = 0; index < lengths.length; index++) {
      final from = profilePoints[index];
      final to = profilePoints[index + 1];
      final length = lengths[index];
      if (length <= 0) continue;
      final direction = BookVector(
        (to.dx - from.dx) / length,
        0,
        (to.dy - from.dy) / length,
      );
      final offset = travelled;
      travelled += length;
      // A hair past both ends. Each facet clips the strip to its own length,
      // and two hard clips that meet leave a seam of whatever is behind them:
      // the foil rules across a spine came out dashed, one gap per joint, and
      // the crack showed the pale block through the covering. The overlap gives
      // that seam real content.
      //
      // It is declared on the face as well as used here, because the renderer
      // has to lay the facet's light over the same sliver. Washed only to its
      // own edges, every facet handed its neighbour a strip of unlit content,
      // and a spine cut into twenty facets came out with twenty pinstripes down
      // it — the crack this was added to close, reopened one step further on.
      final seam = total * 0.012;
      faces.add(
        BookFace(
          debugName: '$name-$index',
          origin: BookVector(from.dx, yTop, from.dy),
          u: direction,
          v: _down,
          width: length,
          height: height,
          seam: seam,
          doubleSided: doubleSided,
          // Only where the strip meets something that is not the strip.
          //
          // The skirt is a flat rectangle laid down before a face's content,
          // and inside a strip it is laid over the content of the facet next to
          // it: the foil rules across a spine came out as a row of dashes, one
          // gap per joint, because every facet wiped the last one's line. The
          // joints inside the strip do not need it, because the seam overlap
          // below fills them with the real content, and the two ends still get
          // it because what lies past them is a board.
          bleed: index == 0 || index == lengths.length - 1 ? bleed : null,
          normalAtStart: curved ? jointNormals[index] : null,
          normalAtEnd: curved ? jointNormals[index + 1] : null,
          depthAnchor: anchor ??
              (anchorAtSpine ? BookVector(0, 0, (from.dy + to.dy) / 2) : null),
          paint: (canvas, size, shade) {
            canvas.save();
            canvas.clipRect(
              Rect.fromLTWH(-seam, 0, size.width + seam * 2, size.height),
            );
            canvas.translate(-offset, 0);
            paintStrip(canvas, Size(total, height), shade);
            canvas.restore();
          },
        ),
      );
    }
    return faces;
  }

  // ------------------------------------------------------------------ paint

  /// One book unit is the height of the page block, so every measurement
  /// below reads as a fraction of the book.
  double get _unit => metrics.blockHeight;

  int get _seed => spec.seed;

  void _paintFrontCover(Canvas canvas, Size size, double shade) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(profile.cornerRadius)),
    );

    final source = art;
    if (source != null) {
      _paintPastedArt(canvas, rect, source.front, source.coverAverage);
    } else {
      _paintClothField(canvas, rect, palette.cloth);
      _paintPrintedCover(canvas, rect);
    }

    if (profile.laminate) {
      _paintLaminate(canvas, rect);
      // A laminated card catches the light all down its fore-edge.
      final lip = size.width * 0.012;
      canvas.drawRect(
        Rect.fromLTWH(size.width - lip, 0, lip, size.height),
        Paint()..color = Colors.white.withValues(alpha: 0.10),
      );
    } else {
      _paintClothGrain(canvas, rect);
    }
    _paintGroove(canvas, size, 0.34);
    canvas.restore();
  }

  void _paintBackCover(Canvas canvas, Size size, double shade) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(profile.cornerRadius)),
    );

    final source = art;
    if (source != null && source.isWrapAround) {
      _paintPastedArt(canvas, rect, source.back, source.backAverage);
    } else {
      final ground = source == null
          ? palette.clothDeep
          : Color.lerp(source.backAverage, Colors.black, 0.14)!;
      _paintClothField(canvas, rect, ground);
      final ink = BookArtCache.inkOver(ground);
      if (profile.printedBack) {
        _paintPrintedBack(canvas, rect, ink);
      } else {
        _paintBlindStamp(canvas, rect);
      }
    }

    if (profile.laminate) {
      _paintLaminate(canvas, rect);
    } else {
      _paintClothGrain(canvas, rect);
    }
    // The groove is at the far side of this face, because the face reads from
    // the fore-edge inward.
    canvas.save();
    canvas.translate(size.width, 0);
    canvas.scale(-1, 1);
    _paintGroove(canvas, size, 0.30);
    canvas.restore();
    canvas.restore();
  }

  /// A printed cover laid onto a board, with the binding showing round it.
  ///
  /// A cover picture is a sheet, and a sheet has an edge. Run to the trim of the
  /// board it becomes the board, and the object loses the one thing that says it
  /// is bound rather than printed. [BookBindingProfile.coverMargin] is how much
  /// binding is left showing: wide on a cased book, the way a plate is mounted,
  /// and barely more than the trim on a laminated card.
  ///
  /// A wrap-around jacket is the exception, and gets none. It is one sheet
  /// carried over the back board, the spine and the front, and insetting the
  /// two boards would break the picture at both joints.
  void _paintPastedArt(Canvas canvas, Rect rect, Rect source, Color ground) {
    final image = art?.image;
    if (image == null) return;
    final margin = profile.coverMargin;
    final panel = rect.deflate(margin);
    if (art!.isWrapAround || margin <= 0 || panel.width <= 0 ||
        panel.height <= 0) {
      canvas.drawImageRect(
        image,
        source,
        rect,
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }

    _paintClothField(canvas, rect, ground);
    // The board under the sheet, and the shade the sheet's own thickness lays
    // on it. Without it the picture is a hole in the board rather than
    // something lying on it.
    //
    // Two hard rectangles, not a blurred one. A `MaskFilter.blur` here is a
    // real blur pass over the whole board, once per board, on every frame of
    // every scroll - and the object is drawn five times over on a shelf. At
    // this size the two steps are indistinguishable from the blur.
    for (final (spread, alpha) in [(0.007, 0.14), (0.003, 0.20)]) {
      canvas.drawRect(
        panel.inflate(_unit * spread),
        Paint()..color = Colors.black.withValues(alpha: alpha),
      );
    }
    canvas.drawImageRect(
      image,
      source,
      panel,
      Paint()..filterQuality = FilterQuality.medium,
    );
    // The rule the binder runs round a mounted plate.
    canvas.drawRect(
      panel.inflate(_unit * 0.008),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _unit * 0.0022
        ..color = palette.foil.withValues(alpha: 0.55),
    );
  }

  /// The line of shadow pressed into a cased board along its joint. It is most
  /// of what says "hardback" from across a room.
  void _paintGroove(Canvas canvas, Size size, double strength) {
    if (profile.grooveWidth <= 0) return;
    final groove = profile.grooveWidth * 1.6;
    final rect = Rect.fromLTWH(0, 0, groove, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: strength),
            Colors.black.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  /// The face of a board the reader sees once the book is open.
  void _paintInsideBoard(Canvas canvas, Size size, double shade) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(profile.cornerRadius)),
    );
    canvas.drawRect(rect, Paint()..color = palette.endpaper);

    if (profile.endpapers) {
      // The cover material is folded over the board edge and pasted down
      // inside it, and the endpaper is laid over the middle, so a border of
      // cloth shows all the way round.
      final turn = profile.turnIn;
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = turn
          ..color = palette.clothDeep,
      );
      canvas.drawRect(
        rect.deflate(turn),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(turn * 0.12, _unit * 0.0008)
          ..color = Colors.black.withValues(alpha: 0.20),
      );
      _paintEndpaperPattern(canvas, rect.deflate(turn));
    } else {
      // A softback has no lining. The inside is the back of the printed card:
      // flat, and a little grey.
      final fold = size.width * 0.06;
      final rect = Rect.fromLTWH(size.width - fold, 0, fold, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.22),
            ],
          ).createShader(rect),
      );
    }
    canvas.restore();
  }

  void _paintEndpaperPattern(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _unit * 0.0012
      ..color = palette.clothDeep.withValues(alpha: 0.24);
    final step = _unit * 0.05;
    for (var y = rect.top + step / 2; y < rect.bottom; y += step) {
      for (var x = rect.left + step / 2; x < rect.right; x += step) {
        canvas.drawCircle(Offset(x, y), step * 0.22, paint);
      }
    }
  }

  void _paintClothField(Canvas canvas, Rect rect, Color ground) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(ground, Colors.white, 0.06)!,
            ground,
            Color.lerp(ground, Colors.black, 0.10)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  /// The weave of a cased board's cloth.
  ///
  /// Only on a book drawn large. The step is a fraction of the book, so a board
  /// carries about two hundred and sixty lines of it whether it is filling the
  /// screen or standing four places down the row as a thumbnail - and a shelf
  /// draws five books, which came to some thousands of lines a frame for a
  /// texture nobody can resolve past the first book. The facets are already cut
  /// this way; the weave should be too.
  void _paintClothGrain(Canvas canvas, Rect rect) {
    if (spec.detail != BookDetail.full) return;
    // And only on a board the reader is looking at something like squarely.
    //
    // The weave is drawn in book units, so a board turned edge on compresses
    // its whole width into a fifth of the screen it had: the threads land
    // closer together than the pixels they are drawn on, and what comes back is
    // not cloth but a moire of it — a hard diagonal corduroy over the cover,
    // and pinstripes down the spine of every book at the shelf's angle. A
    // texture that cannot be resolved should not be drawn, which is the same
    // rule the facets and the leaves are already cut by.
    if (math.cos(spec.camera.yaw).abs() < 0.55) return;
    final step = _unit * 0.0065;
    final warp = Paint()
      ..strokeWidth = _unit * 0.0009
      ..color = Colors.white.withValues(alpha: 0.05);
    for (var y = rect.top; y < rect.bottom; y += step) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), warp);
    }
    final weft = Paint()
      ..strokeWidth = _unit * 0.0009
      ..color = Colors.black.withValues(alpha: 0.05);
    for (var x = rect.left; x < rect.right; x += step) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), weft);
    }
  }

  /// The broad highlight a laminated cover throws back at a window.
  void _paintLaminate(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.17),
            Colors.white.withValues(alpha: 0.02),
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.07),
          ],
          stops: const [0, 0.22, 0.62, 1],
        ).createShader(rect),
    );
  }

  /// A cover with no artwork still has to be a cover: a field, a frame, a
  /// title and an author, printed the way this binding would print them.
  void _paintPrintedCover(Canvas canvas, Rect rect) {
    final inset = rect.width * 0.085;
    final frame = rect.deflate(inset);
    canvas.drawRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _unit * 0.0022
        ..color = palette.foil.withValues(alpha: 0.72),
    );
    canvas.drawRect(
      frame.deflate(inset * 0.18),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _unit * 0.0012
        ..color = palette.foil.withValues(alpha: 0.45),
    );

    _drawText(
      canvas,
      _text(
        spec.title,
        spec.typography.title.copyWith(
          color: palette.foil,
          fontWeight: FontWeight.w700,
          height: 1.12,
        ),
        _unit * 0.052,
        frame.width * 0.88,
        maxLines: 3,
      ),
      Offset(rect.center.dx, rect.height * 0.30),
    );

    canvas.drawLine(
      Offset(rect.center.dx - rect.width * 0.10, rect.height * 0.62),
      Offset(rect.center.dx + rect.width * 0.10, rect.height * 0.62),
      Paint()
        ..strokeWidth = _unit * 0.0018
        ..color = palette.foil.withValues(alpha: 0.62),
    );

    if (spec.author.trim().isNotEmpty) {
      _drawText(
        canvas,
        _text(
          spec.author,
          spec.typography.author.copyWith(
            color: palette.foil.withValues(alpha: 0.88),
            height: 1.1,
          ),
          _unit * 0.028,
          frame.width * 0.88,
          maxLines: 2,
        ),
        Offset(rect.center.dx, rect.height * 0.74),
      );
    }
  }

  /// A paperback back: the blurb, a device, and the barcode the shop scans.
  void _paintPrintedBack(Canvas canvas, Rect rect, Color ink) {
    final margin = rect.width * 0.10;
    final blurb = (spec.blurb ?? '').trim();
    _drawText(
      canvas,
      blurb.isNotEmpty
          ? _text(
              blurb,
              spec.typography.label.copyWith(color: ink, height: 1.34),
              _unit * 0.019,
              rect.width - margin * 2,
              maxLines: 11,
              align: TextAlign.start,
              ellipsis: true,
            )
          : _text(
              spec.title,
              spec.typography.title.copyWith(color: ink, height: 1.2),
              _unit * 0.030,
              rect.width - margin * 2,
              maxLines: 3,
              align: TextAlign.start,
            ),
      Offset(margin, rect.height * 0.12),
      centred: false,
    );

    // The barcode, on its own white panel in the fore-edge corner.
    final codeWidth = rect.width * 0.42;
    final codeHeight = rect.height * 0.085;
    final code = Rect.fromLTWH(
      rect.right - margin - codeWidth,
      rect.bottom - margin - codeHeight,
      codeWidth,
      codeHeight,
    );
    canvas.drawRect(code, Paint()..color = const Color(0xFFF4F1EA));
    final bar = Paint()..color = const Color(0xFF161310);
    final quiet = codeWidth * 0.06;
    var x = code.left + quiet;
    var noise = _seed | 1;
    while (x < code.right - quiet) {
      noise = (noise * 1103515245 + 12345) & 0x7FFFFFFF;
      final width = codeWidth * (0.006 + (noise % 5) * 0.0035);
      if (noise % 3 != 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            x,
            code.top + codeHeight * 0.14,
            width,
            codeHeight * 0.66,
          ),
          bar,
        );
      }
      x += width + codeWidth * 0.008;
    }

    // The publisher's device, in the spine corner.
    final markCentre = Offset(margin + rect.width * 0.05, code.center.dy);
    final markPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _unit * 0.0016
      ..color = ink.withValues(alpha: 0.70);
    canvas
      ..drawCircle(markCentre, rect.width * 0.045, markPaint)
      ..drawLine(
        Offset(markCentre.dx, markCentre.dy - rect.width * 0.026),
        Offset(markCentre.dx, markCentre.dy + rect.width * 0.026),
        markPaint,
      );
  }

  /// A cased book's back board: cloth, and a rule pressed into it with no ink.
  /// The blurb belongs on a jacket, and an EPUB has no jacket.
  void _paintBlindStamp(Canvas canvas, Rect rect) {
    final frame = rect.deflate(rect.width * 0.09);
    canvas
      ..drawRect(
        frame,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _unit * 0.0026
          ..color = Colors.black.withValues(alpha: 0.22),
      )
      ..drawRect(
        frame.translate(_unit * 0.0016, _unit * 0.0016),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _unit * 0.0014
          ..color = Colors.white.withValues(alpha: 0.10),
      );

    final centre = Offset(rect.center.dx, rect.bottom - rect.height * 0.14);
    final size = rect.width * 0.05;
    canvas.drawPath(
      Path()
        ..moveTo(centre.dx, centre.dy - size)
        ..lineTo(centre.dx + size * 0.7, centre.dy)
        ..lineTo(centre.dx, centre.dy + size)
        ..lineTo(centre.dx - size * 0.7, centre.dy)
        ..close(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _unit * 0.0018
        ..color = palette.foil.withValues(alpha: 0.42),
    );
  }

  /// The spine, drawn flat and then wrapped over the curve by the strip.
  void _paintSpine(Canvas canvas, Size size, double shade) {
    final rect = Offset.zero & size;
    final source = art;
    var field = palette.cloth;

    if (source == null) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Color.lerp(palette.cloth, Colors.black, 0.20)!,
              palette.cloth,
              Color.lerp(palette.cloth, Colors.white, 0.06)!,
              Color.lerp(palette.cloth, Colors.black, 0.16)!,
            ],
            stops: const [0, 0.34, 0.66, 1],
          ).createShader(rect),
      );
    } else if (source.isWrapAround) {
      canvas.drawImageRect(
        source.image,
        source.spine,
        rect,
        Paint()..filterQuality = FilterQuality.medium,
      );
      field = source.spineAverage;
    } else {
      field = source.spineAverage;
      _paintClothField(canvas, rect, field);
    }

    final ink = source == null ? palette.ink : source.spineInk;
    final foil =
        BookArtCache.contrast(palette.foil, field) >= 3 ? palette.foil : ink;

    if (profile.raisedHubs && (_seed >> 12) % 3 == 0) {
      // Raised bands across a sewn spine, each with a highlight above it.
      for (var index = 1; index <= 4; index++) {
        final y = size.height * index / 5;
        canvas
          ..drawRect(
            Rect.fromLTWH(0, y - _unit * 0.004, size.width, _unit * 0.008),
            Paint()..color = Colors.white.withValues(alpha: 0.10),
          )
          ..drawLine(
            Offset(0, y + _unit * 0.004),
            Offset(size.width, y + _unit * 0.004),
            Paint()
              ..strokeWidth = _unit * 0.0022
              ..color = Colors.black.withValues(alpha: 0.28),
          );
      }
    }

    if (profile.spineCreases) {
      // The two score lines a softback cover folds on.
      for (final x in [size.width * 0.12, size.width * 0.88]) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..strokeWidth = _unit * 0.0016
            ..color = Colors.black.withValues(alpha: 0.24),
        );
      }
    }

    // Foil rules at the head and the tail.
    final ruleInset = size.height * 0.055;
    for (final y in [ruleInset, size.height - ruleInset]) {
      canvas.drawLine(
        Offset(size.width * 0.18, y),
        Offset(size.width * 0.82, y),
        Paint()
          ..strokeWidth = _unit * 0.0016
          ..color = foil.withValues(alpha: 0.80),
      );
    }

    // The title runs down the spine, turned the same way as the spines on the
    // shelf, so a book found on the shelf and a book held in the hand agree.
    //
    // The whole title, over as many lines as the thickness will take. A spine
    // is the only part of a shelved book anyone can read, and a title cut to
    // one line and then ellipsed makes half the shelf "The Complete Works o…".
    // The type is sized to the thickness rather than to the title, so two books
    // standing beside each other are set at the same scale.
    //
    // The title and the author each own a run of the spine and are laid out
    // inside it. They used to be measured against each other after the fact,
    // and a long title simply deleted the author.
    final across = size.width * 0.78;
    final lines = (across / (_unit * 0.044)).floor().clamp(1, 3);
    final titleSize = math.min(_unit * 0.046, across / (lines * 1.10));
    final titleRun = _text(
      spec.title,
      spec.typography.title.copyWith(
        color: ink,
        fontWeight: FontWeight.w700,
        height: 1.08,
        // Stamped, not printed: a tight halo holding the letter off whatever it
        // sits on, be that cloth, a photograph or a dark spine. Tight is the
        // whole of it. A wide drop shadow, and worse a light one above the
        // letter to answer it, turns a stamped title into word art with a
        // bevel, which is what the first attempt at this looked like.
        //
        // Set in the laid-out space, which is a thousand times the book, so
        // these are thousandths of the height of the book.
        //
        // No blur radius. A blurred shadow is a blur pass, and this title is
        // redrawn once per facet of the bow - twenty times a book, five books
        // to a shelf - so the softness nobody can see at this size was costing
        // a hundred blur passes a frame. Offset alone still lifts the letter
        // off the cloth, and the glyphs are already in the atlas.
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.38),
            offset: const Offset(1.0, 1.2),
          ),
        ],
      ),
      titleSize,
      size.height * 0.52,
      maxLines: lines,
      ellipsis: true,
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.39);
    canvas.rotate(-math.pi / 2);
    _drawText(canvas, titleRun, Offset.zero);
    canvas.restore();

    if (spec.author.trim().isNotEmpty) {
      final authorRun = _text(
        spec.author,
        spec.typography.label.copyWith(
          color: ink,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.34),
              offset: const Offset(0.8, 1.0),
            ),
          ],
        ),
        math.min(_unit * 0.030, across * 0.62),
        // Nearly a third of the spine. A quarter of it ellipsed most real
        // names on the phone - every author on the shelf came out as
        // "Hajime Kamos…" - and a name cut short is worse than no name, because
        // it reads as a fault rather than as an omission.
        size.height * 0.30,
        ellipsis: true,
      );
      canvas.save();
      canvas.translate(size.width / 2, size.height * 0.79);
      canvas.rotate(-math.pi / 2);
      _drawText(canvas, authorRun, Offset.zero);
      canvas.restore();
    }
  }

  /// The paper seen edge on.
  void _paintPaperEdge(
    Canvas canvas,
    Size size,
    double shade, {
    required bool across,
  }) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: across ? Alignment.topCenter : Alignment.centerLeft,
          end: across ? Alignment.bottomCenter : Alignment.centerRight,
          colors: [
            Color.lerp(palette.pageEdge, Colors.black, 0.16)!,
            palette.pageEdge,
            Color.lerp(palette.pageEdge, Colors.white, 0.10)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );

    // The leaves themselves. They run across the thickness, so they follow
    // whichever axis of this edge the thickness is on.
    final paint = Paint()..strokeWidth = _unit * 0.0007;
    final span = across ? size.height : size.width;
    final count = math.max(6, (span / (_unit * 0.0032)).round());
    var noise = (_seed ^ (across ? 0x9E37 : 0x5F1B)) | 1;
    for (var index = 0; index < count; index++) {
      noise = (noise * 1103515245 + 12345) & 0x7FFFFFFF;
      final t = (index + 0.5) / count;
      paint.color = Colors.black.withValues(alpha: 0.05 + (noise % 7) * 0.014);
      if (across) {
        canvas.drawLine(
          Offset(0, size.height * t),
          Offset(size.width, size.height * t),
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(size.width * t, 0),
          Offset(size.width * t, size.height),
          paint,
        );
      }
    }

    // The silk roll at the head and the tail of a cased spine. It sits on the
    // paper at the spine end of the edge, which is where it is on the object.
    if (profile.headbands && across) {
      final band = Rect.fromLTWH(0, 0, _unit * 0.013, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(band, Radius.circular(size.height * 0.45)),
        Paint()..color = palette.headband,
      );
      final stripe = Paint()..strokeWidth = _unit * 0.0011;
      for (var index = 0; index < 5; index++) {
        stripe.color = index.isEven
            ? Colors.white.withValues(alpha: 0.50)
            : Colors.black.withValues(alpha: 0.24);
        final y = size.height * (index + 0.5) / 5;
        canvas.drawLine(Offset(0, y), Offset(band.right, y), stripe);
      }
    }
  }

  /// The bound edge of the block: the folds of the gathered sheets, the glue,
  /// and the silk roll at each end of a cased book.
  void _paintBoundEdge(Canvas canvas, Size size, double shade) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.lerp(palette.pageEdge, Colors.black, 0.34)!,
            Color.lerp(palette.pageEdge, Colors.black, 0.16)!,
            Color.lerp(palette.pageEdge, Colors.black, 0.34)!,
          ],
        ).createShader(rect),
    );

    // The folds, running down the block.
    final fold = Paint()
      ..strokeWidth = _unit * 0.0008
      ..color = Colors.black.withValues(alpha: 0.22);
    final count = math.max(3, (size.height / (_unit * 0.06)).round());
    for (var index = 1; index < count; index++) {
      final y = size.height * index / count;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fold);
    }

    if (profile.headbands) {
      final band = _unit * 0.013;
      for (final top in [0.0, size.height - band]) {
        canvas.drawRect(
          Rect.fromLTWH(0, top, size.width, band),
          Paint()..color = palette.headband,
        );
      }
    }
  }

  void _paintPlainPaper(Canvas canvas, Size size, double shade) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.paper);
  }

  /// The first page, seen once the cover lifts.
  void _paintTopPage(Canvas canvas, Size size, double shade) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = palette.paper);

    // The valley beside the spine, where the paper turns down into the gutter.
    final gutter = Rect.fromLTWH(0, 0, size.width * 0.16, size.height);
    canvas.drawRect(
      gutter,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.28),
            Colors.black.withValues(alpha: 0),
          ],
        ).createShader(gutter),
    );

    _paintForeEdgeShade(canvas, size);

    final margin = size.width * 0.18;
    _drawText(
      canvas,
      _text(
        spec.title,
        spec.typography.title.copyWith(color: palette.paperInk, height: 1.16),
        _unit * 0.036,
        size.width - margin * 2,
        maxLines: 4,
      ),
      Offset(rect.center.dx, size.height * 0.34),
    );

    canvas.drawLine(
      Offset(rect.center.dx - size.width * 0.12, size.height * 0.54),
      Offset(rect.center.dx + size.width * 0.12, size.height * 0.54),
      Paint()
        ..strokeWidth = _unit * 0.0014
        ..color = palette.paperInk.withValues(alpha: 0.5),
    );

    if (spec.author.trim().isNotEmpty) {
      _drawText(
        canvas,
        _text(
          spec.author,
          spec.typography.author.copyWith(
            color: palette.paperInk.withValues(alpha: 0.78),
          ),
          _unit * 0.021,
          size.width - margin * 2,
          maxLines: 2,
        ),
        Offset(rect.center.dx, size.height * 0.62),
      );
    }
  }

  /// A leaf on its way up.
  ///
  /// Paper is thin enough to be read from both sides, so a leaf is drawn the
  /// same either way and the renderer shades it. What makes a fan of them read
  /// as paper rather than as a stack of cards is the fore-edge: each leaf lays
  /// a line of shadow on the one below it, and each is a shade deeper than the
  /// one above.
  void _paintLeaf(
    Canvas canvas,
    Size size,
    int index, {
    required double offset,
    required double total,
  }) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-offset, 0);
    final whole = Size(total, size.height);
    canvas.drawRect(
      Offset.zero & whole,
      Paint()
        ..color = Color.lerp(palette.paper, palette.pageEdge, 0.16 * index)!,
    );
    final gutter = Rect.fromLTWH(0, 0, total * 0.14, size.height);
    canvas.drawRect(
      gutter,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0),
          ],
        ).createShader(gutter),
    );
    _paintForeEdgeShade(canvas, whole);
    canvas.restore();
  }

  /// The band of shade a leaf carries along its free edge, and the line of the
  /// cut itself.
  void _paintForeEdgeShade(Canvas canvas, Size size) {
    final band =
        Rect.fromLTWH(size.width * 0.90, 0, size.width * 0.10, size.height);
    canvas
      ..drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.16),
            ],
          ).createShader(band),
      )
      ..drawLine(
        Offset(size.width, 0),
        Offset(size.width, size.height),
        Paint()
          ..strokeWidth = _unit * 0.0022
          ..color = Color.lerp(palette.pageEdge, Colors.black, 0.35)!,
      );
  }

  void _paintBoardEdge(Canvas canvas, Size size, double shade) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = palette.boardCore);
    // The cover material wraps over the edge, so the outer sliver is cloth and
    // the inner sliver is the turn-in, with the board's grey core between.
    final skin = math.min(size.shortestSide * 0.34, _unit * 0.0035);
    final cloth = Paint()..color = palette.clothDeep;
    if (size.width > size.height) {
      canvas
        ..drawRect(Rect.fromLTWH(0, 0, size.width, skin), cloth)
        ..drawRect(
          Rect.fromLTWH(0, size.height - skin, size.width, skin),
          cloth,
        );
    } else {
      canvas
        ..drawRect(Rect.fromLTWH(0, 0, skin, size.height), cloth)
        ..drawRect(
            Rect.fromLTWH(size.width - skin, 0, skin, size.height), cloth);
    }
    canvas.drawRect(
        rect, Paint()..color = Colors.black.withValues(alpha: 0.06));
  }

  // ------------------------------------------------------------------- text

  /// Text is laid out at a fixed multiple of the book unit and drawn back down
  /// through a matching inverse scale, because 0.03 is not a font size any
  /// layout engine will honour. Laying out large and drawing small also keeps
  /// the type crisp: it is only ever scaled down.
  static const double textScale = 1000;

  BookTextRun _text(
    String content,
    TextStyle style,
    double fontSize,
    double maxWidth, {
    int maxLines = 1,
    TextAlign align = TextAlign.center,
    bool ellipsis = false,
  }) {
    return BookTextRun.resolve(
      content: content,
      style: style.copyWith(fontSize: fontSize),
      maxWidth: maxWidth,
      maxLines: maxLines,
      align: align,
      ellipsis: ellipsis,
      scale: textScale,
    );
  }

  void _drawText(
    Canvas canvas,
    BookTextRun run,
    Offset at, {
    bool centred = true,
  }) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1 / textScale);
    final painter = run.painter;
    painter.paint(
      canvas,
      centred ? Offset(-painter.width / 2, -painter.height / 2) : Offset.zero,
    );
    canvas.restore();
  }
}

/// A laid-out run of type, kept between frames.
///
/// Laying text out is the expensive part of drawing this model, and the model
/// redraws on every frame of an opening. The layout depends only on the
/// content, the style and the width, none of which change while a cover
/// swings, so it is done once and held.
class BookTextRun {
  BookTextRun(this.painter);

  final TextPainter painter;

  static final Map<String, BookTextRun> _cache = {};

  @visibleForTesting
  static void debugClear() => _cache.clear();

  @visibleForTesting
  static int get debugCount => _cache.length;

  @visibleForTesting
  static int get debugLimit => _cacheLimit;
  /// Enough for every run on the screen several times over.
  ///
  /// A shelf draws about nineteen books, and each sets a title and an author:
  /// forty runs live at once, and the reader can climb to another shelf without
  /// the ones behind them going cold. Ninety-six held about two screens' worth,
  /// which is the wrong side of the line for anybody with a real library.
  static const int _cacheLimit = 320;

  static BookTextRun resolve({
    required String content,
    required TextStyle style,
    required double maxWidth,
    required int maxLines,
    required TextAlign align,
    required bool ellipsis,
    required double scale,
  }) {
    final key = '$content|${style.hashCode}|${(maxWidth * scale).round()}'
        '|$maxLines|${align.index}|$ellipsis';
    final cached = _cache.remove(key);
    if (cached != null) {
      // Put back at the young end. A plain `Map` in Dart keeps its insertion
      // order, so removing and re-inserting on a hit is all least-recently-used
      // takes, and it is what keeps the books actually on the screen from being
      // the ones thrown away.
      _cache[key] = cached;
      return cached;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: content,
        style: style.copyWith(fontSize: (style.fontSize ?? 0.02) * scale),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
      ellipsis: ellipsis ? '…' : null,
    )..layout(maxWidth: maxWidth * scale);

    // The oldest one goes, not all of them.
    //
    // This used to empty the whole cache the moment it was one over, and laying
    // out type is the most expensive thing this model does. A shelf shows about
    // nineteen books and each one sets a title and an author, so any library
    // past a few dozen books overran the limit while scrolling and threw away
    // every run it was about to need: the next frame re-laid out some forty
    // runs at once, and it did it again a few books later, for as long as the
    // reader kept moving. That is a hitch every second or two, and it only ever
    // showed on a real library.
    while (_cache.length >= _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
    final run = BookTextRun(painter);
    _cache[key] = run;
    return run;
  }
}
