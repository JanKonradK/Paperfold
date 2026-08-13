import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/shelf_home.dart';

/// Marks a book as to-be-read, reading or finished.
///
/// Migration v8 added the `status`, `started_on` and `finished_on` columns and
/// `BookStatus` has existed since, but nothing in the application ever set
/// them: three of the five shelves sort on a value the reader had no way to
/// change. This is that way.
///
/// The two dates are kept by this control rather than by the reader, because
/// they are what the trackers count and a book can reach "finished" by being
/// marked as much as by being read to the end.
class BookStatusControl extends ConsumerStatefulWidget {
  const BookStatusControl({
    super.key,
    required this.book,
    this.onChanged,
    this.dao,
  });

  final Book book;
  final ValueChanged<BookStatus>? onChanged;

  /// Injected in tests so the control can run against an in-memory database.
  /// Production passes nothing and gets the shared DAO.
  final BookDao? dao;

  @override
  ConsumerState<BookStatusControl> createState() => _BookStatusControlState();
}

class _BookStatusControlState extends ConsumerState<BookStatusControl> {
  late BookStatus _status = widget.book.status;

  @override
  void didUpdateWidget(covariant BookStatusControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.status != widget.book.status) {
      _status = widget.book.status;
    }
  }

  Future<void> _select(BookStatus status) async {
    if (status == _status) return;
    final book = widget.book;
    book.status = status;
    // Marking a book carries its dates with it. Starting one that was never
    // started stamps the day; finishing one stamps the other end. Going back to
    // "to be read" clears both, because a book you have not started has no
    // dates and leaving stale ones behind would put it in the wrong year of the
    // reading challenge.
    final now = DateTime.now();
    switch (status) {
      case BookStatus.notStarted:
        book.startedOn = null;
        book.finishedOn = null;
      case BookStatus.reading:
        book.startedOn ??= now;
        book.finishedOn = null;
      case BookStatus.finished:
        book.startedOn ??= now;
        book.finishedOn ??= now;
    }
    await (widget.dao ?? bookDao).updateBook(book);
    if (!mounted) return;
    setState(() => _status = status);
    ref.read(bookListProvider.notifier).refresh();
    ref.invalidate(shelfHomeProvider);
    widget.onChanged?.call(status);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final labels = <BookStatus, String>{
      BookStatus.notStarted: l10n.coverStatusNotStarted,
      BookStatus.reading: l10n.coverStatusReading,
      BookStatus.finished: l10n.coverStatusFinished,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.coverMarkAs,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<BookStatus>(
          segments: [
            for (final status in BookStatus.values)
              ButtonSegment<BookStatus>(
                value: status,
                label: Text(
                  labels[status]!,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
          selected: {_status},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => _select(selection.first),
        ),
      ],
    );
  }
}
