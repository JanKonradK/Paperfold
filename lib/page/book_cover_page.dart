import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/dao/shelf.dart';
import 'package:paperfold/enums/sync_direction.dart';
import 'package:paperfold/enums/sync_trigger.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/book_notes_page.dart';
import 'package:paperfold/page/journal/book_review_page.dart';
import 'package:paperfold/page/journal/dot_pages_page.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/providers/sync.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/share_file.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/bookshelf/book_status_control.dart';

/// The book, pulled off the shelf.
///
/// Tapping a spine used to open the reader. That was right while the shelf was
/// the only place a book existed, and wrong the moment the journal arrived:
/// everything a reader wants to do with a book that is not reading it - rate
/// it, mark it, tag it, write about it, review it, share it - had no home, and
/// what home it had was a bottom sheet and a second detail page that between
/// them said the same things twice.
///
/// This is one destination with the cover as its subject. The reader arrives
/// here by tapping the book, does whatever they came to do, and opens it from
/// the one filled button on the screen. A long press on the spine still goes
/// straight to the reader for anyone who only wanted to read.
class BookCoverPage extends ConsumerStatefulWidget {
  const BookCoverPage({
    super.key,
    required this.book,
    this.bookDao,
    this.shelfDao,
  });

  final Book book;

  /// Injected in tests so the screen can run against an in-memory database.
  /// Production passes nothing and gets the shared DAOs.
  final BookDao? bookDao;
  final ShelfDao? shelfDao;

  @override
  ConsumerState<BookCoverPage> createState() => _BookCoverPageState();
}

class _BookCoverPageState extends ConsumerState<BookCoverPage> {
  late Book _book = widget.book;

  BookDao get _books => widget.bookDao ?? bookDao;
  ShelfDao get _shelves => widget.shelfDao ?? shelfDao;
  bool _editing = false;
  bool? _favourite;

  late final TextEditingController _title =
      TextEditingController(text: _book.title);
  late final TextEditingController _author =
      TextEditingController(text: _book.author);

  @override
  void initState() {
    super.initState();
    _loadFavourite();
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  Future<void> _loadFavourite() async {
    final value = await _shelves.containsBook(
      shelfId: builtInFavouritesShelfId,
      bookId: _book.id,
    );
    if (mounted) setState(() => _favourite = value);
  }

  Future<void> _toggleFavourite() async {
    final current = _favourite;
    if (current == null) return;
    if (current) {
      await _shelves.removeBookFromShelf(
        shelfId: builtInFavouritesShelfId,
        bookId: _book.id,
      );
    } else {
      await _shelves.addBookToShelf(
        shelfId: builtInFavouritesShelfId,
        bookId: _book.id,
      );
    }
    if (!mounted) return;
    setState(() => _favourite = !current);
    ref.invalidate(shelfHomeProvider);
  }

  Future<void> _save() async {
    _book.title = _title.text.replaceAll('\n', ' ').trim();
    _book.author = _author.text.trim();
    await _books.updateBook(_book);
    if (!mounted) return;
    setState(() => _editing = false);
    unawaitedSync();
    ref.read(bookListProvider.notifier).refresh();
    ref.invalidate(shelfHomeProvider);
  }

  void unawaitedSync() {
    Sync().syncData(SyncDirection.upload, ref, trigger: SyncTrigger.manual);
  }

  /// Replaces the cover with a picture from the device.
  ///
  /// The new file is written under a fresh timestamped name rather than over
  /// the old one, because Flutter's image cache is keyed on the path and
  /// writing in place leaves the old cover on screen until the process
  /// restarts.
  Future<void> _replaceCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final picked = result?.files.single.path;
    if (picked == null) return;

    final old = File(_book.coverFullPath);
    if (await old.exists()) {
      await old.delete();
    }

    var stem = _book.coverPath
        .split('-')
        .sublist(0, _book.coverPath.split('-').length - 1)
        .join('');
    if (!stem.startsWith('cover/')) {
      stem = 'cover/$stem';
    }
    final newPath =
        '$stem-${DateTime.now().millisecondsSinceEpoch}.png'.trim();
    AnxLog.info('BookCoverPage: new cover path $newPath');
    await File(getBasePath(newPath)).writeAsBytes(await File(picked).readAsBytes());

    _book.coverPath = newPath;
    await _books.updateBook(_book);
    if (!mounted) return;
    setState(() {});
    unawaitedSync();
    ref.read(bookListProvider.notifier).refresh();
    ref.invalidate(shelfHomeProvider);
  }

