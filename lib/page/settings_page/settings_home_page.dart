import 'package:paperfold/utils/paperfold_layout.dart';
import 'package:paperfold/widgets/common/paperfold_grid.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/page/opds/opds_catalogs_page.dart';
import 'package:paperfold/page/home_page/notes_page.dart';
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
import 'package:material_ui/material_ui.dart';
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
              switch (Prefs().eInkMode ? 'light' : Prefs().appThemeMode) {
                'light' => l10n.settingsCreamMode,
                'dark' => l10n.settingsDarkMode,
                'burgundy' => l10n.settingsBurgundyMode,
                _ => l10n.settingsSystemMode,
              },
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
            title: l10n.settingsLibraryBooks,
            icon: Icons.local_library_outlined,
            sections: (_) => const StorageSettings(),
            subtitles: [l10n.storageInfo, l10n.storageDataFileDetails],
          ),
          _SettingsCategory(
            title: l10n.navJournal,
            icon: Icons.edit_note_outlined,
            sections: (_) => const NotesPage(),
            subtitles: [l10n.navBarNotes, l10n.journalBooks],
          ),
          _SettingsCategory(
            title: l10n.settingsSyncBackup,
            icon: Icons.sync_outlined,
            sections: (_) => const SyncSetting(),
            subtitles: [l10n.settingsSyncWebdav, l10n.exportAndImport],
          ),
          _SettingsCategory(
            title: l10n.settingsCatalogs,
            icon: Icons.public_outlined,
            sections: (_) => const OpdsCatalogsPage(),
            subtitles: [l10n.opdsFindBooksOnline],
          ),
          _SettingsCategory(
            title: l10n.settingsTranslate,
            icon: Icons.translate_outlined,
            sections: (_) => const TranslateSetting(),
            subtitles: [l10n.settingsTranslate],
          ),
          _SettingsCategory(
            title: l10n.settingsAdvanced,
            icon: Icons.shield_outlined,
            sections: (_) => const AdvancedSetting(),
            subtitles: [l10n.chapterSplitting, l10n.settingsAdvancedLog],
          ),
        ];

        return Scaffold(
          appBar: AppBar(title: Text(l10n.navBarSettings)),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final layout = PaperfoldLayout.of(
                context,
                constraints: constraints,
              );
              // Categories fill the width: two across on a wide portrait
              // screen, up to three in landscape, one on a phone.
              final columns = layout.landscape
                  ? layout.columns(344, gap: 16, max: 3)
                  : layout.content >= 720
                  ? 2
                  : 1;
              return ListView(
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.paddingOf(context).bottom + PaperfoldSpace.lg,
                ),
                children: <Widget>[
                  // The two controls the reader reaches for most, in front of
                  // the categories rather than on a screen of their own.
                  SettingsSection(
                    title: Text(l10n.settingsAppearance),
                    tiles: [
                      const CustomSettingsTile(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: ThemeShelfPreview(),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    // Each section insets itself by 16; this brings the
                    // edge to the page gutter.
                    padding: EdgeInsets.symmetric(
                      horizontal: layout.gutter - PaperfoldSpace.gutter,
                    ),
                    child: PaperfoldGrid(
                      columns: columns,
                      gap: 0,
                      equalHeight: true,
                      children: [
                        for (int index = 0; index < categories.length; index++)
                          SettingsSection(
                            tiles: [
                              CustomSettingsTile(
                                child: ListTileTheme.merge(
                                  contentPadding:
                                      settingsListTileTheme.contentPadding,
                                  minLeadingWidth:
                                      settingsListTileTheme.minLeadingWidth,
                                  horizontalTitleGap:
                                      settingsListTileTheme.horizontalTitleGap,
                                  minTileHeight:
                                      settingsListTileTheme.minTileHeight,
                                  child: SettingsPageBuilder(
                                    isMobile: true,
                                    id: index,
                                    selectedIndex: -1,
                                    setDetail: (_, _) {},
                                    icon: Icon(categories[index].icon),
                                    title: categories[index].title,
                                    sections: categories[index].sections,
                                    subTitles: categories[index].subtitles,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  SettingsSection(
                    tiles: [
                      if (showDeveloperEntry)
                        SettingsTile.navigation(
                          leading: const Icon(Icons.developer_mode),
                          title: Text(l10n.settingsDeveloperOptions),
                          onPressed: (context) => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const DeveloperOptionsPage(),
                            ),
                          ),
                        ),
                      const CustomSettingsTile(
                        child: About(leadingColor: true),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
