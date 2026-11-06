import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/service/book_light.dart';

/// The colour of a book's world, seen through the glass.
///
/// Draws the cover's two clamped colours on a diagonal and fades to the
/// ground over the bottom 40%, so whatever sits below starts on the room
/// colour. Before the colours are known it draws [fallback] (the binding
/// colour), and it never re-reads a cover during an animation: the cached
/// colours are used synchronously when present.
class BookLight extends StatefulWidget {
  const BookLight({
    super.key,
    required this.coverPath,
    required this.fallback,
    this.child,
    this.borderRadius,
    this.fade = true,
  });

  final String coverPath;
  final Color fallback;
  final Widget? child;
  final BorderRadius? borderRadius;

  /// False keeps the colour to the bottom edge (for a short pane).
  final bool fade;

  @override
  State<BookLight> createState() => _BookLightState();
}

class _BookLightState extends State<BookLight> {
  BookLightSource? _source;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(BookLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverPath != widget.coverPath) _read();
  }

  void _read() {
    final path = widget.coverPath;
    _source = path.isEmpty ? null : BookLightService.instance.peek(path);
    if (_source != null || path.isEmpty) return;
    BookLightService.instance.sourceFor(path).then((source) {
      if (!mounted || widget.coverPath != path || source == null) return;
      setState(() => _source = source);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final band = PaperfoldBrand.band(scheme);
    final source = _source ?? BookLightSource.solid(widget.fallback);
    final (first, second) = source.resolve(band);
    final ground = scheme.surface;

    return TweenAnimationBuilder<double>(
      // The colours cross-fade in when they arrive; nothing moves afterwards.
      key: ValueKey(_source == null),
      tween: Tween(begin: _source == null ? 1 : 0, end: 1),
      duration: PaperfoldMotion.of(context, PaperfoldMotion.move),
      curve: PaperfoldMotion.settle,
      builder: (context, t, child) {
        final a = Color.lerp(ground, first, t)!;
        final b = Color.lerp(ground, second, t)!;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [a, b],
            ),
          ),
          position: DecorationPosition.background,
          child: widget.fade
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.6, 1.0],
                      colors: [ground.withValues(alpha: 0), ground],
                    ),
                  ),
                  child: child,
                )
              : child,
        );
      },
      child: widget.child,
    );
  }
}
