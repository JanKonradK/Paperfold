import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:paperfold/config/paperfold_motion.dart';

/// Selects the GPU curl or the no-shader fold fallback.
enum PageCurlEffect {
  curl,
  fold,
}

/// Describes the source of the current page-curl frame.
enum PageCurlPhase {
  idle,
  dragging,
  settling,
  timed,
}

/// A post-transition seam reserved for Step C surface and settle effects.
typedef PageCurlDecorator = Widget Function(
  BuildContext context,
  Widget child,
  double progress,
  PageCurlPhase phase,
);

abstract interface class _PageCurlHandle {
  double get progress;

  Future<void> animate({
    required double to,
    required Duration duration,
    required Curve curve,
  });

  void jumpTo(double progress);

  void dragBegin(Offset localPosition);

  void dragUpdate(Offset localPosition);

  void dragEnd(double velocityX);

  void dragCancel();
}

/// Where the turn has got to, as one value the painters can be pointed at.
///
/// This exists so that a frame of the curl costs a repaint and nothing else.
/// Every field of it changes on every frame of a turn, and a `setState` for
/// each of those frames would rebuild the widget tree, lay it out, and rebuild
/// the two live pages underneath - all to move a number the shader reads. At
/// 120 Hz there are 8.3 milliseconds for the whole frame, and a rebuild storm
/// spends them before the shader is reached.
@immutable
class _CurlFrame {
  const _CurlFrame(this.progress, this.pointer);

  final double progress;
  final Offset pointer;

  @override
  bool operator ==(Object other) =>
      other is _CurlFrame &&
      other.progress == progress &&
      other.pointer == pointer;

  @override
  int get hashCode => Object.hash(progress, pointer);
}

/// Controls interactive and fixed-time page curls.
class PageCurlController {
  _PageCurlHandle? _handle;

  /// Whether this controller is connected to a page curl.
  bool get isAttached => _handle != null;

  /// The visible transition position from the front page to the back page.
  double get progress => _handle?.progress ?? 0.0;

  /// Runs a fixed-time, non-interactive curl to [to].
  ///
  /// Interactive releases do not call this method. They use spring physics.
  Future<void> animate({
    double to = 1.0,
    Duration duration = PaperfoldMotion.pageTurn,
    Curve curve = PaperfoldMotion.turn,
  }) {
    final handle = _handle;
    if (handle == null) {
      throw StateError('PageCurlController is not attached to a page curl.');
    }
    return handle.animate(to: to, duration: duration, curve: curve);
  }

  /// Sets the curl position immediately without animation.
  void jumpTo(double progress) {
    _require().jumpTo(progress);
  }

  /// Takes hold of the page at [localPosition], in the curl's own coordinates.
  ///
  /// These four exist for a host that owns the gesture itself rather than
  /// letting this widget's own `GestureDetector` have it. The reader is that
  /// host: its pages live in a WebView, so the finger lands on the WebView and
  /// the drag arrives second-hand, forwarded out of JavaScript. Without this
  /// the interactive curl - the pointer-led fold, the spring, the flick - could
  /// only ever be reached by a Flutter gesture, which the reader does not get,
  /// and so the reader had no drag-turn at all.
  void dragBegin(Offset localPosition) {
    _require().dragBegin(localPosition);
  }

  /// Moves the held page to [localPosition].
  void dragUpdate(Offset localPosition) {
    _require().dragUpdate(localPosition);
  }

  /// Lets the page go at [velocityX] pixels a second, and springs it home.
  void dragEnd(double velocityX) {
    _require().dragEnd(velocityX);
  }

  /// Abandons the hold and springs the page back where it came from.
  void dragCancel() {
    _require().dragCancel();
  }

  _PageCurlHandle _require() {
    final handle = _handle;
    if (handle == null) {
      throw StateError('PageCurlController is not attached to a page curl.');
    }
    return handle;
  }

  void _attach(_PageCurlHandle handle) {
    assert(
      _handle == null || identical(_handle, handle),
      'A PageCurlController can control only one page curl at a time.',
    );
    _handle = handle;
  }

