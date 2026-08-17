import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/common/anx_segmented_button.dart';
import 'package:paperfold/widgets/settings/settings_title.dart';
import 'package:paperfold/widgets/settings/theme_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:paperfold/widgets/settings/settings_section.dart';
import 'package:paperfold/widgets/settings/settings_tile.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/enums/bookshelf_folder_style.dart';
import 'package:paperfold/widgets/paperfold_glass_slider.dart';

/// Display name to stored code. The first entry follows the system.
///
/// Its name was lowercase `system`, so the language row and the language
/// dialog both printed it in lowercase beside English, Deutsch and Français.
const List<Map<String, String>> languageOptions = [
  {'System': 'System'},
  {'English': 'en'},
  {'简体中文': 'zh-CN'},
  {'繁體中文': 'zh-TW'},
  {'文言文': 'zh-LZH'},
  {'Türkçe': 'tr'},
  {'Deutsch': 'de'},
  {'العربية': 'ar'},
  {'Русский': 'ru'},
  {'Français': 'fr'},
  {'Español': 'es'},
  {'Italiano': 'it'},
  {'Português': 'pt'},
  {'日本語': 'ja'},
  {'한국어': 'ko'},
  {'Română': 'ro'},
];

class AppearanceSetting extends StatefulWidget {
  const AppearanceSetting({super.key});

  @override
  State<AppearanceSetting> createState() => _AppearanceSettingState();
}