  Future<void> _open() async {
    await pushToReadingPage(ref, context, _book);
    if (!mounted) return;
    final refreshed = await _books.selectBookById(_book.id);
    if (!mounted) return;
    setState(() => _book = refreshed);
    ref.invalidate(shelfHomeProvider);
  }

  void _push(Widget page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final percent = (_book.readingPercentage.clamp(0.0, 1.0)).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            tooltip: _editing ? l10n.bookDetailSave : l10n.bookDetailEdit,
            onPressed: () {
              if (_editing) {
                _save();
              } else {
                setState(() => _editing = true);
              }
            },
            icon: Icon(_editing ? Icons.check : Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Center(child: _cover(theme)),
            const SizedBox(height: 20),
            _titleAndAuthor(theme),
            const SizedBox(height: 16),
            _progress(theme, l10n, percent),
            const SizedBox(height: 24),
            BookStatusControl(
              book: _book,
              dao: widget.bookDao,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            _actions(l10n, theme),
          ],
        ),
      ),
      // The one filled thing on the page. Everything else here is a way of
      // thinking about the book; this is the way into it.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FilledButton.icon(
          onPressed: _open,
          icon: const Icon(Icons.menu_book_outlined),
          label: Text(l10n.coverOpenBook),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
        ),
      ),
    );
  }

  Widget _cover(ThemeData theme) {
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Hero(
        tag: 'book-cover-${_book.id}',
        child: BookCover(book: _book, width: 190, height: 280),
      ),
    );
    if (!_editing) {
      return DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: cover,
      );
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        cover,
        Padding(
          padding: const EdgeInsets.all(8),
          child: FilledButton.tonalIcon(
            onPressed: _replaceCover,
            icon: const Icon(Icons.image_outlined, size: 18),
            label: Text(L10n.of(context).bookDetailEdit),
          ),
        ),
      ],
    );
  }

  Widget _titleAndAuthor(ThemeData theme) {
    if (!_editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_book.title, style: theme.textTheme.headlineSmall),
          if (_book.author.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _book.author,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }
    return Column(
      children: [
        TextField(
          controller: _title,
          style: theme.textTheme.headlineSmall,
          maxLines: null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _author,
          style: theme.textTheme.bodyMedium,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }

  Widget _progress(ThemeData theme, L10n l10n, double percent) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          percent <= 0
              ? l10n.coverNeverOpened
              : l10n.coverProgress((percent * 100).round()),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _actions(L10n l10n, ThemeData theme) {
    final favourite = _favourite ?? false;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ActionChip(
          icon: favourite ? Icons.favorite : Icons.favorite_border,
          label: l10n.coverFavourite,
          selected: favourite,
          onTap: _favourite == null ? null : _toggleFavourite,
        ),
        _ActionChip(
          icon: Icons.sticky_note_2_outlined,
          label: l10n.coverNotes,
          onTap: () => _push(
            BookNotesPage(book: _book, numberOfNotes: 0, isMobile: true),
          ),
        ),
        _ActionChip(
          icon: Icons.menu_book_outlined,
          label: l10n.coverJournal,
          onTap: () => _push(DotPagesPage(book: _book)),
        ),
        _ActionChip(
          icon: Icons.rate_review_outlined,
          label: l10n.coverReview,
          onTap: () => _push(BookReviewPage(book: _book)),
        ),
        _ActionChip(
          icon: Icons.translate,
          // The translation target is one setting for the whole application,
          // not a property of this book, so the chip says so rather than
          // letting the reader believe they are changing it here alone.
          label: l10n.translateToLanguage(Prefs().translateTo.nativeName),
          helper: l10n.coverLanguageAppliesEverywhere,
          onTap: null,
        ),
        _ActionChip(
          icon: Icons.ios_share,
          label: l10n.coverShare,
          onTap: () => shareFile(
            title: '${_book.title}.${_book.filePath.split('.').last}',
            filePath: _book.fileFullPath,
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.helper,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: helper ?? label,
      child: ActionChip(
        avatar: Icon(
          icon,
          size: 18,
          color: selected ? scheme.onSecondaryContainer : scheme.onSurface,
        ),
        label: Text(label),
        onPressed: onTap,
        backgroundColor: selected ? scheme.secondaryContainer : null,
        // A 48 dp target, as every target on this page is.
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }
}
