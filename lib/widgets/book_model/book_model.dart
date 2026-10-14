import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/service/book_art.dart';
import 'package:paperfold/widgets/book_model/book_model_builder.dart';
import 'package:paperfold/widgets/book_model/book_model_scene.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';

/// Draws a book as a solid object, seen from a fixed three-quarter view.
///
/// Every surface is a real face in book space: the front board, the spine, the
/// back board, the three cut edges of the paper, and the inside of both boards.
/// The renderer sorts them by depth, hides the ones turned away from the
/// camera, and lights them all from one direction. That is what makes the
/// object read as a book rather than as a cover with a strip glued to its
/// side, and it is what lets the cover swing open over the page without any
/// of the usual sleight of hand.
abstract final class BookModelRenderer {
  /// Room left round the object, so a shadow has somewhere to fall and a book
  /// never touches the edge of the space it was given.
  static const double fitSlack = 1.06;

  /// The light a face gets when it is turned away from the key light.
  ///
  /// A book in a room is never truly unlit: the page it is lying on throws
  /// light back at it. Too little ambient and an open cover turns into a black
  /// slab; too much and the object flattens.
  static const double ambient = 0.46;

  static void paint(
    Canvas canvas,
    Size box,
    BookModelSpec spec, {
    bool mirror = false,
  }) {
    if (box.isEmpty) return;
    final faces = BookModelBuilder.build(spec);
    if (faces.isEmpty) return;

    final projection = viewOf(spec);
    // A book standing in a row is placed by the row, not by itself. Its own
    // middle goes in the middle of the box at the scale every book on the
    // shelf shares, and the outline is neither measured nor consulted.
    final row = spec.rowScale;
    final extent = row == null ? extentOf(faces, projection) : Rect.zero;
    if (row == null && extent.isEmpty) return;
    final scale = row ??
        math.min(
          box.width / (extent.width * fitSlack),
          box.height / (extent.height * fitSlack),
        );

    canvas.save();
    if (mirror) {
      // The book is built one way and the whole scene is turned over, so a
      // right-to-left shelf gets its spine on the trailing side. Each face
      // turns its own content back, below, so the artwork still reads.
      canvas
        ..translate(box.width, 0)
        ..scale(-1, 1);
    }

    // The object is measured where it stands and then placed in the middle of
    // the box. A cover swinging open changes the object's outline every frame,
    // so anything short of measuring it would either crop the cover or leave a
    // hole where it used to be.
    final view = Matrix4.identity()
      ..translateByDouble(
        box.width / 2 - (row == null ? extent.center.dx * scale : 0),
        box.height / 2 - (row == null ? extent.center.dy * scale : 0),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1)
      ..multiply(projection);

    // A face paints this far past its own edge, in book units, to cover the
    // hairline antialiasing leaves between two faces that meet.
    final bleed = 1.4 / math.max(scale, 1);
    final dim = spec.dim.clamp(0.0, 1.0);

    for (final entry in order(faces, spec.camera)) {
      final face = entry.face;
      final size = Size(face.width, face.height);
      canvas.save();
      canvas.transform((view * face.modelMatrix).storage);
      if (mirror) {
        canvas
          ..translate(face.width, 0)
          ..scale(-1, 1);
      }
      final skirt = face.bleed;
      // The light has to cover everything the face draws, which is its own
      // rectangle, the skirt outside it, and the seam one facet of a curve
      // paints over its neighbours.
      final spillX = math.max(skirt == null ? 0.0 : bleed, face.seam);
      final spillY = skirt == null ? 0.0 : bleed;
      final lit = Rect.fromLTWH(
        -spillX,
        -spillY,
        face.width + spillX * 2,
        face.height + spillY * 2,
      );
      if (skirt != null) {
        canvas.drawRect(lit, Paint()..color = skirt);
      }
      face.paint(canvas, size, entry.shade);
      if (face.lit) {
        _light(canvas, lit, entry, width: face.width, flipped: mirror);
      }
      // The scrim a book takes for standing further down the row, laid on each
      // face as it is drawn. Every visible pixel belongs to exactly one face,
      // so darkening them one at a time is the same picture as darkening the
      // finished object — without the offscreen pass that would cost.
      if (dim > 0) {
        canvas.drawRect(
          lit,
          Paint()..color = Colors.black.withValues(alpha: dim),
        );
      }
      canvas.restore();
    }
    canvas.restore();
  }

