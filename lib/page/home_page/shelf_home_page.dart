/*
THESIS: The Library is one climbable 3D bookcase, not five scrolling strips or a cover grid.
OWN-WORLD: Warm paper and true-black grounds; solid bound books; quiet glass Material chrome for shelf controls.
STORY: The reader opens the app onto their own books, recognises one by its spine the way they would at home, and reaches into it.
FIRST VIEWPORT: The active shelf fills the tab. Its name, sort state, and honest filter chips sit above the furniture.
FORM: The five-level Bookcase specified for the Paperfold visual world.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md.
*/

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/dao/wishlist.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/wishlist_item.dart';
import 'package:paperfold/page/book_detail.dart';
import 'package:paperfold/page/journal/book_review_page.dart';
import 'package:paperfold/page/opds/opds_catalogs_page.dart';
import 'package:paperfold/page/search/search_page.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/service/book_binding_settings.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/platform_utils.dart';
import 'package:paperfold/widgets/book_model/book_model_builder.dart'
    as book_model;
import 'package:paperfold/widgets/book_model/book_model_scene.dart';
import 'package:paperfold/widgets/book_model/book_model_warm_up.dart';
import 'package:paperfold/widgets/bookshelf/book_bottom_sheet.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:paperfold/widgets/bookshelf/shelf_controls/shelf_book_actions.dart';
import 'package:paperfold/widgets/bookshelf/shelf_controls/shelf_controls.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';
import 'package:paperfold/widgets/bookshelf/sync_button.dart';
import 'package:paperfold/widgets/ornament.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';
import 'package:path/path.dart' as path;

enum _ShelfHomeAction { search, addBooks, addBookToBuy }

enum _AddBooksRoute { device, catalogs }

class ShelfHomeBookActions {
  const ShelfHomeBookActions({
    this.details,
    this.shelves,
    this.customise,
    this.notes,
  });

  final ValueChanged<Book>? details;
  final ValueChanged<Book>? shelves;
  final ValueChanged<Book>? customise;
  final ValueChanged<Book>? notes;
}

/// Lets the Library take the system back before the destination history does.
///
/// A reader holding a book off the shelf has somewhere to go back to that the
/// navigator knows nothing about: the row they took it from. Back used to walk
/// the tab history instead, so the one gesture everybody reaches for first
/// either changed tab or left the application, with the book still in the air.
///
/// The owner of the handle asks [canTakeBack] to decide whether to intercept,
/// and calls [takeBack] when it has.
class LibraryBackHandle extends ChangeNotifier {
  bool _canTakeBack = false;
  bool Function()? _handler;

  /// True while the Library has something of its own to undo.
  bool get canTakeBack => _canTakeBack;

  /// Returns true when the Library dealt with the back itself.
  bool takeBack() => _handler?.call() ?? false;

  void _bind(bool Function() handler) => _handler = handler;

  void _unbind(bool Function() handler) {
    if (identical(_handler, handler)) _handler = null;
  }

  void _setCanTakeBack(bool value) {
    if (_canTakeBack == value) return;
    _canTakeBack = value;
    notifyListeners();
  }
}

class ShelfHomePage extends ConsumerStatefulWidget {
  const ShelfHomePage({
    super.key,
    this.controller,
    this.backHandle,
    this.bookActions = const ShelfHomeBookActions(),
  });

  final ScrollController? controller;

  /// Where this page registers its claim on the back gesture.
  final LibraryBackHandle? backHandle;

  final ShelfHomeBookActions bookActions;

  @override
  ConsumerState<ShelfHomePage> createState() => _ShelfHomePageState();
}

