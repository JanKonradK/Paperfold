import 'package:battery_plus/battery_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/shared_preference_provider.dart';

/// When Paperfold may spend GPU and battery on looks.
///
/// Glass blur and decorative motion stop in eInk mode, under the system
/// Remove animations setting, with high contrast on, and in battery saver.
/// Every glass layer then becomes opaque and keeps the same colours.
abstract final class PaperfoldVisualPolicy {
  /// True while the device is in battery saver. Refreshed at start and on
  /// every resume; nothing polls it.
  static final ValueNotifier<bool> batterySaver = ValueNotifier<bool>(false);

  static AppLifecycleListener? _lifecycle;

  /// Starts watching battery saver. Safe to call more than once.
  static void init() {
    _lifecycle ??= AppLifecycleListener(onResume: refresh);
    refresh();
  }

  static Future<void> refresh() async {
    try {
      batterySaver.value = await Battery().isInBatterySaveMode;
    } catch (_) {
      // Desktop and tests have no battery plugin; keep the last answer.
    }
  }

  static bool _eInk() {
    try {
      return Prefs().eInkMode;
    } catch (_) {
      return false;
    }
  }

  /// True when live blur is allowed under [context].
  static bool glassAllowed(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media != null && (media.disableAnimations || media.highContrast)) {
      return false;
    }
    return !_eInk() && !batterySaver.value;
  }

  /// True when decorative motion (not state changes) may run.
  static bool motionAllowed(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media != null &&
        (media.disableAnimations || media.accessibleNavigation)) {
      return false;
    }
    return !_eInk();
  }
}