  /// Lays the light over a face that has already drawn its own content.
  ///
  /// A flat face takes one wash. A facet of a curve takes a wash that changes
  /// from one edge to the other, because that is what the curve does, and a
  /// constant wash per facet is exactly what makes a bowed spine look like a
  /// folded strip: the eye finds every joint at once. Two washes rather than
  /// one blend of the two, so a facet that runs from shadow into highlight
  /// passes through nothing instead of through grey.
  static void _light(
    Canvas canvas,
    Rect lit,
    BookDrawable entry, {
    required double width,
    required bool flipped,
  }) {
    if (!entry.isShaded) {
      final shade = entry.shade;
      final dark = _darkOver(shade);
      if (dark > 0) {
        canvas.drawRect(
          lit,
          Paint()..color = Colors.black.withValues(alpha: dark),
        );
      }
      final bright = _brightOver(shade);
      if (bright > 0) {
        canvas.drawRect(
          lit,
          Paint()..color = Colors.white.withValues(alpha: bright),
        );
      }
      return;
    }

    // The content of a face is drawn back the right way round on a mirrored
    // shelf, so this rectangle's own x runs against the face's u there.
    final from = flipped ? entry.shadeEnd : entry.shadeStart;
    final to = flipped ? entry.shadeStart : entry.shadeEnd;
    // The wash covers the seam as well as the face, so the two ends of the
    // gradient sit outside the face's own edges. Carrying the same slope on
    // past them keeps the light at the real edges of the facet exactly what the
    // curve says it is, and hands the neighbouring facet a value that continues
    // its own.
    final reach = width <= 0 ? 0.0 : (lit.width - width) / (2 * width);
    double out(double near, double far) =>
        (near - (far - near) * reach).clamp(0.0, 1.0);
    _wash(
      canvas,
      lit,
      Colors.black,
      out(_darkOver(from), _darkOver(to)),
      out(_darkOver(to), _darkOver(from)),
    );
    _wash(
      canvas,
      lit,
      Colors.white,
      out(_brightOver(from), _brightOver(to)),
      out(_brightOver(to), _brightOver(from)),
    );
  }

  /// The difference in light across one facet that is worth a gradient.
  ///
  /// Below it the two ends are the same wash to the eye, and a gradient there
  /// buys nothing and costs a shader. A book carries about thirty facets and a
  /// shelf carries five books, so this is the difference between four shaders a
  /// frame and a hundred and fifty of them.
  static const double _washStep = 0.012;

