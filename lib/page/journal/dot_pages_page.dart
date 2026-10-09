import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/providers/journal_home.dart';
import 'package:paperfold/page/reading_page.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/widgets/common/load_failure.dart';

/// Saved passages and free writing for one book, using the shared app theme.
class DotPagesPage extends ConsumerStatefulWidget {
  const DotPagesPage({
    super.key,
    required this.book,
    this.dao,
    this.initialPageId,
  });

  final Book book;
  final int? initialPageId;

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
  final _pageCenterKey = GlobalKey();

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

  Future<void> _openPassage(JournalPage page) async {
    final cfi = page.sourceCfi;
    if (cfi == null || cfi.trim().isEmpty || !await _saveAll() || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final reader = readingPageKey.currentState;
      if (reader != null) {
        if (reader.widget.book.id != widget.book.id) {
          throw StateError('Another book is already open');
        }
        // Reuse the reader that this journal was opened from.
        final player = epubPlayerKey.currentState;
        if (player == null) throw StateError('The reader is not ready');
        await player.previewPassage(cfi);
        if (!mounted) return;
        if (!identical(reader, readingPageKey.currentState) ||
            !reader.mounted) {
          throw StateError('The reader was closed');
        }
        reader.hideBottomBar();
        setState(() => _allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }
      await pushToReadingPage(ref, context, widget.book, cfi: cfi);
    } catch (error, stackTrace) {
      AnxLog.warning('Could not open journal passage', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).journalPassageOpenFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePage(JournalPage page) async {
    if (_busy || _allowPop || page.id == null) return;
    setState(() => _busy = true);
    try {
      final l10n = L10n.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.journalDeletePage),
          content: Text(l10n.journalDeletePageConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.commonDelete),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _dao.deletePage(page.id!);
      if (!mounted) return;
      setState(() => _pages = [
            for (final other in _pages)
              if (other.id != page.id) other,
          ]);
      ref.invalidate(journalHomeProvider);
    } catch (error, stackTrace) {
      _showSaveError(error, stackTrace);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _page(JournalPage page) {
    final controller = _controllers[page.id];
    if (controller == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Padding(
      key: ValueKey('journal-page-${page.id}'),
      padding: const EdgeInsets.only(bottom: 16),
      child: _JournalEntry(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (page.hasSource)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (page.sourceExcerpt?.isNotEmpty ?? false)
                      SelectableText(
                        page.sourceExcerpt!,
                        style: theme.textTheme.bodyLarge,
                      ),
                    if (page.sourceChapter?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          page.sourceChapter!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (page.sourceCfi?.trim().isNotEmpty ?? false)
                          TextButton.icon(
                            onPressed: _busy || _allowPop
                                ? null
                                : () => _openPassage(page),
                            icon: const Icon(Icons.menu_book_outlined),
                            label: Text(l10n.journalOpenPassage),
                          ),
                        TextButton.icon(
                          onPressed: _busy || _allowPop
                              ? null
                              : () => _deletePage(page),
                          icon: const Icon(Icons.delete_outline),
                          label: Text(l10n.journalDeletePage),
                        ),
                      ],
                    ),
                    const Divider(),
                  ],
                ),
              ),
            TextField(
              controller: controller,
              readOnly: _busy || _allowPop,
              maxLines: null,
              minLines: page.hasSource ? 4 : 8,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: page.hasSource
                    ? l10n.journalThoughtsHint
                    : l10n.journalPageHint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final requestedIndex =
        _pages.indexWhere((page) => page.id == widget.initialPageId);
    final firstIndex = requestedIndex < 0 ? 0 : requestedIndex;

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
                    : CustomScrollView(
                        center: _pageCenterKey,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          if (firstIndex > 0)
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList.builder(
                                itemCount: firstIndex,
                                itemBuilder: (context, index) =>
                                    _page(_pages[firstIndex - index - 1]),
                              ),
                            ),
                          SliverPadding(
                            key: _pageCenterKey,
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 12,
                              bottom: 120 +
                                  MediaQuery.viewPaddingOf(context).bottom +
                                  MediaQuery.viewInsetsOf(context).bottom,
                            ),
                            sliver: SliverList.builder(
                              itemCount: _pages.length - firstIndex,
                              itemBuilder: (context, index) =>
                                  _page(_pages[firstIndex + index]),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

/// Keep prose to a readable width within the app's shared surface styling.
class _JournalEntry extends StatelessWidget {
  const _JournalEntry({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          margin: EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