  void _detach(_PageCurlHandle handle) {
    if (identical(_handle, handle)) {
      _handle = null;
    }
  }
}

/// A pointer-driven page turn rendered from two full-resolution images.
///
/// [frontImage] is the sheet being turned. [backImage] is the page revealed
/// below it. The caller retains ownership of both images and must dispose them.
/// Use [WidgetPageCurl] when the page sources are live Flutter widgets.
class PageCurl extends StatefulWidget {
  const PageCurl({
    super.key,
    required this.frontImage,
    required this.backImage,
    required this.textDirection,
    this.controller,
    this.interactive = true,
    this.reduceMotion = false,
    this.effect = PageCurlEffect.curl,
    this.initialProgress = 0.0,
    this.radius = 72.0,
    this.shadow = 0.78,
    this.settleThreshold = 0.5,
    this.onProgressChanged,
    this.onSettled,
    this.decorator,
  })  : assert(initialProgress >= 0.0 && initialProgress <= 1.0),
        assert(radius > 0.0),
        assert(shadow >= 0.0 && shadow <= 1.0),
        assert(settleThreshold >= 0.0 && settleThreshold <= 1.0);

  static const String shaderAsset = 'shaders/page_curl.frag';
  static Future<ui.FragmentProgram>? _program;

  final ui.Image frontImage;
  final ui.Image backImage;
  final TextDirection textDirection;
  final PageCurlController? controller;
  final bool interactive;

  /// When true, replaces curl and fold motion with a pointer-led cross-fade.
  ///
  /// The caller owns the platform accessibility setting. This widget never
  /// reads it directly.
  final bool reduceMotion;

  final PageCurlEffect effect;
  final double initialProgress;

  /// How stiff the sheet is.
  ///
  /// Larger rolls looser and wider, the way a cover board does; smaller rolls
  /// tight, the way a leaf does. It is no longer a radius in pixels: the radius
  /// of the roll grows with the paper taken up into it, which is what stops a
  /// long turn winding itself into a scroll.
  final double radius;

  final double shadow;
  final double settleThreshold;
  final ValueChanged<double>? onProgressChanged;
  final ValueChanged<bool>? onSettled;

  /// Optional Step C hook applied after curl, fold, or cross-fade rendering.
  final PageCurlDecorator? decorator;

  static Future<ui.FragmentProgram> _loadProgram() {
    return _program ??= ui.FragmentProgram.fromAsset(shaderAsset);
  }

  /// Loads the shader and submits one fully configured offscreen frame.
  static Future<void> warmUp() async {
    final program = await _loadProgram();
    final shader = program.fragmentShader();

    Future<ui.Image> makeSourceImage(Color color) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
        Paint()..color = color,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(1, 1);
      picture.dispose();
      return image;
    }

    final frontImage = await makeSourceImage(Colors.white);
    final backImage = await makeSourceImage(Colors.black);

    shader
      ..setFloat(0, 1.0)
      ..setFloat(1, 1.0)
      ..setFloat(2, 0.5)
      ..setFloat(3, 0.5)
      ..setFloat(4, 0.5)
      ..setFloat(5, -1.0)
      ..setFloat(6, 72.0)
      ..setFloat(7, 0.78)
      ..setImageSampler(0, frontImage)
      ..setImageSampler(1, backImage);

    final outputRecorder = ui.PictureRecorder();
    final outputCanvas = Canvas(outputRecorder);
    outputCanvas.drawRect(
      const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
      Paint()..shader = shader,
    );
    final outputPicture = outputRecorder.endRecording();
    final outputImage = await outputPicture.toImage(1, 1);

    outputImage.dispose();
    outputPicture.dispose();
    frontImage.dispose();
    backImage.dispose();
    shader.dispose();
  }

  @override
  State<PageCurl> createState() => _PageCurlState();
}

