import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/enums/sync_direction.dart';
import 'package:paperfold/enums/sync_trigger.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/sync.dart';
import 'package:paperfold/service/cover_image.dart';
import 'package:paperfold/service/open_library.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:path/path.dart' as path;

/// Cover, title, author, and description in one form, with Open Library to
/// fill them in. Nothing is written until Save, so Back can discard.
///
/// A [Book.physical] with id -1 is a new paper book: Save adds it to the
/// library. A paper book also has a page count.
class BookEditPage extends ConsumerStatefulWidget {
  const BookEditPage({super.key, required this.book, this.initialCover});

  final Book book;

  /// A cover image to start with, such as a photo shared from another app.
  final File? initialCover;

  @override
  ConsumerState<BookEditPage> createState() => _BookEditPageState();
}

class _BookEditPageState extends ConsumerState<BookEditPage> {
  late final _title = TextEditingController(text: widget.book.title);
  late final _author = TextEditingController(text: widget.book.author);
  late final _description = TextEditingController(
    text: widget.book.description ?? '',
  );
  late final _totalPages = TextEditingController(
    text: widget.book.totalPages?.toString() ?? '',
  );

  /// A new cover, copied into the library on Save.
  late File? _cover = widget.initialCover;
  bool _busy = false;
  bool _titleMissing = false;
  bool _pagesInvalid = false;

  bool get _isNew => widget.book.id == -1;

  bool get _dirty =>
      _cover != null ||
      _title.text != widget.book.title ||
      _author.text != widget.book.author ||
      _description.text != (widget.book.description ?? '') ||
      _totalPages.text != (widget.book.totalPages?.toString() ?? '');

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _description.dispose();
    _totalPages.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickCover({bool camera = false}) async {
    try {
      final picked = camera ? await takeCoverPhoto() : await chooseCoverFile();
      if (picked != null && mounted) setState(() => _cover = picked);
    } catch (e) {
      AnxLog.warning('Cover could not be picked: $e');
      if (mounted) _showMessage(L10n.of(context).coverImageInvalid);
    }
  }

