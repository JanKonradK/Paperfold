import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/dao/shelf.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';
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

  /// The clear air kept at each end of the row, so the plates do not run to
  /// the edge of the screen.
  static const double margin = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Semantics(
      container: true,
      label: l10n.shelfBookOptions,
      // Four plates, set apart from each other. They used to sit eight pixels
      // apart under a halo that breathed all the while the book was in the
      // air: four glowing discs in a huddle, which read as one decorated blob
      // rather than as four separate things a reader can choose between.
      //
      // Measured against the width they are actually given rather than set to
      // a constant. Four plates at their full width and their full gap come to
      // 330, which is ten pixels more than a 320-wide phone has, and a `Row`
      // that does not fit does not shrink — it paints a striped bar and tells
      // the reader their book has a rendering fault.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = (constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : _OptionButton.preferredWidth * 4 + _gap * 3 + margin * 2) -
              margin * 2;
          var gap = _gap;
          var width = (available - gap * 3) / 4;
          if (width < _OptionButton.minimumWidth) {
            // The air between the plates goes before the plates themselves do.
            // A narrower target is harder to hit than a tighter row is to read.
            gap = _tightGap;
            width = (available - gap * 3) / 4;
          }
          width = width.clamp(
            _OptionButton.minimumWidth,
            _OptionButton.preferredWidth,
          );

          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _OptionButton(
                key: const ValueKey('shelf-book-details'),
                icon: Icons.info_outline_rounded,
                label: l10n.shelfBookOptionDetails,
                width: width,
                onPressed: onDetails,
              ),
              SizedBox(width: gap),
              _OptionButton(
                key: const ValueKey('shelf-book-shelves'),
                icon: Icons.library_books_outlined,
                label: l10n.shelfBookOptionShelves,
                width: width,
                onPressed: onShelves,
              ),
              SizedBox(width: gap),
              _OptionButton(
                key: const ValueKey('shelf-book-customise'),
                icon: Icons.palette_outlined,
                label: l10n.shelfBookOptionCustomise,
                width: width,
                onPressed: onCustomise,
              ),
              SizedBox(width: gap),
              _OptionButton(
                key: const ValueKey('shelf-book-notes'),
                icon: Icons.menu_book_outlined,
                label: l10n.shelfBookOptionNotes,
                width: width,
                onPressed: onNotes,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One of the four things a reader can do with the book they are holding.
///
/// The same plate the shelf signposts are on, at the same height and the same
/// radius: a long, quiet piece of glass rather than a filled disc. There is one
/// kind of button laid over the shelf, and this is it. Nothing on this screen
/// has to attract attention — the reader has already picked the book up.
class _OptionButton extends StatelessWidget {
  const _OptionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.width,
    required this.onPressed,
  });

  /// The signpost's own corner, so a plate at the head of the stage and a plate
  /// at its foot are the same object.
  static const double radius = 24;

  /// A full tap target, and short enough to leave air inside the reserved strip
  /// at the head of the stage.
  static const double height = 48;

  /// What a plate is drawn at when there is room for it: half as wide again as
  /// it is tall, which is what makes it read as a bar rather than as a disc.
  static const double preferredWidth = 72;

  /// And what it will never go below, because a plate narrower than this is no
  /// longer a target a thumb can find.
  static const double minimumWidth = 48;

  final IconData icon;
  final String label;
  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: PaperfoldGlassSurface(
        borderRadius: const BorderRadius.all(Radius.circular(radius)),
        // No backdrop filter, for the reason the signposts carry none: this
        // plate sits over the row, and a blur is the one effect the compositor
        // cannot cache.
        allowBlur: false,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: Center(child: Icon(icon, size: 22)),
          ),
        ),
      ),
    );
  }
}

/// The clear air between two plates, and what it falls back to when the screen
/// is too narrow to pay for it.
const double _gap = 14;
const double _tightGap = 8;

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

Future<void> _chooseCover(
  Book book,
  Future<void> Function() onChanged,
) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
  );
  final sourcePath = result?.files.single.path;
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
