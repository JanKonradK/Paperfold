import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';
import 'package:paperfold/config/shared_preference_provider.dart';

/// The native modal route keeps focus, Back, and barrier semantics.
AnimationStyle paperfoldModalMotion(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  final duration = Prefs().eInkMode || (media?.disableAnimations ?? false)
      ? Duration.zero
      : (media?.accessibleNavigation ?? false)
      ? PaperfoldMotion.tick
      : PaperfoldVisualPolicy.motionAllowed(context)
      ? PaperfoldMotion.move
      : Duration.zero;
  return AnimationStyle(
    duration: duration,
    reverseDuration: duration,
    curve: PaperfoldMotion.settle,
    reverseCurve: PaperfoldMotion.depart,
  );
}
