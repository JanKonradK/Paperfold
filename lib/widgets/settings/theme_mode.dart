import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/common/paperfold_pane.dart';
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

/// The same three bindings in each room: only the room changes colour.
class ThemeShelfPreview extends StatelessWidget {
  const ThemeShelfPreview({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Prefs(),
    builder: (context, _) {
      final l10n = L10n.of(context);
      final prefs = Prefs();
      final choices = [
        (
          'light',
          l10n.settingsCreamMode,
          PaperfoldTokens.colorScheme(Brightness.light),
        ),
        (
          'burgundy',
          l10n.settingsBurgundyMode,
          PaperfoldTokens.burgundyColorScheme(),
        ),
        (
          'dark',
          l10n.settingsDarkMode,
          PaperfoldTokens.colorScheme(
            Brightness.dark,
            trueBlack: prefs.trueDarkMode,
          ),
        ),
      ];
      final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flex(
            direction: largeText ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final choice in choices)
                Flexible(
                  fit: largeText ? FlexFit.loose : FlexFit.tight,
                  child: Padding(
                    padding: const EdgeInsets.all(PaperfoldSpace.xxs),
                    child: Semantics(
                      selected:
                          (prefs.eInkMode ? 'light' : prefs.appThemeMode) ==
                          choice.$1,
                      child: PaperfoldPane(
                        key: ValueKey('theme-swatch-${choice.$1}'),
                        color: choice.$3.surface,
                        borderRadius: PaperfoldShape.controlRadius,
                        padding: const EdgeInsets.all(PaperfoldSpace.sm),
                        onTap: prefs.eInkMode
                            ? null
                            : () => prefs.saveThemeModeToPrefs(choice.$1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ExcludeSemantics(
                              child: SizedBox(
                                height: 48,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (final book in [
                                      (
                                        PaperfoldTokens.surfaces.sageGreen,
                                        34.0,
                                      ),
                                      (PaperfoldTokens.darkSienna, 42.0),
                                      (
                                        PaperfoldTokens.surfaces.goldenTan,
                                        30.0,
                                      ),
                                    ])
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              end: PaperfoldSpace.xxs,
                                            ),
                                        child: Container(
                                          width: 10,
                                          height: book.$2,
                                          decoration: BoxDecoration(
                                            color: book.$1,
                                            borderRadius:
                                                PaperfoldShape.objectRadius,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: PaperfoldSpace.xs),
                            Text(
                              choice.$2,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: choice.$3.onSurface),
                            ),
                            if ((prefs.eInkMode
                                    ? 'light'
                                    : prefs.appThemeMode) ==
                                choice.$1)
                              Icon(
                                Icons.check,
                                size: PaperfoldSize.smallIcon,
                                color: choice.$3.onSurface,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilterChip(
              avatar: const Icon(
                Icons.brightness_auto_outlined,
                size: PaperfoldSize.smallIcon,
              ),
              label: Text(l10n.settingsSystemMode),
              selected: !prefs.eInkMode && prefs.appThemeMode == 'auto',
              onSelected: prefs.eInkMode
                  ? null
                  : (selected) => prefs.saveThemeModeToPrefs(
                      selected ? 'auto' : 'burgundy',
                    ),
            ),
          ),
        ],
      );
    },
  );
}
