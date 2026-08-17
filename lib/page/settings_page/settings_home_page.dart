import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/settings_page/advanced.dart';
import 'package:paperfold/page/settings_page/appearance.dart';
import 'package:paperfold/page/settings_page/developer/developer_options_page.dart';
import 'package:paperfold/page/settings_page/reading.dart';
import 'package:paperfold/page/settings_page/settings_page.dart';
import 'package:paperfold/page/settings_page/storege.dart';
import 'package:paperfold/page/settings_page/sync.dart';
import 'package:paperfold/page/settings_page/translate.dart';
import 'package:paperfold/widgets/settings/about.dart';
import 'package:paperfold/widgets/settings/settings_section.dart';
import 'package:paperfold/widgets/settings/settings_tile.dart';
import 'package:paperfold/widgets/settings/theme_mode.dart';
import 'package:paperfold/widgets/settings/webdav_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One settings category.
class _SettingsCategory {
  const _SettingsCategory({
    required this.title,
    required this.icon,
    required this.sections,
    required this.subtitles,
  });

  final String title;
  final IconData icon;

  /// A builder, not a widget. plan.md Section 11.2 asks for the settings tree
  /// to open as lazy routes.
  final WidgetBuilder sections;
  final List<String> subtitles;
}

/// The settings screen.
///
/// It used to be two screens. The first held a 96 dp mark, the application
/// name, one theme control, one sync switch and a row called "More settings";
/// the second, opened from that row, held every actual category under an app
/// bar that read "More settings" beneath one that read "Settings". Two taps
/// and two headings stood between the reader and the first real setting, and
/// the word "more" described the whole of the settings rather than any part
/// of it. The categories are on the first screen now.
class SettingsHomePage extends ConsumerStatefulWidget {
  const SettingsHomePage({super.key});

  @override
  ConsumerState<SettingsHomePage> createState() => _SettingsHomePageState();
}

class _SettingsHomePageState extends ConsumerState<SettingsHomePage> {
  int selectedIndex = 0;
  WidgetBuilder? settingsDetail;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Prefs(),
      builder: (context, _) {
        final l10n = L10n.of(context);
        final showDeveloperEntry = Prefs().developerOptionsEnabled;

        final categories = <_SettingsCategory>[
          _SettingsCategory(
            title: l10n.settingsAppearance,
            icon: Icons.color_lens_outlined,
            sections: (BuildContext context) => const AppearanceSetting(),
            subtitles: [
              l10n.settingsAppearanceTheme,
              l10n.settingsAppearanceDisplay,
              l10n.settingsBookshelfCover,
            ],
          ),
          _SettingsCategory(
            title: l10n.settingsReading,
            icon: Icons.book_rounded,
            sections: (BuildContext context) => const ReadingSettings(),
            subtitles: [
              l10n.readingPageReading,
              l10n.font,
              l10n.readingPageStyle,
              l10n.readingPageOther,
            ],
          ),
          _SettingsCategory(
            title: l10n.settingsSync,
            icon: Icons.sync_outlined,
            sections: (BuildContext context) => const SyncSetting(),
            subtitles: [
              l10n.settingsSyncWebdav,
              l10n.exportAndImport,
            ],
          ),
          _SettingsCategory(
            title: l10n.settingsTranslate,
            icon: Icons.translate_outlined,
            sections: (BuildContext context) => const TranslateSetting(),
            subtitles: [
              l10n.settingsTranslate,
            ],
          ),
          _SettingsCategory(
            title: l10n.storage,
            icon: Icons.storage_outlined,
            sections: (BuildContext context) => const StorageSettings(),
            subtitles: [
              l10n.storageInfo,
              l10n.storageDataFileDetails,
            ],
          ),
          _SettingsCategory(
            title: l10n.settingsAdvanced,
            icon: Icons.shield_outlined,
            sections: (BuildContext context) => const AdvancedSetting(),
            subtitles: [
              l10n.chapterSplitting,
              l10n.settingsAdvancedLog,
              l10n.duplicateFile,
              l10n.settingsAdvancedJavascript,
              l10n.settingsAdvancedNetwork,
            ],
          ),
        ];

        return Scaffold(
          appBar: AppBar(title: Text(l10n.navBarSettings)),
          body: LayoutBuilder(builder: (context, constraints) {
            // The wide layout still shows one screen at a time, so it holds
            // the builder rather than a built screen.
            settingsDetail ??= (BuildContext context) => SettingsPageBody(
                  isMobile: false,
                  title: categories[0].title,
                  sections: categories[0].sections,
                );

            void setDetail(WidgetBuilder detail, int id) {
              setState(() {
                settingsDetail = detail;
                selectedIndex = id;
              });
            }

            Widget settingsList(bool isMobile) {
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: <Widget>[
                  // The two controls the reader reaches for most, in front of
                  // the categories rather than on a screen of their own.
                  SettingsSection(
                    title: Text(l10n.settingsQuickSettings),
                    tiles: [
                      const CustomSettingsTile(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: ChangeThemeMode(),
                        ),
                      ),
                      webdavSwitch(context, setState, ref),
                    ],
                  ),
                  // No header. It would read "Settings" directly under an app
                  // bar that already reads "Settings".
                  SettingsSection(
                    tiles: [
                      CustomSettingsTile(
                        // Every row in this card is a ListTile, so they take
                        // the settings metrics rather than the stock ones and
                        // line up with the quick-settings card above.
                        child: ListTileTheme.merge(
                          contentPadding:
                              settingsListTileTheme.contentPadding,
                          minLeadingWidth:
                              settingsListTileTheme.minLeadingWidth,
                          horizontalTitleGap:
                              settingsListTileTheme.horizontalTitleGap,
                          minTileHeight: settingsListTileTheme.minTileHeight,
                          child: Column(
                            children: <Widget>[
                              for (int index = 0;
                                  index < categories.length;
                                  index++)
                                SettingsPageBuilder(
                                  isMobile: isMobile,
                                  id: index,
                                  selectedIndex: selectedIndex,
                                  setDetail: setDetail,
                                  icon: Icon(
                                    categories[index].icon,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  title: categories[index].title,
                                  sections: categories[index].sections,
                                  subTitles: categories[index].subtitles,
                                ),
                              if (showDeveloperEntry)
                                ListTile(
                                  leading: Icon(Icons.developer_mode,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  title: Text(l10n.settingsDeveloperOptions),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (context) =>
                                            const DeveloperOptionsPage(),
                                      ),
                                    );
                                  },
                                ),
                              const About(leadingColor: true),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            if (constraints.maxWidth > 600) {
              return Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: settingsList(false),
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(
                    flex: 2,
                    child: Builder(builder: settingsDetail!),
                  ),
                ],
              );
            }
            return settingsList(true);
          }),
        );
      },
    );
  }
}
