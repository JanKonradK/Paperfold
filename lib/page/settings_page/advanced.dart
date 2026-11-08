import 'package:paperfold/widgets/common/paperfold_modal_motion.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/md5_statistics.dart';
import 'package:paperfold/page/settings_page/subpage/chapter_split_rules_page.dart';
import 'package:paperfold/page/changelog_screen.dart';
import 'package:paperfold/page/onboarding_screen.dart';
import 'package:paperfold/service/md5_service.dart';
import 'package:paperfold/utils/app_version.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/widgets/common/load_failure.dart';
import 'package:paperfold/widgets/settings/settings_section.dart';
import 'package:paperfold/widgets/settings/settings_tile.dart';
import 'package:paperfold/widgets/settings/settings_title.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:paperfold/main.dart';

class AdvancedSetting extends StatefulWidget {
  const AdvancedSetting({
    super.key,
    this.loadMd5Statistics = MD5Service.getMd5Statistics,
  });

  @visibleForTesting
  final Future<MD5Statistics> Function() loadMd5Statistics;

  @override
  State<AdvancedSetting> createState() => _AdvancedSettingState();
}

class _AdvancedSettingState extends State<AdvancedSetting> {
  MD5Statistics? _md5Stats;
  Object? _md5LoadError;
  bool _isCalculating = false;
  double _progress = 0.0;
  String _currentFile = '';

  @override
  void initState() {
    super.initState();
    _loadMd5Statistics();
  }

