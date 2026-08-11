import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paperfold/widgets/page_curl/page_curl.dart';

/// Builds the line artwork placed over the provisional opening cover.
///
/// Milestone 3 can supply the final user artwork here without changing the
/// opening motion, cover material, or page-curl integration.
typedef OpeningCoverArtBuilder = Widget Function(BuildContext context);

/// A cold-start book opening that reveals [child] in at most 1.2 seconds.
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

  // Leave one frame of headroom inside the 1.2 second interaction budget.
  static const Duration duration = Duration(milliseconds: 1150);

  final Widget child;
  final VoidCallback? onFinished;
  final OpeningCoverArtBuilder? coverArtBuilder;

  @override
  State<OpeningSequence> createState() => _OpeningSequenceState();
}

class _OpeningSequenceState extends State<OpeningSequence>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final PageCurlController _curlController = PageCurlController();
  late final AnimationController _timeline;

  bool _started = false;
  bool _finished = false;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _timeline = AnimationController(
      vsync: this,
      duration: OpeningSequence.duration,
    )..addStatusListener(_handleTimelineStatus);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(_startAfterFirstPaint);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && !_finished) {
      _finished = true;
      _timeline.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyFinished());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeline.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _finish();
    }
  }

  void _startAfterFirstPaint(Duration _) {
    if (!mounted || _started || _finished) {
      return;
    }
    _started = true;
    unawaited(_warmShader());
    unawaited(_runCurl());
    unawaited(_timeline.forward());
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

  Future<void> _runCurl() async {
    try {
      await _curlController.animate(
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    } catch (error, stackTrace) {
      _reportError(error, stackTrace, 'while opening the book cover');
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

  void _handleTimelineStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) {
      return;
    }
    _finished = true;
    _timeline.stop();
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
              builder: (context, _) => _OpeningScene(
                progress: _timeline.value,
                curlController: _curlController,
                coverArtBuilder: widget.coverArtBuilder,
              ),
            ),
          ),
      ],
    );
  }
}

class _OpeningScene extends StatelessWidget {
  const _OpeningScene({
    required this.progress,
    required this.curlController,
    required this.coverArtBuilder,
  });

  final double progress;
  final PageCurlController curlController;
  final OpeningCoverArtBuilder? coverArtBuilder;

  static const Color _paper = Color(0xFFFAF6EE);
  static const Color _coverGround = Color(0xFF3B111D);
  static const Color _coverEdge = Color(0xFF21090F);

