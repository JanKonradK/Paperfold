import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/markdown/styled_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paperfold/utils/log/common.dart';

/// Changelog screen for showing app updates
/// Displays version history and new features
class ChangelogScreen extends StatefulWidget {
  final String lastVersion;
  final String currentVersion;
  final VoidCallback onComplete;

  const ChangelogScreen({
    super.key,
    required this.lastVersion,
    required this.currentVersion,
    required this.onComplete,
  });

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  String _changelogContent = '';
  bool _isLoading = true;

  String get currentVersion => widget.currentVersion.split('+').first;
  String get lastVersion => widget.lastVersion.split('+').first;

  @override
  void initState() {
    super.initState();
    _loadChangelog();
  }

  Future<void> _loadChangelog() async {
    try {
      // Load changelog from assets
      final String fullChangelog =
          await rootBundle.loadString('assets/CHANGELOG.md');
      _changelogContent = _extractVersionChangelog(fullChangelog);
    } catch (e) {
      AnxLog.warning('Failed to load changelog from assets: $e');
      _changelogContent = _getDefaultChangelog();
    } finally {
      _changelogContent = processChangelogContent(_changelogContent);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Tidies one version's section for display.
  ///
  /// It used to do two more things, both of them inherited from the upstream
  /// project's own changelog and both wrong for this one.
  ///
  /// It kept only lines beginning with a bullet and threw the rest away, so an
  /// entry long enough to wrap lost every line after its first and was shown
  /// cut off in the middle of a sentence. And it took the first half of the
  /// list for English and the second half for Chinese, because upstream wrote
  /// each entry twice, one language after the other. Paperfold's changelog is
  /// written once, so halving it simply hid half the release.
  String processChangelogContent(String content) {
    final out = <String>[];
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final isBullet = line.startsWith('- ') || line.startsWith('* ');
      if (isBullet || out.isEmpty) {
        out.add(line);
      } else {
        // A continuation of the line above, folded back onto it.
        out[out.length - 1] = '${out.last} $line';
      }
    }
    return out.join('\n');
  }

  String _extractVersionChangelog(String fullChangelog) {
    // Extract version number from currentVersion (e.g., "1.2.3+1234" -> "1.2.3")
    final versionMatch = RegExp(r'^(\d+\.\d+\.\d+)').firstMatch(currentVersion);
    if (versionMatch == null) {
      return _getDefaultChangelog();
    }

    final version = versionMatch.group(1)!;
    final versionHeader = '## $version';

    // Find the version section in the changelog
    final lines = fullChangelog.split('\n');
    final startIndex = lines.indexWhere((line) => line.trim() == versionHeader);

    if (startIndex == -1) {
      AnxLog.warning('Version $version not found in changelog');
      return _getDefaultChangelog();
    }

    // Find the end of this version section (next version header or end of file)
    int endIndex = lines.length;
    for (int i = startIndex + 1; i < lines.length; i++) {
      if (lines[i].trim().startsWith('## ') &&
          lines[i].trim() != versionHeader) {
        endIndex = i;
        break;
      }
    }

    // Extract the content for this version (skip the header line)
    final versionContent =
        lines.sublist(startIndex + 1, endIndex).join('\n').trim();

    if (versionContent.isEmpty) {
      return _getDefaultChangelog();
    }

    return versionContent;
  }

  String _getDefaultChangelog() {
    return '''
- Fixed some bugs
- 修复已知问题
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).whatsNew),
        elevation: 0,
        actions: [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.update,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            L10n.of(context).updateFromVersion(lastVersion),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        L10n.of(context).welcomeToVersion(currentVersion),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: StyledMarkdown(data: _changelogContent),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: _onComplete,
                    child: Text(L10n.of(context).commonOk),
                  ),
                ),
              ],
            ),
    );
  }

  void _onComplete() async {
    widget.onComplete();
  }
}