class _PageCurlState extends State<PageCurl>
    with SingleTickerProviderStateMixin
    implements _PageCurlHandle {
  late final AnimationController _motionController;

  /// The one thing that changes every frame, and the one thing the painters
  /// listen to. Nothing rebuilds while a turn is running.
  late final ValueNotifier<_CurlFrame> _frame;

  Future<ui.FragmentProgram>? _program;
  ui.FragmentShader? _shader;

  Size _pageSize = Size.zero;
  PageCurlPhase _phase = PageCurlPhase.idle;

  double get _direction =>
      widget.textDirection == TextDirection.rtl ? 1.0 : -1.0;

  @override
  double get progress => _frame.value.progress;

  Offset get _pointer => _frame.value.pointer;

  @override
  void initState() {
    super.initState();
    _frame = ValueNotifier<_CurlFrame>(
      _CurlFrame(widget.initialProgress, Offset.zero),
    );
    _motionController = AnimationController.unbounded(
      value: widget.initialProgress,
      vsync: this,
    )..addListener(_handleMotionTick);
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant PageCurl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.textDirection != widget.textDirection &&
        _phase != PageCurlPhase.dragging &&
        !_pageSize.isEmpty) {
      _frame.value = _CurlFrame(
        progress,
        _pointerForProgress(progress, _pageSize),
      );
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _motionController.dispose();
    _frame.dispose();
    _shader?.dispose();
    super.dispose();
  }

  /// Publishes one frame of the turn without touching the widget tree.
  void _emit(double value, Offset pointer, {bool notify = true}) {
    _frame.value = _CurlFrame(value, pointer);
    if (notify) {
      widget.onProgressChanged?.call(value);
    }
  }

  void _handleMotionTick() {
    if (!mounted) {
      return;
    }
    final value = _motionController.value.clamp(0.0, 1.0).toDouble();
    _emit(
      value,
      _pageSize.isEmpty ? _pointer : _pointerForProgress(value, _pageSize),
    );
  }

  Offset _pointerForProgress(double value, Size size) {
    final x =
        _direction > 0.0 ? size.width * value : size.width * (1.0 - value);
    return Offset(x, size.height * 0.5);
  }

  double _progressForPointer(Offset pointer, Size size) {
    if (size.width <= 0.0) {
      return progress;
    }
    final value = _direction > 0.0
        ? pointer.dx / size.width
        : (size.width - pointer.dx) / size.width;
    return value.clamp(0.0, 1.0).toDouble();
  }

  Offset _clampPointer(Offset pointer, Size size) {
    return Offset(
      pointer.dx.clamp(0.0, size.width).toDouble(),
      pointer.dy.clamp(0.0, size.height).toDouble(),
    );
  }

  void _setPhase(PageCurlPhase phase) {
    if (_phase == phase || !mounted) {
      return;
    }
    setState(() => _phase = phase);
  }

  @override
  void dragBegin(Offset localPosition) => _beginDragAt(localPosition);

  @override
  void dragUpdate(Offset localPosition) => _updateDragAt(localPosition);

  @override
  void dragEnd(double velocityX) => _endDragWithVelocity(velocityX);

  @override
  void dragCancel() => _cancelDrag();

  void _beginDragAt(Offset localPosition) {
    _motionController.stop();
    final pointer = _clampPointer(localPosition, _pageSize);
    _setPhase(PageCurlPhase.dragging);
    _emit(_progressForPointer(pointer, _pageSize), pointer);
  }

  void _updateDragAt(Offset localPosition) {
    final pointer = _clampPointer(localPosition, _pageSize);
    _emit(_progressForPointer(pointer, _pageSize), pointer);
  }

  void _endDragWithVelocity(double velocityX) {
    // In pages per second, and positive in the direction the turn completes.
    final velocity =
        _pageSize.width <= 0.0 ? 0.0 : velocityX * _direction / _pageSize.width;
    // A page thrown hard goes where it was thrown. Only a page let go of at
    // rest is judged on where it was left, because only then is there nothing
    // else to go on. Reading the threshold first is what makes a fast flick
    // that started early spring backwards under the reader's own hand.
    final double target;
    if (velocity.abs() >= PaperfoldMotion.flickVelocity) {
      target = velocity > 0.0 ? 1.0 : 0.0;
    } else {
      target = progress >= widget.settleThreshold ? 1.0 : 0.0;
    }
    _startSpring(target, velocity);
  }

  void _cancelDrag() {
    _startSpring(0.0, 0.0);
  }

  void _onDragStart(DragStartDetails details) {
    _beginDragAt(details.localPosition);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _updateDragAt(details.localPosition);
  }

  void _onDragEnd(DragEndDetails details) {
    _endDragWithVelocity(details.velocity.pixelsPerSecond.dx);
  }

  void _onDragCancel() {
    _cancelDrag();
  }

  void _startSpring(double target, double velocity) {
    _setPhase(PageCurlPhase.settling);
    _motionController.value = progress;
    final simulation = SpringSimulation(
      PaperfoldMotion.release,
      progress,
      target,
      velocity,
      tolerance: PaperfoldMotion.releaseTolerance,
    );
    _motionController.animateWith(simulation).whenCompleteOrCancel(() {
      if (!mounted) {
        return;
      }
      _emit(target, _pointerForProgress(target, _pageSize));
      _setPhase(PageCurlPhase.idle);
      widget.onSettled?.call(target == 1.0);
    });
  }

  @override
  Future<void> animate({
    required double to,
    required Duration duration,
    required Curve curve,
  }) async {
    assert(duration > Duration.zero);
    final target = to.clamp(0.0, 1.0).toDouble();
    _motionController.stop();
    _motionController.value = progress;
    _setPhase(PageCurlPhase.timed);
    try {
      await _motionController
          .animateTo(target, duration: duration, curve: curve)
          .orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) {
      return;
    }
    _emit(target, _pointerForProgress(target, _pageSize), notify: false);
    _setPhase(PageCurlPhase.idle);
    widget.onSettled?.call(target == 1.0);
  }

  @override
  void jumpTo(double value) {
    _motionController.stop();
    final target = value.clamp(0.0, 1.0).toDouble();
    _motionController.value = target;
    _setPhase(PageCurlPhase.idle);
    _emit(target, _pointerForProgress(target, _pageSize));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return const SizedBox.shrink();
        }
        final size = constraints.biggest;
        if (size != _pageSize) {
          _pageSize = size;
          if (_phase != PageCurlPhase.dragging) {
            // Laid out at a new size between frames, so the pointer that was
            // derived from the old one no longer means anything. Written
            // straight into the notifier: a rebuild from inside a build is an
            // error, and there is nothing here that needs one.
            _frame.value = _CurlFrame(
              progress,
              _pointerForProgress(progress, size),
            );
          }
        }

        Widget transition;
        if (widget.reduceMotion) {
          transition = _paint(
            _PageCrossFadePainter(
              frame: _frame,
              frontImage: widget.frontImage,
              backImage: widget.backImage,
            ),
          );
        } else if (widget.effect == PageCurlEffect.fold) {
          transition = _buildFold();
        } else {
          transition = _buildCurl();
        }

        // STEP C EXTENSION POINT: add paper grain or a settle-only visual
        // wrapper here through PageCurl.decorator. Step C is intentionally not
        // implemented in this widget.
        final decorated = widget.decorator?.call(
              context,
              transition,
              progress,
              _phase,
            ) ??
            transition;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: widget.interactive ? _onDragStart : null,
          onHorizontalDragUpdate: widget.interactive ? _onDragUpdate : null,
          onHorizontalDragEnd: widget.interactive ? _onDragEnd : null,
          onHorizontalDragCancel: widget.interactive ? _onDragCancel : null,
          child: IgnorePointer(child: decorated),
        );
      },
    );
  }

  /// Every frame of every effect goes through here.
  ///
  /// The boundary is not decoration. Without it the layer the shader draws into
  /// is shared with whatever is around it, and a repaint of the turn drags its
  /// neighbours through the raster thread with it.
  Widget _paint(CustomPainter painter) {
    return RepaintBoundary(
      child: CustomPaint(
        // Never worth a raster cache: the picture is different every frame by
        // definition, so offering it for caching only costs the attempt.
        isComplex: false,
        willChange: true,
        painter: painter,
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildCurl() {
    return FutureBuilder<ui.FragmentProgram>(
      future: _program ??= PageCurl._loadProgram(),
      builder: (context, snapshot) {
        final program = snapshot.data;
        if (program == null || snapshot.hasError) {
          return _buildFold();
        }
        _shader ??= program.fragmentShader();

        return _paint(
          _PageCurlPainter(
            frame: _frame,
            shader: _shader!,
            frontImage: widget.frontImage,
            backImage: widget.backImage,
            direction: _direction,
            radius: widget.radius,
            shadow: widget.shadow,
          ),
        );
      },
    );
  }

  Widget _buildFold() {
    return _paint(
      _PageFoldPainter(
        frame: _frame,
        frontImage: widget.frontImage,
        backImage: widget.backImage,
        direction: _direction,
      ),
    );
  }
}

class _PageCurlPainter extends CustomPainter {
  _PageCurlPainter({
    required this.frame,
    required this.shader,
    required this.frontImage,
    required this.backImage,
    required this.direction,
    required this.radius,
    required this.shadow,
  }) : super(repaint: frame);

  final ValueListenable<_CurlFrame> frame;
  final ui.FragmentShader shader;
  final ui.Image frontImage;
  final ui.Image backImage;
  final double direction;
  final double radius;
  final double shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final current = frame.value;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, current.progress)
      ..setFloat(3, current.pointer.dx)
      ..setFloat(4, current.pointer.dy)
      ..setFloat(5, direction)
      ..setFloat(6, radius)
      ..setFloat(7, shadow)
      ..setImageSampler(0, frontImage)
      ..setImageSampler(1, backImage);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _PageCurlPainter oldDelegate) {
    // The frame itself drives repaints through `repaint`. This only has to
    // catch the things a rebuild can change.
    return !identical(frame, oldDelegate.frame) ||
        !identical(shader, oldDelegate.shader) ||
        !identical(frontImage, oldDelegate.frontImage) ||
        !identical(backImage, oldDelegate.backImage) ||
        direction != oldDelegate.direction ||
        radius != oldDelegate.radius ||
        shadow != oldDelegate.shadow;
  }
}

