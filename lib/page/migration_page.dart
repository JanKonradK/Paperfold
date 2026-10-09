import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/utils/get_path/macos_migration.dart';
import 'package:material_ui/material_ui.dart';

class MigrationPage extends StatefulWidget {
  final Future<void> Function() onMigrationComplete;
  final MigrationCheckResult checkResult;

  const MigrationPage(
      {super.key,
      required this.onMigrationComplete,
      required this.checkResult});

  @override
  State<MigrationPage> createState() => _MigrationPageState();
}

class _MigrationPageState extends State<MigrationPage> {
  String _currentItem = '';
  int _progress = 0;
  int _total = 6;
  bool _isComplete = false;
  bool _hasFailed = false;

  @override
  void initState() {
    super.initState();
    _startMigration();
  }

  Future<void> _startMigration() async {
    setState(() {
      _hasFailed = false;
      _progress = 0;
    });
    try {
      final checkResult = widget.checkResult;

      if (!checkResult.needsMigration) {
        // No migration needed, proceed immediately
        await widget.onMigrationComplete();
        return;
      }

      final success = _isComplete ||
          await performMigration(
            oldPath: checkResult.oldPath!,
            newPath: checkResult.newPath!,
            onProgress: (currentItem, progress, total) {
              if (mounted) {
                setState(() {
                  _currentItem = currentItem;
                  _progress = progress;
                  _total = total;
                });
              }
            },
          );

      if (mounted) {
        if (success) {
          setState(() {
            _isComplete = true;
          });
          await widget.onMigrationComplete();
        } else {
          setState(() {
            _hasFailed = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isComplete && !_hasFailed
                    ? Icons.check_circle_outline
                    : _hasFailed
                        ? Icons.error_outline
                        : Icons.folder_copy_outlined,
                size: 64,
                color: _isComplete && !_hasFailed
                    ? Colors.green
                    : _hasFailed
                        ? Colors.red
                        : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _isComplete && !_hasFailed
                    ? l10n.migrationComplete
                    : _hasFailed
                        ? l10n.migrationFailed
                        : l10n.migrationInProgress,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (!_isComplete && !_hasFailed) ...[
                Text(
                  l10n.migrationDoNotClose,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                LinearProgressIndicator(
                  value: _total > 0 ? _progress / _total : null,
                ),
                const SizedBox(height: 16),
                Text(
                  _currentItem.isNotEmpty
                      ? '${l10n.migrationCurrentItem}: $_currentItem'
                      : l10n.migrationPreparing,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '$_progress / $_total',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (_hasFailed) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.storageMigrationFailed,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _startMigration,
                  child: Text(l10n.commonRetry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