  Future<void> _findOnline() async {
    final l10n = L10n.of(context);
    final match = await showModalBottomSheet<OpenLibraryMatch>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) =>
          _OpenLibrarySheet(query: '${_title.text} ${_author.text}'.trim()),
    );
    if (match == null || !mounted) return;
    setState(() {
      _title.text = match.title;
      _titleMissing = false;
      if (match.author.isNotEmpty) _author.text = match.author;
      _busy = true;
    });
    try {
      final description = await openLibraryDescription(match.key);
      if (description != null) _description.text = description;
      final coverId = match.coverId;
      if (coverId != null) {
        final dir = await (await getAnxTempDir()).createTemp('cover-');
        final file = File(path.join(dir.path, 'cover.jpg'));
        await downloadOpenLibraryCover(coverId, file.path);
        _cover = file;
      }
    } catch (e) {
      AnxLog.warning('Open Library details failed: $e');
      _showMessage(l10n.bookEditLookupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final l10n = L10n.of(context);
    final title = _title.text.trim();
    final pagesText = _totalPages.text.trim();
    final totalPages = pagesText.isEmpty ? null : int.tryParse(pagesText);
    final pagesInvalid =
        pagesText.isNotEmpty && (totalPages == null || totalPages < 1);
    if (title.isEmpty || pagesInvalid) {
      setState(() {
        _titleMissing = title.isEmpty;
        _pagesInvalid = pagesInvalid;
      });
      return;
    }
    setState(() => _busy = true);
    final book = widget.book;
    final previous = (
      title: book.title,
      author: book.author,
      description: book.description,
      coverPath: book.coverPath,
      totalPages: book.totalPages,
      currentPage: book.currentPage,
      readingPercentage: book.readingPercentage,
    );
    try {
      final cover = _cover;
      if (cover != null) {
        try {
          book.coverPath = await saveCoverImage(
            cover,
            'paperfold-${_isNew ? 'paper' : book.id}-'
            '${DateTime.now().millisecondsSinceEpoch}',
          );
        } on CoverImageException catch (e) {
          AnxLog.warning('Cover refused: $e');
          _showMessage(l10n.coverImageInvalid);
          return;
        }
      }
      final description = _description.text.trim();
      book
        ..title = title
        ..author = _author.text.trim()
        ..description = description.isEmpty ? null : description;
      if (book.isPhysical) {
        book.totalPages = totalPages;
        if (totalPages != null && book.currentPage > totalPages) {
          book.currentPage = totalPages;
        }
        book.readingPercentage =
            totalPages == null ? 0 : book.currentPage / totalPages;
      }
      if (_isNew) {
        book.id = await bookDao.insertBook(book);
      } else {
        await bookDao.updateBook(book);
      }
      if (cover != null && previous.coverPath.isNotEmpty) {
        final old = File(getBasePath(previous.coverPath));
        if (await old.exists()) await old.delete();
      }
      Sync().syncData(SyncDirection.upload, ref, trigger: SyncTrigger.manual);
      ref.read(bookListProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      AnxLog.warning('Book details could not be saved: $e');
      book
        ..title = previous.title
        ..author = previous.author
        ..description = previous.description
        ..coverPath = previous.coverPath
        ..totalPages = previous.totalPages
        ..currentPage = previous.currentPage
        ..readingPercentage = previous.readingPercentage;
      _showMessage(l10n.bookEditSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final l10n = L10n.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bookEditDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.bookEditDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final cover = _cover;
    return PopScope(
      // Save writes the fields before the database, so the page is briefly
      // clean while busy. Back waits for Save to finish.
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isNew ? l10n.physicalBookAddTitle : l10n.bookEditTitle,
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : _save,
              child: Text(l10n.commonSave),
            ),
          ],
          bottom: _busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(4),
                  child: LinearProgressIndicator(),
                )
              : null,
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 96,
                          height: 140,
                          child: cover != null
                              ? Image.file(cover, fit: BoxFit.cover)
                              : BookCover(book: widget.book),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _pickCover,
                              icon: const Icon(Icons.image_outlined),
                              label: Text(l10n.shelfBookChooseCoverArt),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                            ),
                            if (canTakeCoverPhoto) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                key: const ValueKey('book-edit-take-photo'),
                                onPressed: _busy
                                    ? null
                                    : () => _pickCover(camera: true),
                                icon: const Icon(Icons.photo_camera_outlined),
                                label: Text(l10n.coverTakePhoto),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _busy ? null : _findOnline,
                              icon: const Icon(Icons.travel_explore),
                              label: Text(l10n.bookEditFindOnline),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _title,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.bookshelfTitle,
                      errorText: _titleMissing
                          ? l10n.commonInputCannotBeEmpty
                          : null,
                    ),
                    onChanged: (_) => setState(() => _titleMissing = false),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _author,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.bookshelfAuthor,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (widget.book.isPhysical) ...[
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('book-edit-total-pages'),
                      controller: _totalPages,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.physicalBookTotalPages,
                        errorText: _pagesInvalid
                            ? l10n.physicalBookPagesInvalid
                            : null,
                      ),
                      onChanged: (_) => setState(() => _pagesInvalid = false),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _description,
                    minLines: 4,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l10n.bookEditDescription,
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenLibrarySheet extends StatefulWidget {
  const _OpenLibrarySheet({required this.query});

  final String query;

  @override
  State<_OpenLibrarySheet> createState() => _OpenLibrarySheetState();
}

class _OpenLibrarySheetState extends State<_OpenLibrarySheet> {
  late final _query = TextEditingController(text: widget.query);
  Future<List<OpenLibraryMatch>>? _results;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search() {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    setState(() => _results = searchOpenLibrary(query));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    Widget message(String text, {bool retry = false}) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (retry) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _search, child: Text(l10n.commonRetry)),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: l10n.bookEditSearchLabel,
                  prefixIcon: const Icon(Icons.search),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                l10n.bookEditSource,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<OpenLibraryMatch>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return _results == null
                        ? const SizedBox.shrink()
                        : const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return message(l10n.bookEditLookupFailed, retry: true);
                  }
                  final matches = snapshot.data ?? const [];
                  if (matches.isEmpty) {
                    return message(l10n.bookEditNoMatches);
                  }
                  return ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final match = matches[index];
                      final coverId = match.coverId;
                      return ListTile(
                        minTileHeight: 72,
                        leading: SizedBox(
                          width: 40,
                          height: 60,
                          child: coverId == null
                              ? const Icon(Icons.menu_book_outlined)
                              : Image.network(
                                  openLibraryCover(
                                    coverId,
                                    size: 'S',
                                  ).toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.menu_book_outlined),
                                ),
                        ),
                        title: Text(match.title),
                        subtitle: Text(
                          [
                            if (match.author.isNotEmpty) match.author,
                            if (match.year != null) '${match.year}',
                          ].join(' · '),
                        ),
                        onTap: () => Navigator.of(context).pop(match),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