class _ShelfHomePageState extends ConsumerState<ShelfHomePage>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<BookcaseState> _bookcaseKey = GlobalKey<BookcaseState>();
  int _shelfIndex = 0;
  bool _dragging = false;

  /// Whether the books on the first shelf have been drawn once already, out of
  /// sight, and whether a slice of that work is already booked for after this
  /// frame. See [BookModelWarmUp].
  bool _warmed = false;
  bool _warming = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.backHandle?._bind(_handleBack);
  }

  @override
  void didUpdateWidget(covariant ShelfHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backHandle != widget.backHandle) {
      oldWidget.backHandle?._unbind(_handleBack);
      widget.backHandle?._bind(_handleBack);
    }
  }

  @override
  void dispose() {
    widget.backHandle?._unbind(_handleBack);
    super.dispose();
  }

  /// What back means on the Library.
  ///
  /// Holding a book, it puts the book back on the shelf. Part way into opening
  /// one, it is swallowed: the reader is already on its way and there is no
  /// half-open state to return to. On the shelf itself back is not ours, and
  /// the destination history gets it.
  bool _handleBack() {
    final stage = _bookcaseKey.currentState?.activeStage;
    switch (stage?.phase) {
      case ShelfPhase.held:
        stage!.putBack();
        return true;
      case ShelfPhase.opening:
        return true;
      case ShelfPhase.shelved:
      case null:
        return false;
    }
  }

  Future<File> _copyToTempFile({
    required String sourcePath,
    required String fileName,
  }) async {
    final tempDir = await getAnxTempDir();
    final targetPath = path.join(tempDir.path, fileName);
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    return File(sourcePath).copy(targetPath);
  }

  Future<void> _importBooks(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result == null || !context.mounted) {
      return;
    }

    AnxLog.info('importBook files: ${result.files}');
    final files = AnxPlatform.isAndroid
        ? result.files.map((file) => File(file.path!)).toList()
        : await Future.wait(
            result.files.map(
              (file) => _copyToTempFile(
                sourcePath: file.path!,
                fileName: file.name,
              ),
            ),
          );
    if (!context.mounted) {
      return;
    }
    importBookList(files, context, ref);
  }

  /// The two ways a book arrives: a file on the device, or a download from an
  /// OPDS catalog. Both hang off one "Add books" affordance, because the online
  /// route was buried in the More destination where nobody looking for a book
  /// would think to open it.
  Future<void> _openAddBooksSheet() async {
    final route = await showModalBottomSheet<_AddBooksRoute>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final l10n = L10n.of(context);
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(l10n.shelfAddBooksFromDevice),
                onTap: () => Navigator.pop(context, _AddBooksRoute.device),
              ),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.cloud_download_outlined),
                title: Text(l10n.opdsFindBooksOnline),
                onTap: () => Navigator.pop(context, _AddBooksRoute.catalogs),
              ),
            ],
          ),
        );
      },
    );
    if (route == null || !mounted) {
      return;
    }
    switch (route) {
      case _AddBooksRoute.device:
        await _importBooks(context);
      case _AddBooksRoute.catalogs:
        // The catalogs page carries its own scaffold, app bar and action
        // button, so it is pushed whole rather than wrapped in another one.
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (context) => const OpdsCatalogsPage(),
          ),
        );
        if (mounted) {
          await ref.read(shelfHomeProvider.notifier).refresh();
        }
    }
  }

  Future<void> _openBook(Book book) async {
    await pushToReadingPage(ref, context, book);
    if (mounted) {
      await ref.read(shelfHomeProvider.notifier).refresh();
    }
  }

  Future<void> _openShelf(_ShelfSection section) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ShelfCollectionPage(
          title: section.label,
          books: section.books,
          wishlistItems: section.wishlistItems,
        ),
      ),
    );
    if (mounted) {
      await ref.read(shelfHomeProvider.notifier).refresh();
    }
  }

  Future<void> _addWishlistBook() async {
    // The dialog owns its own fields. It used to hold them here and dispose
    // them in a `finally`, but `showDialog` returns the moment the route is
    // popped and the dialog goes on being built for the whole of its exit
    // animation. The fields were disposed out from under those frames, which
    // crashed the application on every dismissal that was not a tap on one of
    // the two buttons - the back gesture, for one.
    final entry = await showDialog<({String title, String author})>(
      context: context,
      builder: (context) => const _AddBookToBuyDialog(),
    );
    if (!mounted || entry == null) return;
    if (entry.title.trim().isEmpty) return;
    await wishlistDao.addBookToBuy(
      title: entry.title,
      author: entry.author,
    );
    await ref.read(shelfHomeProvider.notifier).refresh();
  }

  Future<void> _handleDrop(
    DropDoneDetails detail,
    BuildContext context,
  ) async {
    final files = await Future.wait(
      detail.files.map(
        (file) => _copyToTempFile(
          sourcePath: file.path,
          fileName: file.name,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    importBookList(files, context, ref);
    setState(() => _dragging = false);
  }

  List<_ShelfSection> _sections(BuildContext context, ShelfHomeData data) {
    final l10n = L10n.of(context);
    return [
      _ShelfSection(
        label: l10n.shelfReadingNow,
        books: data.readingNow,
      ),
      _ShelfSection(
        label: l10n.shelfAllTimeFavourites,
        books: data.favourites,
      ),
      _ShelfSection(
        label: l10n.shelfToBeRead,
        books: data.toBeRead,
      ),
      _ShelfSection(
        label: l10n.shelfFinished,
        books: data.finished,
      ),
      _ShelfSection(
        label: l10n.shelfBooksToBuy,
        wishlistItems: data.booksToBuy,
      ),
    ];
  }

  Future<void> _openDetails(Book book) async {
    final override = widget.bookActions.details;
    if (override != null) {
      override(book);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => BookDetail(book: book)),
    );
    if (mounted) await ref.read(shelfHomeProvider.notifier).refresh();
  }

  Future<void> _openShelves(Book book) async {
    final override = widget.bookActions.shelves;
    if (override != null) {
      override(book);
      return;
    }
    await showShelfBookShelvesSheet(
      context,
      book,
      onChanged: ref.read(shelfHomeProvider.notifier).refresh,
    );
  }

  Future<void> _openCustomise(Book book) async {
    final override = widget.bookActions.customise;
    if (override != null) {
      override(book);
      return;
    }
    await showShelfBookCustomiseSheet(
      context,
      book,
      onChanged: ref.read(shelfHomeProvider.notifier).refresh,
    );
  }

  Future<void> _openNotes(Book book) async {
    final override = widget.bookActions.notes;
    if (override != null) {
      override(book);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => BookReviewPage(book: book)),
    );
  }

  List<ShelfRow> _shelfRows(
    List<_ShelfSection> sections,
    ShelfHomeData data,
    ShelfHomeControls controls,
  ) {
    return [
      for (final section in sections)
        ShelfRow(
          name: section.label,
          books: [
            for (final book
                in controls.booksForShelf(section.books, data.bookTagIds))
              shelfBookFromBook(book),
            for (final item in controls.wishlistForShelf(section.wishlistItems))
              shelfBookFromWishlist(item),
          ],
        ),
    ];
  }

  /// Draws the books the reader is about to be shown, once, out of sight.
  ///
  /// The first frame a shelf paints is the frame that lays out a title and an
  /// author for every book on it, resolves every palette, and finds no artwork
  /// decoded — twenty books' worth of first-time work in the one frame the
  /// reader is watching arrive. Doing it beforehand at idle priority costs
  /// nothing anybody can see and leaves that frame with nothing but drawing to
  /// do. Once per run: the caches are static and outlive this page.
  void _warmUpShelves(List<ShelfRow> rows) {
    if (_warmed || _warming || rows.isEmpty) return;
    _warming = true;
    final scheme = Theme.of(context).colorScheme;
    final typography = book_model.BookModelTypography.of(context);
    final mirror = Directionality.of(context) == TextDirection.rtl;
    // The shelf the reader lands on, and no more. Warming the whole bookcase
    // would be most of a library, and every other shelf is a climb away — by
    // which time this has long finished.
    final books = rows[_shelfIndex.clamp(0, rows.length - 1)].books;
    final specs = [
      for (final book in books)
        () {
          final seed = BookSpine.stableHash(book.id);
          return book_model.BookModelSpec(
            binding: book.binding,
            title: book.title,
            author: book.author,
            blurb: book.blurb,
            palette: BookModelPalette.resolve(
              scheme: scheme,
              binding: book.binding,
              seed: seed,
            ),
            typography: typography,
            seed: seed,
            camera: ShelfStage.camera,
            showDropShadow: false,
            // What the row is actually drawn at. A book warmed at another
            // level of detail lays out its type at another size, which is
            // another cache key, which is no warming at all.
            detail: book_model.BookDetail.reduced,
          );
        }(),
    ];

    // After the frame, not during it: this is called from build, and the point
    // is to use the time between frames rather than any part of one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _warming = false;
      BookModelWarmUp.warmArt(
        [for (final book in books) book.coverPath ?? ''],
        mirror: mirror,
      );
      final more = BookModelWarmUp.slice(
        specs,
        keyOf: (spec) => '${spec.seed}|${spec.title}|${spec.author}',
      );
      // Nothing is scheduled to finish the rest. A shelf arriving rebuilds
      // several times over, and each of those asks again; if the screen goes
      // still before the row is warm, there is no longer anything to be warm
      // for. Requesting a frame to finish warming would be spending the very
      // thing this is trying to save.
      if (!more) _warmed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = L10n.of(context);
    final shelves = ref.watch(shelfHomeProvider);
    final controls = ref.watch(shelfHomeControlsProvider);

    ref.listen(bookListProvider, (previous, next) {
      final previousBooks = previous?.asData?.value;
      final nextBooks = next.asData?.value;
      if (nextBooks != null && !identical(previousBooks, nextBooks)) {
        Future.microtask(ref.read(shelfHomeProvider.notifier).refresh);
      }
    });

    // The shelf the reader is on, worked out before the bar is built, because
    // the bar is where its name goes now. "My shelves" told the reader nothing
    // they could not see, and it cost a whole second row of chrome to say which
    // shelf they were actually looking at.
    final data = shelves.asData?.value;
    final sections =
        data == null ? const <_ShelfSection>[] : _sections(context, data);
    final rows = data == null
        ? const <ShelfRow>[]
        : _shelfRows(sections, data, controls);
    final activeIndex =
        rows.isEmpty ? 0 : _shelfIndex.clamp(0, rows.length - 1);
    if (rows.isNotEmpty) _warmUpShelves(rows);

    final page = Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          rows.isEmpty ? l10n.shelfHomeTitle : rows[activeIndex].name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Always four actions, in one order. The sort and the filter are
        // disabled rather than absent until the shelves have loaded: an
        // actions list that changes length hands the sync button's State to a
        // different element as the bar rebuilds, and the Riverpod subscription
        // inside it throws on the second read. That is the same trap the key
        // below exists for, reached by a different road.
        actions: [
          IconButton(
            key: const ValueKey('shelf-sort-control'),
            tooltip: l10n.shelfSortControl,
            onPressed: data == null
                ? null
                : () => showShelfSortSheet(context, controls),
            icon: const Icon(Icons.sort_rounded),
          ),
          Badge.count(
            count: controls.filterCount,
            isLabelVisible: data != null && controls.hasFilters,
            child: IconButton(
              key: const ValueKey('shelf-filter-control'),
              tooltip: l10n.shelfFilterControl,
              onPressed: data == null
                  ? null
                  : () => showShelfFilterSheet(context, controls, data.tags),
              icon: const Icon(Icons.filter_alt_outlined),
            ),
          ),
          // Keyed so the framework matches this button by identity rather than
          // by its position among the actions. Matched positionally, it gets
          // its State handed to a different element as the bar rebuilds, and
          // the Riverpod subscription inside it throws on the second read.
          const SyncButton(key: ValueKey('shelf-sync-button')),
          PopupMenuButton<_ShelfHomeAction>(
            tooltip: l10n.more,
            onSelected: (action) {
              switch (action) {
                case _ShelfHomeAction.search:
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SearchPage(),
                    ),
                  );
                case _ShelfHomeAction.addBooks:
                  _openAddBooksSheet();
                case _ShelfHomeAction.addBookToBuy:
                  _addWishlistBook();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ShelfHomeAction.search,
                child: Row(
                  children: [
                    const Icon(Icons.search),
                    const SizedBox(width: 12),
                    Flexible(child: Text(l10n.searchBooksOrNotes)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _ShelfHomeAction.addBooks,
                child: Row(
                  children: [
                    const Icon(Icons.add),
                    const SizedBox(width: 12),
                    Flexible(child: Text(l10n.shelfAddBooksTooltip)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _ShelfHomeAction.addBookToBuy,
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined),
                    const SizedBox(width: 12),
                    Flexible(child: Text(l10n.addBookToBuyTitle)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: shelves.when(
          data: (data) {
            final booksById = <String, Book>{
              for (final section in sections)
                for (final book in section.books) 'book-${book.id}': book,
            };
            return Column(
              children: [
                ShelfFilterChips(controls: controls, tags: data.tags),
                Expanded(
                  child: Bookcase(
                    key: _bookcaseKey,
                    shelves: rows,
                    initialShelf: activeIndex,
                    onHoldingChanged: (holding) =>
                        widget.backHandle?._setCanTakeBack(holding),
                    onShelfChanged: (index) {
                      if (_shelfIndex != index) {
                        setState(() => _shelfIndex = index);
                      }
                    },
                    onOpen: (shelfBook) async {
                      final book = booksById[shelfBook.id];
                      if (book != null) {
                        await _openBook(book);
                      } else {
                        await _openShelf(sections.last);
                      }
                      _bookcaseKey.currentState?.activeStage?.reset();
                    },
                    optionsBuilder: (context, shelfBook) {
                      final book = booksById[shelfBook.id];
                      if (book == null) return const SizedBox.shrink();
                      return ShelfBookOptionBar(
                        onDetails: () => _openDetails(book),
                        onShelves: () => _openShelves(book),
                        onCustomise: () => _openCustomise(book),
                        onNotes: () => _openNotes(book),
                      );
                    },
                    emptyBuilder: (context, shelf) {
                      final index = rows.indexWhere(
                        (candidate) => candidate.name == shelf.name,
                      );
                      final sourceCount = index < 0 ? 0 : sections[index].count;
                      final filteredEmpty =
                          controls.hasFilters && sourceCount > 0;
                      return _BookcaseEmptyState(
                        shelfName: shelf.name,
                        message: filteredEmpty
                            ? l10n.shelfNoFilterResults
                            : l10n.emptyShelf,
                        actionLabel: filteredEmpty
                            ? l10n.shelfClearFilters
                            : index == 0
                                ? l10n.shelfAddBooksTooltip
                                : index == 4
                                    ? l10n.addBookToBuyAction
                                    : null,
                        actionIcon: filteredEmpty
                            ? Icons.filter_alt_off_outlined
                            : Icons.add_rounded,
                        onAction: filteredEmpty
                            ? controls.clearFilters
                            : index == 0
                                ? _openAddBooksSheet
                                : index == 4
                                    ? _addWishlistBook
                                    : null,
                      );
                    },
                    pickUpHint: l10n.shelfPickUpHint,
                    openHint: l10n.shelfOpenHint,
                  ),
                ),
              ],
            );
          },
          loading: () => const _ShelfLoadingView(),
          error: (error, stackTrace) => _ShelfLoadError(
            onRetry: ref.read(shelfHomeProvider.notifier).refresh,
          ),
        ),
      ),
    );

    return DropTarget(
      onDragDone: (detail) => _handleDrop(detail, context),
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      child: Stack(
        children: [
          page,
          if (_dragging)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.92),
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.bookshelfDragging,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Names a book the reader means to buy.
///
/// A widget with state rather than two controllers held by the caller, because
/// only a [State] is told when the route has really gone. Its `dispose` runs
/// after the exit animation, which is the earliest moment the fields are not
/// still being painted.
class _AddBookToBuyDialog extends StatefulWidget {
  const _AddBookToBuyDialog();

  @override
  State<_AddBookToBuyDialog> createState() => _AddBookToBuyDialogState();
}

class _AddBookToBuyDialogState extends State<_AddBookToBuyDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _author = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(
        context,
        (title: _title.text, author: _author.text),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.addBookToBuyTitle),
      // Scrolling, because the keyboard takes the bottom half of the screen
      // and a landscape phone has not got two text fields' worth of height
      // left over. Fixed, this column overflowed its own dialog.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.bookshelfTitle),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _author,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(labelText: l10n.bookshelfAuthor),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.addBookToBuyAction),
        ),
      ],
    );
  }
}

class _ShelfSection {
  const _ShelfSection({
    required this.label,
    this.books = const [],
    this.wishlistItems = const [],
  });

  final String label;
  final List<Book> books;
  final List<WishlistItem> wishlistItems;

  int get count => books.length + wishlistItems.length;
}

double normaliseShelfProgress(double storedProgress) =>
    storedProgress.clamp(0.0, 1.0).toDouble();

ShelfBook shelfBookFromBook(Book book) => ShelfBook(
      id: 'book-${book.id}',
      title: book.title,
      author: book.author,
      binding: book.binding(),
      blurb: book.description,
      coverPath: book.coverFullPath,
      progress: normaliseShelfProgress(book.readingPercentage),
      finished: book.status == BookStatus.finished,
    );

ShelfBook shelfBookFromWishlist(WishlistItem item) => ShelfBook(
      id: 'wishlist-${item.id}',
      title: item.title,
      author: item.author,
      binding: BookBinding.hardback,
      progress: 0,
    );

class _BookcaseEmptyState extends StatelessWidget {
  const _BookcaseEmptyState({
    required this.shelfName,
    required this.message,
    this.actionIcon = Icons.add_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String shelfName;
  final String message;
  final IconData actionIcon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: shelfName,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Ornament(
                  ornament: PaperfoldOrnament.circularWreath,
                  width: 58,
                  height: 58,
                  tint: scheme.outlineVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  key: const ValueKey('shelf-empty-action'),
                  onPressed: onAction,
                  icon: Icon(actionIcon),
                  label: Text(actionLabel!),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The shelf the books stand on.
///
/// The bookcase used to be the loudest object on the screen: a walnut carcass
/// with uprights, a grained back panel and a thick board, filling every bay
/// with brown. It buried the books it was meant to hold, and it made the whole
/// application read as antique when only the books were supposed to.
///
/// What is left is a single sheet of glass. It is almost nothing: a lit front
/// edge, a faint body, and the shadow the books drop onto it. The page ground
/// shows through, the books supply every colour on the screen, and the
/// furniture stops competing with them.
///
/// Solid colour and linear gradients only, no blur or image, and
/// [shouldRepaint] is false unless the palette changes.
class _GlassShelfPainter extends CustomPainter {
  _GlassShelfPainter({
    required this.sheen,
    required this.edge,
    required this.shadow,
  });

  final Color sheen;
  final Color edge;
  final Color shadow;

  /// The height the glass occupies at the foot of a shelf stage. The stage
  /// pads its books by the same amount, so the books stand on the plate rather
  /// than floating above it or sinking through it.
  static const double plateInset = 14;
  static const double _plateThickness = 9;
  static const double _contactHeight = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final plateTop = size.height - plateInset;
    if (plateTop <= 0) return;

    // The books darken the glass where they touch it. This band is what makes
    // them stand on the shelf rather than in front of it.
    final contact = Rect.fromLTWH(
      0,
      math.max(0, plateTop - _contactHeight),
      size.width,
      math.min(_contactHeight, plateTop),
    );
    canvas.drawRect(
      contact,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            shadow.withValues(alpha: 0),
            shadow.withValues(alpha: 0.34),
          ],
        ).createShader(contact),
    );

    // The plate itself: bright where the light catches its top face, fading
    // through the thickness of the glass.
    final plate = Rect.fromLTWH(0, plateTop, size.width, _plateThickness);
    canvas.drawRect(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            sheen.withValues(alpha: 0.16),
            sheen.withValues(alpha: 0.04),
          ],
        ).createShader(plate),
    );

    // Two hairlines carry the whole illusion: the lit top face, and the ground
    // edge underneath it.
    canvas.drawLine(
      Offset(0, plateTop),
      Offset(size.width, plateTop),
      Paint()
        ..color = sheen.withValues(alpha: 0.58)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(0, plateTop + _plateThickness),
      Offset(size.width, plateTop + _plateThickness),
      Paint()
        ..color = edge.withValues(alpha: 0.42)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassShelfPainter oldDelegate) {
    return sheen != oldDelegate.sheen ||
        edge != oldDelegate.edge ||
        shadow != oldDelegate.shadow;
  }
}

class _ShelfLoadingView extends StatelessWidget {
  const _ShelfLoadingView();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final labels = [
      l10n.shelfReadingNow,
      l10n.shelfAllTimeFavourites,
      l10n.shelfToBeRead,
      l10n.shelfFinished,
      l10n.shelfBooksToBuy,
    ];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glass = PaperfoldGlassStyle.fromScheme(scheme);

    return Semantics(
      liveRegion: true,
      label: l10n.shelvesLoading,
      child: ListView.builder(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 32),
        itemCount: labels.length,
        itemBuilder: (context, index) => ExcludeSemantics(
          child: CustomPaint(
            painter: _GlassShelfPainter(
              sheen: scheme.onSurface,
              edge: scheme.outlineVariant,
              shadow: scheme.shadow,
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                16,
                index == 0 ? 12 : 16,
                16,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PaperfoldGlassSurface(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    blurSigma: 10,
                    child: SizedBox(
                      height: 48,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            labels[index],
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: glass.foreground),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: BookSpine.shelfStageHeight(
                          MediaQuery.textScalerOf(context),
                        ) +
                        6,
                    child: Center(
                      child: Ornament(
                        ornament: PaperfoldOrnament.circularWreath,
                        width: 50,
                        height: 50,
                        tint: scheme.outlineVariant,
                      ),
                    ),
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

class _ShelfLoadError extends StatelessWidget {
  const _ShelfLoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Ornament(
                ornament: PaperfoldOrnament.circularWreath,
                width: 104,
                height: 104,
                tint: scheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.shelfLoadErrorTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.shelfLoadErrorBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShelfCollectionPage extends ConsumerStatefulWidget {
  const ShelfCollectionPage({
    super.key,
    required this.title,
    this.books = const [],
    this.wishlistItems = const [],
  });

  final String title;
  final List<Book> books;
  final List<WishlistItem> wishlistItems;

  @override
  ConsumerState<ShelfCollectionPage> createState() =>
      _ShelfCollectionPageState();
}

/// The columns the log can show. Title is always present, so it is not here.
enum _LogColumn { author, rating, status, dates }

class _ShelfCollectionPageState extends ConsumerState<ShelfCollectionPage> {
  // The owner's words: the log is "an alternate view of the book library where
  // its just the titles author rating and other information that the user can
  // toggle on and off". Same data, two ways of looking at it.
  bool _showLog = false;
  final Set<_LogColumn> _columns = {_LogColumn.author, _LogColumn.rating};

  Future<void> _openBookOptions(Book book) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => BookBottomSheet(book: book),
    );
    if (mounted) {
      await ref.read(shelfHomeProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.books.isEmpty && widget.wishlistItems.isEmpty;
    final l10n = L10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: _showLog ? l10n.shelfViewCovers : l10n.shelfViewLog,
            icon: Icon(
                _showLog ? Icons.grid_view_outlined : Icons.view_list_outlined),
            onPressed: () => setState(() => _showLog = !_showLog),
          ),
          if (_showLog)
            PopupMenuButton<_LogColumn>(
              tooltip: l10n.shelfLogColumns,
              icon: const Icon(Icons.tune),
              // Closing on each tap would make choosing several columns a chore,
              // so the menu stays open and each row toggles in place.
              itemBuilder: (context) => [
                for (final column in _LogColumn.values)
                  CheckedPopupMenuItem(
                    value: column,
                    checked: _columns.contains(column),
                    child: Text(switch (column) {
                      _LogColumn.author => l10n.shelfLogAuthor,
                      _LogColumn.rating => l10n.shelfLogRating,
                      _LogColumn.status => l10n.shelfLogStatus,
                      _LogColumn.dates => l10n.shelfLogDates,
                    }),
                  ),
              ],
              onSelected: (column) => setState(() {
                if (!_columns.remove(column)) {
                  _columns.add(column);
                }
              }),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: isEmpty
            ? _CollectionEmptyState(label: L10n.of(context).emptyShelf)
            : _showLog
                ? _ShelfLogView(
                    books: widget.books,
                    wishlistItems: widget.wishlistItems,
                    columns: _columns,
                    onOpenBook: (book) => pushToReadingPage(ref, context, book),
                    onOpenOptions: _openBookOptions,
                  )
                : GridView.builder(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 32),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 190,
                      mainAxisExtent: 310,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 16,
                    ),
                    itemCount:
                        widget.books.length + widget.wishlistItems.length,
                    itemBuilder: (context, index) {
                      if (index < widget.books.length) {
                        final book = widget.books[index];
                        return _ShelfCoverTile(
                          book: book,
                          onOpenOptions: () => _openBookOptions(book),
                          onOpenBook: () => pushToReadingPage(
                            ref,
                            context,
                            book,
                          ),
                        );
                      }
                      final item =
                          widget.wishlistItems[index - widget.books.length];
                      return _WishlistCoverTile(item: item);
                    },
                  ),
      ),
    );
  }
}

/// The same books as the cover grid, read as a table instead. Title always
/// shows; everything else is a column the reader turns on.
class _ShelfLogView extends StatelessWidget {
  const _ShelfLogView({
    required this.books,
    required this.wishlistItems,
    required this.columns,
    required this.onOpenBook,
    required this.onOpenOptions,
  });

  final List<Book> books;
  final List<WishlistItem> wishlistItems;
  final Set<_LogColumn> columns;
  final void Function(Book) onOpenBook;
  final void Function(Book) onOpenOptions;

  String _statusLabel(BookStatus status, L10n l10n) => switch (status) {
        BookStatus.reading => l10n.shelfReadingNow,
        BookStatus.finished => l10n.shelfFinished,
        BookStatus.notStarted => l10n.shelfToBeRead,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final dateFormat = MaterialLocalizations.of(context);

    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 32),
      itemCount: books.length + wishlistItems.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
      itemBuilder: (context, index) {
        if (index >= books.length) {
          final item = wishlistItems[index - books.length];
          return ListTile(
            minTileHeight: 56,
            title: Text(item.title),
            subtitle: columns.contains(_LogColumn.author) &&
                    item.author.trim().isNotEmpty
                ? Text(item.author)
                : null,
          );
        }

        final book = books[index];
        final details = <String>[
          if (columns.contains(_LogColumn.author) &&
              book.author.trim().isNotEmpty)
            book.author,
          if (columns.contains(_LogColumn.status))
            _statusLabel(book.status, l10n),
          if (columns.contains(_LogColumn.dates) && book.finishedOn != null)
            dateFormat.formatShortDate(book.finishedOn!)
          else if (columns.contains(_LogColumn.dates) && book.startedOn != null)
            dateFormat.formatShortDate(book.startedOn!),
        ];

        return ListTile(
          minTileHeight: 56,
          title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: details.isEmpty ? null : Text(details.join(' · ')),
          trailing: columns.contains(_LogColumn.rating) && book.rating > 0
              ? _LogRating(rating: book.rating)
              : null,
          onTap: () => onOpenBook(book),
          onLongPress: () => onOpenOptions(book),
        );
      },
    );
  }
}

/// A rating read as a number with one star, not five glyphs. Five icons in a
/// dense table is noise, and a screen reader would announce it five times.
class _LogRating extends StatelessWidget {
  const _LogRating({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${rating.toStringAsFixed(1)} / 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _ShelfCoverTile extends StatelessWidget {
  const _ShelfCoverTile({
    required this.book,
    required this.onOpenBook,
    required this.onOpenOptions,
  });

  final Book book;
  final VoidCallback onOpenBook;
  final VoidCallback onOpenOptions;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Semantics(
      button: true,
      label: l10n.bookCoverSemanticLabel(book.title),
      onTap: onOpenBook,
      onLongPress: onOpenOptions,
      onLongPressHint: l10n.bookOptionsSemanticHint,
      child: ExcludeSemantics(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: InkWell(
            onTap: onOpenBook,
            onLongPress: onOpenOptions,
            onSecondaryTap: onOpenOptions,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: BookCover(book: book, radius: 10)),
                  const SizedBox(height: 10),
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (book.author.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WishlistCoverTile extends StatelessWidget {
  const _WishlistCoverTile({required this.item});

  final WishlistItem item;

  @override
  Widget build(BuildContext context) {
    final visual = BookSpine.resolveVisual(
      'wishlist-${item.id}',
      Theme.of(context).colorScheme,
    );
    final l10n = L10n.of(context);
    final semantics = item.author.trim().isEmpty
        ? l10n.wishlistSpineSemanticLabelNoAuthor(item.title)
        : l10n.wishlistSpineSemanticLabel(item.author, item.title);

    return Semantics(
      label: semantics,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Ornament(
                        ornament: PaperfoldOrnament.rectangularVineFrame,
                        tint: visual.foreground.withValues(alpha: 0.7),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Text(
                          item.title,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: visual.foreground,
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (item.author.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CollectionEmptyState extends StatelessWidget {
  const _CollectionEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ornament(
              ornament: PaperfoldOrnament.circularWreath,
              width: 112,
              height: 112,
              tint: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
