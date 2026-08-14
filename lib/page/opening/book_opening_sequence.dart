import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/page_curl/page_curl.dart';

/// The book opening, played over the reader while the reader loads behind it.
///
/// The cold-start sequence in `opening_sequence.dart` does this for a
/// provisional cover once per launch. This is the same motion for a real book,
/// on the way from its cover screen into the reader: the cover curls open on a
/// fixed spine, the view moves in until the page fills the screen, and the
/// overlay lifts.
///
/// The reader is mounted underneath from the first frame. That is the whole
/// point of running this as a route transition rather than as a screen of its
/// own - a WebView takes time to lay out and paint its first page, and if the
/// zoom finished before it had, the reader would arrive as a white rectangle.
/// By the time the overlay lifts the page underneath is real.
///
/// Every rule from `plan.md` Section 6.2 applies here as much as it does to the
/// cold start: a tap anywhere skips it from the first frame, the system
/// "Remove animations" setting replaces it with a cross-fade, and it is
/// direction-aware so a right-to-left book opens from the other side.
class BookOpeningSequence extends StatefulWidget {
  const BookOpeningSequence({
    super.key,
    required this.book,
    required this.child,
    this.onFinished,
  });

  final Book book;

  /// The reader, mounted and painting behind the animation.
  final Widget child;

  final VoidCallback? onFinished;

  static const Duration duration = Duration(milliseconds: 1050);

  @override
  State<BookOpeningSequence> createState() => _BookOpeningSequenceState();
}

class _BookOpeningSequenceState extends State<BookOpeningSequence>
    with SingleTickerProviderStateMixin {
  final PageCurlController _curl = PageCurlController();
  late final AnimationController _timeline;

  bool _started = false;
  bool _finished = false;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _timeline = AnimationController(
      vsync: this,
      duration: BookOpeningSequence.duration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
    WidgetsBinding.instance.addPostFrameCallback(_start);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Checked live rather than once, so turning the system setting on mid-flight
    // still lands the reader immediately.
    if (MediaQuery.disableAnimationsOf(context) && !_finished) {
      _finished = true;
      _timeline.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
    }
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  void _start(Duration _) {
    if (!mounted || _started || _finished) return;
    _started = true;
    unawaited(_runCurl());
    unawaited(_timeline.forward());
  }

  Future<void> _runCurl() async {
    try {
      await _curl.animate(
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeOutCubic,
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'book opening sequence',
          context: ErrorDescription('while opening ${widget.book.title}'),
        ),
      );
    }
  }

  void _finish() {
    if (_finished) return;
    setState(() => _finished = true);
    _timeline.stop();
    _notify();
  }

  void _notify() {
    if (_notified) return;
    _notified = true;
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_finished)
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _finish(),
            child: AnimatedBuilder(
              animation: _timeline,
              builder: (context, _) => _OpeningBook(
                book: widget.book,
                progress: _timeline.value,
                curl: _curl,
              ),
            ),
          ),
      ],
    );
  }
}

class _OpeningBook extends StatelessWidget {
  const _OpeningBook({
    required this.book,
    required this.progress,
    required this.curl,
  });

  final Book book;
  final double progress;
  final PageCurlController curl;

  double _interval(double begin, double end, {Curve curve = Curves.linear}) {
    return curve.transform(
      ((progress - begin) / (end - begin)).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final textDirection = Directionality.of(context);
    final isPortrait = size.height >= size.width;

    // The book starts at about the size it was on its cover screen, so the
    // motion continues from where the reader was looking rather than starting
    // over somewhere else.
    var bookHeight = math.min(size.height * (isPortrait ? 0.55 : 0.74), 470.0);
    var bookWidth = bookHeight * 0.68;
    final maxWidth = size.width * (isPortrait ? 0.66 : 0.4);
    if (bookWidth > maxWidth) {
      bookWidth = maxWidth;
      bookHeight = bookWidth / 0.68;
    }

    // It ends filling the screen, which is where the page is.
    final targetScale = math.max(
      size.width / bookWidth,
      size.height / bookHeight,
    );
    final moveIn = _interval(0.40, 0.90, curve: Curves.easeInOutCubic);
    final scale = 1.0 + ((targetScale - 1.0) * moveIn);
    final lift = _interval(0.86, 1.0, curve: Curves.easeInCubic);

    return Opacity(
      opacity: 1.0 - lift,
      child: ColoredBox(
        color: scheme.surface,
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: bookWidth,
              height: bookHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(
                        alpha: 0.34 * (1.0 - moveIn),
                      ),
                      offset: Offset(0, 18 - (14 * moveIn)),
                      blurRadius: 34 - (20 * moveIn),
                    ),
                  ],
                ),
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      WidgetPageCurl(
                        controller: curl,
                        interactive: false,
                        textDirection: textDirection,
                        radius: 58,
                        shadow: 0.82,
                        front: BookCover(
                          book: book,
                          width: bookWidth,
                          height: bookHeight,
                        ),
                        // What is behind the cover is the page, and the page is
                        // the reader. A plain sheet in the reader's own surface
                        // colour is what the WebView is about to replace, so
                        // the swap at the end has nothing to announce.
                        back: ColoredBox(color: scheme.surface),
                      ),
                      // The spine stays fixed while the cover lifts off it.
                      Align(
                        alignment: textDirection == TextDirection.rtl
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 1.0 - moveIn,
                            child: SizedBox(
                              width: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      scheme.shadow.withValues(alpha: 0.42),
                                      scheme.shadow.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
