import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/shared_preference_provider.dart';

/// Spatial transitions dissolve for reduced motion and stop entirely on eInk.
Duration paperfoldTransitionDuration(BuildContext context, Duration duration) {
  if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
  try {
    if (Prefs().eInkMode) return Duration.zero;
  } catch (_) {}
  return MediaQuery.accessibleNavigationOf(context)
      ? PaperfoldMotion.tick
      : duration;
}
