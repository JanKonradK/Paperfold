import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/book_note.dart';
import 'package:paperfold/page/journal/dot_pages_page.dart';
import 'package:paperfold/providers/journal_home.dart';
import 'package:paperfold/utils/log/common.dart';

class AddToJournalButton extends ConsumerStatefulWidget {
  const AddToJournalButton({
    super.key,
    required this.note,
    this.book,
    this.dao,
  });

  final BookNote note;
  final Book? book;
  final JournalDao? dao;

  @override
  ConsumerState<AddToJournalButton> createState() => _AddToJournalButtonState();
}

class _AddToJournalButtonState extends ConsumerState<AddToJournalButton> {
  bool _saving = false;

  Future<void> _add() async {
    if (_saving) return;
    setState(() => _saving = true);
    Book book;
    int pageId;
    try {
      book = widget.book ?? await bookDao.selectBookById(widget.note.bookId);
      if (book.isDeleted || book.id != widget.note.bookId) {
        throw StateError('The passage book is unavailable');
      }
      pageId = await (widget.dao ?? journalDao).addPageFromNote(widget.note);
    } catch (error, stackTrace) {
      AnxLog.warning('Could not add passage to journal', error, stackTrace);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).journalPassageSaveFailed)),
        );
      }
      return;
    }
    if (!mounted) return;
    ref.invalidate(journalHomeProvider);
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => DotPagesPage(
        book: book,
        dao: widget.dao,
        initialPageId: pageId,
      ),
    ));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _saving ? null : _add,
      icon: _saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.post_add_outlined),
      label: Text(L10n.of(context).journalAddPassage),
    );
  }
}
