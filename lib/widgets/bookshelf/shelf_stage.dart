import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/widgets/book_model/book_model.dart';
import 'package:paperfold/widgets/book_model/book_model_builder.dart';
import 'package:paperfold/widgets/book_model/book_model_scene.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/widgets/bookshelf/shelf_plane.dart';
import 'package:paperfold/widgets/book_opening_page.dart';

/// One book, as the stage needs to know it.
///
/// Deliberately not [Book]. The stage draws wishlist entries and demonstration
/// books as readily as library rows, and a view model keeps the database out
/// of a widget whose whole job is motion.
@immutable
class ShelfBook {
  const ShelfBook({
    required this.id,
    required this.title,
    required this.author,
    required this.binding,
    this.blurb,
    this.coverPath,
    this.progress = 0,
    this.finished = false,
  });

  final String id;
  final String title;
  final String author;
  final String? blurb;
  final String? coverPath;
  final BookBinding binding;

  /// How far through the book the reader has got, from 0 to 1.
  ///
  /// This is what decides where the book opens. A book nobody has started
  /// opens at its first page; a book somebody is halfway through opens where
  /// they left off, with the read half lifting away in one piece.
  final double progress;

  /// Whether the reader has finished it. A finished book is not a book open at
  /// its last page: it is a book being shut.
  final bool finished;

  /// Where through the block the opening happens.
  double get openAt => finished ? 1.0 : progress.clamp(0.0, 1.0);
}

/// One shelf of the bookcase: a name and the books standing on it.
@immutable
class ShelfRow {
  const ShelfRow({required this.name, required this.books});

  /// Printed on the front edge of this shelf's board.
  final String name;

  final List<ShelfBook> books;

  bool get isEmpty => books.isEmpty;
}

/// What the stage is doing.
enum ShelfPhase {
  /// The books stand in a row. A horizontal drag runs through them.
  shelved,

  /// One book has come off the shelf and is held in front of the reader.
  held,

  /// The held book is opening, and the stage is on its way into the reader.
  opening,
}

/// The bookshelf as an object, not as a list.
///
/// Three things happen here and they are one continuous piece of motion, which
/// is why they are one widget rather than three screens:
///
/// * **Running along the shelf.** About eleven books stand in a rank at one
///   angle, spine to the reader, receding to the leading side and off both
///   edges of the screen. Nothing comes out of the row and nothing turns to
///   face the reader: it is a shelf, not a carousel. Dragging slides the rank
///   through a window whose near end stays put.
/// * **Taking a book down.** A tap on *any* book in view runs the row to it
///   and lifts it out, square on and held in the air. Nothing carries it: no
///   hand, no arm. The rest of the row slides away and dims, and the options
///   for that book come up under it.
/// * **Opening it.** A tap, or a drag toward the leading side, swings the book
///   open and carries the camera into it. A drag the other way puts it back in
///   the row.
class ShelfStage extends StatefulWidget {
  const ShelfStage({
    super.key,
    required this.books,
    this.shelfName,
    this.initialIndex = 0,
    this.onOpen,
    this.onIndexChanged,
    this.onPickedUp,
    this.onReturned,
    this.onPhaseChanged,
    this.optionsBuilder,
    this.pickUpHint,
    this.openHint,
  });

  final List<ShelfBook> books;

  /// The name of this shelf, printed on the front edge of its board.
  final String? shelfName;

  final int initialIndex;

  /// Called once the book has opened and the stage has arrived. This is where
  /// the reader is pushed.
  final ValueChanged<ShelfBook>? onOpen;

  final ValueChanged<int>? onIndexChanged;
  final ValueChanged<ShelfBook>? onPickedUp;
  final ValueChanged<ShelfBook>? onReturned;

  /// Told whenever the stage changes what it is doing. The bookcase listens so
  /// it can stop the reader climbing to another shelf while they are holding a
  /// book off this one.
  final ValueChanged<ShelfPhase>? onPhaseChanged;

  /// The settings and customisation shown under a held book.
  final Widget Function(BuildContext context, ShelfBook book)? optionsBuilder;

  final String? pickUpHint;
  final String? openHint;

  /// The one orientation every book on the shelf stands at: spine to the
  /// reader, cover looking along the row toward the near end.
  ///
  /// One angle for all of them, including the book being looked at. A shelf is
  /// a rank of identical objects seen from a single point of view, and turning
  /// one of them to face the camera says the shelf is a menu rather than a
  /// place. The book being read is singled out by leaving the row, not by
  /// pointing somewhere else.
  static const double shelfYaw = 1.30;
  static const double shelfPitchAngle = -0.16;

  /// How small the whole shelf is drawn, against the size one book is held at.
  ///
  /// A shelf is a place with a lot of books in it. Drawn at the size of the
  /// book in your hands it held about three, the one in front filled the
  /// screen, and running along it was a slideshow of covers rather than a
  /// look down a row. At this factor about eleven books stand on the stage at
  /// once and the row runs off both edges, which is what a shelf is.
  ///
  /// It is one number because it scales the whole scene: the books, the
  /// spacing between them and the board they stand on all come out of the same
  /// projection, so nothing can drift out of agreement with anything else. The
  /// held book is drawn at 1, and the lift is what crosses between the two.
  static const double shelfZoom = 0.50;

  /// A long lens, not the model's default short one.
  ///
  /// A short focal length is a wide-angle photograph: the books at the ends of
  /// the row splay outward and the shelf runs away at a steep diagonal. That is
  /// right for one book held up close and wrong for a rank of them, which the
  /// eye expects to see standing parallel and upright.
  static const double shelfFocalLength = 11.0;

  /// The camera the board and the row are both measured in.
  static const BookCamera camera = BookCamera(
    yaw: shelfYaw,
    pitch: shelfPitchAngle,
    focalLength: shelfFocalLength,
  );

  /// How long the row takes to run to a book the reader touched further down
  /// it, before that book is taken off the shelf.
  static const Duration runDuration = Duration(milliseconds: 280);

  static const Duration liftDuration = Duration(milliseconds: 540);
  static const Duration returnDuration = Duration(milliseconds: 460);
  static const Duration openDuration = Duration(milliseconds: 760);

