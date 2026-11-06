import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';

/// One clock on first mount; parent updates do not restart the chart.
class ChartEntrance extends StatelessWidget {
  const ChartEntrance({super.key, required this.builder});
  final Widget Function(double value) builder;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dissolve = media.accessibleNavigation && !media.disableAnimations;
    final duration = !PaperfoldVisualPolicy.glassAllowed(context)
        ? Duration.zero
        : dissolve
        ? PaperfoldMotion.tick
        : PaperfoldMotion.move;
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: PaperfoldMotion.settle,
        builder: (_, value, _) => dissolve
            ? Opacity(opacity: value, child: builder(1))
            : builder(value),
      ),
    );
  }
}
