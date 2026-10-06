import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/book_review.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/page/book_detail.dart';
import 'package:paperfold/page/book_notes_page.dart';
import 'package:paperfold/page/journal/book_review_page.dart';
import 'package:paperfold/page/journal/dot_pages_page.dart';
import 'package:paperfold/providers/book_notes.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/service/journal/export_journal.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/common/load_failure.dart';

/// One place to return to a book, its passages, and the reader's own writing.
/// Uses the shared app theme and editors; opening it never creates a row.
class BookJournalPage extends ConsumerStatefulWidget {
  const BookJournalPage({super.key, required this.book, this.dao});

  final Book book;
  final JournalDao? dao;

  @override
  ConsumerState<BookJournalPage> createState() => _BookJournalPageState();
}

class _BookJournalPageState extends ConsumerState<BookJournalPage> {
  late Future<(BookReview?, List<JournalPage>)> _writing;
  bool _opening = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _writing = _load();
  }

  Future<(BookReview?, List<JournalPage>)> _load() async {
    final dao = widget.dao ?? journalDao;
    final review = await dao.findReview(widget.book.id);
    final pages = await dao.listPages(widget.book.id);
    return (review, pages.where((page) => !page.isEmpty).toList());
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) {
      setState(() {
        _writing = _load();
      });
    }
  }

  Future<void> _read() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await pushToReadingPage(ref, context, widget.book);
    } catch (error, stackTrace) {
      AnxLog.warning('Could not open the journal book', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).commonFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _export() async {
    if (_exporting) return;
    final l10n = L10n.of(context);
    setState(() => _exporting = true);
    try {
      final (review, pages) = await _load();
      if (!mounted) return;
      if ((review == null || review.isEmpty) && pages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.journalExportEmpty)),
        );
        return;
      }
      final path = await exportJournal(widget.book, review, pages, l10n);
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.journalExportSaved)),
        );
      }
    } catch (error, stackTrace) {
      AnxLog.warning('Could not export the journal', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.journalExportFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final book = widget.book;
    final readPercentage = book.readingPercentage.isFinite
        ? (book.readingPercentage.clamp(0, 1) * 100).round()
        : 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navJournal),
        actions: [
          IconButton(
            tooltip: l10n.journalExport,
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: l10n.journalExport,
                    ),
                  )
                : const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final stacked = constraints.maxWidth /
                          MediaQuery.textScalerOf(context).scale(1) <
                      320;
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: theme.textTheme.headlineSmall),
                      if (book.author.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(book.author, style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 12),
                      Text(l10n.notesReadPercentage('$readPercentage%')),
                    ],
                  );
                  return Flex(
                    direction: stacked ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        // This cover is decoration; its full title and author
                        // are repeated beside it with the reader's text scale.
                        child: MediaQuery.withNoTextScaling(
                          child: BookCover(book: book, width: 72, height: 108),
                        ),
                      ),
                      SizedBox(
                          width: stacked ? 0 : 20, height: stacked ? 16 : 0),
                      if (stacked) details else Expanded(child: details),
                    ],
                  );
                }),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _opening ? null : _read,
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(l10n.journalReadBook),
                    ),
                    TextButton.icon(
                      onPressed: () => _open(BookDetail(book: book)),
                      icon: const Icon(Icons.info_outline),
                      label: Text(l10n.notesPageDetail),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(l10n.journalBookOverview,
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                FutureBuilder<(BookReview?, List<JournalPage>)>(
                  future: _writing,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return LoadFailure.inline(
                        title: l10n.journalLoadFailed,
                        error: snapshot.error,
                        onRetry: () async {
                          setState(() {
                            _writing = _load();
                          });
                        },
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final (review, pages) = snapshot.data!;
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.rate_review_outlined),
                          title: Text(l10n.searchJournalReview),
                          subtitle: Text(
                              review == null || review.isEmpty
                                  ? l10n.journalReviewEmpty
                                  : review.thoughts.trim().isNotEmpty
                                      ? review.thoughts
                                      : l10n.journalReviewed,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(
                              BookReviewPage(book: book, dao: widget.dao)),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.edit_note_outlined),
                          title: Text(l10n.journalDotPages),
                          subtitle: Text(pages.isEmpty
                              ? l10n.journalPagesEmpty
                              : l10n.journalPagesCount(pages.length)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              _open(DotPagesPage(book: book, dao: widget.dao)),
                        ),
                      ],
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.format_quote_outlined),
                  title: Text(l10n.tileNotesTotalTitle),
                  subtitle: Text(l10n.journalHighlightsHint),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(BookNotesPage(
                    book: book,
                    numberOfNotes: ref
                            .read(bookNotesControllerProvider(book))
                            .valueOrNull
                            ?.allNotes
                            .length ??
                        0,
                    isMobile: true,
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