  /// How far through the opening the reader is sent for.
  ///
  /// The point the page has finished covering the shelf. Everything after it
  /// is a board finishing its swing behind an opaque sheet of paper, and there
  /// is no reason to make the reader watch that before the file is even opened.
  /// Handing over here spends the rest of the animation loading the book.
  static const double handoverAt = 0.76;

  /// The strip kept clear at the head of the stage, and the one at its foot.
  ///
  /// Nothing is allowed to be laid over the books. The signpost to the shelf
  /// above, the row of options over a held book, the title under it and the
  /// signpost to the shelf below all live in these two strips, and the books
  /// are sized and centred in what is left. Everything used to be centred on
  /// the whole stage and then nudged, which is why the title sat across the
  /// navigation bar and the options sat across the shelf name.
  static const double headBand = 64;
  static const double footBand = 96;

  /// The clear space two books leave between them on the shelf, in book units.
  ///
  /// A hair, and no more.
  ///
  /// Books on a shelf stand board to board, and the row has to as well. Opened
  /// up even a little, the front board of each book shows between the spines
  /// as a blank panel and eats the spine of its neighbour: half a shelf comes
  /// out with its titles cut down the middle. What separated the spines from
  /// each other was never air, it was the bow: two deeply rounded backs
  /// meeting read as one continuous tube. Flat backs need only the seam.
  static const double shelfGap = 0.002;

  /// Where each book stands along the row, in book units, measured from the
  /// first.
  ///
  /// A book takes up as much of the shelf as it is thick, so the places are not
  /// evenly spaced. Stepping every book back by one constant is what let a fat
  /// hardback stand inside its neighbour: the row was stepping by less than the
  /// books measured across.
  static List<double> rowPlaces(List<ShelfBook> books) {
    final depths = [for (final book in books) bookDepth(book)];
    final places = <double>[];
    var along = 0.0;
    for (var index = 0; index < depths.length; index++) {
      // Centre to centre: half of the book behind, half of this one, and the
      // clear air between the two.
      if (index > 0) {
        along += (depths[index - 1] + depths[index]) / 2 + shelfGap;
      }
      places.add(along);
    }
    return places;
  }

  /// How much of the row one book takes up: its whole thickness, boards and
  /// all.
  static double bookDepth(ShelfBook book) => BookMetrics.from(
        BookBindingProfile.of(book.binding),
        BookSpine.stableHash(book.id),
      ).totalDepth;

  /// How far apart two boards stand, as a share of the stage.
  ///
  /// The shelves are one piece of furniture and the view climbs it, so the
  /// pitch is what says how tall a bay is. Too small and the shelf above is
  /// already on screen with nowhere to arrive from; too large and climbing
  /// costs a long empty travel between two boards.
  static const double shelfPitch = 0.78;

  @override
  State<ShelfStage> createState() => ShelfStageState();
}

class ShelfStageState extends State<ShelfStage> with TickerProviderStateMixin {
  /// The deck is driven by a real [PageController] rather than by a bare drag,
  /// so a fling has the same physics and the same snap as every other pager in
  /// the application. Nothing is ever laid out inside its viewport: the deck is
  /// painted in a stack behind it, and the pager is there for its scroll
  /// position and its gestures alone.
  late final PageController _pager;

  /// 0 in the row, 1 held in the air.
  late final AnimationController _lift;

  /// 0 shut, 1 open and arrived.
  late final AnimationController _opening;

  /// Turns the mark on the page while the reader is being got ready. It runs
  /// only during [ShelfPhase.opening], because that is the only time anybody
  /// is waiting on anything.
  late final AnimationController _waiting;

  late final CurvedAnimation _lifted;

  ShelfPhase _phase = ShelfPhase.shelved;
  int _index = 0;
  double _page = 0;
  double _heldDrag = 0;

  /// The opening page, raised above the whole application.
  ///
  /// The paper a book opens onto has to be the whole screen, and this widget is
  /// a panel inside a page: drawn where it lives, it covered the shelf and left
  /// the title bar, the filters and the navigation bar standing round the edge
  /// of it, so the last thing before a book was a sheet of paper in a frame of
  /// chrome. Raised into the overlay it covers everything, which is what the
  /// reader arriving behind it also does.
  OverlayEntry? _cover;
  Timer? _coverDrop;

  /// Where every book was last drawn, in stage coordinates, in paint order.
  ///
  /// The gesture layer covers the whole stage because the pager needs it to,
  /// but a tap anywhere on that layer used to take a book down. Only a tap on
  /// a book should, and on a shelf with eleven of them in view it should be
  /// the book that was actually touched, not whichever one the pager happens
  /// to be sitting on. Written by the deck and read by the gesture layer,
  /// which is safe because the deck is built first in the same frame.
  final List<({int index, Rect rect})> _hitRects = [];

  /// Where each book stands along the row, in book units, measured from the
  /// first. Rebuilt whenever the row changes.
  List<double>? _alongCache;

  ShelfPhase get phase => _phase;
  int get index => _index;