/// The reduced-motion transition: no fold, no curl, the pointer alone.
class _PageCrossFadePainter extends CustomPainter {
  _PageCrossFadePainter({
    required this.frame,
    required this.frontImage,
    required this.backImage,
  }) : super(repaint: frame);

  final ValueListenable<_CurlFrame> frame;
  final ui.Image frontImage;
  final ui.Image backImage;

  Rect _sourceRect(ui.Image image) => Rect.fromLTWH(
        0.0,
        0.0,
        image.width.toDouble(),
        image.height.toDouble(),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final progress = frame.value.progress;
    final destination = Offset.zero & size;
    // Bilinear, not bicubic. The captures are taken at the device pixel ratio
    // and drawn back at exactly one to one, so there is nothing for a cubic
    // filter to reconstruct: it costs raster time and returns a softer picture.
    final paint = Paint()..filterQuality = FilterQuality.low;
    canvas.drawImageRect(backImage, _sourceRect(backImage), destination, paint);
    final fading = (1.0 - progress).clamp(0.0, 1.0);
    if (fading <= 0.0) {
      return;
    }
    canvas.drawImageRect(
      frontImage,
      _sourceRect(frontImage),
      destination,
      paint..color = Colors.white.withValues(alpha: fading),
    );
  }

  @override
  bool shouldRepaint(covariant _PageCrossFadePainter oldDelegate) {
    return !identical(frame, oldDelegate.frame) ||
        !identical(frontImage, oldDelegate.frontImage) ||
        !identical(backImage, oldDelegate.backImage);
  }
}

