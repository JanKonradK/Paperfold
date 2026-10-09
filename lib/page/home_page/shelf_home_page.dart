/*
THESIS: A personal library of flat, readable book spines on straight shelves.
OWN-WORLD: Burgundy bookcloth, warm ivory paper, aged gold and dove bindings.
STORY: Choose a shelf, take down a book, and return to reading.
FIRST VIEWPORT: A gold wordmark, visible shelf choices, and a front-on shelf.
FORM: The user's supplied burgundy cover and paper references govern this redesign.
*/

import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/dao/wishlist.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/wishlist_item.dart';
import 'package:paperfold/page/book_detail.dart';
import 'package:paperfold/page/journal/book_journal_page.dart';
import 'package:paperfold/page/opds/opds_catalogs_page.dart';
import 'package:paperfold/page/search/search_page.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/service/book_binding_settings.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/platform_utils.dart';
import 'package:paperfold/widgets/bookshelf/book_bottom_sheet.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:paperfold/widgets/bookshelf/continue_reading_banner.dart';
import 'package:paperfold/widgets/bookshelf/shelf_controls/shelf_book_actions.dart';
import 'package:paperfold/widgets/bookshelf/shelf_controls/shelf_controls.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';
import 'package:paperfold/widgets/bookshelf/sync_button.dart';
import 'package:paperfold/widgets/ornament.dart';
import 'package:paperfold/widgets/paperfold_wordmark.dart';
import 'package:paperfold/widgets/paperfold_library_theme.dart';
import 'package:path/path.dart' as path;

enum _ShelfHomeAction { search, addBooks, addBookToBuy }

enum _AddBooksRoute { device, catalogs }

class ShelfHomeBookActions {
  const ShelfHomeBookActions({
    this.open,
    this.details,
    this.shelves,
    this.customise,
    this.notes,
  });

