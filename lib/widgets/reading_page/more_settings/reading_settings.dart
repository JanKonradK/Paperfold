import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/reading_info.dart';
import 'package:paperfold/enums/code_highlight_theme.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/reading_info.dart';
import 'package:paperfold/page/reading_page.dart';
import 'package:paperfold/widgets/common/anx_segmented_button.dart';
import 'package:material_ui/material_ui.dart';

class ReadingMoreSettings extends StatefulWidget {
  const ReadingMoreSettings({super.key});

  @override
  State<ReadingMoreSettings> createState() => _ReadingMoreSettingsState();
}

class _ReadingMoreSettingsState extends State<ReadingMoreSettings> {
  final isReading =
      epubPlayerKey.currentState != null && epubPlayerKey.currentState!.mounted;

  @override
  Widget build(BuildContext context) {
    Widget columnCount() {
      return StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.of(context).readingPageColumnCount,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Row(
              children: [
                Expanded(
                  child: AnxSegmentedButton<int>(
                    segments: [
                      SegmentButtonItem(
                        label: L10n.of(context).readingPageAuto,
                        value: 0,
                        icon: const Icon(Icons.auto_awesome),
                      ),
                      SegmentButtonItem(
                        label: L10n.of(context).readingPageSingle,
                        value: 1,
                        icon: const Icon(Icons.book_outlined),
                      ),
                      SegmentButtonItem(
                        label: L10n.of(context).readingPageDouble,
                        value: 2,
                        icon: const Icon(Icons.menu_book_outlined),
                      ),
                    ],
                    selected: {Prefs().bookStyle.maxColumnCount},
                    onSelectionChanged: (value) {
                      setState(() {
                        final newBookStyle = Prefs().bookStyle.copyWith(
                          maxColumnCount: value.first,
                        );
                        Prefs().saveBookStyleToPrefs(newBookStyle);
                        epubPlayerKey.currentState?.changeStyle(newBookStyle);
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget columnThreshold() {
      return StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  L10n.of(context).readingPageColumnThreshold,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  '${Prefs().bookStyle.columnThreshold.toInt()}px',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (Prefs().bookStyle.maxColumnCount == 0)
              Text(
                L10n.of(context).readingPageColumnThresholdTip,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            Slider(
              value: Prefs().bookStyle.columnThreshold,
              min: 400,
              max: 1200,
              divisions: 40,
              label: '${Prefs().bookStyle.columnThreshold.toInt()}px',
              onChanged: Prefs().bookStyle.maxColumnCount == 0
                  ? (value) {
                      setState(() {
                        final newBookStyle = Prefs().bookStyle.copyWith(
                          columnThreshold: value,
                        );
                        Prefs().saveBookStyleToPrefs(newBookStyle);
                        epubPlayerKey.currentState?.changeStyle(newBookStyle);
                      });
                    }
                  : null,
            ),
          ],
        ),
      );
    }

    Widget buildInfoDropdown(
      BuildContext context,
      String label,
      ReadingInfoEnum currentValue,
      Function(ReadingInfoEnum) onChanged,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          DropdownButton<ReadingInfoEnum>(
            isDense: true,
            isExpanded: true,
            value: currentValue,
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
            underline: Container(),
            dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: PaperfoldShape.controlRadius,
            items: ReadingInfoEnum.values.map((info) {
              return DropdownMenuItem<ReadingInfoEnum>(
                value: info,
                child: Text(
                  info.getL10n(context),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    Widget readingInfo() {
      return StatefulBuilder(
        builder: (context, setState) {
          void updateReadingInfo(ReadingInfoModel info) {
            Prefs().readingInfo = info;
            epubPlayerKey.currentState?.changeReadingInfo();
          }

          Widget buildSettingSlider({
            required String label,
            required double value,
            required double min,
            required double max,
            required int divisions,
            required ValueChanged<double> onChanged,
          }) {
            return Row(
              children: [
                SizedBox(width: 96, child: Text(label)),
                Expanded(
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    label: value.toStringAsFixed(0),
                    onChanged: (newValue) {
                      setState(() {
                        onChanged(newValue);
                        epubPlayerKey.currentState?.changeReadingInfo();
                      });
                    },
                  ),
                ),
              ],
            );
          }

          Widget buildSectionSettings({
            required String title,
            required ReadingInfoSectionModel section,
            required ValueChanged<ReadingInfoSectionModel> onChanged,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: buildInfoDropdown(
                        context,
                        L10n.of(context).readingPageLeft,
                        section.left,
                        (value) {
                          setState(() {
                            onChanged(section.copyWith(left: value));
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: buildInfoDropdown(
                        context,
                        L10n.of(context).readingPageCenter,
                        section.center,
                        (value) {
                          setState(() {
                            onChanged(section.copyWith(center: value));
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: buildInfoDropdown(
                        context,
                        L10n.of(context).readingPageRight,
                        section.right,
                        (value) {
                          setState(() {
                            onChanged(section.copyWith(right: value));
                          });
                        },
                      ),
                    ),
                  ],
                ),
                buildSettingSlider(
                  label: L10n.of(context).readingSettingsMargin,
                  value: section.verticalMargin,
                  min: 0,
                  max: 80,
                  divisions: 40,
                  onChanged: (value) =>
                      onChanged(section.copyWith(verticalMargin: value)),
                ),
                buildSettingSlider(
                  label: L10n.of(context).readingPageLeftMargin,
                  value: section.leftMargin,
                  min: 0,
                  max: 80,
                  divisions: 40,
                  onChanged: (value) =>
                      onChanged(section.copyWith(leftMargin: value)),
                ),
                buildSettingSlider(
                  label: L10n.of(context).readingPageRightMargin,
                  value: section.rightMargin,
                  min: 0,
                  max: 80,
                  divisions: 40,
                  onChanged: (value) =>
                      onChanged(section.copyWith(rightMargin: value)),
                ),
                buildSettingSlider(
                  label: L10n.of(context).readingPageFontSize,
                  value: section.fontSize,
                  min: 8,
                  max: 24,
                  divisions: 16,
                  onChanged: (value) =>
                      onChanged(section.copyWith(fontSize: value)),
                ),
              ],
            );
          }

          final readingInfo = Prefs().readingInfo;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSectionSettings(
                title: L10n.of(context).readingPageHeaderSettings,
                section: readingInfo.header,
                onChanged: (section) {
                  updateReadingInfo(readingInfo.copyWith(header: section));
                },
              ),
              const Divider(),
              buildSectionSettings(
                title: L10n.of(context).readingPageFooterSettings,
                section: readingInfo.footer,
                onChanged: (section) {
                  updateReadingInfo(readingInfo.copyWith(footer: section));
                },
              ),
            ],
          );
        },
      );
    }

    Widget codeHighlightTheme() {
      return StatefulBuilder(
        builder: (context, setState) {
          final lightThemes = [
            CodeHighlightThemeEnum.defaultTheme,
            CodeHighlightThemeEnum.github,
            CodeHighlightThemeEnum.oneLight,
            CodeHighlightThemeEnum.materialLight,
          ];

          final darkThemes = [
            CodeHighlightThemeEnum.vsDark,
            CodeHighlightThemeEnum.oneDark,
            CodeHighlightThemeEnum.dracula,
            CodeHighlightThemeEnum.materialDark,
            CodeHighlightThemeEnum.nord,
            CodeHighlightThemeEnum.nightOwl,
            CodeHighlightThemeEnum.solarizedDark,
            CodeHighlightThemeEnum.atomDark,
          ];

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L10n.of(context).codeHighlightTheme,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              // Quick toggle: Off / Light / Dark
              Row(
                children: [
                  Expanded(
                    child: AnxSegmentedButton<String>(
                      segments: [
                        SegmentButtonItem(
                          label: L10n.of(context).codeHighlightOff,
                          value: 'off',
                          icon: const Icon(Icons.code_off),
                        ),
                        SegmentButtonItem(
                          label: L10n.of(context).codeHighlightLight,
                          value: 'light',
                          icon: const Icon(Icons.light_mode),
                        ),
                        SegmentButtonItem(
                          label: L10n.of(context).codeHighlightDark,
                          value: 'dark',
                          icon: const Icon(Icons.dark_mode),
                        ),
                      ],
                      selected: {
                        Prefs().codeHighlightTheme == CodeHighlightThemeEnum.off
                            ? 'off'
                            : Prefs().codeHighlightTheme.isLight
                            ? 'light'
                            : 'dark',
                      },
                      onSelectionChanged: (value) {
                        setState(() {
                          if (value.first == 'off') {
                            Prefs().codeHighlightTheme =
                                CodeHighlightThemeEnum.off;
                          } else if (value.first == 'light') {
                            Prefs().codeHighlightTheme =
                                CodeHighlightThemeEnum.defaultTheme;
                          } else {
                            Prefs().codeHighlightTheme =
                                CodeHighlightThemeEnum.vsDark;
                          }
                          epubPlayerKey.currentState?.changeStyle(null);
                        });
                      },
                    ),
                  ),
                ],
              ),
              // Detailed theme selection (only show if not off)
              if (Prefs().codeHighlightTheme != CodeHighlightThemeEnum.off) ...[
                const SizedBox(height: 16),
                // Light themes section
                if (Prefs().codeHighlightTheme.isLight) ...[
                  Text(
                    L10n.of(context).codeHighlightLightThemes,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: lightThemes.map((theme) {
                      final isSelected = Prefs().codeHighlightTheme == theme;
                      return ChoiceChip(
                        label: Text(theme.displayName),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              Prefs().codeHighlightTheme = theme;
                              epubPlayerKey.currentState?.changeStyle(null);
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
                // Dark themes section
                if (Prefs().codeHighlightTheme.isDark) ...[
                  Text(
                    L10n.of(context).codeHighlightDarkThemes,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: darkThemes.map((theme) {
                      final isSelected = Prefs().codeHighlightTheme == theme;
                      return ChoiceChip(
                        label: Text(theme.displayName),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              Prefs().codeHighlightTheme = theme;
                              epubPlayerKey.currentState?.changeStyle(null);
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ],
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        children: [
          ExpansionTile(
            title: Text(L10n.of(context).readingPageColumnCount),
            children: [columnCount(), columnThreshold()],
          ),
          ExpansionTile(
            title: Text(L10n.of(context).codeHighlightTheme),
            children: [codeHighlightTheme()],
          ),
          ExpansionTile(
            title: Text(L10n.of(context).readerPageInformation),
            children: [readingInfo()],
          ),
        ],
      ),
    );
  }
}