  double _interval(
    double begin,
    double end, {
    Curve curve = Curves.linear,
  }) {
    final value = ((progress - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(value);
  }

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

    final widthScale = (size.width * 0.94) / bookWidth;
    final heightScale = (size.height * 0.94) / bookHeight;
    final targetScale = math.min(
      1.5,
      math.max(1.0, math.min(widthScale, heightScale)),
    );
    final moveIn = _interval(0.42, 0.88, curve: Curves.easeOutCubic);
    final scale = 1.0 + ((targetScale - 1.0) * moveIn);
    final chromeReveal = _interval(0.82, 0.98, curve: Curves.easeInOutCubic);
    final pageArrival = _interval(0.48, 0.9, curve: Curves.easeOutCubic);
    final background = Color.lerp(_coverEdge, _paper, pageArrival)!;

    return Opacity(
      opacity: 1.0 - chromeReveal,
      child: ColoredBox(
        color: background,
        child: SafeArea(
          child: Center(
            child: Transform.translate(
              offset: Offset(0.0, -10.0 * moveIn),
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: bookWidth,
                  height: bookHeight,
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5.0),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          WidgetPageCurl(
                            controller: curlController,
                            interactive: false,
                            front: _BookCover(
                              artBuilder: coverArtBuilder,
                            ),
                            back: const _WelcomePage(),
                            textDirection: textDirection,
                            radius: 58.0,
                            shadow: 0.82,
                          ),
                          Align(
                            alignment: textDirection == TextDirection.rtl
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: const _FixedSpine(),
                          ),
                        ],
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
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.artBuilder});

  final OpeningCoverArtBuilder? artBuilder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4A1424),
            Color(0xFF2C0B14),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // MILESTONE 3 EXTENSION POINT: replace only this artwork layer.
          if (artBuilder case final builder?)
            builder(context)
          else
            const CustomPaint(painter: _ProvisionalCoverArtPainter()),
          const Padding(
            padding: EdgeInsets.fromLTRB(28.0, 36.0, 28.0, 34.0),
            child: Column(
              children: [
                Spacer(flex: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'PAPERFOLD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFC4A071),
                      fontFamily: 'SourceHanSerif',
                      fontSize: 24.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.0,
                      height: 1.0,
                    ),
                  ),
                ),
                SizedBox(height: 14.0),
                SizedBox(
                  width: 42.0,
                  child: Divider(
                    height: 1.0,
                    thickness: 1.0,
                    color: Color(0xFFC4A071),
                  ),
                ),
                Spacer(flex: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFAF6EE),
      child: CustomPaint(
        painter: const _WelcomePagePainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(34.0, 38.0, 30.0, 34.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 5),
              Text(
                '“A page remembers what we almost forgot.”',
                textAlign: Directionality.of(context) == TextDirection.rtl
                    ? TextAlign.right
                    : TextAlign.left,
                style: const TextStyle(
                  color: Color(0xFF3A2E28),
                  fontFamily: 'SourceHanSerif',
                  fontSize: 21.0,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22.0),
              const SizedBox(
                width: 48.0,
                child: Divider(
                  height: 1.0,
                  thickness: 1.0,
                  color: Color(0xFF846044),
                ),
              ),
              const Spacer(flex: 4),
            ],
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

class _ProvisionalCoverArtPainter extends CustomPainter {
  const _ProvisionalCoverArtPainter();

  static const Color _gold = Color(0xFFC4A071);

  @override
  void paint(Canvas canvas, Size size) {
    final fine = Paint()
      ..color = _gold.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final strong = Paint()
      ..color = _gold.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final inset = math.min(size.width, size.height) * 0.075;
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(frame, fine);

    final center = Offset(size.width * 0.5, size.height * 0.31);
    final motifWidth = size.width * 0.23;
    final motifHeight = size.height * 0.075;
    final leftPage = Path()
      ..moveTo(center.dx, center.dy + motifHeight)
      ..quadraticBezierTo(
        center.dx - motifWidth * 0.38,
        center.dy + motifHeight * 0.2,
        center.dx - motifWidth,
        center.dy + motifHeight * 0.46,
      )
      ..lineTo(center.dx - motifWidth, center.dy - motifHeight * 0.55)
      ..quadraticBezierTo(
        center.dx - motifWidth * 0.38,
        center.dy - motifHeight * 0.82,
        center.dx,
        center.dy,
      )
      ..close();
    final rightPage = Path()
      ..moveTo(center.dx, center.dy + motifHeight)
      ..quadraticBezierTo(
        center.dx + motifWidth * 0.38,
        center.dy + motifHeight * 0.2,
        center.dx + motifWidth,
        center.dy + motifHeight * 0.46,
      )
      ..lineTo(center.dx + motifWidth, center.dy - motifHeight * 0.55)
      ..quadraticBezierTo(
        center.dx + motifWidth * 0.38,
        center.dy - motifHeight * 0.82,
        center.dx,
        center.dy,
      )
      ..close();
    canvas
      ..drawPath(leftPage, strong)
      ..drawPath(rightPage, strong)
      ..drawLine(
        Offset(center.dx, center.dy),
        Offset(center.dx, center.dy + motifHeight),
        fine,
      );

    final ruleHalfWidth = size.width * 0.12;
    final upperRuleY = size.height * 0.18;
    final lowerRuleY = size.height * 0.79;
    canvas
      ..drawLine(
        Offset(center.dx - ruleHalfWidth, upperRuleY),
        Offset(center.dx + ruleHalfWidth, upperRuleY),
        fine,
      )
      ..drawLine(
        Offset(center.dx - ruleHalfWidth, lowerRuleY),
        Offset(center.dx + ruleHalfWidth, lowerRuleY),
        fine,
      );
  }

  @override
  bool shouldRepaint(covariant _ProvisionalCoverArtPainter oldDelegate) {
    return false;
  }
}

class _WelcomePagePainter extends CustomPainter {
  const _WelcomePagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final inset = math.min(size.width, size.height) * 0.055;
    canvas.drawRect(
      Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset),
      Paint()
        ..color = const Color(0xFFC4A071).withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _WelcomePagePainter oldDelegate) => false;
}