  final ValueChanged<Book>? open;
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
  bool _holding = false;
  bool _openingBook = false;

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
    final tempDir = await (await getAnxTempDir()).createTemp('import-');
    final targetPath = path.join(tempDir.path, path.basename(fileName));
    return File(sourcePath).copy(targetPath);
  }

  Future<void> _importBooks(BuildContext context) async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result.isEmpty || !context.mounted) {
      return;
    }

    AnxLog.info('importBook files: $result');
    final files = AnxPlatform.isAndroid
        ? result.map((file) => File(file.path!)).toList()
        : await Future.wait(
            result.map(
              (file) =>
                  _copyToTempFile(sourcePath: file.path!, fileName: file.name),
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
          MaterialPageRoute(builder: (context) => const OpdsCatalogsPage()),
        );
        if (mounted) {
          await ref.read(shelfHomeProvider.notifier).refresh();
        }
    }
  }

  Future<void> _openBook(Book book) async {
    if (_openingBook) return;
    final override = widget.bookActions.open;
    if (override != null) {
      override(book);
      return;
    }
    setState(() => _openingBook = true);
    try {
      await pushToReadingPage(ref, context, book);
      if (mounted) {
        await ref.read(shelfHomeProvider.notifier).refresh();
      }
    } finally {
      if (mounted) setState(() => _openingBook = false);
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
    await wishlistDao.addBookToBuy(title: entry.title, author: entry.author);
    if (!mounted) return;
    await ref.read(shelfHomeProvider.notifier).refresh();
  }

  Future<void> _handleDrop(DropDoneDetails detail, BuildContext context) async {
    final files = await Future.wait(
      detail.files.map(
        (file) => _copyToTempFile(sourcePath: file.path, fileName: file.name),
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
      _ShelfSection(label: l10n.shelfReadingNow, books: data.readingNow),
      _ShelfSection(label: l10n.shelfAllTimeFavourites, books: data.favourites),
      _ShelfSection(label: l10n.shelfToBeRead, books: data.toBeRead),
      _ShelfSection(label: l10n.shelfFinished, books: data.finished),
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
      MaterialPageRoute(builder: (context) => BookJournalPage(book: book)),
    );
    if (mounted) await ref.read(shelfHomeProvider.notifier).refresh();
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
            for (final book in controls.booksForShelf(
              section.books,
              data.bookTagIds,
            ))
              shelfBookFromBook(book),
            for (final item in controls.wishlistForShelf(section.wishlistItems))
              shelfBookFromWishlist(item),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Theme(
      data: paperfoldLibraryTheme(Theme.of(context)),
      child: ListenableBuilder(
        listenable: Prefs(),
        builder: (context, _) =>
            Consumer(builder: (context, ref, _) => _buildLibrary(context, ref)),
      ),
    );
  }

  Widget _buildLibrary(BuildContext context, WidgetRef ref) {
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
    final sections = data == null
        ? const <_ShelfSection>[]
        : _sections(context, data);
    final rows = data == null
        ? const <ShelfRow>[]
        : _shelfRows(sections, data, controls);
    final activeIndex = rows.isEmpty
        ? 0
        : _shelfIndex.clamp(0, rows.length - 1);

    final page = Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: 72,
        title: const PaperfoldWordmark(),
        // Stable actions keep the sync subscription attached during loading.
        actions: [
          IconButton(
            tooltip: l10n.searchLibraryHint,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => const SearchPage())),
            icon: const Icon(Icons.search_rounded),
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
                    MaterialPageRoute(builder: (context) => const SearchPage()),
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
                    Flexible(child: Text(l10n.searchLibraryHint)),
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
      floatingActionButton: _holding
          ? null
          : FloatingActionButton(
              tooltip: l10n.shelfAddBooksTooltip,
              onPressed: _openAddBooksSheet,
              child: const Icon(Icons.add_rounded),
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
            final resumeBook = continueReadingBook(data.readingNow);
            return LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(16) >= 24;
                return Column(
                  children: [
                    if (!_holding)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.5,
                        ),
                        child: SingleChildScrollView(
                          key: const ValueKey('shelf-header-scroll'),
                          primary: false,
                          child: Column(
                            children: [
                              if (resumeBook != null && !_holding)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    8,
                                  ),
                                  child: ContinueReadingBanner(
                                    key: const ValueKey(
                                      'library-continue-reading',
                                    ),
                                    book: resumeBook,
                                    compact:
                                        largeText ||
                                        constraints.maxHeight < 480,
                                    onOpen: _openingBook
                                        ? null
                                        : () => _openBook(resumeBook),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                  24,
                                  8,
                                  12,
                                  4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rows.isEmpty
                                            ? l10n.shelfHomeTitle
                                            : rows[activeIndex].name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: largeText
                                            ? Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                            : Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall,
                                      ),
                                    ),
                                    PopupMenuButton<bool>(
                                      key: const ValueKey('shelf-view-control'),
                                      tooltip: l10n.shelfBookView,
                                      enabled: !_holding,
                                      initialValue: Prefs().shelfCoverView,
                                      icon: Icon(
                                        Prefs().shelfCoverView
                                            ? Icons.grid_view_rounded
                                            : Icons.view_week_outlined,
                                      ),
                                      onSelected: (value) =>
                                          Prefs().shelfCoverView = value,
                                      itemBuilder: (context) => [
                                        CheckedPopupMenuItem(
                                          value: false,
                                          checked: !Prefs().shelfCoverView,
                                          child: Text(l10n.shelfViewSpines),
                                        ),
                                        CheckedPopupMenuItem(
                                          value: true,
                                          checked: Prefs().shelfCoverView,
                                          child: Text(l10n.shelfViewCoverGrid),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      key: const ValueKey('shelf-sort-control'),
                                      tooltip: l10n.shelfSortControl,
                                      onPressed: () =>
                                          showShelfSortSheet(context, controls),
                                      icon: const Icon(Icons.sort_rounded),
                                    ),
                                    Badge.count(
                                      count: controls.filterCount,
                                      isLabelVisible: controls.hasFilters,
                                      child: IconButton(
                                        key: const ValueKey(
                                          'shelf-filter-control',
                                        ),
                                        tooltip: l10n.shelfFilterControl,
                                        onPressed: () => showShelfFilterSheet(
                                          context,
                                          controls,
                                          data.tags,
                                        ),
                                        icon: const Icon(
                                          Icons.filter_alt_outlined,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height:
                                    38 +
                                    MediaQuery.textScalerOf(context).scale(14),
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: rows.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) => ChoiceChip(
                                    key: ValueKey('shelf-tab-$index'),
                                    label: Text(rows[index].name),
                                    selected: index == activeIndex,
                                    showCheckmark: false,
                                    onSelected: _holding
                                        ? null
                                        : (_) => _bookcaseKey.currentState
                                              ?.climbTo(index),
                                  ),
                                ),
                              ),
                              ShelfFilterChips(
                                controls: controls,
                                tags: data.tags,
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      // Keep the PageView subtree in place when its header hides.
                      key: const ValueKey('shelf-bookcase-region'),
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: _holding
                              ? 0
                              : constraints.maxHeight < 400
                              ? 12
                              : 72,
                        ),
                        child: Bookcase(
                          key: _bookcaseKey,
                          showCovers: Prefs().shelfCoverView,
                          showSignposts: false,
                          shelves: rows,
                          initialShelf: activeIndex,
                          onHoldingChanged: (holding) {
                            setState(() => _holding = holding);
                            widget.backHandle?._setCanTakeBack(holding);
                          },
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
                            final sourceCount = index < 0
                                ? 0
                                : sections[index].count;
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
                    ),
                  ],
                );
              },
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
                color: Theme.of(context).colorScheme.surface
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

  void _submit() =>
      Navigator.pop(context, (title: _title.text, author: _author.text));

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
        FilledButton(onPressed: _submit, child: Text(l10n.addBookToBuyAction)),
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
  coverPath: book.coverPath.isEmpty ? null : book.coverFullPath,
  progress: normaliseShelfProgress(book.readingPercentage),
  finished: book.status == BookStatus.finished,
  series: book.series,
  volume: book.volume,
  pageCount: book.pageCount,
);

ShelfBook shelfBookFromWishlist(WishlistItem item) => ShelfBook(
  id: 'wishlist-${item.id}',
  title: item.title,
  author: item.author,
  binding: BookBinding.hardback,
  isWishlist: true,
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
        child: SingleChildScrollView(
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
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfLoadingView extends StatelessWidget {
  const _ShelfLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 160, child: LinearProgressIndicator()),
            const SizedBox(height: 24),
            Text(L10n.of(context).shelvesLoading),
          ],
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
              _showLog ? Icons.grid_view_outlined : Icons.view_list_outlined,
            ),
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
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 32),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisExtent: 310,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 16,
                ),
                itemCount: widget.books.length + widget.wishlistItems.length,
                itemBuilder: (context, index) {
                  if (index < widget.books.length) {
                    final book = widget.books[index];
                    return _ShelfCoverTile(
                      book: book,
                      onOpenOptions: () => _openBookOptions(book),
                      onOpenBook: () => pushToReadingPage(ref, context, book),
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
            subtitle:
                columns.contains(_LogColumn.author) &&
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
          Text(rating.toStringAsFixed(1), style: theme.textTheme.labelLarge),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: visual.foreground),
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