  static void _wash(
    Canvas canvas,
    Rect lit,
    Color ink,
    double from,
    double to,
  ) {
    if (from <= 0 && to <= 0) return;
    if ((from - to).abs() < _washStep) {
      canvas.drawRect(
        lit,
        Paint()..color = ink.withValues(alpha: (from + to) / 2),
      );
      return;
    }
    canvas.drawRect(
      lit,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            ink.withValues(alpha: from),
            ink.withValues(alpha: to),
          ],
        ).createShader(lit),
    );
  }

  static double _darkOver(double shade) =>
      shade >= 0.99 ? 0 : math.min(0.38, (1 - shade) * 0.58);

  static double _brightOver(double shade) =>
      shade <= 0.93 ? 0 : (shade - 0.93) * 0.55;

  /// The camera looking at one book, with the book's own centre at the origin.
  ///
  /// Everything up to the perspective divide, and nothing after it: where the
  /// object then lands on the screen is [paint]'s business.
  static Matrix4 viewOf(BookModelSpec spec) {
    final metrics = BookMetrics.from(spec.profile, spec.seed);
    return Matrix4.identity()
      ..multiply(spec.camera.projection)
      ..multiply(spec.camera.rotation)
      ..translateByDouble(
        -metrics.boardWidth / 2,
        0,
        -metrics.totalDepth / 2,
        1,
      );
  }

  /// The outline the object casts on the screen, in projected units.
  ///
  /// Measured from the corners of the faces themselves, so it is right for a
  /// shut book, a book at any angle of opening, and any camera. Shadows are
  /// left out: a shadow is allowed to fall outside the object, and letting it
  /// vote would shrink the book to make room for its own blur.
  static Rect extentOf(List<BookFace> faces, Matrix4 projection) {
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;

    for (final face in faces) {
      if (!face.lit) continue;
      for (final corner in [
        face.origin,
        face.origin + face.u * face.width,
        face.origin + face.v * face.height,
        face.origin + face.u * face.width + face.v * face.height,
      ]) {
        final point = applyMatrix(projection, corner);
        if (point.w <= 0) continue;
        final x = point.x / point.w;
        final y = point.y / point.w;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    if (left > right || top > bottom) return Rect.zero;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// The faces the camera can see, nearest last, each with its lighting term.
  ///
  /// A face turned away from the camera is dropped: a book is solid, and the
  /// far side of a board is not a thing anyone can see through it. Paper is
  /// the exception, because a leaf is thin enough to be read from both sides.
  ///
  /// The order is by depth, which is what makes the spine sit behind the
  /// boards, the boards hide the paper, and a lifted cover pass in front of
  /// the page it just uncovered, with no special cases for any of it.
  static List<BookDrawable> order(List<BookFace> faces, BookCamera camera) {
    final rotation = camera.rotation;
    final light = kBookLight.normalized;
    final drawable = <BookDrawable>[];
    for (final face in faces) {
      final normal = _rotate(rotation, face.normal);
      if (!face.doubleSided && normal.z <= 0) continue;
      final lambert = normal.dot(light);
      final key = face.doubleSided ? lambert.abs() : math.max(0.0, lambert);
      final anchor = face.depthAnchor;
      // A facet of a curve carries the normals the curve has at its two ends,
      // and is lit from those rather than from its own flat one.
      final startNormal = face.normalAtStart;
      final endNormal = face.normalAtEnd;
      drawable.add(
        BookDrawable(
          face: face,
          depth: (anchor == null
                  ? _nearestDepth(rotation, face)
                  : applyMatrix(rotation, anchor).z) +
              face.depthBias,
          shade: ambient + (1 - ambient) * key,
          shadeStart: startNormal == null
              ? null
              : _shadeOf(rotation, light, startNormal, face.doubleSided),
          shadeEnd: endNormal == null
              ? null
              : _shadeOf(rotation, light, endNormal, face.doubleSided),
        ),
      );
    }
    drawable.sort((a, b) => a.depth.compareTo(b.depth));
    return drawable;
  }

  /// How near to the camera a face comes at its nearest corner.
  ///
  /// The middle of a face is the obvious thing to sort by and the wrong one. A
  /// book is a sandwich of parallel faces that all meet at the spine, and once
  /// the object is turned far enough, the small differences in width across
  /// that sandwich outweigh the differences in thickness: the first page then
  /// sorts in front of the board lying on top of it. Their nearest corners sit
  /// on the hinge, where only the thickness separates them, so the sandwich
  /// always stacks in the right order.
  static double _nearestDepth(Matrix4 rotation, BookFace face) {
    var nearest = double.negativeInfinity;
    for (final corner in [
      face.origin,
      face.origin + face.u * face.width,
      face.origin + face.v * face.height,
      face.origin + face.u * face.width + face.v * face.height,
    ]) {
      final z = applyMatrix(rotation, corner).z;
      if (z > nearest) nearest = z;
    }
    return nearest;
  }

  /// The light one surface normal takes, in the same terms as [order].
  static double _shadeOf(
    Matrix4 rotation,
    BookVector light,
    BookVector direction,
    bool doubleSided,
  ) {
    final lambert = _rotate(rotation, direction).dot(light);
    final key = doubleSided ? lambert.abs() : math.max(0.0, lambert);
    return ambient + (1 - ambient) * key;
  }

  static BookVector _rotate(Matrix4 matrix, BookVector direction) {
    final s = matrix.storage;
    return BookVector(
      s[0] * direction.x + s[4] * direction.y + s[8] * direction.z,
      s[1] * direction.x + s[5] * direction.y + s[9] * direction.z,
      s[2] * direction.x + s[6] * direction.y + s[10] * direction.z,
    ).normalized;
  }
}

/// Opens and closes a [BookModel] from outside it.
class BookModelController extends ChangeNotifier {
  _BookModelState? _state;

  bool get isOpen => _state?.isOpen ?? false;

  /// How far open the book is now, from 0 to 1.
  double get value => _state?.openValue ?? 0;

  Future<void> open() async => _state?.animateTo(true);

  Future<void> close() async => _state?.animateTo(false);

  Future<void> toggle() async => _state?.animateTo(!isOpen);

  /// True when the reader is looking at the back of the book.
  bool get isTurnedOver => _state?.isTurnedOver ?? false;

  /// Turns the book over, so the back board comes round to the reader.
  Future<void> turnOver() async => _state?.turnTo(!isTurnedOver);

  void _attach(_BookModelState state) {
    _state = state;
  }

  void _detach(_BookModelState state) {
    if (identical(_state, state)) _state = null;
  }

  void _notify() => notifyListeners();
}

/// A book, drawn in three dimensions, that opens and closes.
class BookModel extends StatefulWidget {
  const BookModel({
    super.key,
    required this.title,
    required this.author,
    required this.binding,
    this.blurb,
    this.coverPath,
    this.stableId,
    this.controller,
    this.open,
    this.openAt = 0,
    this.onTap,
    this.semanticLabel,
    this.camera = const BookCamera(),
    this.detail = BookDetail.full,
    this.rowScale,
    this.dim = 0,
    this.showDropShadow = true,
    this.tapToOpen = true,
    this.dragToOpen = true,
    this.turnToSeeBack = true,
    this.turnHint,
  });

  final String title;
  final String author;

  /// The blurb printed on a softback's back cover.
  final String? blurb;

  /// The book's cover file. Absent, or missing on disk, and the model prints
  /// its own cover on the binding's cloth instead.
  final String? coverPath;

  /// Fixes the thickness, the bands and the cloth. Two books with the same id
  /// are the same book, on this run and on every other.
  final String? stableId;

  final BookBinding binding;

  /// Drives the book from outside. Leave it null and the book keeps its own
  /// state, which a tap or a drag changes.
  final BookModelController? controller;

  /// Fixes the opening, from 0 to 1, and turns off every interaction. Use it
  /// to tie the book to another animation.
  final double? open;

  /// Where through the paper the book opens, from 0 to 1.
  ///
  /// 0 is the front cover, which is where a book nobody has started opens. A
  /// reader halfway through opens their book halfway through, with the read
  /// part lifting away in one gathered piece, and 1 lifts the whole block off
  /// the back board, which is the picture of a book being shut on its last
  /// page rather than opened at its first.
  final double openAt;

  /// Called on a tap, after the book has started to open.
  final VoidCallback? onTap;

  final String? semanticLabel;
  final BookCamera camera;

  /// How finely the curved surfaces are cut into flats. Drop it for a book
  /// drawn small: the facets cost a run of the painter apiece.
  final BookDetail detail;

  /// The scale this book is drawn at when it stands in a row with others.
  ///
  /// See [BookModelSpec.rowScale]. Null for a book on its own, which measures
  /// itself and fills the space it was given.
  final double? rowScale;

  /// How far this book is darkened for standing further down a row.
  ///
  /// See [BookModelSpec.dim]. Painted into the object, not laid over it.
  final double dim;

  final bool showDropShadow;
  final bool tapToOpen;
  final bool dragToOpen;

  /// Whether a long press turns the book over.
  ///
  /// The back of a book is a real surface with real matter on it - the blurb,
  /// the device, the barcode on a paperback, the blind-stamped rule on a cased
  /// board - and a camera that can never reach it makes all of that a rumour.
  final bool turnToSeeBack;

  /// What a long press does, for the screen reader.
  final String? turnHint;

  /// How long a cover takes to swing open, and to fall shut.
  static const Duration openDuration = Duration(milliseconds: 720);
  static const Duration closeDuration = Duration(milliseconds: 560);

  /// How long the book takes to come round to its back and back again.
  static const Duration turnDuration = Duration(milliseconds: 620);

  @override
  State<BookModel> createState() => _BookModelState();
}

class _BookModelState extends State<BookModel> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _opening;
  late final AnimationController _turning;
  late final CurvedAnimation _turned;
  BookArt? _art;
  String? _artPath;
  bool _artMirror = false;
  bool _dragging = false;

  bool get isOpen => _controller.value > 0.5;

  double get openValue => _controller.value;

  bool get isTurnedOver => _turning.value > 0.5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: BookModel.openDuration,
      reverseDuration: BookModel.closeDuration,
      value: widget.open ?? 0,
    );
    _opening = CurvedAnimation(
      parent: _controller,
      curve: const _CoverLift(),
      reverseCurve: const _CoverLanding(),
    );
    _turning = AnimationController(
      vsync: this,
      duration: BookModel.turnDuration,
    );
    _turned = CurvedAnimation(parent: _turning, curve: Curves.easeInOutCubic);
    widget.controller?._attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadArt();
  }

  @override
  void didUpdateWidget(covariant BookModel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.coverPath != widget.coverPath) {
      _art = null;
      _artPath = null;
      _loadArt();
    }
    final target = widget.open;
    if (target != null && target != _controller.value) {
      _controller.value = target.clamp(0.0, 1.0);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _opening.dispose();
    _turned.dispose();
    _turning.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Art already decoded is taken at once, so a book that has been seen never
  /// blinks back to its printed cover while a page rebuilds.
  void _loadArt() {
    final path = widget.coverPath;
    final mirror = Directionality.of(context) == TextDirection.rtl;
    if (path == null || path.isEmpty) return;
    if (_artPath == path && _artMirror == mirror) return;
    _artPath = path;
    _artMirror = mirror;

    final ready = BookArtCache.peek(path);
    if (ready != null) {
      _art = ready;
      return;
    }
    BookArtCache.load(path, mirror: mirror).then((art) {
      if (!mounted || art == null || _artPath != path) return;
      setState(() => _art = art);
    });
  }

  Future<void> animateTo(bool open) async {
    if (widget.open != null || !mounted) return;
    // When the system removes animations, a book still opens and closes. It
    // just does it in one frame.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = open ? 1 : 0;
      widget.controller?._notify();
      return;
    }
    await (open ? _controller.forward() : _controller.reverse());
    if (mounted) widget.controller?._notify();
  }

  /// Brings the back board round to the reader, or sends it away again.
  Future<void> turnTo(bool back) async {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _turning.value = back ? 1 : 0;
      widget.controller?._notify();
      return;
    }
    await (back ? _turning.forward() : _turning.reverse());
    if (mounted) widget.controller?._notify();
  }

  void _handleLongPress() {
    if (!widget.turnToSeeBack) return;
    turnTo(!isTurnedOver);
  }

  void _handleTap() {
    widget.onTap?.call();
    if (widget.tapToOpen) animateTo(!isOpen);
  }

  void _handleDragUpdate(DragUpdateDetails details, double width, bool mirror) {
    if (width <= 0) return;
    _dragging = true;
    // Dragging the cover toward the spine opens the book.
    final direction = mirror ? 1.0 : -1.0;
    _controller.value =
        (_controller.value + direction * details.delta.dx / (width * 0.9))
            .clamp(0.0, 1.0);
  }

  void _handleDragEnd(DragEndDetails details, double width, bool mirror) {
    if (!_dragging) return;
    _dragging = false;
    final velocity = details.velocity.pixelsPerSecond.dx * (mirror ? 1 : -1);
    if (velocity.abs() > 320) {
      animateTo(velocity > 0);
    } else {
      animateTo(_controller.value > 0.42);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mirror = Directionality.of(context) == TextDirection.rtl;
    final seed = BookSpine.stableHash(
      widget.stableId ?? '${widget.title}|${widget.author}',
    );
    final palette = BookModelPalette.resolve(
      scheme: theme.colorScheme,
      binding: widget.binding,
      art: _art,
      seed: seed,
    );
    final spec = BookModelSpec(
      binding: widget.binding,
      title: widget.title,
      author: widget.author,
      blurb: widget.blurb,
      art: _art,
      palette: palette,
      typography: BookModelTypography.of(context),
      seed: seed,
      openAt: widget.openAt.clamp(0.0, 1.0),
      camera: widget.camera,
      detail: widget.detail,
      showDropShadow: widget.showDropShadow,
      rowScale: widget.rowScale,
      dim: widget.dim,
    );

    final fixed = widget.open;
    final interactive =
        fixed == null && (widget.tapToOpen || widget.onTap != null);
    final canTurn = fixed == null && widget.turnToSeeBack;
    final canDrag = fixed == null && widget.dragToOpen;

    final surface = RepaintBoundary(
      child: CustomPaint(
        painter: _BookModelPainter(
          spec: spec,
          opening: _opening,
          turning: _turned,
          mirror: mirror,
          fixedOpen: fixed,
        ),
        size: Size.infinite,
      ),
    );

    // A book nobody can touch is the picture and nothing else.
    //
    // The gesture detector and the layout builder are both here for the drag
    // that opens a cover, which needs to know how wide the book is. A shelf
    // draws about nineteen books and turns every one of those off, and a
    // `LayoutBuilder` is not free to keep anyway: it builds inside the layout
    // phase, so nineteen of them put nineteen build callbacks in the middle of
    // every frame of a scroll for a width nothing was going to read.
    Widget body = surface;
    if (canDrag) {
      body = LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : constraints.maxHeight * 0.8;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: interactive ? _handleTap : null,
            onLongPress: canTurn ? _handleLongPress : null,
            onHorizontalDragUpdate: (details) =>
                _handleDragUpdate(details, width, mirror),
            onHorizontalDragEnd: (details) =>
                _handleDragEnd(details, width, mirror),
            child: surface,
          );
        },
      );
    } else if (interactive || canTurn) {
      body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? _handleTap : null,
        onLongPress: canTurn ? _handleLongPress : null,
        child: surface,
      );
    }

    return Semantics(
      button: interactive,
      image: !interactive,
      label: widget.semanticLabel,
      onTap: interactive ? _handleTap : null,
      onLongPress: canTurn ? _handleLongPress : null,
      onLongPressHint: canTurn ? widget.turnHint : null,
      excludeSemantics: true,
      child: body,
    );
  }
}

