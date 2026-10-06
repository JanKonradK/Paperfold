import 'dart:io';
import 'dart:math';

import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/providers/storage_info.dart';

import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/get_path/storage_migration.dart';
import 'package:paperfold/utils/platform_utils.dart';
import 'package:paperfold/widgets/common/anx_button.dart';
import 'package:paperfold/widgets/delete_confirm.dart';
import 'package:paperfold/widgets/settings/settings_section.dart';
import 'package:paperfold/widgets/settings/settings_tile.dart';
import 'package:paperfold/widgets/settings/settings_title.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StorageSettings extends ConsumerStatefulWidget {
  const StorageSettings({super.key});

  @override
  ConsumerState<StorageSettings> createState() => _StorageSettingsState();
}

class _StorageSettingsState extends ConsumerState<StorageSettings>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Custom storage location state
  String? _selectedNewPath;
  bool _isMigrating = false;
  String? _currentStoragePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentPath();
  }

  Future<void> _loadCurrentPath() async {
    final path = await getAnxDocumentsPath();
    if (mounted) {
      setState(() {
        _currentStoragePath = path;
        _selectedNewPath = Prefs().pendingStoragePath;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectNewPath() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null || !mounted) return;

    // Check if directory is empty
    final isEmpty = await isDirectoryEmpty(result);
    if (!isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.of(context).storagePathNotEmpty),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    // Check write permission by creating a test file
    try {
      final testFile =
          File('$result${Platform.pathSeparator}.anx_permission_test');
      await testFile.writeAsString('test');
      await testFile.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.of(context).storagePathNoPermission),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedNewPath = result;
    });
  }

  Future<void> _startMigration() async {
    if (_selectedNewPath == null || _isMigrating) return;
    setState(() => _isMigrating = true);
    try {
      // A live SQLite database must never be moved. Startup applies this
      // request before the database, log, reader server, or sync can write.
      await Prefs().setPendingStoragePath(_selectedNewPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L10n.of(context).storageMigrationScheduled),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L10n.of(context).storageMigrationFailed),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  Future<void> _resetToDefaultPath() async {
    final defaultPath = await getDefaultStoragePath();
    if (!mounted || _currentStoragePath == defaultPath) return;

    if (!await isStorageDestinationEmpty(defaultPath)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L10n.of(context).storagePathNotEmpty),
      ));
      return;
    }
    if (!mounted) return;

    setState(() {
      _selectedNewPath = defaultPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final storageInfoAsync = ref.watch(storageInfoProvider);

    Widget fileSizeTriling(String? size) {
      if (size == null) {
        return const CircularProgressIndicator.adaptive();
      }
      return Text(
        size,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    Widget cacheSizeTriling(String? size) {
      if (size == null) {
        return const CircularProgressIndicator.adaptive();
      }
      return ElevatedButton(
        onPressed: () async {
          await ref.read(storageInfoProvider.notifier).clearCache();
          ref.invalidate(storageInfoProvider);
        },
        child: Text('${L10n.of(context).storageClearCache} $size'),
      );
    }

    return settingsSections(sections: [
      SettingsSection(
        title: Text(L10n.of(context).storageInfo),
        tiles: [
          CustomSettingsTile(
            child: Column(
              children: [
                ListTile(
                  title: Text(L10n.of(context).storageTotalSize),
                  trailing:
                      fileSizeTriling(storageInfoAsync.value?.totalSizeStr),
                ),
                ListTile(
                  title: Text(L10n.of(context).storageDatabaseFile),
                  trailing:
                      fileSizeTriling(storageInfoAsync.value?.databaseSizeStr),
                ),
                ListTile(
                  title: Text(L10n.of(context).storageLogFile),
                  trailing: fileSizeTriling(storageInfoAsync.value?.logSizeStr),
                ),
                ListTile(
                  title: Text(L10n.of(context).storageCacheFile),
                  trailing:
                      cacheSizeTriling(storageInfoAsync.value?.cacheSizeStr),
                ),
                Column(
                  children: [
                    ListTile(
                      title: Text(L10n.of(context).storageDataFile),
                      trailing: fileSizeTriling(
                          storageInfoAsync.value?.dataFilesSizeStr),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 20.0),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(L10n.of(context).storageBookFile),
                            trailing: fileSizeTriling(
                                storageInfoAsync.value?.booksSizeStr),
                          ),
                          ListTile(
                            title: Text(L10n.of(context).storageCoverFile),
                            trailing: fileSizeTriling(
                                storageInfoAsync.value?.coverSizeStr),
                          ),
                          ListTile(
                            title: Text(L10n.of(context).storageFontFile),
                            trailing: fileSizeTriling(
                                storageInfoAsync.value?.fontSizeStr),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),

      // Custom storage location (Windows only)
      if (AnxPlatform.isWindows)
        SettingsSection(
          title: Text(L10n.of(context).storageCustomLocation),
          tiles: [
            CustomSettingsTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current storage path
                  ListTile(
                    title: Text(L10n.of(context).storageCurrentPath),
                    subtitle: Text(
                      _currentStoragePath ?? '...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  // Selected new path (if any)
                  if (_selectedNewPath != null) ...[
                    ListTile(
                      title: Text(L10n.of(context).storageNewPath),
                      subtitle: Text(
                        _selectedNewPath!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: L10n.of(context).commonCancel,
                        onPressed: _isMigrating
                            ? null
                            : () async {
                                await Prefs().setPendingStoragePath(null);
                                if (!mounted) return;
                                setState(() => _selectedNewPath = null);
                              },
                      ),
                    ),
                  ],
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        if (_selectedNewPath == null)
                          Expanded(
                            child: AnxButton(
                              onPressed: _selectNewPath,
                              child: Text(L10n.of(context).storageSelectPath),
                            ),
                          )
                        else
                          Expanded(
                            child: AnxButton(
                              onPressed: _isMigrating ? null : _startMigration,
                              isLoading: _isMigrating,
                              child: Text(L10n.of(context).storageMigrateData),
                            ),
                          ),
                        const SizedBox(width: 8),
                        if (Prefs().customStoragePath != null &&
                            _selectedNewPath == null)
                          AnxButton.outlined(
                            onPressed:
                                _isMigrating ? null : _resetToDefaultPath,
                            child: Text(L10n.of(context).storageResetPath),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

      // Tab view for data files details
      SettingsSection(
          title: Text(L10n.of(context).storageDataFileDetails),
          tiles: [
            CustomSettingsTile(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      tabs: [
                        Tab(
                            text: L10n.of(context).storageBookFile,
                            icon: const Icon(Icons.book)),
                        Tab(
                            text: L10n.of(context).storageCoverFile,
                            icon: const Icon(Icons.image)),
                        Tab(
                            text: L10n.of(context).storageFontFile,
                            icon: const Icon(Icons.font_download)),
                      ],
                    ),
                    SizedBox(
                      // Screen height less a magic 140 went negative on a
                      // short window and threw. The list needs a workable
                      // height, not the whole screen, so it takes a share of
                      // what is there and never less than 240.
                      height: max(
                        240,
                        MediaQuery.of(context).size.height * 0.55,
                      ),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Books tab
                          storageInfoAsync.when(
                            data: (_) => DataFilesDetailTab(
                              title: L10n.of(context).storageBookFile,
                              icon: Icons.book,
                              listFiles: ref
                                  .read(storageInfoProvider.notifier)
                                  .listBookFiles(),
                              showDelete: false,
                              ref: ref,
                            ),
                            loading: () => const Center(
                                child: CircularProgressIndicator.adaptive()),
                            error: (_, __) => Center(
                                child: Text(L10n.of(context).commonError)),
                          ),
                          // Covers tab
                          storageInfoAsync.when(
                            data: (_) => DataFilesDetailTab(
                              title: L10n.of(context).storageCoverFile,
                              icon: Icons.image,
                              listFiles: ref
                                  .read(storageInfoProvider.notifier)
                                  .listCoverFiles(),
                              showDelete: false,
                              ref: ref,
                            ),
                            loading: () => const Center(
                                child: CircularProgressIndicator.adaptive()),
                            error: (_, __) => Center(
                                child: Text(L10n.of(context).commonError)),
                          ),
                          // Fonts tab
                          storageInfoAsync.when(
                            data: (_) => DataFilesDetailTab(
                              title: L10n.of(context).storageFontFile,
                              icon: Icons.font_download,
                              listFiles: ref
                                  .read(storageInfoProvider.notifier)
                                  .listFontFiles(),
                              showDelete: true,
                              ref: ref,
                            ),
                            loading: () => const Center(
                                child: CircularProgressIndicator.adaptive()),
                            error: (_, __) => Center(
                                child: Text(L10n.of(context).commonError)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ])
    ]);
  }
}

// Tab content for data files details
class DataFilesDetailTab extends StatelessWidget {
  final String title;
  final IconData icon;
  final Future<List<File>> listFiles;
  final bool showDelete;
  final WidgetRef ref;

  const DataFilesDetailTab({
    super.key,
    required this.title,
    required this.icon,
    required this.listFiles,
    this.showDelete = false,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    String formatSize(int bytes) {
      if (bytes <= 0) return '0 B';

      const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
      var i = (log(bytes) / log(1024)).floor();
      return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
    }

    Widget fileSizeWidget(File file) {
      return FutureBuilder<int>(
        future: file.length(),
        builder: (context, snapshot) {
          return Text(formatSize(snapshot.data ?? 0));
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FutureBuilder<List<File>>(
            future: listFiles,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final files = snapshot.data!;
                files.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
                return ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return ListTile(
                      title: Text(file.path.split(Platform.pathSeparator).last),
                      subtitle: showDelete ? fileSizeWidget(file) : null,
                      trailing: showDelete
                          ? file.path.endsWith('SourceHanSerifSC-Regular.otf')
                              ? null
                              : DeleteConfirm(
                                  delete: () {
                                    snapshot.data!.remove(file);
                                    ref
                                        .read(storageInfoProvider.notifier)
                                        .deleteFile(file);
                                  },
                                  deleteIcon: const Icon(Icons.delete),
                                  confirmIcon: const Icon(Icons.check),
                                )
                          : fileSizeWidget(file),
                    );
                  },
                );
              }
              return const Center(child: CircularProgressIndicator.adaptive());
            },
          ),
        ),
      ],
    );
  }
}
