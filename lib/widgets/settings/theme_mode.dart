import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/utils/theme_mode_to_string.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/widgets/common/anx_segmented_button.dart';
import 'package:flutter/material.dart';

/// The light / dark / system control.
///
/// It reads the preference on every build and rebuilds when the preference
/// changes. The mode it used to cache in `initState` went stale the moment
/// anything else wrote it — E-ink mode, the onboarding screen, or a restored
/// backup — and the control then showed a mode the application was not in.
class ChangeThemeMode extends StatelessWidget {
  const ChangeThemeMode({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Prefs(),
      builder: (BuildContext context, _) {
        // E-ink mode pins the application to light. The control says so
        // instead of offering a choice that has no effect.
        final bool eInk = Prefs().eInkMode;
        return AnxSegmentedButton<String>(
          segments: <SegmentButtonItem<String>>[
            SegmentButtonItem(
              value: 'auto',
              label: L10n.of(context).settingsSystemMode,
              icon: const Icon(Icons.brightness_auto),
            ),
            SegmentButtonItem(
              value: 'dark',
              label: L10n.of(context).settingsDarkMode,
              icon: const Icon(Icons.brightness_2),
            ),
            SegmentButtonItem(
              value: 'light',
              label: L10n.of(context).settingsLightMode,
              icon: const Icon(Icons.brightness_5),
            ),
          ],
          selected: {eInk ? 'light' : themeModeToString(Prefs().themeMode)},
          onSelectionChanged: eInk
              ? null
              : (Set<String> newSelection) {
                  Prefs().saveThemeModeToPrefs(newSelection.first);
                },
        );
      },
    );
  }
}