  Future<void> _loadMd5Statistics() async {
    try {
      final stats = await widget.loadMd5Statistics();
      if (!mounted) return;
      setState(() {
        _md5Stats = stats;
        _md5LoadError = null;
      });
    } catch (error, stackTrace) {
      AnxLog.warning(
        'Could not load file checksum statistics',
        error,
        stackTrace,
      );
      if (mounted) setState(() => _md5LoadError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return settingsSections(
      sections: [
        SettingsSection(
          title: Text(L10n.of(context).eBookProcess),
          tiles: [
            SettingsTile.navigation(
              leading: const Icon(Icons.auto_stories_outlined),
              title: Text(L10n.of(context).chapterSplitting),
              onPressed: (_) {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => const ChapterSplitRulesPage(),
                  ),
                );
              },
            ),
          ],
        ),
        SettingsSection(
          title: Text(L10n.of(context).md5Management),
          tiles: [
            if (_md5LoadError != null)
              CustomSettingsTile(
                child: LoadFailure.inline(
                  error: _md5LoadError,
                  onRetry: _loadMd5Statistics,
                ),
              ),
            if (_md5Stats != null)
              SettingsTile(
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.fingerprint),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(L10n.of(context).md5Statistics),
                          const SizedBox(height: 4),
                          Text(
                            L10n.of(context)
                                .md5TotalBooks(_md5Stats!.totalBooks),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            L10n.of(context)
                                .md5BooksWithMd5(_md5Stats!.booksWithMd5),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            L10n.of(context)
                                .md5BooksWithoutMd5(_md5Stats!.booksWithoutMd5),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            L10n.of(context)
                                .md5LocalFiles(_md5Stats!.localFilesCount),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            L10n.of(context).md5LocalFilesWithoutMd5(
                              _md5Stats!.localFilesWithoutMd5,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_isCalculating)
              SettingsTile(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L10n.of(context).md5Calculating),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 4),
                    Text(
                      '${(_progress * 100).toStringAsFixed(1)}% - $_currentFile',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                leading: const Icon(Icons.calculate),
              )
            else
              SettingsTile.navigation(
                title: Text(L10n.of(context).md5CalculateMissing),
                leading: const Icon(Icons.calculate),
                onPressed: _calculateMd5,
                enabled: _md5Stats != null,
              ),
          ],
        ),
        SettingsSection(
          title: Text(L10n.of(context).settingsAdvancedJavascript),
          tiles: [
            SettingsTile.switchTile(
              title: Text(
                L10n.of(context).settingsAdvancedEnableJavascriptForEpub,
              ),
              leading: const Icon(Icons.code),
              initialValue: Prefs().enableJsForEpub,
              onToggle: (value) {
                Prefs().enableJsForEpub = value;
                setState(() {});
              },
            ),
          ],
        ),
        SettingsSection(
          title: Text(L10n.of(context).hints),
          tiles: [
            SettingsTile.navigation(
              title: Text(L10n.of(context).showAllHintsAgain),
              leading: const Icon(Icons.lightbulb_outline),
              onPressed: (_) {
                Prefs().resetHints();
                AnxToast.show(L10n.of(context).allHintsWillBeShownAgain);
              },
            ),
            SettingsTile.navigation(
              title: Text(L10n.of(context).viewChangelog),
              leading: const Icon(Icons.update),
              onPressed: _showChangelog,
            ),
            SettingsTile.navigation(
              title: Text(L10n.of(context).viewOnboarding),
              leading: const Icon(Icons.menu_book_outlined),
              onPressed: _showOnboarding,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _calculateMd5(BuildContext context) async {
    if (_isCalculating || _md5Stats == null) return;

    if (_md5Stats?.localFilesWithoutMd5 == 0) {
      AnxToast.show(L10n.of(context).md5NoCalculationNeeded);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: paperfoldModalMotion(context),
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(L10n.of(context).md5CalculateConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L10n.of(context).md5CalculateConfirmContent),
            const SizedBox(height: 8),
            if (_md5Stats!.localFilesWithoutMd5 < _md5Stats!.booksWithoutMd5)
              Container(
                padding: const EdgeInsets.all(PaperfoldSpace.xs),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(30),
                  borderRadius: PaperfoldShape.objectRadius,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        L10n.of(context).md5MissingFilesTip,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(L10n.of(context).commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(L10n.of(context).commonConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isCalculating = true;
      _progress = 0.0;
      _currentFile = '';
    });

    try {
      final booksToCalculate = await bookDao.getBooksWithoutMd5();

      final result = await MD5Service.batchCalculateMd5(
        booksToCalculate,
        onProgress: (current, total, currentFile) {
          if (!mounted) return;
          setState(() {
            _progress = current / total;
            _currentFile = currentFile;
          });
        },
      );

      await _loadMd5Statistics();
      if (!mounted) return;

      setState(() {
        _isCalculating = false;
        _progress = 0.0;
        _currentFile = '';
      });

      if (context.mounted) {
        showDialog(
          context: context,
          animationStyle: paperfoldModalMotion(context),
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(L10n.of(context).md5CalculationComplete),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.of(context)
                      .md5CalculationResultCalculated(result.calculated),
                ),
                Text(
                  L10n.of(context).md5CalculationResultSkipped(result.skipped),
                ),
                Text(
                  L10n.of(context).md5CalculationResultFailed(result.failed),
                ),
                if (result.missingFiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    L10n.of(context).md5MissingFiles,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...result.missingFiles.take(5).map((file) => Text('• $file')),
                  if (result.missingFiles.length > 5)
                    Text(
                      L10n.of(context)
                          .md5AndMore(result.missingFiles.length - 5),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(L10n.of(context).commonOk),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCalculating = false;
        _progress = 0.0;
        _currentFile = '';
      });

      if (context.mounted) {
        AnxToast.show(L10n.of(context).md5CalculationError(e.toString()));
      }
    }
  }

}

Future<void> _showChangelog(BuildContext context) async {
  final currentVersion = await getAppVersion();
  if (!context.mounted) return;
  final lastVersion = Prefs().lastAppVersion ?? currentVersion;

  showCupertinoSheet(
    context: navigatorKey.currentContext ?? context,
    builder: (sheetContext) => ChangelogScreen(
      lastVersion: lastVersion,
      currentVersion: currentVersion,
      onComplete: () {
        Prefs().lastAppVersion = currentVersion;
        Navigator.pop(sheetContext);
      },
    ),
  );
}

Future<void> _showOnboarding(BuildContext context) async {
  final currentVersion = await getAppVersion();
  if (!context.mounted) return;

  showCupertinoSheet(
    context: navigatorKey.currentContext ?? context,
    builder: (sheetContext) => Scaffold(
      body: OnboardingScreen(
        onComplete: () {
          Prefs().lastAppVersion = currentVersion;
          Navigator.pop(sheetContext);
        },
      ),
    ),
  );
}
