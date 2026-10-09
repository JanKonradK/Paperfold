import 'package:material_ui/material_ui.dart';

import 'paperfold_glass_surface.dart';

/// A Material slider with a glass track and a thumb that only appears while
/// the user manipulates the control.
///
/// Flutter's [Slider] remains the interactive widget. It supplies slider
/// semantics, keyboard input, RTL behavior, value announcements, and the 48 dp
/// touch target. Only its visual track and thumb are replaced.
class PaperfoldGlassSlider extends StatefulWidget {
  const PaperfoldGlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.semanticLabel,
    this.semanticFormatterCallback,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? semanticLabel;
  final SemanticFormatterCallback? semanticFormatterCallback;

  @override
  State<PaperfoldGlassSlider> createState() => _PaperfoldGlassSliderState();
}

class _PaperfoldGlassSliderState extends State<PaperfoldGlassSlider> {
  bool _dragging = false;

  void _handleChangeStart(double value) {
    if (!_dragging) {
      setState(() => _dragging = true);
    }
  }

  void _handleChangeEnd(double value) {
    if (_dragging) {
      setState(() => _dragging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = PaperfoldGlassStyle.fromScheme(scheme);
    final bubbleFill = glass.solidTint.withValues(alpha: 0.86);

    return MergeSemantics(
      child: Semantics(
        label: widget.semanticLabel,
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const PositionedDirectional(
                start: 14,
                end: 14,
                child: SizedBox(
                  height: 8,
                  child: PaperfoldGlassSurface(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    blurSigma: 8,
                    child: SizedBox.expand(),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  activeTrackColor: scheme.primary,
                  inactiveTrackColor: Colors.transparent,
                  disabledActiveTrackColor:
                      scheme.onSurface.withValues(alpha: 0.3),
                  disabledInactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.transparent,
                  overlayColor: Colors.transparent,
                  overlayShape: SliderComponentShape.noOverlay,
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                  thumbShape: _DragOnlyGlassThumbShape(
                    visible: _dragging,
                    fill: bubbleFill,
                    edge: glass.foreground.withValues(alpha: 0.42),
                  ),
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Slider(
                  value: widget.value,
                  onChanged: widget.onChanged,
                  onChangeStart:
                      widget.onChanged == null ? null : _handleChangeStart,
                  onChangeEnd:
                      widget.onChanged == null ? null : _handleChangeEnd,
                  min: widget.min,
                  max: widget.max,
                  divisions: widget.divisions,
                  semanticFormatterCallback: widget.semanticFormatterCallback,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragOnlyGlassThumbShape extends SliderComponentShape {
  const _DragOnlyGlassThumbShape({
    required this.visible,
    required this.fill,
    required this.edge,
  });

  static const double radius = 14;

  final bool visible;
  final Color fill;
  final Color edge;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(radius * 2);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    if (!visible) {
      return;
    }
    final canvas = context.canvas;
    canvas.drawCircle(center, radius, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}
