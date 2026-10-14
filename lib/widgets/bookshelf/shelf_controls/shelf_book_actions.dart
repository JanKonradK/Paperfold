import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/dao/shelf.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:path/path.dart' as path;

class ShelfBookOptionBar extends StatelessWidget {
  const ShelfBookOptionBar({
    super.key,
    required this.onDetails,
    required this.onShelves,
    required this.onCustomise,
    required this.onNotes,
  });

  final VoidCallback onDetails;
  final VoidCallback onShelves;
  final VoidCallback onCustomise;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final actions = [
      ('notes', Icons.edit_note_rounded, l10n.navJournal, onNotes),
      (
        'details',
        Icons.info_outline_rounded,
        l10n.shelfBookOptionDetails,
        onDetails,
      ),
      (
        'shelves',
        Icons.library_books_outlined,
        l10n.shelfBookOptionShelves,
        onShelves,
      ),
      (
        'customise',
        Icons.palette_outlined,
        l10n.shelfBookOptionCustomise,
        onCustomise,
      ),
    ];
    return Semantics(
      container: true,
      label: l10n.shelfBookOptions,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          final largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;
          final columns = available < 280 || largeText ? 1 : 2;
          final width = (available - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (name, icon, label, onPressed) in actions)
                SizedBox(
                  width: width,
                  child: OutlinedButton.icon(
                    key: ValueKey('shelf-book-$name'),
                    onPressed: onPressed,
                    icon: Icon(icon, size: 22),
                    label: Text(label),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      alignment: AlignmentDirectional.centerStart,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> showShelfBookShelvesSheet(
  BuildContext context,
  Book book, {
  required Future<void> Function() onChanged,
}) async {
  var favourite = await shelfDao.containsBook(
    shelfId: builtInFavouritesShelfId,
    bookId: book.id,
  );
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final l10n = L10n.of(context);
        return SingleChildScrollView(
          padding: const EdgeInsetsDirectional.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                child: Text(
                  l10n.shelfBookShelvesTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final status in BookStatus.values)
                ListTile(
                  minTileHeight: 56,
                  leading: Icon(_statusIcon(status)),
                  title: Text(_statusLabel(status, l10n)),
                  trailing: book.status == status
                      ? const Icon(Icons.check_rounded)
                      : null,
                  selected: book.status == status,
                  onTap: () async {
                    if (book.status == status) return;
                    book.status = status;
                    book.updateTime = DateTime.now();
                    await bookDao.updateBook(book);
                    if (!context.mounted) return;
                    setSheetState(() {});
                    await onChanged();
                  },
                ),
              SwitchListTile(
                value: favourite,
                secondary: const Icon(Icons.favorite_outline_rounded),
                title: Text(l10n.shelfAllTimeFavourites),
                onChanged: (selected) async {
                  if (selected) {
                    await shelfDao.addBookToShelf(
                      shelfId: builtInFavouritesShelfId,
                      bookId: book.id,
                    );
                  } else {
                    await shelfDao.removeBookFromShelf(
                      shelfId: builtInFavouritesShelfId,
                      bookId: book.id,
                    );
                  }
                  if (!context.mounted) return;
                  setSheetState(() => favourite = selected);
                  await onChanged();
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> showShelfBookCustomiseSheet(
  BuildContext context,
  Book book, {
  required Future<void> Function() onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => AnimatedBuilder(
      animation: Prefs(),
      builder: (context, child) {
        final l10n = L10n.of(context);
        final choice = Prefs().bookBindingChoice(book.id);
        return SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.shelfBookCustomiseTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.bookBindingSectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<BookBindingChoice>(
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(0, 48)),
                ),
                segments: [
                  ButtonSegment(
                    value: BookBindingChoice.automatic,
                    label: Text(l10n.bookBindingAutomatic),
                  ),
                  ButtonSegment(
                    value: BookBindingChoice.hardback,
                    label: Text(l10n.bookBindingHardback),
                  ),
                  ButtonSegment(
                    value: BookBindingChoice.softback,
                    label: Text(l10n.bookBindingSoftback),
                  ),
                ],
                selected: {choice},
                showSelectedIcon: false,
                onSelectionChanged: (selection) async {
                  Prefs().setBookBindingChoice(book.id, selection.first);
                  await onChanged();
                },
              ),
              const SizedBox(height: 20),
              Text(
                l10n.shelfBookCoverArt,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _chooseCover(book, onChanged),
                icon: const Icon(Icons.image_outlined),
                label: Text(l10n.shelfBookChooseCoverArt),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _chooseCover(Book book, Future<void> Function() onChanged) async {
  final result = await FilePicker.pickFile(type: FileType.image);
  final sourcePath = result?.path;
  if (sourcePath == null) return;

  final extension = path.extension(sourcePath).toLowerCase();
  final relativePath =
      'cover/paperfold-${book.id}-${DateTime.now().millisecondsSinceEpoch}$extension';
  await File(sourcePath).copy(getBasePath(relativePath));
  book
    ..coverPath = relativePath
    ..updateTime = DateTime.now();
  await bookDao.updateBook(book);
  await onChanged();
}

IconData _statusIcon(BookStatus status) => switch (status) {
  BookStatus.reading => Icons.auto_stories_outlined,
  BookStatus.finished => Icons.check_circle_outline_rounded,
  BookStatus.notStarted => Icons.bookmark_border_rounded,
};

String _statusLabel(BookStatus status, L10n l10n) => switch (status) {
  BookStatus.reading => l10n.shelfReadingNow,
  BookStatus.finished => l10n.shelfFinished,
  BookStatus.notStarted => l10n.shelfToBeRead,
};
