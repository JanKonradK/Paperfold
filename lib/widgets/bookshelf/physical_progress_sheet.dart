import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/utils/log/common.dart';

/// Records [page] as the place a reader reached in a paper [book].
///
/// The page sets the progress and moves the status forward: a first page
/// starts the book, and the last page finishes it. A page below the last one
/// returns a finished book to reading. [totalPages] replaces the saved total
/// when the reader enters one.
void applyPhysicalProgress(
  Book book,
  int page, {
  int? totalPages,
  DateTime? now,
}) {
  final total = totalPages ?? book.totalPages;
  final today = now ?? DateTime.now();
  final current = page.clamp(0, total ?? page);
  book
    ..totalPages = total
    ..currentPage = current
    ..readingPercentage = total == null ? 0 : current / total;
  if (total != null && current >= total) {
    book
      ..status = BookStatus.finished
      ..startedOn ??= today
      ..finishedOn ??= today;
  } else if (current > 0) {
    if (book.status != BookStatus.reading) {
      book.finishedOn = null;
    }
    book
      ..status = BookStatus.reading
      ..startedOn ??= today;
  }
}

bool validPhysicalProgress(int page, int? total) =>
    page >= 0 && (total == null || (total > 0 && page <= total));

/// Asks for the current page of a paper book and saves it.
///
/// Returns true when the progress was saved.
Future<bool> showPhysicalProgressSheet(BuildContext context, Book book) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _PhysicalProgressSheet(book: book),
  );
  return saved ?? false;
}

class _PhysicalProgressSheet extends StatefulWidget {
  const _PhysicalProgressSheet({required this.book});

  final Book book;

  @override
  State<_PhysicalProgressSheet> createState() => _PhysicalProgressSheetState();
}

class _PhysicalProgressSheetState extends State<_PhysicalProgressSheet> {
  late final _page = TextEditingController(
    text: widget.book.currentPage > 0 ? '${widget.book.currentPage}' : '',
  );
  late final _total = TextEditingController();
  bool _invalid = false;
  bool _busy = false;

  bool get _needsTotal => widget.book.totalPages == null;

  @override
  void dispose() {
    _page.dispose();
    _total.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = L10n.of(context);
    final page = int.tryParse(_page.text.trim());
    final totalText = _total.text.trim();
    final total = totalText.isEmpty ? null : int.tryParse(totalText);
    final knownTotal = total ?? widget.book.totalPages;
    if (page == null ||
        !validPhysicalProgress(page, knownTotal) ||
        (totalText.isNotEmpty && (total == null || total < 1)) ||
        (knownTotal != null && page > knownTotal)) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _busy = true);
    final book = widget.book;
    final before = Book.fromDb({...book.toMap(), 'id': book.id});
    applyPhysicalProgress(book, page, totalPages: total);
    try {
      await bookDao.updateBook(book);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      AnxLog.warning('Paper book progress not saved: $e');
      book
        ..totalPages = before.totalPages
        ..currentPage = before.currentPage
        ..readingPercentage = before.readingPercentage
        ..status = before.status
        ..startedOn = before.startedOn
        ..finishedOn = before.finishedOn;
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(l10n.commonFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final total = widget.book.totalPages;
    final digitsOnly = [FilteringTextInputFormatter.digitsOnly];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.physicalBookLogProgress, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            widget.book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('physical-progress-page'),
            controller: _page,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: digitsOnly,
            textInputAction: _needsTotal
                ? TextInputAction.next
                : TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.physicalBookCurrentPage,
              suffixText: total == null
                  ? null
                  : l10n.physicalBookOfPages(total),
              errorText: _invalid ? l10n.physicalBookPagesInvalid : null,
            ),
            onChanged: (_) => setState(() => _invalid = false),
            onSubmitted: _needsTotal ? null : (_) => _save(),
          ),
          if (_needsTotal) ...[
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('physical-progress-total'),
              controller: _total,
              keyboardType: TextInputType.number,
              inputFormatters: digitsOnly,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.physicalBookTotalPages,
                helperText: l10n.physicalBookTotalPagesHint,
              ),
              onChanged: (_) => setState(() => _invalid = false),
              onSubmitted: (_) => _save(),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}