class _AppearanceSettingState extends State<AppearanceSetting> {
  @override
  Widget build(BuildContext context) {
    final String currentLanguageCode = currentLanguageOptionCode();
    final languageSubtitle = languageOptions
        .firstWhere(
          (element) => element.values.first == currentLanguageCode,
          orElse: () => languageOptions[0],
        )
        .keys
        .first;

    return settingsSections(
      sections: [
        SettingsSection(
          title: Text(L10n.of(context).settingsAppearanceTheme),
          tiles: [
            const CustomSettingsTile(
                child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: ChangeThemeMode(),
            )),
            SettingsTile.navigation(
                title: Text(L10n.of(context).settingsAppearanceThemeColor),
                leading: const Icon(Icons.color_lens),
                // Which scheme is running is the one thing this row could not
                // say. A reader who had picked a seed colour saw the same row
                // as a reader on the Paperfold scheme.
                value: Text(
                  Prefs().useBrandTheme
                      ? L10n.of(context).settingsAppearanceThemeColorBrand
                      : L10n.of(context).settingsAppearanceThemeColorCustom,
                ),
                trailing: _ThemeColourSwatch(
                  color: Prefs().useBrandTheme
                      ? Theme.of(context).colorScheme.primary
                      : Prefs().themeColor,
                ),
                onPressed: (context) async {
                  await showColorPickerDialog(context);
                  if (mounted) setState(() {});
                }),
            SettingsTile.switchTile(
              title: Text(L10n.of(context).settingsAppearanceTrueBlack),
              description: Text(
                  L10n.of(context).settingsAppearanceTrueBlackDescription),
              leading: const Icon(Icons.brightness_2),
              // Dark grounds only. In light mode the switch changes nothing,
              // so it says so rather than pretending to work.
              enabled: !Prefs().eInkMode,
              initialValue: Prefs().trueDarkMode,
              onToggle: (bool value) {
                setState(() {
                  Prefs().trueDarkMode = value;
                });
              },
            ),
            SettingsTile.switchTile(
              title: Text(L10n.of(context).eInkMode),
              description:
                  Text(L10n.of(context).settingsAppearanceEInkDescription),
              leading: const Icon(Icons.contrast),
              initialValue: Prefs().eInkMode,
              onToggle: (bool value) {
                setState(() {
                  // E-ink already forces a light brightness in the theme
                  // itself. Writing 'light' here as well overwrote the
                  // reader's own Dark or System choice, and it did it on the
                  // way out as well as on the way in, so turning E-ink off
                  // never gave the choice back.
                  Prefs().eInkMode = value;
                });
              },
            ),
          ],
        ),
        SettingsSection(
            title: Text(L10n.of(context).settingsAppearanceDisplay),
            tiles: [
              SettingsTile.navigation(
                  title: Text(L10n.of(context).settingsAppearanceLanguage),
                  value: Text(languageSubtitle),
                  leading: const Icon(Icons.language),
                  onPressed: (context) async {
                    await showLanguagePickerDialog(context);
                    if (mounted) setState(() {});
                  }),
              SettingsTile.switchTile(
                title:
                    Text(L10n.of(context).settingsAppearanceOpenBookAnimation),
                leading: const Icon(Icons.animation),
                initialValue: Prefs().openBookAnimation,
                onToggle: (bool value) {
                  setState(() {
                    Prefs().openBookAnimation = value;
                  });
                },
              ),
              SettingsTile.switchTile(
                title: Text(L10n.of(context).settingsAdvancedAutoHideBottomBar),
                leading: const Icon(Icons.vertical_align_bottom),
                initialValue: Prefs().autoHideBottomBar,
                onToggle: (value) {
                  Prefs().autoHideBottomBar = value;
                  setState(() {});
                },
              ),
              SettingsTile.switchTile(
                title: Text(L10n.of(context).reduceVibrationFeedback),
                leading: const Icon(Icons.vibration),
                initialValue: Prefs().reduceVibrationFeedback,
                onToggle: (bool value) {
                  setState(() {
                    Prefs().reduceVibrationFeedback = value;
                  });
                },
              ),
              SettingsTile.switchTile(
                title: Text(L10n.of(context).readingPageShowActionLabels),
                leading: const Icon(Icons.subtitles_outlined),
                initialValue: Prefs().showActionLabels,
                onToggle: (bool value) {
                  setState(() {
                    Prefs().showActionLabels = value;
                  });
                },
                description:
                    Text(L10n.of(context).readingPageShowActionLabelsTips),
              ),
            ]),
        SettingsSection(
            title: Text(L10n.of(context).settingsBookshelf),
            tiles: [
              CustomSettingsTile(
                child: Semantics(
                  label: L10n.of(context).settingsBookshelfUniformSpines,
                  hint: L10n.of(context)
                      .settingsBookshelfUniformSpinesDescription,
                  toggled: Prefs().shelfUniformSpines,
                  onTap: () {
                    setState(() {
                      Prefs().shelfUniformSpines = !Prefs().shelfUniformSpines;
                    });
                  },
                  child: ExcludeSemantics(
                    child: SettingsTile.switchTile(
                      title: Text(
                        L10n.of(context).settingsBookshelfUniformSpines,
                      ),
                      description: Text(
                        L10n.of(context)
                            .settingsBookshelfUniformSpinesDescription,
                      ),
                      leading: const Icon(Icons.view_column_outlined),
                      initialValue: Prefs().shelfUniformSpines,
                      onToggle: (bool value) {
                        setState(() {
                          Prefs().shelfUniformSpines = value;
                        });
                      },
                    ),
                  ),
                ),
              ),
              SettingsControlTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text(L10n.of(context).settingsDefaultBinding),
                description:
                    Text(L10n.of(context).settingsDefaultBindingDescription),
                control: AnxSegmentedButton<BookBinding>(
                  segments: [
                    SegmentButtonItem(
                      value: BookBinding.hardback,
                      label: L10n.of(context).bookBindingHardback,
                    ),
                    SegmentButtonItem(
                      value: BookBinding.softback,
                      label: L10n.of(context).bookBindingSoftback,
                    ),
                  ],
                  selected: {Prefs().defaultBookBinding},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setState(() {
                      Prefs().defaultBookBinding = selection.first;
                    });
                  },
                ),
              ),
              SettingsControlTile(
                leading: const Icon(Icons.photo_size_select_large_outlined),
                title: Text(L10n.of(context).settingsBookshelfCoverWidth),
                control: Row(
                  children: [
                    Expanded(
                      child: PaperfoldGlassSlider(
                        value: Prefs().bookCoverWidth,
                        onChanged: (value) {
                          setState(() {
                            Prefs().bookCoverWidth = value;
                          });
                        },
                        max: 260,
                        min: 80,
                        divisions: 18,
                        semanticLabel:
                            L10n.of(context).settingsBookshelfCoverWidth,
                        semanticFormatterCallback: (value) =>
                            value.toStringAsFixed(0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // The reading, after the control rather than in front of
                    // it, and wide enough that three digits do not shift the
                    // slider as the reader drags.
                    SizedBox(
                      width: 40,
                      child: Text(
                        Prefs().bookCoverWidth.toStringAsFixed(0),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
              SettingsControlTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(L10n.of(context).settingsBookshelfFolderStyle),
                control: AnxSegmentedButton<BookshelfFolderStyle>(
                  segments: [
                    SegmentButtonItem(
                      label:
                          L10n.of(context).settingsBookshelfFolderStyleOverlap,
                      value: BookshelfFolderStyle.stacked,
                      icon: const Icon(Icons.layers),
                    ),
                    SegmentButtonItem(
                      label: L10n.of(context).settingsBookshelfFolderStyleGrid,
                      value: BookshelfFolderStyle.grid2x2,
                      icon: const Icon(Icons.grid_view),
                    ),
                  ],
                  selected: {Prefs().bookshelfFolderStyle},
                  onSelectionChanged: (value) {
                    setState(() {
                      Prefs().bookshelfFolderStyle = value.first;
                    });
                  },
                ),
              ),
              SettingsTile.switchTile(
                title: Text(
                    L10n.of(context).settingsBookshelfDefaultCoverShowTitle),
                leading: const Icon(Icons.title),
                initialValue: Prefs().showBookTitleOnDefaultCover,
                onToggle: (bool value) {
                  setState(() {
                    Prefs().showBookTitleOnDefaultCover = value;
                  });
                },
              ),
              SettingsTile.switchTile(
                title: Text(
                    L10n.of(context).settingsBookshelfDefaultCoverShowAuthor),
                leading: const Icon(Icons.person),
                initialValue: Prefs().showAuthorOnDefaultCover,
                onToggle: (bool value) {
                  setState(() {
                    Prefs().showAuthorOnDefaultCover = value;
                  });
                },
              ),
            ]),
        // The "Bottom Navigator" section stood here. It offered to show or
        // hide Statistics and Notes in the navigation bar, but the bar has
        // carried a fixed Journal / Library / More set since the navigation
        // was rebuilt, and nothing read either preference. Two switches that
        // moved nothing are worse than no switches.
      ],
    );
  }
}

/// The colour the application is currently accented with.
class _ThemeColourSwatch extends StatelessWidget {
  const _ThemeColourSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        // The row still opens something, so it keeps its chevron.
        Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// The stored code for the language the reader is on, or `System`.
String currentLanguageOptionCode() {
  final locale = Prefs().locale;
  if (locale == null) return 'System';
  final country = locale.countryCode;
  return locale.languageCode + (country != null ? '-$country' : '');
}

Future<void> showLanguagePickerDialog(BuildContext context) {
  // A plain list of names stood here. It said nothing about which language
  // the application was already in, and it popped a context captured at build
  // time from the root navigator rather than the dialog's own.
  final String current = currentLanguageOptionCode();

  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return SimpleDialog(
        title: Text(L10n.of(dialogContext).settingsAppearanceLanguage),
        children: [
          for (final option in languageOptions)
            Builder(
              builder: (BuildContext itemContext) {
                final String name = option.keys.first;
                final String code = option[name]!;
                final bool selected = code == current;
                return SimpleDialogOption(
                  onPressed: () {
                    Prefs().saveLocaleToPrefs(code);
                    Navigator.of(dialogContext).pop();
                  },
                  child: Semantics(
                    selected: selected,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: selected
                              ? Icon(
                                  Icons.check,
                                  size: 20,
                                  color: Theme.of(itemContext)
                                      .colorScheme
                                      .primary,
                                )
                              : null,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              name,
                              style: selected
                                  ? TextStyle(
                                      color: Theme.of(itemContext)
                                          .colorScheme
                                          .primary,
                                      fontWeight: FontWeight.w700,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}

Future<void> showColorPickerDialog(BuildContext context) async {
  final prefsProvider = Provider.of<Prefs>(context, listen: false);
  final currentColor = prefsProvider.themeColor;

  Color pickedColor = currentColor;

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(L10n.of(context).settingsAppearanceThemeColor),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickedColor,
            onColorChanged: (color) {
              pickedColor = color;
            },
            enableAlpha: false,
            displayThumbColor: true,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: <Widget>[
          TextButton.icon(
            icon: const Icon(Icons.auto_stories_outlined),
            label: Text(
              L10n.of(context).settingsAppearanceUsePaperfoldTheme,
            ),
            onPressed: () {
              prefsProvider.useBrandTheme = true;
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text(L10n.of(context).commonCancel),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text(L10n.of(context).commonOk),
            onPressed: () {
              prefsProvider.saveThemeToPrefs(pickedColor.toARGB32());
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
