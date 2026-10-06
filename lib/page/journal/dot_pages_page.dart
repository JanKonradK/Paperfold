import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/providers/journal_home.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/widgets/common/load_failure.dart';

/// Free journal space for one book: blank dot pages the reader writes on.
///
/// plan.md Section 8 calls this the dot page, and Section 12 warns that text
/// input on a page surface is the hardest interaction in the project, because
/// the keyboard, the insets and the book metaphor all fight each other. The
/// resolution here is that the paper is a background, not a container the
/// keyboard has to be fitted inside.
class DotPagesPage extends ConsumerStatefulWidget {
  const DotPagesPage({super.key, required this.book, this.dao});

  final Book book;

  /// Injected in tests so the pages can run against an in-memory database.
  final JournalDao? dao;

  @override
  ConsumerState<DotPagesPage> createState() => _DotPagesPageState();
}

class _DotPagesPageState extends ConsumerState<DotPagesPage> {
  JournalDao get _dao => widget.dao ?? journalDao;
  List<JournalPage> _pages = const [];
  final Map<int, TextEditingController> _controllers = {};
  bool _loading = true;
  Object? _loadError;
  bool _busy = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final pages = await _dao.listPages(widget.book.id);
      if (!mounted) return;
      setState(() {
        _pages = pages;
        for (final page in pages) {
          final id = page.id;
          if (id != null) {
            // Adding a page must keep the drafts already in the editor.
            _controllers.putIfAbsent(
                id, () => TextEditingController(text: page.body));
          }
        }
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addPage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _dao.addPage(widget.book.id);
      if (mounted) await _load();
    } catch (error, stackTrace) {
      _showSaveError(error, stackTrace);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Writes every page whose text changed. A page emptied of text is deleted
  /// by the DAO, so leaving a blank page behind does not litter the journal.
  Future<bool> _saveAll() async {
    if (_busy) return false;
    // Capture text before any write yields; controllers belong to this route.
    final changed = [
      for (final page in _pages)
        if (_controllers[page.id] case final controller?)
          if (controller.text != page.body)
            page.copyWith(body: controller.text),
    ];
    setState(() => _busy = true);
    try {
      for (final page in changed) {
        final id = await _dao.savePage(page);
        if (!mounted) return false;
        // A retry must start with the writes that already succeeded, including
        // a page deletion, rather than trying to update a removed row.
        setState(() {
          _pages = [
            for (final original in _pages)
              if (original.id != page.id)
                original
              else if (id != null)
                page.copyWith(id: id),
          ];
        });
      }
      if (!mounted) return false;
      if (changed.isNotEmpty) ref.invalidate(journalHomeProvider);
      return true;
    } catch (error, stackTrace) {
      _showSaveError(error, stackTrace);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSaveError(Object error, StackTrace stackTrace) {
    AnxLog.warning('Could not save journal pages', error, stackTrace);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).journalSaveFailed)),
      );
    }
  }

  Future<void> _leave() async {
    if (!await _saveAll() || !mounted || _allowPop) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: _allowPop || (_pages.isEmpty && !_busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.journalDotPages)),
        floatingActionButton: FloatingActionButton(
          tooltip: l10n.journalAddPage,
          onPressed: _loading || _busy || _loadError != null ? null : _addPage,
          child: const Icon(Icons.add),
        ),
        body: _loadError != null
            ? LoadFailure.page(
                title: l10n.journalLoadFailed,
                error: _loadError,
                onRetry: _load,
              )
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : _pages.isEmpty
                    ? Center(
                        child: Text(
                          l10n.journalNoPages,
                          style: theme.textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 12,
                          // Room for the button, the gesture inset, and the
                          // keyboard when it is up.
                          bottom: 120 +
                              MediaQuery.viewPaddingOf(context).bottom +
                              MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          final page = _pages[index];
                          final controller = _controllers[page.id];
                          if (controller == null) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _DotPaper(
                              child: TextField(
                                controller: controller,
                                readOnly: _busy || _allowPop,
                                maxLines: null,
                                minLines: 8,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: theme.textTheme.bodyLarge,
                                decoration: InputDecoration(
                                  hintText: l10n.journalPageHint,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

/// A sheet of dot paper. The dots are drawn, not an image asset, so they take
/// the theme's ink colour and cost nothing to ship.
class _DotPaper extends StatelessWidget {
  const _DotPaper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isLight
            ? PaperfoldTokens.light.surfaceLow
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: CustomPaint(
        painter: _DotGridPainter(
          dot: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.22),
        ),
        child: child,
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.dot});

  final Color dot;

  static const double _spacing = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dot;
    for (var y = _spacing; y < size.height; y += _spacing) {
      for (var x = _spacing; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      dot != oldDelegate.dot;
}