class _BookModelPainter extends CustomPainter {
  _BookModelPainter({
    required this.spec,
    required this.opening,
    required this.turning,
    required this.mirror,
    this.fixedOpen,
  }) : super(repaint: Listenable.merge([opening, turning]));

  final BookModelSpec spec;
  final Animation<double> opening;

  /// 0 with the front board to the reader, 1 with the back board round.
  final Animation<double> turning;

  final bool mirror;

  /// Set when the caller drives the opening itself. The curve belongs to the
  /// book's own gesture, not to somebody else's timeline.
  final double? fixedOpen;

  @override
  void paint(Canvas canvas, Size size) {
    // Turning the book over is a turn of the object, not a move of the camera
    // rig: the light stays where it is and the far side comes round into it.
    final camera = turning.value == 0
        ? spec.camera
        : spec.camera.copyWith(
            yaw: spec.camera.yaw + math.pi * turning.value,
          );
    BookModelRenderer.paint(
      canvas,
      size,
      spec.copyWith(open: fixedOpen ?? opening.value, camera: camera),
      mirror: mirror,
    );
  }

  @override
  bool shouldRepaint(covariant _BookModelPainter oldDelegate) {
    return oldDelegate.mirror != mirror ||
        oldDelegate.fixedOpen != fixedOpen ||
        // The camera is not decoration: a book turning from its spine to its
        // cover changes nothing else about itself, and a delegate that ignores
        // the camera holds that book still while the caller animates it.
        oldDelegate.spec.camera.yaw != spec.camera.yaw ||
        oldDelegate.spec.camera.pitch != spec.camera.pitch ||
        oldDelegate.spec.camera.focalLength != spec.camera.focalLength ||
        oldDelegate.spec.showDropShadow != spec.showDropShadow ||
        oldDelegate.spec.dim != spec.dim ||
        // The scale a book is drawn at when it stands in a row. It was missing,
        // and it decides the size of the object: a row whose scale changed
        // under it kept drawing every book at the old one until some other
        // field happened to change and force the repaint.
        oldDelegate.spec.rowScale != spec.rowScale ||
        oldDelegate.spec.detail != spec.detail ||
        oldDelegate.spec.openAt != spec.openAt ||
        oldDelegate.spec.binding != spec.binding ||
        oldDelegate.spec.title != spec.title ||
        oldDelegate.spec.author != spec.author ||
        oldDelegate.spec.blurb != spec.blurb ||
        oldDelegate.spec.seed != spec.seed ||
        !identical(oldDelegate.spec.art, spec.art) ||
        oldDelegate.spec.palette != spec.palette;
  }
}

/// The way a cover swings open: away fast, then a small overshoot as the board
/// passes the point it settles at, and back.
class _CoverLift extends Curve {
  const _CoverLift();

  @override
  double transformInternal(double t) {
    final base = Curves.easeOutCubic.transform(t);
    if (t < 0.55) return base;
    final phase = (t - 0.55) / 0.45;
    return base + math.sin(phase * math.pi) * 0.055 * (1 - phase * 0.65);
  }
}

/// The way a cover falls shut: it lands on the block, lifts a little, and
/// settles. A cover that simply stops reads as a lid, not as paper and board.
class _CoverLanding extends Curve {
  const _CoverLanding();

  static const double _window = 0.30;

  @override
  double transformInternal(double t) {
    final base = Curves.easeInCubic.transform(t);
    if (t >= _window) return base;
    final phase = t / _window;
    final rebound = math.sin(phase * math.pi) * 0.085 * (1 - phase);
    return math.min(1, base + rebound);
  }
}
