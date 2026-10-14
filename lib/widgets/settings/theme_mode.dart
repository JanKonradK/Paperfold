import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:material_ui/material_ui.dart';

/// Three explicit surfaces, plus the device's automatic light/dark choice.
class ChangeThemeMode extends StatelessWidget {
  const ChangeThemeMode({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Prefs(),
      builder: (BuildContext context, _) {
        final bool eInk = Prefs().eInkMode;
        final mode = eInk ? 'light' : Prefs().appThemeMode;
        final l10n = L10n.of(context);
        return LayoutBuilder(
          builder: (context, constraints) {
            final vertical =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(16) > 21;
            final showIcons = vertical || constraints.maxWidth >= 420;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  direction: vertical ? Axis.vertical : Axis.horizontal,
                  emptySelectionAllowed: true,
                  segments: [
                    ButtonSegment(
                      value: 'light',
                      label: Text(
                        eInk || !Prefs().useBrandTheme
                            ? l10n.settingsLightMode
                            : l10n.settingsCreamMode,
                      ),
                      icon: showIcons
                          ? const Icon(Icons.light_mode_outlined)
                          : null,
                    ),
                    ButtonSegment(
                      value: 'burgundy',
                      label: Text(l10n.settingsBurgundyMode),
                      icon: showIcons
                          ? const Icon(Icons.auto_stories_outlined)
                          : null,
                    ),
                    ButtonSegment(
                      value: 'dark',
                      label: Text(l10n.settingsDarkMode),
                      icon: showIcons
                          ? const Icon(Icons.dark_mode_outlined)
                          : null,
                    ),
                  ],
                  selected: mode == 'auto' ? const {} : {mode},
                  onSelectionChanged: eInk
                      ? null
                      : (selection) {
                          if (selection.isNotEmpty) {
                            Prefs().saveThemeModeToPrefs(selection.first);
                          }
                        },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilterChip(
                    avatar: const Icon(
                      Icons.brightness_auto_outlined,
                      size: 18,
                    ),
                    label: Text(l10n.settingsSystemMode),
                    selected: mode == 'auto',
                    onSelected: eInk
                        ? null
                        : (selected) => Prefs().saveThemeModeToPrefs(
                            selected ? 'auto' : 'burgundy',
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
