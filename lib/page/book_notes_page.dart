import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/book_note.dart';
import 'package:paperfold/models/book_notes_state.dart';
import 'package:paperfold/page/book_detail.dart';
import 'package:paperfold/page/journal/book_journal_page.dart';
import 'package:paperfold/providers/book_notes.dart';
import 'package:paperfold/service/notes/export_notes.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/widgets/book_notes/book_notes_list.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/common/container/filled_container.dart';
import 'package:paperfold/widgets/common/load_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';

class BookNotesPage extends ConsumerStatefulWidget {
  const BookNotesPage({
    super.key,
    required this.book,
    required this.numberOfNotes,
    required this.isMobile,
  });

  final Book book;
  final int numberOfNotes;
  final bool isMobile;

  @override
  ConsumerState<BookNotesPage> createState() => _BookNotesPageState();
}

class _BookNotesPageState extends ConsumerState<BookNotesPage> {
  Widget _bookInfo(BuildContext context, int? numberOfNotes) {
    final book = widget.book;
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    return FilledContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: theme.textTheme.headlineSmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    if (numberOfNotes != null)
                      Text(
                        l10n.notesNotes(numberOfNotes),
                        style: theme.textTheme.titleMedium,
                      ),
                    Text(l10n.notesReadPercentage(
                      '${(book.readingPercentage.clamp(0, 1) * 100).round()}%',
                    )),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ExcludeSemantics(
                child: Hero(
                  tag: book.coverFullPath,
                  child: BookCover(book: book, height: 126, width: 84),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(l10n.navJournal),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BookJournalPage(book: book),
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.info_outline),
                label: Text(l10n.notesPageDetail),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BookDetail(book: book),
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.ios_share),
                label: Text(l10n.notesPageExport),
                onPressed: (numberOfNotes ?? 0) > 0
                    ? () => _handleExportNotes(context, book)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportNotes(BuildContext context, Book book,
      {List<BookNote>? notes}) async {
    bool mergeChapters = Prefs().notesExportMergeChapters;
    bool exporting = false;
    Object? exportError;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Consumer(
                builder: (context, ref, _) {
                  final asyncState =
                      ref.watch(bookNotesControllerProvider(book));
                  return asyncState.when(
                    data: (state) {
                      Future<void> export(ExportType type) async {
                        if (exporting) return;
                        final route = ModalRoute.of(context);
                        setModalState(() {
                          exporting = true;
                          exportError = null;
                        });
                        try {
                          final sorted = ref
                              .read(bookNotesControllerProvider(book).notifier)
                              .notesForExport(
                                  selectedOnly: false, custom: notes);
                          await exportNotes(
                            book,
                            sorted,
                            type,
                            mergeChapterHeadings: mergeChapters &&
                                state.exportSortMode.field ==
                                    NotesSortField.cfi,
                          );
                          if (context.mounted && route?.isCurrent == true) {
                            Navigator.of(context).pop();
                          }
                        } catch (error, stackTrace) {
                          AnxLog.warning(
                              'Could not export notes', error, stackTrace);
                          if (context.mounted) {
                            setModalState(() => exportError = error);
                          }
                        } finally {
                          if (context.mounted) {
                            setModalState(() => exporting = false);
                          }
                        }
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _exportSortControls(
                            context,
                            ref,
                            state,
                            enabled: !exporting,
                            mergeChapters: mergeChapters,
                            onMergeChanged: (value) {
                              setModalState(() => mergeChapters = value);
                              Prefs().notesExportMergeChapters = value;
                            },
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: exporting
                                    ? null
                                    : () => export(ExportType.copy),
                                icon: const Icon(Icons.copy),
                                label: Text(L10n.of(context).notesExportCopy),
                              ),
                              OutlinedButton.icon(
                                onPressed: exporting
                                    ? null
                                    : () => export(ExportType.md),
                                icon: const Icon(IonIcons.logo_markdown),
                                label: const Text('Markdown'),
                              ),
                              OutlinedButton.icon(
                                onPressed: exporting
                                    ? null
                                    : () => export(ExportType.txt),
                                icon: const Icon(Icons.text_snippet),
                                label:
                                    Text(L10n.of(context).notesExportPlainText),
                              ),
                              OutlinedButton.icon(
                                onPressed: exporting
                                    ? null
                                    : () => export(ExportType.csv),
                                icon: const Icon(Icons.table_chart),
                                label: const Text('CSV'),
                              ),
                            ],
                          ),
                          if (exporting) ...[
                            const SizedBox(height: 20),
                            const LinearProgressIndicator(),
                          ],
                          if (exportError != null)
                            LoadFailure.inline(
                              title: L10n.of(context).notesExportFailed,
                              error: exportError,
                            ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) => LoadFailure.inline(
                      title: L10n.of(context).notesLoadFailed,
                      error: error,
                      onRetry: () => ref
                          .read(bookNotesControllerProvider(book).notifier)
                          .refresh(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _exportSortControls(
    BuildContext context,
    WidgetRef ref,
    BookNotesState state, {
    required bool enabled,
    required bool mergeChapters,
    required ValueChanged<bool> onMergeChanged,
  }) {
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.notesPageExport,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final field in NotesSortField.values)
              _exportSortButton(
                label: field == NotesSortField.createdTime
                    ? l10n.notesPageSortTime
                    : l10n.notesPageSortChapter,
                field: field,
                current: state.exportSortMode,
                onPressed: enabled
                    ? () {
                        final controller = ref.read(
                            bookNotesControllerProvider(widget.book).notifier);
                        if (state.exportSortMode.field == field) {
                          controller.toggleExportSortDirection();
                        } else {
                          controller.setExportSortField(field);
                        }
                      }
                    : null,
              ),
          ],
        ),
        if (state.exportSortMode.field == NotesSortField.cfi)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notesExportMergeChapters),
            subtitle: Text(l10n.notesExportMergeChaptersDescription),
            value: mergeChapters,
            onChanged: enabled ? onMergeChanged : null,
          ),
      ],
    );
  }

  Widget _exportSortButton({
    required String label,
    required NotesSortField field,
    required NotesSortMode current,
    required VoidCallback? onPressed,
  }) {
    if (current.field != field) {
      return OutlinedButton(onPressed: onPressed, child: Text(label));
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(current.direction == SortDirection.asc
          ? Icons.arrow_upward
          : Icons.arrow_downward),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(bookNotesControllerProvider(widget.book));
    return Scaffold(
      appBar: widget.isMobile ? AppBar(title: Text(widget.book.title)) : null,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _bookInfo(context, notes.valueOrNull?.totalNotes),
                const SizedBox(height: 24),
                BookNotesList(
                  book: widget.book,
                  reading: false,
                  exportNotes: _handleExportNotes,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
