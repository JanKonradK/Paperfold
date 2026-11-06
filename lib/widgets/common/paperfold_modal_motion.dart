import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';

/// The native modal route keeps focus, Back, and barrier semantics.
AnimationStyle paperfoldModalMotion(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  final duration = !PaperfoldVisualPolicy.glassAllowed(context)
      ? Duration.zero
      : (media?.accessibleNavigation ?? false)
      ? PaperfoldMotion.tick
      : PaperfoldMotion.move;
  return AnimationStyle(
    duration: duration,
    reverseDuration: duration,
    curve: PaperfoldMotion.settle,
    reverseCurve: PaperfoldMotion.depart,
  );
}
