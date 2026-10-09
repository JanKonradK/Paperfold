import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/lang_list.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/service/translate/index.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:paperfold/widgets/settings/service_config_form.dart';
import 'package:paperfold/widgets/settings/settings_section.dart';
import 'package:paperfold/widgets/settings/settings_tile.dart';
import 'package:paperfold/widgets/settings/settings_title.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class TranslateSetting extends StatefulWidget {
  const TranslateSetting({super.key});

  @override
  State<TranslateSetting> createState() => _TranslateSettingState();
}

class _TranslateSettingState extends State<TranslateSetting> {
  @override
  Widget build(BuildContext context) {
    return settingsSections(
      sections: [
        SettingsSection(
          title: Text(L10n.of(context).underlineTranslation),
          tiles: [
            CustomSettingsTile(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TranslationConfig(
                      setState: () => setState(() {}),
                    ),
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            L10n.of(context).underlineTranslationTip,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SettingsTile.switchTile(
              leading: const Icon(Icons.translate_outlined),
              title: Text(L10n.of(context).readingPageAutoTranslateSelection),
              initialValue: Prefs().autoTranslateSelection,
              onToggle: (value) => setState(() {
                Prefs().autoTranslateSelection = value;
              }),
            ),
          ],
        ),
        SettingsSection(
          title: Text(L10n.of(context).fullTextTranslation),
          tiles: [
            CustomSettingsTile(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    FullTextTranslationConfig(
                      setState: () => setState(() {}),
                    ),
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            L10n.of(context).fullTextTranslationTip,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: Text(L10n.of(context).translationServiceConfiguration),
          tiles: [
            for (var service in TranslateService.activeValues)
              CustomSettingsTile(
                child: TranslateSettingItem(service: service),
              ),
          ],
        ),
      ],
    );
  }
}

class TranslationConfig extends StatelessWidget {
  const TranslationConfig({super.key, required this.setState});

  final VoidCallback setState;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => const TranslateServicePicker(),
                ).then((value) {
                  if (context.mounted) setState();
                });
              },
              child: Text(
                Prefs().translateService.getLabel(context),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(L10n.of(context).settingsTranslateCurrentService),
          ],
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => const TranslateLangPicker(
                        isFrom: true, isWebView: false),
                  ).then((value) {
                    if (context.mounted) setState();
                  });
                },
                child: Text(Prefs().translateFrom.getNative(context)),
              ),
            ),
            const Icon(Icons.arrow_forward_ios),
            Expanded(
              child: TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => const TranslateLangPicker(
                        isFrom: false, isWebView: false),
                  ).then((value) {
                    if (context.mounted) setState();
                  });
                },
                child: Text(
                  Prefs().translateTo.getNative(context),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class FullTextTranslationConfig extends StatelessWidget {
  const FullTextTranslationConfig({super.key, required this.setState});

  final VoidCallback setState;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => const FullTextTranslateServicePicker(),
                ).then((value) {
                  if (context.mounted) setState();
                });
              },
              child: Text(
                Prefs().fullTextTranslateService.getLabel(context),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(L10n.of(context).settingsTranslateCurrentService),
          ],
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => const TranslateLangPicker(
                        isFrom: true, isWebView: true),
                  ).then((value) {
                    if (context.mounted) setState();
                  });
                },
                child: Text(Prefs().fullTextTranslateFrom.getNative(context)),
              ),
            ),
            const Icon(Icons.arrow_forward_ios),
            Expanded(
              child: TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => const TranslateLangPicker(
                        isFrom: false, isWebView: true),
                  ).then((value) {
                    if (context.mounted) setState();
                  });
                },
                child: Text(
                  Prefs().fullTextTranslateTo.getNative(context),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TranslateServicePicker extends StatelessWidget {
  const TranslateServicePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: TranslateService.activeValues.length,
      itemBuilder: (context, index) {
        final service = TranslateService.activeValues.elementAt(index);
        return ListTile(
          title: Text(service.getLabel(context)),
          selected: service == Prefs().translateService,
          trailing: service == Prefs().translateService
              ? const Icon(Icons.check)
              : null,
          onTap: () {
            Prefs().translateService = service;
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

class FullTextTranslateServicePicker extends StatelessWidget {
  const FullTextTranslateServicePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final services =
        TranslateService.activeValues.where((s) => !s.isWebView).toList();

    return ListView.builder(
      itemCount: services.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(services[index].getLabel(context)),
        selected: services[index] == Prefs().fullTextTranslateService,
        trailing: services[index] == Prefs().fullTextTranslateService
            ? const Icon(Icons.check)
            : null,
        onTap: () {
          Prefs().fullTextTranslateService = services[index];
          Navigator.pop(context);
        },
      ),
    );
  }
}

class TranslateLangPicker extends StatelessWidget {
  const TranslateLangPicker(
      {super.key, required this.isFrom, this.isWebView = false});

  final bool isFrom;
  final bool isWebView;

  @override
  Widget build(BuildContext context) {
    final languages = LangListEnum.values
        .where((language) => isFrom || language != LangListEnum.auto)
        .toList();
    final selected = isWebView
        ? (isFrom ? Prefs().fullTextTranslateFrom : Prefs().fullTextTranslateTo)
        : (isFrom ? Prefs().translateFrom : Prefs().translateTo);
    return ListView.builder(
      itemCount: languages.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(languages[index].getNative(context)),
        selected: languages[index] == selected,
        trailing: languages[index] == selected ? const Icon(Icons.check) : null,
        onTap: () {
          if (isWebView) {
            if (isFrom) {
              Prefs().fullTextTranslateFrom = languages[index];
            } else {
              Prefs().fullTextTranslateTo = languages[index];
            }
          } else {
            if (isFrom) {
              Prefs().translateFrom = languages[index];
            } else {
              Prefs().translateTo = languages[index];
            }
          }
          Navigator.pop(context);
        },
      ),
    );
  }
}

class TranslateSettingItem extends StatefulWidget {
  const TranslateSettingItem({super.key, required this.service});

  final TranslateService service;

  @override
  State<TranslateSettingItem> createState() => _TranslateSettingItemState();
}

class _TranslateSettingItemState extends State<TranslateSettingItem> {
  bool isExpanded = false;
  static const testText = "Hello, world!";
  static const languageTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  Map<String, dynamic> _currentConfig = {};

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    _currentConfig = getTranslateServiceConfig(widget.service);
    setState(() {});
  }

  Widget languageText(String text) {
    return Expanded(
      child: Text(
        text,
        style: languageTextStyle,
        textAlign: TextAlign.center,
      ),
    );
  }

  bool _saveConfig() {
    try {
      saveTranslateServiceConfig(widget.service, _currentConfig);
      AnxToast.show(L10n.of(context).commonSaved);
      return true;
    } catch (e) {
      AnxToast.show(L10n.of(context).commonFailed);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final configItems = getTranslateServiceConfigItems(context, widget.service);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: settingsListTileTheme.contentPadding,
          minLeadingWidth: settingsListTileTheme.minLeadingWidth,
          horizontalTitleGap: settingsListTileTheme.horizontalTitleGap,
          leading: const Icon(Icons.translate_outlined),
          title: Text(widget.service.getLabel(context)),
          trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ServiceConfigForm(
                        configItems: configItems,
                        initialConfig: _currentConfig,
                        onConfigChanged: (newConfig) {
                          _currentConfig = newConfig;
                        },
                      ),
                      const Divider(),
                      OverflowBar(
                        alignment: MainAxisAlignment.end,
                        overflowAlignment: OverflowBarAlignment.end,
                        spacing: 8,
                        overflowSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: () {
                              if (!_saveConfig()) return;
                              SmartDialog.show(
                                useSystem: true,
                                animationType:
                                    SmartAnimationType.centerFade_otherSlide,
                                builder: (context) => AlertDialog(
                                  title: const Center(
                                    child: Icon(Icons.translate_outlined),
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          languageText(
                                            Prefs()
                                                .translateFrom
                                                .getNative(context),
                                          ),
                                          const Icon(Icons.arrow_forward_ios),
                                          languageText(
                                            Prefs()
                                                .translateTo
                                                .getNative(context),
                                          ),
                                        ],
                                      ),
                                      const Divider(),
                                      const Text(testText),
                                      const Icon(Icons.arrow_downward),
                                      translateText(testText,
                                          service: widget.service),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Text(L10n.of(context).commonTest),
                          ),
                          FilledButton(
                            onPressed: () {
                              if (!_saveConfig()) return;
                              setState(() {
                                isExpanded = !isExpanded;
                              });
                            },
                            child: Text(L10n.of(context).commonSave),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
