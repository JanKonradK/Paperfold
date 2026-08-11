import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

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
    Duration duration = const Duration(milliseconds: 900),
    Curve curve = Curves.easeOutCubic,
  }) {
    final handle = _handle;
    if (handle == null) {
      throw StateError('PageCurlController is not attached to a page curl.');
    }
    return handle.animate(to: to, duration: duration, curve: curve);
  }

  /// Sets the curl position immediately without animation.
  void jumpTo(double progress) {
    final handle = _handle;
    if (handle == null) {
      throw StateError('PageCurlController is not attached to a page curl.');
    }
    handle.jumpTo(progress);
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
  Future<ui.FragmentProgram>? _program;
  ui.FragmentShader? _shader;

  late double _progress;
  Offset _pointer = Offset.zero;
  Size _pageSize = Size.zero;
  PageCurlPhase _phase = PageCurlPhase.idle;

  double get _direction =>
      widget.textDirection == TextDirection.rtl ? 1.0 : -1.0;

  @override
  double get progress => _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
    _motionController = AnimationController.unbounded(
      value: _progress,
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
      _pointer = _pointerForProgress(_progress, _pageSize);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _motionController.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _handleMotionTick() {
    final value = _motionController.value.clamp(0.0, 1.0).toDouble();
    if (!mounted) {
      return;
    }
    setState(() {
      _progress = value;
      if (!_pageSize.isEmpty) {
        _pointer = _pointerForProgress(value, _pageSize);
      }
    });
    widget.onProgressChanged?.call(value);
  }

  Offset _pointerForProgress(double value, Size size) {
    final x =
        _direction > 0.0 ? size.width * value : size.width * (1.0 - value);
    return Offset(x, size.height * 0.5);
  }

  double _progressForPointer(Offset pointer, Size size) {
    if (size.width <= 0.0) {
      return _progress;
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

  void _beginDragAt(Offset localPosition) {
    _motionController.stop();
    final pointer = _clampPointer(localPosition, _pageSize);
    final value = _progressForPointer(pointer, _pageSize);
    setState(() {
      _phase = PageCurlPhase.dragging;
      _pointer = pointer;
      _progress = value;
    });
    widget.onProgressChanged?.call(value);
  }

  void _updateDragAt(Offset localPosition) {
    final pointer = _clampPointer(localPosition, _pageSize);
    final value = _progressForPointer(pointer, _pageSize);
    setState(() {
      _pointer = pointer;
      _progress = value;
    });
    widget.onProgressChanged?.call(value);
  }

  void _endDragWithVelocity(double velocityX) {
    final target = _progress >= widget.settleThreshold ? 1.0 : 0.0;
    final velocity =
        _pageSize.width <= 0.0 ? 0.0 : velocityX * _direction / _pageSize.width;
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
    setState(() {
      _phase = PageCurlPhase.settling;
    });
    _motionController.value = _progress;
    final simulation = SpringSimulation(
      const SpringDescription(
        mass: 1.0,
        stiffness: 420.0,
        damping: 34.0,
      ),
      _progress,
      target,
      velocity,
    );
    _motionController.animateWith(simulation).whenCompleteOrCancel(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _progress = target;
        _pointer = _pointerForProgress(target, _pageSize);
        _phase = PageCurlPhase.idle;
      });
      widget.onProgressChanged?.call(target);
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
    _motionController.value = _progress;
    setState(() {
      _phase = PageCurlPhase.timed;
    });
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
    setState(() {
      _progress = target;
      _pointer = _pointerForProgress(target, _pageSize);
      _phase = PageCurlPhase.idle;
    });
    widget.onSettled?.call(target == 1.0);
  }

  @override
  void jumpTo(double value) {
    _motionController.stop();
    final target = value.clamp(0.0, 1.0).toDouble();
    setState(() {
      _phase = PageCurlPhase.idle;
    });
    _motionController.value = target;
    setState(() {
      _progress = target;
      _pointer = _pointerForProgress(target, _pageSize);
    });
    widget.onProgressChanged?.call(target);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return const SizedBox.shrink();
        }
        final size = constraints.biggest;
        _pageSize = size;
        if (_phase != PageCurlPhase.dragging) {
          _pointer = _pointerForProgress(_progress, size);
        }

        Widget transition;
        if (widget.reduceMotion) {
          transition = _buildCrossFade();
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
              _progress,
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

  Widget _buildCrossFade() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: _progress,
          child: RawImage(
            image: widget.backImage,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
        ),
        Opacity(
          opacity: 1.0 - _progress,
          child: RawImage(
            image: widget.frontImage,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
        ),
      ],
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

        return CustomPaint(
          isComplex: true,
          willChange: _phase != PageCurlPhase.idle,
          painter: _PageCurlPainter(
            shader: _shader!,
            frontImage: widget.frontImage,
            backImage: widget.backImage,
            progress: _progress,
            pointer: _pointer,
            direction: _direction,
            radius: widget.radius,
            shadow: widget.shadow,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Widget _buildFold() {
    return CustomPaint(
      isComplex: true,
      willChange: _phase != PageCurlPhase.idle,
      painter: _PageFoldPainter(
        frontImage: widget.frontImage,
        backImage: widget.backImage,
        progress: _progress,
        direction: _direction,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _PageCurlPainter extends CustomPainter {
  const _PageCurlPainter({
    required this.shader,
    required this.frontImage,
    required this.backImage,
    required this.progress,
    required this.pointer,
    required this.direction,
    required this.radius,
    required this.shadow,
  });

  final ui.FragmentShader shader;
  final ui.Image frontImage;
  final ui.Image backImage;
  final double progress;
  final Offset pointer;
  final double direction;
  final double radius;
  final double shadow;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, progress)
      ..setFloat(3, pointer.dx)
      ..setFloat(4, pointer.dy)
      ..setFloat(5, direction)
      ..setFloat(6, radius)
      ..setFloat(7, shadow)
      ..setImageSampler(0, frontImage)
      ..setImageSampler(1, backImage);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _PageCurlPainter oldDelegate) {
    return !identical(shader, oldDelegate.shader) ||
        !identical(frontImage, oldDelegate.frontImage) ||
        !identical(backImage, oldDelegate.backImage) ||
        progress != oldDelegate.progress ||
        pointer != oldDelegate.pointer ||
        direction != oldDelegate.direction ||
        radius != oldDelegate.radius ||
        shadow != oldDelegate.shadow;
  }
}

class _PageFoldPainter extends CustomPainter {
  const _PageFoldPainter({
    required this.frontImage,
    required this.backImage,
    required this.progress,
    required this.direction,
  });

  final ui.Image frontImage;
  final ui.Image backImage;
  final double progress;
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
    final imagePaint = Paint()..filterQuality = FilterQuality.high;

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
        ..filterQuality = FilterQuality.high
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
    return !identical(frontImage, oldDelegate.frontImage) ||
        !identical(backImage, oldDelegate.backImage) ||
        progress != oldDelegate.progress ||
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

  void _onDragStart(DragStartDetails details) {
    _curlKey.currentState?._motionController.stop();
    _gestureId += 1;
    _gestureActive = true;
    _gestureReady = false;
    _gestureCancelled = false;
    _latestPointer = details.localPosition;
    _pendingEndVelocity = null;
    unawaited(_prepareGesture(_gestureId));
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _latestPointer = details.localPosition;
    if (_gestureReady) {
      _curlKey.currentState?._updateDragAt(_latestPointer);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    _gestureActive = false;
    _pendingEndVelocity = details.velocity.pixelsPerSecond.dx;
    if (_gestureReady) {
      _curlKey.currentState?._endDragWithVelocity(_pendingEndVelocity!);
      _gestureReady = false;
    }
  }

  void _onDragCancel() {
    _gestureActive = false;
    _gestureCancelled = true;
    if (_gestureReady) {
      _curlKey.currentState?._cancelDrag();
      _gestureReady = false;
    }
  }

  void _handleProgress(double value) {
    if (mounted) {
      setState(() {
        _progress = value;
      });
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
    setState(() {
      _progress = target;
    });
    widget.onProgressChanged?.call(target);
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
              excluding: _progress < 0.5,
              child: widget.back,
            ),
          ),
          RepaintBoundary(
            key: _frontBoundaryKey,
            child: ExcludeSemantics(
              excluding: _progress >= 0.5,
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