class _PageFoldPainter extends CustomPainter {
  _PageFoldPainter({
    required this.frame,
    required this.frontImage,
    required this.backImage,
    required this.direction,
  }) : super(repaint: frame);

  final ValueListenable<_CurlFrame> frame;
  final ui.Image frontImage;
  final ui.Image backImage;
  final double direction;

  Rect _sourceRect(ui.Image image) {
    return Rect.fromLTWH(
      0.0,
      0.0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final progress = frame.value.progress;
    final turnFromLeft = direction > 0.0;
    final showBackFace = progress > 0.5;
    final foldProgress = (progress * 1.7).clamp(0.0, 1.0).toDouble();
    final stationaryOpacity = (1.0 - Curves.easeIn.transform(foldProgress))
        .clamp(0.0, 1.0)
        .toDouble();
    final width = size.width;
    final height = size.height;
    final halfWidth = width * 0.5;
    final pageRect = Offset.zero & size;
    final imagePaint = Paint()..filterQuality = FilterQuality.low;

    canvas.drawImageRect(
      backImage,
      _sourceRect(backImage),
      pageRect,
      imagePaint,
    );

    final frontHalfWidth = frontImage.width * 0.5;
    final stationarySource = turnFromLeft
        ? Rect.fromLTWH(
            frontHalfWidth,
            0.0,
            frontHalfWidth,
            frontImage.height.toDouble(),
          )
        : Rect.fromLTWH(
            0.0,
            0.0,
            frontHalfWidth,
            frontImage.height.toDouble(),
          );
    final stationaryDestination = turnFromLeft
        ? Rect.fromLTWH(halfWidth, 0.0, halfWidth, height)
        : Rect.fromLTWH(0.0, 0.0, halfWidth, height);
    canvas.drawImageRect(
      frontImage,
      stationarySource,
      stationaryDestination,
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Colors.white.withValues(alpha: stationaryOpacity),
    );

    final projectedWidth = halfWidth * math.cos(math.pi * progress).abs();
    final turningDestination = turnFromLeft
        ? (showBackFace
            ? Rect.fromLTWH(halfWidth, 0.0, projectedWidth, height)
            : Rect.fromLTWH(
                halfWidth - projectedWidth,
                0.0,
                projectedWidth,
                height,
              ))
        : (showBackFace
            ? Rect.fromLTWH(
                halfWidth - projectedWidth,
                0.0,
                projectedWidth,
                height,
              )
            : Rect.fromLTWH(halfWidth, 0.0, projectedWidth, height));

    final turningImage = showBackFace ? backImage : frontImage;
    final turningHalfWidth = turningImage.width * 0.5;
    final turningSource = showBackFace
        ? (turnFromLeft
            ? Rect.fromLTWH(
                turningHalfWidth,
                0.0,
                turningHalfWidth,
                turningImage.height.toDouble(),
              )
            : Rect.fromLTWH(
                0.0,
                0.0,
                turningHalfWidth,
                turningImage.height.toDouble(),
              ))
        : (turnFromLeft
            ? Rect.fromLTWH(
                0.0,
                0.0,
                turningHalfWidth,
                turningImage.height.toDouble(),
              )
            : Rect.fromLTWH(
                turningHalfWidth,
                0.0,
                turningHalfWidth,
                turningImage.height.toDouble(),
              ));

    if (projectedWidth > 0.0) {
      canvas.drawImageRect(
        turningImage,
        turningSource,
        turningDestination,
        imagePaint,
      );
      canvas.drawRect(
        turningDestination,
        Paint()
          ..color = Colors.black.withValues(
            alpha: 0.14 * math.sin(math.pi * progress).abs(),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PageFoldPainter oldDelegate) {
    return !identical(frame, oldDelegate.frame) ||
        !identical(frontImage, oldDelegate.frontImage) ||
        !identical(backImage, oldDelegate.backImage) ||
        direction != oldDelegate.direction;
  }
}

/// A convenience wrapper that snapshots two live widgets once per page turn.
///
/// Each child remains at full layout width in its own [RepaintBoundary]. At
/// the start of a drag or timed turn, both boundaries are captured at the
/// device pixel ratio and passed to [PageCurl] as independent images.
class WidgetPageCurl extends StatefulWidget {
  const WidgetPageCurl({
    super.key,
    required this.front,
    required this.back,
    required this.textDirection,
    this.controller,
    this.interactive = true,
    this.reduceMotion = false,
    this.effect = PageCurlEffect.curl,
    this.initialProgress = 0.0,
    this.radius = 72.0,
    this.shadow = 0.78,
    this.settleThreshold = 0.5,
    this.onProgressChanged,
    this.onSettled,
    this.decorator,
  })  : assert(initialProgress >= 0.0 && initialProgress <= 1.0),
        assert(radius > 0.0),
        assert(shadow >= 0.0 && shadow <= 1.0),
        assert(settleThreshold >= 0.0 && settleThreshold <= 1.0);

  final Widget front;
  final Widget back;
  final TextDirection textDirection;
  final PageCurlController? controller;
  final bool interactive;
  final bool reduceMotion;
  final PageCurlEffect effect;
  final double initialProgress;
  final double radius;
  final double shadow;
  final double settleThreshold;
  final ValueChanged<double>? onProgressChanged;
  final ValueChanged<bool>? onSettled;
  final PageCurlDecorator? decorator;

  @override
  State<WidgetPageCurl> createState() => _WidgetPageCurlState();
}

class _WidgetPageCurlState extends State<WidgetPageCurl>
    implements _PageCurlHandle {
  final GlobalKey _frontBoundaryKey = GlobalKey();
  final GlobalKey _backBoundaryKey = GlobalKey();
  final GlobalKey<_PageCurlState> _curlKey = GlobalKey<_PageCurlState>();
  final PageCurlController _imageController = PageCurlController();

  ui.Image? _frontImage;
  ui.Image? _backImage;
  Future<void>? _captureInFlight;
  late double _progress;

  /// Which of the two pages a screen reader is being offered.
  ///
  /// This is the only thing in this widget that the progress of a turn changes,
  /// and it changes once, at the half way point. It used to be read off a field
  /// that `setState` rewrote on every frame, so a turn rebuilt both live pages
  /// 120 times a second to move a boolean that flipped once.
  bool _backIsForeground = false;

  int _gestureId = 0;
  bool _gestureActive = false;
  bool _gestureReady = false;
  bool _gestureCancelled = false;
  Offset _latestPointer = Offset.zero;
  double? _pendingEndVelocity;

  @override
  double get progress => _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
    _backIsForeground = _progress >= 0.5;
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant WidgetPageCurl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _frontImage?.dispose();
    _backImage?.dispose();
    super.dispose();
  }

  RenderRepaintBoundary _boundaryFor(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary || renderObject.size.isEmpty) {
      throw StateError('PageCurl source widgets are not ready to capture.');
    }
    return renderObject;
  }

  Future<void> _capturePages() {
    final inFlight = _captureInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final capture = _capturePagesNow();
    _captureInFlight = capture;
    return capture.whenComplete(() {
      if (identical(_captureInFlight, capture)) {
        _captureInFlight = null;
      }
    });
  }

  Future<void> _capturePagesNow() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final frontBoundary = _boundaryFor(_frontBoundaryKey);
    final backBoundary = _boundaryFor(_backBoundaryKey);
    final frontFuture = frontBoundary.toImage(pixelRatio: pixelRatio);
    final backFuture = backBoundary.toImage(pixelRatio: pixelRatio);

    ui.Image? nextFront;
    ui.Image? nextBack;
    try {
      nextFront = await frontFuture;
      nextBack = await backFuture;
    } catch (_) {
      nextFront?.dispose();
      nextBack?.dispose();
      rethrow;
    }

    if (!mounted) {
      nextFront.dispose();
      nextBack.dispose();
      return;
    }

    final previousFront = _frontImage;
    final previousBack = _backImage;
    setState(() {
      _frontImage = nextFront;
      _backImage = nextBack;
    });

    await WidgetsBinding.instance.endOfFrame;
    previousFront?.dispose();
    previousBack?.dispose();
  }

  void _reportGestureCaptureError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'page curl',
        context: ErrorDescription('while capturing page widgets'),
      ),
    );
  }

  Future<void> _prepareGesture(int gestureId) async {
    try {
      await _capturePages();
    } catch (error, stackTrace) {
      _reportGestureCaptureError(error, stackTrace);
      return;
    }
    if (!mounted || gestureId != _gestureId) {
      return;
    }

    final curlState = _curlKey.currentState;
    if (curlState == null) {
      return;
    }
    curlState._beginDragAt(_latestPointer);
    _gestureReady = true;

    if (_gestureActive) {
      return;
    }
    if (_gestureCancelled) {
      curlState._cancelDrag();
    } else {
      curlState._endDragWithVelocity(_pendingEndVelocity ?? 0.0);
    }
    _gestureReady = false;
  }

  @override
  void dragBegin(Offset localPosition) {
    _curlKey.currentState?._motionController.stop();
    _gestureId += 1;
    _gestureActive = true;
    _gestureReady = false;
    _gestureCancelled = false;
    _latestPointer = localPosition;
    _pendingEndVelocity = null;
    unawaited(_prepareGesture(_gestureId));
  }

  @override
  void dragUpdate(Offset localPosition) {
    _latestPointer = localPosition;
    if (_gestureReady) {
      _curlKey.currentState?._updateDragAt(_latestPointer);
    }
  }

  @override
  void dragEnd(double velocityX) {
    _gestureActive = false;
    _pendingEndVelocity = velocityX;
    if (_gestureReady) {
      _curlKey.currentState?._endDragWithVelocity(velocityX);
      _gestureReady = false;
    }
  }

  @override
  void dragCancel() {
    _gestureActive = false;
    _gestureCancelled = true;
    if (_gestureReady) {
      _curlKey.currentState?._cancelDrag();
      _gestureReady = false;
    }
  }

  void _onDragStart(DragStartDetails details) =>
      dragBegin(details.localPosition);

  void _onDragUpdate(DragUpdateDetails details) =>
      dragUpdate(details.localPosition);

  void _onDragEnd(DragEndDetails details) =>
      dragEnd(details.velocity.pixelsPerSecond.dx);

  void _onDragCancel() => dragCancel();

  void _handleProgress(double value) {
    _progress = value;
    final backIsForeground = value >= 0.5;
    if (backIsForeground != _backIsForeground && mounted) {
      setState(() => _backIsForeground = backIsForeground);
    }
    widget.onProgressChanged?.call(value);
  }

  @override
  Future<void> animate({
    required double to,
    required Duration duration,
    required Curve curve,
  }) async {
    await _capturePages();
    if (!mounted || !_imageController.isAttached) {
      return;
    }
    await _imageController.animate(to: to, duration: duration, curve: curve);
  }

  @override
  void jumpTo(double value) {
    final target = value.clamp(0.0, 1.0).toDouble();
    if (_imageController.isAttached) {
      _imageController.jumpTo(target);
      return;
    }
    _handleProgress(target);
  }

  @override
  Widget build(BuildContext context) {
    final frontImage = _frontImage;
    final backImage = _backImage;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: widget.interactive ? _onDragStart : null,
      onHorizontalDragUpdate: widget.interactive ? _onDragUpdate : null,
      onHorizontalDragEnd: widget.interactive ? _onDragEnd : null,
      onHorizontalDragCancel: widget.interactive ? _onDragCancel : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: _backBoundaryKey,
            child: ExcludeSemantics(
              excluding: !_backIsForeground,
              child: widget.back,
            ),
          ),
          RepaintBoundary(
            key: _frontBoundaryKey,
            child: ExcludeSemantics(
              excluding: _backIsForeground,
              child: widget.front,
            ),
          ),
          if (frontImage != null && backImage != null)
            PageCurl(
              key: _curlKey,
              frontImage: frontImage,
              backImage: backImage,
              textDirection: widget.textDirection,
              controller: _imageController,
              interactive: false,
              reduceMotion: widget.reduceMotion,
              effect: widget.effect,
              initialProgress: _progress,
              radius: widget.radius,
              shadow: widget.shadow,
              settleThreshold: widget.settleThreshold,
              onProgressChanged: _handleProgress,
              onSettled: widget.onSettled,
              decorator: widget.decorator,
            ),
        ],
      ),
    );
  }
}