  ShelfBook? get current =>
      _index >= 0 && _index < widget.books.length ? widget.books[_index] : null;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, math.max(0, widget.books.length - 1));
    _page = _index.toDouble();
    _pager = PageController(initialPage: _index)..addListener(_readPager);
    _lift = AnimationController(
      vsync: this,
      duration: ShelfStage.liftDuration,
      reverseDuration: ShelfStage.returnDuration,
    );
    _lifted = CurvedAnimation(
      parent: _lift,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _opening = AnimationController(
      vsync: this,
      duration: ShelfStage.openDuration,
    );
    _waiting = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void didUpdateWidget(covariant ShelfStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.books, oldWidget.books)) _alongCache = null;
    if (widget.books.length != oldWidget.books.length) {
      final bound = math.max(0, widget.books.length - 1);
      if (_index > bound) {
        _index = bound;
        _page = _index.toDouble();
        if (_pager.hasClients) _pager.jumpToPage(_index);
      }
    }
  }

  @override
  void dispose() {
    _dropCover();
    _pager
      ..removeListener(_readPager)
      ..dispose();
    _lifted.dispose();
    _lift.dispose();
    _opening.dispose();
    _waiting.dispose();
    super.dispose();
  }

  void _readPager() {
    if (!_pager.hasClients) return;
    final position = _pager.position;
    if (!position.hasContentDimensions) return;
    final page = _pager.page;
    if (page == null) return;
    if (page == _page) return;
    setState(() => _page = page);
    final settled =
        page.round().clamp(0, math.max(0, widget.books.length - 1)).toInt();
    if (settled != _index && (page - settled).abs() < 0.5) {
      _index = settled;
      widget.onIndexChanged?.call(settled);
    }
  }

  bool get _instant => MediaQuery.disableAnimationsOf(context);

  // ------------------------------------------------------------- the phases

  /// Brings the book at [index] to the front of the row and takes it down.
  ///
  /// A shelf with eleven books in view is touched on the book the reader
  /// wants, not on whichever one the pager is sitting on. The row runs to that
  /// book first, so the lift still starts from the place the book stands in.
  Future<void> pickUpAt(int index) async {
    if (_phase != ShelfPhase.shelved) return;
    if (index < 0 || index >= widget.books.length) return;
    if (index != _index && _pager.hasClients) {
      if (_instant) {
        _pager.jumpToPage(index);
      } else {
        await _pager.animateToPage(
          index,
          duration: ShelfStage.runDuration,
          curve: Curves.easeOutCubic,
        );
      }
      if (!mounted) return;
    }
    await pickUp();
  }

  /// Takes the book in front out of the row.
  Future<void> pickUp() async {
    if (_phase != ShelfPhase.shelved) return;
    final book = current;
    if (book == null) return;
    setState(() => _phase = ShelfPhase.held);
    widget.onPhaseChanged?.call(_phase);
    widget.onPickedUp?.call(book);
    if (_instant) {
      _lift.value = 1;
      return;
    }
    await _lift.forward();
  }

  /// Puts the held book back where it stood.
  Future<void> putBack() async {
    if (_phase != ShelfPhase.held) return;
    final book = current;
    if (_instant) {
      _lift.value = 0;
    } else {
      await _lift.reverse();
    }
    if (!mounted) return;
    setState(() {
      _phase = ShelfPhase.shelved;
      _heldDrag = 0;
    });
    widget.onPhaseChanged?.call(_phase);
    if (book != null) widget.onReturned?.call(book);
  }

  /// Swings the held book open and carries the stage into it.
  Future<void> openBook() async {
    if (_phase == ShelfPhase.opening) return;
    if (_phase == ShelfPhase.shelved) {
      await pickUp();
      if (!mounted) return;
    }
    final book = current;
    if (book == null) return;
    setState(() {
      _phase = ShelfPhase.opening;
      _heldDrag = 0;
    });
    widget.onPhaseChanged?.call(_phase);
    if (_instant) {
      _opening.value = 1;
      widget.onOpen?.call(book);
      return;
    }

    _waiting.repeat();
    _raiseCover();
    final handover = Completer<void>();
    void watch() {
      if (!handover.isCompleted &&
          _opening.value >= ShelfStage.handoverAt) {
        handover.complete();
      }
    }

    _opening.addListener(watch);
    unawaited(_opening.forward());
    await handover.future;
    _opening.removeListener(watch);
    if (!mounted) return;
    widget.onOpen?.call(book);
    // The reader draws this very page underneath itself while the file is being
    // read, so once its route has faded in there are two identical sheets of
    // paper and this one has nothing left to hide. Timed off that fade, because
    // the route is not this widget's to watch.
    _coverDrop = Timer(const Duration(milliseconds: 520), _dropCover);
  }

  /// Puts the opening page above every other thing on the screen.
  void _raiseCover() {
    if (_cover != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final book = current;
    if (book == null) return;
    final entry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([_opening, _waiting]),
          builder: (context, _) => _openingPaper(book),
        ),
      ),
    );
    _cover = entry;
    overlay.insert(entry);
  }

  void _dropCover() {
    _coverDrop?.cancel();
    _coverDrop = null;
    _cover?.remove();
    _cover = null;
  }

  /// Puts the stage back on the shelf after the reader has come out of a book.
  void reset() {
    _dropCover();
    _waiting.stop();
    _opening.value = 0;
    _lift.value = 0;
    if (!mounted) return;
    setState(() {
      _phase = ShelfPhase.shelved;
      _heldDrag = 0;
    });
    widget.onPhaseChanged?.call(_phase);
  }

  // ------------------------------------------------------------- the gestures

  void _handleTap() {
    switch (_phase) {
      case ShelfPhase.shelved:
        pickUp();
      case ShelfPhase.held:
        openBook();
      case ShelfPhase.opening:
        break;
    }
  }

  /// A tap somewhere on the stage that is not on the book.
  ///
  /// On the shelf this is the black around the row and it means nothing: a
  /// reader who misses the book has not asked for anything, and taking the
  /// book down anyway is what made the stage feel like it was acting on its
  /// own. Holding a book, the same tap is the ordinary way out of a thing you
  /// have picked up, so it goes back on the shelf.
  void _handleTapAt(Offset position) {
    final touched = _bookAt(position);
    if (touched != null) {
      if (_phase == ShelfPhase.shelved) {
        pickUpAt(touched);
      } else {
        _handleTap();
      }
      return;
    }
    if (_phase == ShelfPhase.held) putBack();
  }

  /// Which book the reader touched, or null for the black around the row.
  ///
  /// The books overlap each other by about half their width, so containment
  /// alone answers with two or three of them. The nearest centre is the one
  /// whose spine the finger is actually on.
  int? _bookAt(Offset position) {
    int? best;
    var nearest = double.infinity;
    for (final entry in _hitRects) {
      if (!entry.rect.contains(position)) continue;
      final distance = (position.dx - entry.rect.center.dx).abs();
      if (distance < nearest) {
        nearest = distance;
        best = entry.index;
      }
    }
    return best;
  }

  void _handleHeldDragUpdate(DragUpdateDetails details, bool mirror) {
    if (_phase != ShelfPhase.held) return;
    setState(() => _heldDrag += details.delta.dx * (mirror ? -1 : 1));
  }

  void _handleHeldDragEnd(DragEndDetails details, double width, bool mirror) {
    if (_phase != ShelfPhase.held) return;
    final velocity =
        details.velocity.pixelsPerSecond.dx * (mirror ? -1 : 1);
    final travelled = _heldDrag;
    setState(() => _heldDrag = 0);
    // Toward the trailing side puts it back in the row; toward the leading
    // side opens it. The two are the same gesture with a sign, which is what
    // makes them learnable in one go.
    if (velocity > 420 || travelled > width * 0.18) {
      putBack();
    } else if (velocity < -420 || travelled < -width * 0.18) {
      openBook();
    }
  }

  // ------------------------------------------------------------- the layout

  /// Where a book sits when its distance from the front of the deck is [d].
  ///
  /// Positive [d] is behind the front book, negative is on its way out.
  /// Where a book stands when it is [d] places along the shelf from the one
  /// the reader is on. Negative is on the reader's trailing side.
  ///
  /// One rule for the whole row, and no special case for a book that has been
  /// passed. Books on a shelf do not fly away when you look at the next one:
  /// they stay where they are, and the row goes on past both edges of the
  /// screen. Only the one being looked at leaves the row, and only far enough
  /// to turn its cover round.
  _ShelfSlot _deckSlot(
    double d,
    Size stage,
    ShelfProjection? projection,
    ({Offset offset, double scale})? front,
  ) {
    // Nothing comes out of the row. Every book on the shelf stands in it, at
    // one angle, the way a shelf of books does; the only book that leaves is
    // the one somebody has taken down, and that is the lift.
    final slot = projection?.slotAlong(
      _placeAlong(_page + d) - _placeAlong(_page),
    );
    // Measured against the book at the front, which is drawn at exactly the
    // size and the place of its box. Coming out of the row carries that book
    // toward the reader, and the perspective that follows from it was
    // magnifying and lowering the book past the edges of the box the whole
    // layout is measured in. The row is what moves; the book being looked at
    // stays where the layout put it.
    final frontScale = front?.scale ?? 1;
    final frontOffset = front?.offset ?? Offset.zero;
    return _ShelfSlot(
      dx: slot == null
          ? -stage.width * 0.10 * d
          : (slot.offset.dx - frontOffset.dx) / frontScale,
      dy: slot == null ? 0 : (slot.offset.dy - frontOffset.dy) / frontScale,
      scale: (slot?.scale ?? 1) / frontScale,
      yaw: ShelfStage.shelfYaw,
      pitch: ShelfStage.shelfPitchAngle,
      focalLength: ShelfStage.shelfFocalLength,
      // The row falls away into the dark at its far end rather than stopping,
      // so the shelf reads as longer than the screen. Only at the far end: a
      // book on the near side is nearer the reader, not further from them, and
      // dimming it darkened the half of the row that is closest.
      //
      // Stepped, for the same reason the scale above is. The book paints the
      // dark into itself now, so a value that creeps every frame throws away
      // that book's cached raster every frame — the very thing the step is
      // there to prevent. Fiftieths: the scrim runs to about a quarter, so
      // that is a dozen levels down the row, which is more than the eye finds
      // in a gradient this shallow, and it costs each book about two redraws
      // for a whole page of scrolling.
      dim: (0.035 * math.min(math.max(d, 0), 8) * 50).roundToDouble() / 50,
      opacity: 1,
    );
  }

  /// The row's places, worked out once and kept until the row changes.
  List<double> get _rowAlong =>
      _alongCache ??= ShelfStage.rowPlaces(widget.books);

  /// How far down the row the fractional place [place] stands. The deck moves
  /// through fractions of a place as the pager scrolls, so the row has to be
  /// measurable between two books as well as at them.
  double _placeAlong(double place) {
    final along = _rowAlong;
    if (along.isEmpty) return 0;
    if (along.length == 1) return along.first + place * -ShelfProjection.step.z;
    if (place <= 0) return along.first + place * (along[1] - along[0]);
    final last = along.length - 1;
    if (place >= last) {
      return along[last] + (place - last) * (along[last] - along[last - 1]);
    }
    final low = place.floor();
    return lerpDouble(along[low], along[low + 1], place - low)!;
  }

  /// How far the whole scene sits off the middle of the stage, so that the
  /// books are centred in the space between the two reserved strips rather
  /// than behind them.
  double _bandOffset() => (ShelfStage.headBand - ShelfStage.footBand) / 2;

  /// Where a held book sits: out of the row, lowered, and turned square on.
  ///
  /// No yaw and no pitch. A book someone has picked up to look at is held flat
  /// in front of their face, not presented at three quarters like a thing in a
  /// shop window. The angle that makes a book on a shelf legible is the wrong
  /// angle the moment it is in your hands.
  _ShelfSlot _heldSlot(Size stage) => const _ShelfSlot(
        // Square in front of the reader. Offsetting it toward the leading side
        // made sense while the row was still behind it; the row has gone by the
        // time the lift finishes, and all the offset did was run the book off
        // the edge of the screen.
        dx: 0,
        dy: 0,
        // The box already fills the space between the two reserved strips, and
        // a book turned square on refits itself into it, so there is nothing
        // left to magnify. The old 1.30 was making up for a box that was too
        // small, and it pushed the book across the strips.
        scale: 1.04,
        yaw: 0,
        pitch: 0,
        // Held in the hands, not seen across a room: the short lens comes back
        // so the object has some depth to it again.
        focalLength: 5.0,
        dim: 0,
        opacity: 1,
      );

  /// Where the near end of the drawn row sits across the stage.
  ///
  /// Well over toward the trailing edge, and it is the *near end* that is
  /// anchored there, not the book being looked at. The row recedes toward the
  /// leading side, so anchoring the book in front puts the whole row in the
  /// leading half of a shelf whose first book is showing, and runs the near
  /// half of it off the trailing edge on every shelf whose middle is showing.
  /// Anchoring the near end instead keeps the drawn window in one place, and
  /// the books slide through it as the reader runs along the shelf.
  static const double _nearAnchor = 0.26;

  double _deckOrigin(
    Size stage,
    ShelfProjection? projection,
    ({Offset offset, double scale})? front,
  ) {
    final anchor = stage.width * _nearAnchor;
    if (projection == null || front == null) return anchor;
    // The nearest book that is actually drawn, which at the start of a shelf
    // is the first book on it.
    final back = math.min(_page, _nearWindow);
    final slot = projection.slotAlong(
      _placeAlong(_page - back) - _placeAlong(_page),
    );
    if (slot == null) return anchor;
    final dx = (slot.offset.dx - front.offset.dx) /
        front.scale *
        ShelfStage.shelfZoom;
    return anchor - dx;
  }

  /// [child], faded, and only wrapped in a layer when there is a fade to apply.
  ///
  /// `Opacity` composites through a layer whether or not it has anything to do,
  /// and almost everything on this stage sits at 1 for the whole time the
  /// reader is looking at a shelf. Nineteen books, a board and two captions
  /// came to twenty layers a frame for nothing.
  static Widget _fading(double opacity, {required Widget child}) =>
      opacity >= 0.999
          ? child
          : Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);

  /// How far down the stage the row is set while it is on the shelf.
  ///
  /// A hair, and a hair only. A shelf is something you look slightly down
  /// onto, so the row wants to sit a little under the middle of the space it
  /// is given — but the board and its name already hang below the books, so
  /// most of that has been paid for. At six per cent the row was a third of a
  /// screen of black over a fifth of a screen of black, which reads as a
  /// picture that has slipped down its frame.
  double _shelfDrop(Size stage) => stage.height * 0.015;

  /// The box one book is drawn in.
  ///
  /// It is the whole of the stage that is not reserved for the strips at the
  /// head and the foot. A book on a shelf you are standing in front of is a
  /// large object, and the old box, three fifths of the stage height, drew it
  /// as a thumbnail with a great deal of black around it.
  Size _bookBox(Size stage) {
    final free = math.max(
      160.0,
      stage.height - ShelfStage.headBand - ShelfStage.footBand,
    );
    final height = free * 0.98;
    // Nearly the whole width. A book standing three-quarters on is a wide
    // object, and the width is what the fit ends up binding on, so a narrow
    // box draws a small book with a great deal of black around it. The height
    // used to be clamped to the width as well, which quietly threw away most
    // of the band the moment the width ran out first.
    final width = math.min(stage.width * 0.88, height * 1.10);
    return Size(width, height);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.books.isEmpty) return const SizedBox.shrink();
    final mirror = Directionality.of(context) == TextDirection.rtl;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stage = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 360,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 560,
        );
        return AnimatedBuilder(
          animation: Listenable.merge([_lifted, _opening, _waiting]),
          builder: (context, _) {
            // The gesture layer goes under the options, not over them.
            //
            // It is a `Positioned.fill` with an opaque hit test on it, because
            // the pager under it has to be able to take a drag anywhere on the
            // stage. Built last, it was also on top of everything, and every
            // tap on the row of options over a held book was swallowed by the
            // shelf: none of the four buttons had ever worked. Nothing in the
            // options layer is opaque except the buttons themselves, so a tap
            // that misses one still falls through to the shelf beneath.
            //
            // The caption stays underneath it. Laid-out text answers a hit test
            // whether or not anything is listening, so a title raised over the
            // gesture layer would quietly make the bottom band of the stage
            // deaf — and that band is where a tap beside a held book puts it
            // back on the shelf.
            return Stack(
              fit: StackFit.expand,
              children: [
                _deck(stage, mirror),
                _caption(stage),
                _gestureLayer(stage, mirror),
                if (widget.optionsBuilder != null) _options(stage),
                _openingPage(stage),
              ],
            );
          },
        );
      },
    );
  }

  /// How many places of the row are drawn on the reader's near side, and how
  /// many on the far side.
  ///
  /// Not the same number. The near side comes toward the camera and runs off
  /// the edge quickly; the far side recedes toward the vanishing point, so it
  /// fits many more books in the same strip of screen. Together they put about
  /// eleven books on a phone.
  ///
  /// Narrowed once the book is up and the row has finished fading, never while
  /// it is on its way. Keyed to the phase, the window closed on the frame the
  /// reader touched a book: eight books at the far end of a fully lit row
  /// stopped existing in one frame, which is the flicker at the start of every
  /// pick-up. By the time the lift has run the row is invisible anyway, so
  /// nothing is drawn twice for the sake of it.
  bool get _wideWindow =>
      _phase == ShelfPhase.shelved || _lifted.value < 0.999;

  double get _nearWindow => _wideWindow ? 4 : 2.5;
  double get _farWindow => _wideWindow ? 14 : 6;

  Widget _deck(Size stage, bool mirror) {
    final lift = _lifted.value;
    final opening = _opening.value;
    final book = current;
    _hitRects.clear();

    // The far books paint first. Sorting by distance from the front is what
    // makes the deck a deck rather than a pile in source order.
    final entries = <_ShelfEntry>[];
    for (var i = 0; i < widget.books.length; i++) {
      final d = i - _page;
      // A shelf runs off both edges of the screen, but the row converges on a
      // vanishing point: past the far end of this window a book is a few
      // pixels of spine behind a dozen others, and drawing it costs as much as
      // drawing the one in front.
      if (d < -_nearWindow || d > _farWindow) continue;
      entries.add(_ShelfEntry(i, d));
    }
    // Furthest first: the painter's algorithm, and nothing else.
    //
    // Sorted by distance from the front of the deck it was not. A book two
    // places nearer the reader than the one at the front sorts as `2`, the
    // same as a book two places further away, so a book behind was painted
    // over a book in front and the near half of the row came out interleaved
    // with the far half. It only showed once a book somewhere in the middle of
    // the shelf was being looked at, which is why the first books on a shelf
    // always looked right.
    //
    // A book that has left the row is the exception, and goes on top of
    // everything: it is no longer standing anywhere the row can sort it.
    entries.sort((a, b) {
      if (_phase != ShelfPhase.shelved) {
        final aFront = a.index == _index;
        final bFront = b.index == _index;
        if (aFront != bFront) return aFront ? 1 : -1;
      }
      return b.d.compareTo(a.d);
    });

    final box = _bookBox(stage);
    // One projection for the whole deck and the board under it, and one that
    // does not depend on which book happens to be at the front. See [_rowSpec].
    final projection = book == null
        ? null
        : ShelfProjection(spec: _rowSpec(), box: box);
    // Where the front book actually is, which is what the rest of the deck is
    // measured against.
    final front = projection?.slotAlong(0);
    final origin = _deckOrigin(stage, projection, front);

    return Stack(
      fit: StackFit.expand,
      children: [
        _plane(stage, box, origin, lift, opening, mirror, projection),
        for (final entry in entries)
          _positioned(
            entry: entry,
            stage: stage,
            origin: origin,
            lift: lift,
            opening: opening,
            projection: projection,
            front: front,
            isHeld: entry.index == _index && _phase != ShelfPhase.shelved,
            size: box,
            mirror: mirror,
            book: entry.index == _index ? book : null,
          ),
      ],
    );
  }

  /// The book the board and the row are measured against.
  ///
  /// Not the book at the front, and this is the whole point of it.
  ///
  /// The projection fits one book's outline to the box and hands that scale to
  /// every book on the shelf. Measured from the front book, the scale is a
  /// function of *that* book's thickness and binding — so the moment the pager
  /// crossed the half-way mark between a fat hardback and a thin paperback, the
  /// entire row and the board under it changed size in one frame. Across the
  /// range of thicknesses and both bindings that step reaches four and a half
  /// per cent, and it lands once per book for the whole length of a shelf: the
  /// row breathes as the reader runs along it, which is exactly the kind of
  /// fault the eye reads as jitter without being able to name it. Worse,
  /// [BookModelSpec.rowScale] was not one of the things the
  /// painter repainted for, so the books kept their old raster at the old scale
  /// while the slots the projection gave them moved to the new one.
  ///
  /// A shelf is one place with one camera, so it gets one frame of reference: a
  /// cased book of the middle thickness, which is nobody's book in particular
  /// and therefore everybody's. Nothing about it moves while the reader runs
  /// along the row.
  ///
  /// The reference has to be a hardback. A cased board stands proud of its
  /// paper at the head and the tail, so it is the taller of the two bindings by
  /// about a twentieth; fitted to a softback, a hardback standing next to it
  /// would be cropped at the head.
  static const int _referenceSeed = 4096;

  BookModelSpec _rowSpec() {
    final scheme = Theme.of(context).colorScheme;
    return BookModelSpec(
      binding: BookBinding.hardback,
      title: '',
      author: '',
      palette: BookModelPalette.resolve(
        scheme: scheme,
        binding: BookBinding.hardback,
        seed: _referenceSeed,
      ),
      typography: BookModelTypography.of(context),
      seed: _referenceSeed,
      camera: ShelfStage.camera,
      showDropShadow: false,
    );
  }

  /// The board the row stands on.
  ///
  /// Drawn in the front book's own camera and fit, so the shelf and the books
  /// on it cannot be at different angles. It goes when a book is taken down,
  /// because a book held in the air is not standing on anything.
  Widget _plane(
    Size stage,
    Size box,
    double origin,
    double lift,
    double opening,
    bool mirror,
    ShelfProjection? projection,
  ) {
    if (projection == null) return const SizedBox.shrink();
    final fade = (1 - lift) * (1 - opening.clamp(0.0, 1.0));
    if (fade <= 0.004) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final spec = projection.spec;

    // The board shrinks with the row it carries, about the same point, so the
    // books cannot come off their own shelf. Drawn longer by as much as it is
    // drawn smaller, or a shelf at this size would stop in mid-air rather than
    // running off both edges of the screen.
    final zoom = lerpDouble(ShelfStage.shelfZoom, 1, lift)!;
    final reach = 1 / ShelfStage.shelfZoom;
    final drop = _shelfDrop(stage) * (1 - lift);

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          child: Transform.translate(
            offset: Offset(mirror ? -origin : origin, _bandOffset() + drop),
            child: Transform.scale(
              scale: zoom,
              // Only while it is fading. See the note on the row above: an
              // `Opacity` is a composited layer even at 1, and the board sits
              // at 1 for the whole time the reader is on the shelf.
              child: _fading(
                fade,
                child: SizedBox(
                  width: box.width,
                  height: box.height,
                  // The board is one large picture that changes only when the
                  // reader moves to a book of another thickness, while the row
                  // over it is redrawn on every frame of a scroll. Without a
                  // boundary of its own it is re-rasterised with them.
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: ShelfPlanePainter(
                        spec: spec,
                        label: widget.shelfName,
                        labelStyle: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        surface: scheme.onSurface,
                        sheen: scheme.onSurface,
                        shadow: scheme.shadow,
                        leading: 3.4 * reach,
                        trailing: 1.1 * reach,
                        zoom: zoom,
                      ),
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

  Widget _positioned({
    required _ShelfEntry entry,
    required Size stage,
    required double origin,
    required double lift,
    required double opening,
    required ShelfProjection? projection,
    required ({Offset offset, double scale})? front,
    required bool isHeld,
    required Size size,
    required bool mirror,
    required ShelfBook? book,
  }) {
    final data = widget.books[entry.index];
    final deck = _deckSlot(entry.d, stage, projection, front);
    final held = _heldSlot(stage);

    // The front book crosses from its place in the row to the held pose. Every
    // other book stays exactly where it stands and fades where it stands, so
    // the row gives way to the book that left it without moving an inch.
    final isFront = entry.index == _index;
    final t = isFront ? lift : 0.0;
    final clearing = isFront ? 0.0 : lift;

    // The shelf is drawn small and the held book large, and the lift is what
    // crosses between the two. Applied to the deck slot rather than to the
    // stage, so the spacing between the books shrinks with the books and the
    // row cannot come apart.
    const zoom = ShelfStage.shelfZoom;
    final drop = _shelfDrop(stage);
    var dx = lerpDouble(origin + deck.dx * zoom, held.dx, t)!;
    var dy = lerpDouble(deck.dy * zoom + drop, held.dy, t)! + _bandOffset();
    var scale = lerpDouble(deck.scale * zoom, held.scale, t)!;
    if (!isFront) {
      // Snapped to a step. A book behind the front one is drawn into a cached
      // layer, and sliding that layer costs nothing while resizing it throws
      // the cache away: a scale that creeps by a thousandth every frame made
      // every book in the row re-render on every frame of a scroll. The step
      // is far finer than the eye can follow at these sizes, and the book
      // still travels smoothly, because travel is the translation.
      scale = (scale * 40).roundToDouble() / 40;
    }
    final yaw = lerpDouble(deck.yaw, held.yaw, t)!;
    final pitch = lerpDouble(deck.pitch, held.pitch, t)!;
    final focal = lerpDouble(deck.focalLength, held.focalLength, t)!;
    final dim = deck.dim * (1 - t);
    var opacity = deck.opacity;

    if (clearing > 0) {
      // The gap the book left stays open, and nothing slides across it.
      //
      // The row used to be pushed nearly half a screen toward the trailing edge
      // as the book came up. Nothing about that is what a shelf does: the books
      // beside the one you take down do not close ranks behind your hand, and
      // seen at the shelf's angle the push read as the whole row swimming
      // sideways through the slot that had just been vacated. Worse, it had to
      // be undone on the way back, so putting a book away was a second slide
      // the reader had not asked for and the two motions fought each other
      // across the same pixels. Standing still, the row simply recedes, the
      // empty slot is still there when the book comes back to it, and the only
      // thing moving on the screen is the book the reader touched.
      opacity *= 1 - clearing;
    }

    if (isFront && _phase == ShelfPhase.held) {
      // The drag carries the book with the finger, so the reader can see which
      // way they are about to send it before they let go.
      dx += _heldDrag * (mirror ? -1 : 1) * 0.55;
    }

    if (isFront && opening > 0) {
      // The arrival: the book comes at the reader and the stage is handed to
      // whatever opens next.
      //
      // A short step forward, not a balloon. This used to scale the object to
      // three and a half times its size, which put a cover decoded at 512 px
      // across a 1400 px screen: the last thing the reader saw of their book
      // was a soft, enormous picture of its front board. The forward motion is
      // now carried by the page arriving underneath it, the same way the cold
      // start opens.
      final zoom = Curves.easeInCubic.transform(
        ((opening - 0.42) / 0.58).clamp(0.0, 1.0),
      );
      scale *= 1 + zoom * 0.30;
      dx = lerpDouble(dx, 0, zoom)!;
      dy = lerpDouble(dy, 0, zoom)!;
      opacity *= 1 - Curves.easeIn.transform(zoom);
    } else if (!isFront && opening > 0) {
      opacity = 0;
    }

    if (opacity <= 0.004) return const SizedBox.shrink();

    // Where this book landed. Read back by the gesture layer, which is built
    // after the deck in the same frame.
    //
    // Recorded after the visibility test, not before it. A book that has been
    // faded out is not on the screen, and a rect left behind for it is a piece
    // of the black that still answers to a tap: holding a book, the tap beside
    // it that should have put it back landed on the ghost of a shelved
    // neighbour and opened the held book instead.
    final centre = Offset(
      stage.width / 2 + (mirror ? -dx : dx),
      stage.height / 2 + dy,
    );
    _hitRects.add((
      index: entry.index,
      rect: Rect.fromCenter(
        center: centre,
        width: size.width * scale,
        height: size.height * scale,
      ),
    ));

    final child = SizedBox(
      width: size.width,
      height: size.height,
      child: BookModel(
        key: ValueKey('shelf-book-${data.id}'),
        title: data.title,
        author: data.author,
        blurb: data.blurb,
        coverPath: data.coverPath,
        stableId: data.id,
        binding: data.binding,
        camera: BookCamera(yaw: yaw, pitch: pitch, focalLength: focal),
        // Standing in the row, every book is drawn at the row's scale and
        // placed by its own middle. Off the shelf it is one object again and
        // measures itself, which is what keeps a swinging cover in the box.
        rowScale: t > 0 ? null : projection?.scale,
        // The row falls away into the dark, and the book paints that into
        // itself. A `ColorFiltered` over the widget is the obvious way to get a
        // scrim that follows the silhouette, and it was costing an offscreen
        // composite per book on every frame of a scroll.
        dim: dim,
        // Every facet for the book being looked at, held or opened. The rest
        // of the row is spine-on and small, and cannot show the difference.
        detail: isFront ? BookDetail.full : BookDetail.reduced,
        open: isFront ? _openValue(data) : 0,
        // Where the book opens is the reader's own place in it.
        openAt: data.openAt,
        tapToOpen: false,
        dragToOpen: false,
        turnToSeeBack: false,
        showDropShadow: isFront && _phase != ShelfPhase.shelved,
        semanticLabel: data.title,
      ),
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.center,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(mirror ? -dx : dx, dy, 0, 1)
              ..scaleByDouble(scale, scale, 1, 1),
            // No `Opacity` on a book that is not fading. It is a composited
            // layer whether or not it has anything to do — a row of nineteen
            // books handed the compositor nineteen of them — and on the shelf,
            // which is where the reader spends their time, every one of them is
            // at 1. The fade only exists while a book is being taken down.
            child: _fading(opacity, child: child),
          ),
        ),
      ),
    );
  }

  /// How far open the front book is drawn.
  double _openValue(ShelfBook data) {
    if (_phase != ShelfPhase.opening) return 0;
    final travel = (_opening.value / 0.62).clamp(0.0, 1.0);
    // A finished book is not opened, it is shut: the animation runs the other
    // way, and what the reader watches is the back board coming down.
    //
    // The two are not the same movement reversed. A board is swung open by a
    // hand, so it starts still, goes, and is caught where it lands. A board
    // shut is let go of, so it starts slowly and gathers speed all the way to
    // the moment it meets the block. `easeOutCubic` for both gave the closing
    // book a soft landing, which is the one thing a falling cover does not do.
    if (data.finished) {
      return 1 - PaperfoldMotion.depart.transform(travel);
    }
    return PaperfoldMotion.turn.transform(travel);
  }

  Widget _options(Size stage) {
    final book = current;
    if (book == null) return const SizedBox.shrink();
    final lift = _lifted.value * (1 - _opening.value.clamp(0.0, 1.0));
    if (lift <= 0.004) return const SizedBox.shrink();
    // Above the book, not below it. The options are what the reader came to
    // this state for, and a row of them under the title reads as a caption to
    // the book rather than as the thing they can act on.
    //
    // Inside the reserved strip at the head, so the row cannot land on the
    // book or on the signpost above it.
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: ShelfStage.headBand,
      // Clipped to the strip it was given. The row slides in from above, and
      // without this the travel is drawn over whatever is above the stage.
      child: ClipRect(
        child: IgnorePointer(
          // Once the book is opening there is nothing left to set about it,
          // and the row is on its way out.
          ignoring: _phase == ShelfPhase.opening,
          child: Opacity(
            opacity: lift.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -(1 - lift) * ShelfStage.headBand),
              child: Center(child: widget.optionsBuilder!(context, book)),
            ),
          ),
        ),
      ),
    );
  }

  /// The title and the author, under a held book.
  ///
  /// They belong to the held state and not to the shelf: on the shelf the
  /// spine and the cover already say what the book is, and a caption under
  /// every book in a row is a list with pictures.
  Widget _caption(Size stage) {
    final book = current;
    if (book == null) return const SizedBox.shrink();
    final lift = _lifted.value * (1 - _opening.value.clamp(0.0, 1.0));
    if (lift <= 0.004) return const SizedBox.shrink();

    final theme = Theme.of(context);
    // Inside the reserved strip at the foot, and clipped to it. The title used
    // to be set as a share of the stage height, which put a two-line title
    // across the navigation bar on a short screen.
    return Positioned(
      left: 16,
      right: 16,
      bottom: 8,
      height: ShelfStage.footBand - 16,
      // Clipped to the strip, and every line of it free to give way. A two-line
      // title at a large system font size used to be laid out taller than the
      // strip: the caption overflowed onto the navigation bar, and in a debug
      // build it took the screen with it.
      child: ClipRect(
        child: Opacity(
          opacity: lift.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - lift) * ShelfStage.footBand * 0.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    book.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (book.author.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      book.author,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The page the book opens onto, and the wait that happens on it.
  ///
  /// The reader is not ready the moment the cover has swung: the file has to be
  /// read and the reading page has to be built, and until this existed the
  /// stage filled that gap by holding an enormously magnified picture of the
  /// front board. A book being opened shows you paper, not a bigger cover. The
  /// paper arrives under the swinging board, takes the screen, and carries the
  /// title and a turning mark until the reader arrives over the top of it.
  Widget _openingPage(Size stage) {
    // Raised into the overlay, the page is drawn there and nowhere else. Two of
    // them is two sheets of paper, and the one down here is the smaller.
    if (_cover != null) return const SizedBox.shrink();
    final book = current;
    if (book == null || _opening.value <= 0.001) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(child: _openingPaper(book)),
    );
  }

  /// The sheet itself, at whatever it has arrived to.
  Widget _openingPaper(ShelfBook book) {
    // The paper comes up as the board swings clear of it.
    final arrival = Curves.easeOutCubic.transform(
      ((_opening.value - 0.30) / 0.46).clamp(0.0, 1.0),
    );
    if (arrival <= 0.001) return const SizedBox.shrink();

    // The title only once the paper is the whole screen. Anything printed on a
    // half-arrived page reads as a caption floating over the book.
    final settled = Curves.easeOut.transform(
      ((_opening.value - 0.72) / 0.28).clamp(0.0, 1.0),
    );
    return Opacity(
      opacity: arrival.clamp(0.0, 1.0),
      child: BookOpeningPage(
        title: book.title,
        author: book.author,
        turn: _waiting,
        showMark: settled > 0.5,
      ),
    );
  }

  /// The one layer that takes input.
  ///
  /// On the shelf it is a pager, so a fling behaves like every other pager.
  /// Held, the pager is stood down and the drag decides between putting the
  /// book back and opening it.
  Widget _gestureLayer(Size stage, bool mirror) {
    final book = current;
    final shelved = _phase == ShelfPhase.shelved;
    return Positioned.fill(
      child: Semantics(
        button: _phase != ShelfPhase.opening,
        label: book == null
            ? null
            : book.author.trim().isEmpty
                ? book.title
                : '${book.title}, ${book.author}',
        hint: shelved ? widget.pickUpHint : widget.openHint,
        onTap: _phase == ShelfPhase.opening ? null : _handleTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _phase == ShelfPhase.opening
              ? null
              : (details) => _handleTapAt(details.localPosition),
          onHorizontalDragUpdate: _phase == ShelfPhase.held
              ? (details) => _handleHeldDragUpdate(details, mirror)
              : null,
          onHorizontalDragEnd: _phase == ShelfPhase.held
              ? (details) => _handleHeldDragEnd(details, stage.width, mirror)
              : null,
          child: PageView.builder(
            controller: _pager,
            // Reversed. Dragging toward the trailing side brings the next book
            // forward, the way you push along a row of spines with a finger
            // rather than the way a gallery of pictures scrolls.
            reverse: true,
            physics: shelved
                ? const PageScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: widget.books.length,
            itemBuilder: (context, index) => const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// One book's place in the deck.
@immutable
class _ShelfSlot {
  const _ShelfSlot({
    required this.dx,
    required this.dy,
    required this.scale,
    required this.yaw,
    required this.pitch,
    required this.focalLength,
    required this.dim,
    required this.opacity,
  });

  final double dx;
  final double dy;
  final double scale;
  final double yaw;
  final double pitch;
  final double focalLength;

  /// How much the book is darkened by standing behind the one in front.
  final double dim;

  final double opacity;
}

@immutable
class _ShelfEntry {
  const _ShelfEntry(this.index, this.d);

  final int index;

  /// Distance from the front of the deck. 0 is the book in front.
  final double d;
}
