import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/page/opening/opening_quotes.dart';
import 'package:paperfold/widgets/page_curl/page_curl.dart';

/// Builds the line artwork placed over the provisional opening cover.
///
/// Milestone 3 can supply the final user artwork here without changing the
/// opening motion, cover material, or page-curl integration.
typedef OpeningCoverArtBuilder = Widget Function(BuildContext context);

/// Where the opening has got to.
enum _OpeningStage {
  /// The shut book, waiting to be opened.
  cover,

  /// The cover turning.
  turning,

  /// The first page, waiting to be gone past.
  page,

  /// The page growing into the application.
  leaving,
}

/// A cold-start book opening that the reader moves through, a tap at a time.
///
/// Nothing here runs on a timer. The book is shut when the application starts,
/// one tap turns the cover, and another goes through the page into the
/// application: a book on a table does not open itself, and an opening that
/// plays and disappears is a splash screen, which is the one thing this is not
/// meant to be. Each tap runs one movement, and a tap while a movement is
/// running takes the reader straight to the end of it, so the sequence can
/// never hold anybody up.
///
/// The caller decides whether this widget exists for the current process. This
/// widget also observes the platform remove-animations setting and cuts to
/// [child] when motion is disabled.
class OpeningSequence extends StatefulWidget {
  const OpeningSequence({
    super.key,
    required this.child,
    this.onFinished,
    this.coverArtBuilder,
  });

  /// How long the cover takes to turn.
  static const Duration turnDuration = PaperfoldMotion.coverTurn;

  /// How long the page takes to grow into the application.
  static const Duration leaveDuration = PaperfoldMotion.pageLeave;

  final Widget child;
  final VoidCallback? onFinished;
  final OpeningCoverArtBuilder? coverArtBuilder;

  @override
  State<OpeningSequence> createState() => _OpeningSequenceState();
}

class _OpeningSequenceState extends State<OpeningSequence>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final PageCurlController _curlController = PageCurlController();

  /// How far the cover has turned, kept beside the curl so the ground under it
  /// can come up from the colour of the board to the colour of the paper.
  late final AnimationController _turn;

  /// How far the page has grown into the application.
  late final AnimationController _leave;

  /// The breathing of the mark that says a tap is wanted.
  late final AnimationController _hint;

  /// The line this launch's page carries. Drawn once, in [initState], because
  /// a quotation that changed in the middle of the reader looking at it would
  /// be a fault rather than a flourish.
  final OpeningQuote _quote = OpeningQuotes.pick();

  _OpeningStage _stage = _OpeningStage.cover;
  bool _warmed = false;
  bool _finished = false;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _turn = AnimationController(
      vsync: this,
      duration: OpeningSequence.turnDuration,
    );
    _leave = AnimationController(
      vsync: this,
      duration: OpeningSequence.leaveDuration,
    );
    _hint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(_afterFirstPaint);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && !_finished) {
      _finished = true;
      _stop();
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyFinished());
      return;
    }
    _syncHint();
  }

  /// The mark breathes only while there is a tap to ask for.
  ///
  /// It used to breathe from the first frame to the last, which kept a ticker
  /// and therefore the whole application awake through both movements as well,
  /// for a mark that is faded out for the length of each of them.
  void _syncHint() {
    final wanted = !_finished &&
        (_stage == _OpeningStage.cover || _stage == _OpeningStage.page);
    if (wanted == _hint.isAnimating) {
      return;
    }
    if (wanted) {
      _hint.repeat(reverse: true);
    } else {
      _hint.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hint.dispose();
    _leave.dispose();
    _turn.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The reader has actually left, so there is nothing to open.
    //
    // `inactive` is not that. Android passes through it while the activity is
    // still coming up, and again for a pull of the notification shade or a
    // moment of split focus. It cost nothing while this ran on a 1.15 second
    // clock; it cost the whole opening once the opening started waiting for a
    // tap, because a cold start would skip straight past the book on its way
    // in - which is exactly what it did on the phone.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _finish();
    }
  }

  void _afterFirstPaint(Duration _) {
    if (!mounted || _warmed || _finished) return;
    _warmed = true;
    unawaited(_warmShader());
  }

  Future<void> _warmShader() async {
    try {
      await PageCurl.warmUp();
    } catch (error, stackTrace) {
      _reportError(
        error,
        stackTrace,
        'while warming the opening page-curl shader',
      );
    }
  }

  /// One tap: run the next movement, or finish the one already running.
  void _advance() {
    switch (_stage) {
      case _OpeningStage.cover:
        setState(() => _stage = _OpeningStage.turning);
        unawaited(_turnCover());
      case _OpeningStage.turning:
        _turn.stop();
        _turn.value = 1;
        _settleCurl();
        setState(() => _stage = _OpeningStage.page);
      case _OpeningStage.page:
        setState(() => _stage = _OpeningStage.leaving);
        unawaited(_leavePage());
      case _OpeningStage.leaving:
        _finish();
    }
    _syncHint();
  }

  /// Turns the cover, and moves on when the movement this widget owns is done.
  ///
  /// The curl runs beside that clock rather than being waited on. A curl that
  /// stalls, or that never attaches because its shader would not build, must
  /// not leave the reader tapping a cover that has stopped being able to turn:
  /// the stage this widget is in is this widget's own business.
  Future<void> _turnCover() async {
    unawaited(_runCurl());
    await _turn.forward();
    if (!mounted || _stage != _OpeningStage.turning) return;
    setState(() => _stage = _OpeningStage.page);
    _syncHint();
  }

  Future<void> _runCurl() async {
    try {
      await _curlController.animate(
        duration: OpeningSequence.turnDuration,
        // A board starts at rest. `easeOutCubic` starts at full speed, which
        // made the cover appear to be already flying when the reader touched it.
        curve: PaperfoldMotion.turn,
      );
    } catch (error, stackTrace) {
      _reportError(error, stackTrace, 'while opening the book cover');
    }
  }

  Future<void> _leavePage() async {
    await _leave.forward();
    if (!mounted) return;
    _finish();
  }

  /// Puts the curl at its end without waiting for it, for a reader who taps
  /// through the movement rather than watching it.
  void _settleCurl() {
    if (!_curlController.isAttached) return;
    try {
      _curlController.jumpTo(1);
    } catch (error, stackTrace) {
      _reportError(error, stackTrace, 'while finishing the cover turn');
    }
  }

  void _reportError(Object error, StackTrace stackTrace, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'opening sequence',
        context: ErrorDescription(context),
      ),
    );
  }

  void _stop() {
    _turn.stop();
    _leave.stop();
    _hint.stop();
  }

  void _finish() {
    if (_finished) {
      return;
    }
    _finished = true;
    _stop();
    if (mounted) {
      setState(() {});
    }
    _notifyFinished();
  }

  void _notifyFinished() {
    if (_notified) {
      return;
    }
    _notified = true;
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    // The application is built, laid out and kept alive underneath from the
    // first frame, so it is warm when the reader arrives - but it is not
    // painted while a shut book is covering every pixel of it.
    //
    // Measured on the phone: the opening's own frame costs 0.2 ms of UI time
    // and almost no raster, and the screen still spent 7.0 ms a frame of an
    // 8.3 ms budget. All of it was the bookshelf drawing behind an opaque
    // cover. Flutter does not cull what is hidden; something has to say so.
    //
    // It comes back the moment the cover has finished turning, which is a stage
    // the reader is standing still in, looking at the welcome page and deciding
    // to tap again. That is deliberate. A shelf of books painting for the first
    // time costs one frame of texture upload - measured at 34 ms, four frames
    // at 120 Hz - and that frame has to be spent somewhere. Spent here, nothing
    // is moving and nobody can see it. Spent one stage later it lands in the
    // middle of the movement that hands over the screen, which is the most
    // watched half second the application has.
    final revealed = _finished ||
        _stage == _OpeningStage.page ||
        _stage == _OpeningStage.leaving;

    return Stack(
      fit: StackFit.expand,
      children: [
        _PaintGate(painting: revealed, child: widget.child),
        if (!_finished)
          BlockSemantics(
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _advance(),
                child: Semantics(
                  button: true,
                  onTap: _advance,
                  child: _OpeningScene(
                    turn: _turn,
                    leave: _leave,
                    hint: _hint,
                    waiting: _stage == _OpeningStage.cover ||
                        _stage == _OpeningStage.page,
                    curlController: _curlController,
                    coverArtBuilder: widget.coverArtBuilder,
                    quote: _quote,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Holds a subtree back from painting, and does nothing else to it.
///
/// Layout, state, tickers, hit testing and semantics all carry on exactly as
/// they were: the child is a fully live screen that simply is not drawn. That
/// is the whole point - it has to go on getting itself ready underneath.
///
/// `Visibility` and `Offstage` are the obvious tools and neither fits.
/// `Offstage` stops layout, so the screen would arrive unmeasured. `Visibility`
/// moves semantics, and toggling that from inside a scheduler callback trips
/// `!semantics.parentDataDirty` in the framework - which it did, on the tap
/// that ends the opening.
class _PaintGate extends SingleChildRenderObjectWidget {
  const _PaintGate({required this.painting, required super.child});

  final bool painting;

  @override
  _RenderPaintGate createRenderObject(BuildContext context) =>
      _RenderPaintGate(painting);

  @override
  void updateRenderObject(BuildContext context, _RenderPaintGate renderObject) {
    renderObject.painting = painting;
  }
}

class _RenderPaintGate extends RenderProxyBox {
  _RenderPaintGate(this._painting);

  bool _painting;

  set painting(bool value) {
    if (_painting == value) return;
    _painting = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_painting) return;
    super.paint(context, offset);
  }
}

/// The shut book, the ground it sits on, and the mark that asks for a tap.
///
/// Every moving part of this scene is driven from an [Animation] it is handed,
/// and each one is wrapped as tightly around what it actually moves as it can
/// be. The scene used to be one builder listening to all three controllers at
/// once, which meant the breathing mark - which never stops while the reader is
/// looking at the cover - rebuilt the cover, the welcome page, the curl and the
/// whole layout calculation on every frame of a screen that is, by design,
/// standing still. On a 120 Hz phone that is 120 rebuilds a second of a picture
/// that is not changing.
class _OpeningScene extends StatelessWidget {
  const _OpeningScene({
    required this.turn,
    required this.leave,
    required this.hint,
    required this.waiting,
    required this.curlController,
    required this.coverArtBuilder,
    required this.quote,
  });

  /// The line printed on the page inside the cover, drawn once per launch.
  final OpeningQuote quote;

  /// How far the cover has turned, and how far the page has grown into the
  /// application. Each belongs to one tap.
  final Animation<double> turn;
  final Animation<double> leave;

  /// The breath of the mark that asks for the next tap.
  final Animation<double> hint;

  /// Whether the book is standing still, waiting to be touched.
  final bool waiting;

  final PageCurlController curlController;
  final OpeningCoverArtBuilder? coverArtBuilder;

  static final Color _coverGround = PaperfoldTokens.cover.ground;
  static const Color _coverEdge = PaperfoldTokens.blackRaspberry;

  /// The stiffness of the sheet the curl is turning.
  ///
  /// High, because this one is a cover board and not a leaf. A board rolls
  /// loose and wide; paper rolls tight. It is the one number that makes the
  /// opening of a book feel unlike the turning of a page inside it.
  static const double _boardStiffness = 96.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textDirection = Directionality.of(context);
    final isPortrait = size.height >= size.width;

    double bookHeight = math.min(
      size.height * (isPortrait ? 0.57 : 0.76),
      490.0,
    );
    double bookWidth = bookHeight * 0.68;
    final maxInitialWidth = size.width * (isPortrait ? 0.68 : 0.42);
    if (bookWidth > maxInitialWidth) {
      bookWidth = maxInitialWidth;
      bookHeight = bookWidth / 0.68;
    }

    // Guarded, because the whole of this scene hangs off one division. A window
    // that reports no size yet - which a desktop shell can do for a frame, and
    // a MediaQuery built by hand always does - divides zero by zero, and the
    // NaN goes into a Transform. A NaN transform does not draw wrong: it takes
    // the hit test with it, so nothing on the screen can be touched again.
    final fits = bookWidth > 0 && bookHeight > 0;
    final targetScale = fits
        ? math.min(
            1.5,
            math.max(
              1.0,
              math.min(
                (size.width * 0.94) / bookWidth,
                (size.height * 0.94) / bookHeight,
              ),
            ),
          )
        : 1.0;

    // Built once. Neither the cover nor the welcome page has anything in it
    // that a frame of the opening changes, and both are the live sources the
    // curl captures, so rebuilding them mid-turn is work thrown away twice.
    final book = SizedBox(
      width: bookWidth,
      height: bookHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            WidgetPageCurl(
              controller: curlController,
              interactive: false,
              front: _BookCover(artBuilder: coverArtBuilder),
              back: _WelcomePage(quote: quote),
              textDirection: textDirection,
              radius: _boardStiffness,
              shadow: 0.82,
            ),
            // The page, once the turn is over and the curl has nothing left to
            // do.
            //
            // A curl does not put the sheet down flat: it leaves a few pixels
            // of roll and its own shadow at the gutter, so a finished turn read
            // as a strip of burgundy board and a grey smear down the leading
            // edge of the paper. That is right in the middle of a turn and
            // wrong after it. Laid over the top at the end, the page is a page.
            AnimatedBuilder(
              animation: turn,
              builder: (context, child) {
                final settled = ((turn.value - 0.94) / 0.06).clamp(0.0, 1.0);
                if (settled <= 0) return const SizedBox.shrink();
                return Opacity(opacity: settled, child: child);
              },
              child: _WelcomePage(quote: quote),
            ),
            // The spine, and only while there is a shut book to have one.
            //
            // It is a strip of dark board laid down the leading edge of the
            // object. On the shut cover it is the fold the board turns on; on
            // the open page it is a bar of burgundy printed across the paper,
            // which is what the reader kept catching their eye on. It goes as
            // the cover goes.
            Align(
              alignment: textDirection == TextDirection.rtl
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: AnimatedBuilder(
                animation: turn,
                builder: (context, child) => Opacity(
                  opacity: (1.0 - turn.value * 2.4).clamp(0.0, 1.0),
                  child: child,
                ),
                child: const _FixedSpine(),
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // The ground follows the cover, so the dark of the board gives way to
        // the cream of the paper exactly as the paper is uncovered, and then
        // gives way itself as the application arrives. Faded as a colour rather
        // than under an `Opacity`: a translucent rectangle is one blend, and an
        // opacity layer over the whole screen is an offscreen buffer the size
        // of the screen, allocated and composited on every frame of the last
        // movement.
        AnimatedBuilder(
          animation: Listenable.merge([turn, leave]),
          builder: (context, _) => ColoredBox(
            color: Color.lerp(
              _coverEdge,
              // Burgundy, not paper. The ground used to come up to the colour
              // of the page as the cover turned, so an opened book was a sheet
              // of cream paper on a sheet of cream ground: the page had no
              // edges and the object stopped being an object. Left burgundy,
              // the page is a page lying inside its own covers.
              _coverGround,
              Curves.easeInOutCubic.transform(turn.value),
            )!
                .withValues(alpha: 1.0 - _chromeReveal(leave.value)),
          ),
        ),
        SafeArea(
          child: Stack(
            children: [
              // Its own layer. The book carries a 34-pixel drop shadow, which
              // is a real blur pass, and the mark below breathes on every
              // vsync. Sharing one layer with the mark meant that blur was
              // re-rastered 120 times a second for a picture standing still:
              // 6.4 ms of an 8.3 ms frame, to show a shut book.
              RepaintBoundary(
                child: Center(
                  child: AnimatedBuilder(
                    animation: leave,
                    child: book,
                    builder: (context, child) {
                      // The page grows into the application on the last tap, and
                      // the book goes with the end of that growth rather than on
                      // a clock of its own.
                      final moveIn = PaperfoldMotion.settle.transform(
                        leave.value,
                      );
                      final gone = _chromeReveal(leave.value);
                      return Transform.translate(
                        offset: Offset(0.0, -10.0 * moveIn),
                        child: Transform.scale(
                          scale: 1.0 + ((targetScale - 1.0) * moveIn),
                          child: Opacity(
                            opacity: 1.0 - gone,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: _coverGround.withValues(
                                      alpha: 0.34 * (1.0 - (moveIn * 0.45)),
                                    ),
                                    offset: Offset(0.0, 18.0 - (8.0 * moveIn)),
                                    blurRadius: 34.0 - (10.0 * moveIn),
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // The mark that asks for the tap. A screen that waits and shows
              // nothing is a screen that has hung, and this one waits on
              // purpose.
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: _TapMark(
                      breath: hint,
                      showing: waiting,
                      textDirection: textDirection,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// How far the application underneath has been handed the screen.
  static double _chromeReveal(double leave) =>
      Curves.easeInOutCubic.transform(((leave - 0.62) / 0.38).clamp(0.0, 1.0));
}

/// The chevron under the book that says the reader is the one who turns it.
///
/// No words: this is the first screen of the application, before a locale has
/// been settled and before anything has been read, and a chevron pointing the
/// way the reader reads needs no translating.
class _TapMark extends StatelessWidget {
  const _TapMark({
    required this.breath,
    required this.showing,
    required this.textDirection,
  });

  final Animation<double> breath;

  final bool showing;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    // Two layers, because the two have different jobs: the breath changes every
    // frame and must not be a target anything animates toward, and the coming
    // and going is a target that must never be re-aimed mid-flight.
    //
    // The breath is now inside the painter rather than an `Opacity` above it,
    // so a mark that breathes for as long as the reader looks at the cover
    // costs one repaint of a strip 26 pixels tall and no rebuild at all.
    return AnimatedOpacity(
      opacity: showing ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      child: SizedBox(
        height: 26,
        child: CustomPaint(
          painter: _TapMarkPainter(
            breath: breath,
            still: still,
            mirror: textDirection == TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}

class _TapMarkPainter extends CustomPainter {
  _TapMarkPainter({
    required this.breath,
    required this.still,
    required this.mirror,
  }) : super(repaint: breath);

  final Animation<double> breath;
  final bool still;
  final bool mirror;

  /// The two chevrons, and how far behind the first the second breathes.
  static const List<double> _leads = [-8.0, 4.0];
  static const double _lag = 0.22;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    const reach = 7.0;
    // The ground stays burgundy after opening. Keep the next-tap hint legible.
    final ink = PaperfoldTokens.cover.foil;
    final direction = mirror ? -1.0 : 1.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < _leads.length; i++) {
      final lead = _leads[i];
      // Out of phase, so the pair reads as something travelling the way the
      // reader reads rather than as two shapes blinking together.
      final phase = still ? 1.0 : (breath.value - i * _lag).clamp(0.0, 1.0);
      final pulse =
          still ? 0.9 : (0.36 + 0.54 * Curves.easeInOut.transform(phase));
      final tip = centre.dx + direction * (lead + reach);
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx + direction * lead, centre.dy - reach)
          ..lineTo(tip, centre.dy)
          ..lineTo(centre.dx + direction * lead, centre.dy + reach),
        paint..color = ink.withValues(alpha: pulse),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TapMarkPainter oldDelegate) =>
      oldDelegate.breath != breath ||
      oldDelegate.still != still ||
      oldDelegate.mirror != mirror;
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.artBuilder});

  final OpeningCoverArtBuilder? artBuilder;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paperfold',
      image: true,
      child: artBuilder?.call(context) ??
          Image.asset(
            'assets/images/paperfold_cover.jpg',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.quote});

  /// What is printed on this page. A real line by a real writer, drawn once
  /// per launch, and named: an unattributed aphorism on a first screen is a
  /// slogan however well it is set.
  final OpeningQuote quote;

  @override
  Widget build(BuildContext context) {
    final rightToLeft = Directionality.of(context) == TextDirection.rtl;
    final align = rightToLeft ? TextAlign.right : TextAlign.left;
    return ColoredBox(
      color: PaperfoldTokens.light.ground,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/paperfold_paper.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(34.0, 38.0, 30.0, 34.0),
          // No `Spacer`, and no `Flexible` on the type.
          //
          // The block used to be held between two flexible gaps. A `Spacer` is
          // an `Expanded`, so the gaps took the free height first and the text
          // was handed whatever was left: on a phone the second line of a
          // two-line quotation was cut off across its middle. The block now
          // measures itself and is placed a little below centre, and the whole
          // of it is clipped rather than any one line of it - a page laid out
          // in a box too small for it should lose its margins, not its words.
          child: ClipRect(
            child: Align(
              alignment: rightToLeft
                  ? const Alignment(1, 0.08)
                  : const Alignment(-1, 0.08),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: rightToLeft
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    '“${quote.words}”',
                    textAlign: align,
                    style: const TextStyle(
                      color: PaperfoldTokens.blackRaspberry,
                      fontFamily: PaperfoldTypeTokens.journalFamily,
                      fontSize: 21.0,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18.0),
                  SizedBox(
                    width: 48.0,
                    child: Divider(
                      height: 1.0,
                      thickness: 1.0,
                      color: PaperfoldTokens.cover.foil,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    quote.source,
                    textAlign: align,
                    style: const TextStyle(
                      color: PaperfoldTokens.spicedHotChocolate,
                      fontFamily: PaperfoldTypeTokens.chromeFamily,
                      fontSize: 12.0,
                      letterSpacing: 1.4,
                      height: 1.2,
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
}

class _FixedSpine extends StatelessWidget {
  const _FixedSpine();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 7.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: Directionality.of(context) == TextDirection.rtl
                  ? const [Color(0x553A2E28), Color(0xFF21090F)]
                  : const [Color(0xFF21090F), Color(0x553A2E28)],
            ),
          ),
        ),
      ),
    );
  }
}
