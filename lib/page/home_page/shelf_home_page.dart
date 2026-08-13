/*
THESIS: A modern interface wrapped around an antique library. The chrome is thin, quiet and contemporary so the bookcase - its spines, its clutter, its plants - is the only ornate thing on screen. It refuses both the cover-grid home every reading app ships and the all-over cosy-vintage skin the subject invites.
OWN-WORLD: Warm paper ground, candlelight dark; the five-colour nature palette as SURFACES only; terracotta ink accent swapping to golden tan in dark; Philosopher italic for display, Source Sans 3 for labels; single-tint SVG ornaments; bookcloth saturation reserved for spines, covers and the bookcase itself.
STORY: The reader opens the app onto their own bookcase, recognises a book by its spine the way they would at home, and reaches into it.
FIRST VIEWPORT: One bookcase - side panels, top rail, a recessed back panel and shelf boards with real thickness - holding tall vertical spines, some leaning, with plants and bookends between them; Reading now at the top; a thin sliding tab bar below carrying Journal, Library, More.
FORM: Bookcase. Chosen by the owner from a running three-model prototype and then directed by their own feedback on hardware.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md.
*/

import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/dao/wishlist.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/wishlist_item.dart';
import 'package:paperfold/page/search/search_page.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/platform_utils.dart';
import 'package:paperfold/widgets/bookshelf/book_bottom_sheet.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/widgets/bookshelf/sync_button.dart';
import 'package:paperfold/widgets/ornament.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';
import 'package:path/path.dart' as path;

enum _ShelfHomeAction { search, addBooks, addBookToBuy }

class ShelfHomePage extends ConsumerStatefulWidget {
  const ShelfHomePage({super.key, this.controller});

  final ScrollController? controller;

  @override
  ConsumerState<ShelfHomePage> createState() => _ShelfHomePageState();
}

class _ShelfHomePageState extends ConsumerState<ShelfHomePage>
    with AutomaticKeepAliveClientMixin {
  late final ScrollController _scrollController =
      widget.controller ?? ScrollController();
  bool _dragging = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
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

  Future<void> _openBookOptions(Book book) async {
    final controller = showBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => BookBottomSheet(book: book),
    );
    await controller.closed;
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
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    try {
      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (context) {
          final l10n = L10n.of(context);
          return AlertDialog(
            title: Text(l10n.addBookToBuyTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l10n.bookshelfTitle),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: authorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l10n.bookshelfAuthor),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.addBookToBuyAction),
              ),
            ],
          );
        },
      );
      if (!mounted) {
        return;
      }
      if (shouldAdd == true && titleController.text.trim().isNotEmpty) {
        await wishlistDao.addBookToBuy(
          title: titleController.text,
          author: authorController.text,
        );
        await ref.read(shelfHomeProvider.notifier).refresh();
      }
    } finally {
      titleController.dispose();
      authorController.dispose();
    }
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = L10n.of(context);
    final shelves = ref.watch(shelfHomeProvider);

    ref.listen(bookListProvider, (previous, next) {
      final previousBooks = previous?.asData?.value;
      final nextBooks = next.asData?.value;
      if (nextBooks != null && !identical(previousBooks, nextBooks)) {
        Future.microtask(ref.read(shelfHomeProvider.notifier).refresh);
      }
    });

    final page = Scaffold(
      appBar: AppBar(
        title: Text(l10n.shelfHomeTitle),
        actions: [
          const SyncButton(),
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
                  _importBooks(context);
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
            final sections = _sections(context, data);
            return ListenableBuilder(
              listenable: Prefs(),
              builder: (context, child) => RefreshIndicator(
                onRefresh: ref.read(shelfHomeProvider.notifier).refresh,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 32),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return _BookshelfSection(
                      section: section,
                      shelfIndex: index,
                      isFirst: index == 0,
                      isLast: index == sections.length - 1,
                      uniformSpines: Prefs().shelfUniformSpines,
                      onOpenShelf: () => _openShelf(section),
                      onOpenBook: _openBookOptions,
                      emptyAction: section.count > 0
                          ? null
                          : index == 0
                              ? () => _importBooks(context)
                              : index == 4
                                  ? _addWishlistBook
                                  : null,
                      emptyActionLabel: index == 0
                          ? l10n.shelfAddBooksTooltip
                          : index == 4
                              ? l10n.addBookToBuyAction
                              : null,
                    );
                  },
                ),
              ),
            );
          },
          loading: () => _ShelfLoadingView(controller: _scrollController),
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

class _BookshelfSection extends StatelessWidget {
  const _BookshelfSection({
    required this.section,
    required this.shelfIndex,
    required this.isFirst,
    required this.isLast,
    required this.uniformSpines,
    required this.onOpenShelf,
    required this.onOpenBook,
    this.emptyAction,
    this.emptyActionLabel,
  });

  final _ShelfSection section;
  final int shelfIndex;
  final bool isFirst;
  final bool isLast;
  final bool uniformSpines;
  final VoidCallback onOpenShelf;
  final ValueChanged<Book> onOpenBook;
  final VoidCallback? emptyAction;
  final String? emptyActionLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final semanticLabel = l10n.shelfHeaderSemanticLabel(
      section.count,
      section.label,
    );

    final scheme = theme.colorScheme;
    final wood = PaperfoldTokens.wood(theme.brightness);
    final glass = PaperfoldGlassStyle.fromScheme(scheme);
    return Semantics(
      container: true,
      child: CustomPaint(
        painter: _BookcaseBayPainter(
          back: wood.back,
          board: wood.board,
          edge: wood.edge,
          detail: wood.onWood,
          showTopRail: isFirst,
          showPlinth: isLast,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            16,
            isFirst ? 20 : 0,
            16,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaperfoldGlassSurface(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                blurSigma: 10,
                child: Semantics(
                  button: true,
                  label: semanticLabel,
                  onTap: onOpenShelf,
                  child: ExcludeSemantics(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: onOpenShelf,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              8,
                              6,
                              8,
                              6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    section.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                      color: glass.foreground,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '${section.count}',
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        color: scheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right,
                                  color: glass.foreground,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: BookSpine.shelfStageHeight(
                  MediaQuery.textScalerOf(context),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 4, 22),
                  child: section.count == 0
                      ? _EmptyShelf(
                          label: l10n.emptyShelf,
                          actionLabel: emptyActionLabel,
                          onAction: emptyAction,
                        )
                      : _ShelfSpineList(
                          section: section,
                          shelfIndex: shelfIndex,
                          uniformSpines: uniformSpines,
                          onOpenBook: onOpenBook,
                          onOpenWishlist: onOpenShelf,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfSpineList extends StatelessWidget {
  const _ShelfSpineList({
    required this.section,
    required this.shelfIndex,
    required this.uniformSpines,
    required this.onOpenBook,
    required this.onOpenWishlist,
  });

  final _ShelfSection section;
  final int shelfIndex;
  final bool uniformSpines;
  final ValueChanged<Book> onOpenBook;
  final VoidCallback onOpenWishlist;

  List<_ShelfSlot> _arrangement() {
    final slots = <_ShelfSlot>[
      for (var index = 0; index < section.count; index++) _SpineSlot(index),
    ];

    switch (shelfIndex) {
      case 0:
        slots.insert(
          math.min(2, slots.length),
          const _DecorationSlot(_ShelfDecorationKind.plant),
        );
      case 1 when section.count >= 2:
        slots
          ..insert(
            0,
            const _DecorationSlot(_ShelfDecorationKind.leadingBookend),
          )
          ..add(
            const _DecorationSlot(_ShelfDecorationKind.trailingBookend),
          );
      // One object per shelf, and a different one on each, so five shelves do
      // not read as the same vase repeated. The slot index is the shelf index,
      // so the arrangement is identical on every launch.
      case 2:
        slots.insert(
          math.min(1, slots.length),
          const _DecorationSlot(_ShelfDecorationKind.curio),
        );
      case 3 when section.count >= 3:
        slots.insert(
          math.min(3, slots.length),
          const _DecorationSlot(_ShelfDecorationKind.plant),
        );
      case 4 when section.count >= 4:
        slots.insert(
          math.min(1, slots.length),
          const _DecorationSlot(_ShelfDecorationKind.candle),
        );
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final arrangement = _arrangement();

    Widget spineAt(int sourceIndex) {
      if (sourceIndex < section.books.length) {
        final book = section.books[sourceIndex];
        return BookSpine(
          stableId: 'book-${book.id}',
          title: book.title,
          author: book.author,
          semanticLabel: book.author.trim().isEmpty
              ? l10n.bookSpineSemanticLabelNoAuthor(book.title)
              : l10n.bookSpineSemanticLabel(book.author, book.title),
          onTap: () => onOpenBook(book),
          uniform: uniformSpines,
        );
      }

      final item = section.wishlistItems[sourceIndex - section.books.length];
      return BookSpine(
        stableId: 'wishlist-${item.id}',
        title: item.title,
        author: item.author,
        semanticLabel: item.author.trim().isEmpty
            ? l10n.wishlistSpineSemanticLabelNoAuthor(item.title)
            : l10n.wishlistSpineSemanticLabel(item.author, item.title),
        onTap: onOpenWishlist,
        uniform: uniformSpines,
      );
    }

    return ListView.separated(
      key: ValueKey('shelf-spine-viewport-$shelfIndex'),
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
      itemCount: arrangement.length,
      separatorBuilder: (context, index) =>
          const SizedBox(width: BookSpine.spacing),
      itemBuilder: (context, index) {
        final slot = arrangement[index];
        return Align(
          alignment: Alignment.bottomCenter,
          child: switch (slot) {
            _SpineSlot(:final sourceIndex) => spineAt(sourceIndex),
            _DecorationSlot(:final kind) => Padding(
                padding: const EdgeInsets.only(
                  bottom: BookSpine.contactShadowDepth,
                ),
                child: _ShelfDecoration(kind: kind),
              ),
          },
        );
      },
    );
  }
}

sealed class _ShelfSlot {
  const _ShelfSlot();
}

class _SpineSlot extends _ShelfSlot {
  const _SpineSlot(this.sourceIndex);

  final int sourceIndex;
}

class _DecorationSlot extends _ShelfSlot {
  const _DecorationSlot(this.kind);

  final _ShelfDecorationKind kind;
}

enum _ShelfDecorationKind {
  plant,
  leadingBookend,
  trailingBookend,
  urn,
  curio,
  candle,
}

class _ShelfDecoration extends StatelessWidget {
  const _ShelfDecoration({required this.kind});

  final _ShelfDecorationKind kind;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final scheme = Theme.of(context).colorScheme;
    // The two reference worlds dress differently. The printed keepsake page is
    // a teacup, a candle and a jug of flowers; the dark shelf is a classical
    // bust. Same slots, resolved by brightness.
    final isDark = scheme.brightness == Brightness.dark;
    final (ornament, width, height, flipX) = switch (kind) {
      _ShelfDecorationKind.curio => isDark
          ? (PaperfoldOrnament.classicalBust, 52.0, 76.0, false)
          : (PaperfoldOrnament.teacup, 60.0, 46.0, isRtl),
      _ShelfDecorationKind.candle => isDark
          ? (PaperfoldOrnament.smallUrn, 46.0, 66.0, false)
          : (PaperfoldOrnament.candle, 36.0, 70.0, false),
      _ShelfDecorationKind.plant => (
          PaperfoldOrnament.pottedPlant,
          58.0,
          94.0,
          false
        ),
      _ShelfDecorationKind.leadingBookend => (
          PaperfoldOrnament.bookend,
          38.0,
          82.0,
          isRtl
        ),
      _ShelfDecorationKind.trailingBookend => (
          PaperfoldOrnament.bookend,
          38.0,
          82.0,
          !isRtl
        ),
      _ShelfDecorationKind.urn => (
          PaperfoldOrnament.smallUrn,
          46.0,
          66.0,
          false
        ),
    };

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: Transform.flip(
          flipX: flipX,
          child: Ornament(
            ornament: ornament,
            width: width,
            height: height,
            tint: scheme.primary,
          ),
        ),
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({
    required this.label,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    final ornamentSize = largeText && onAction != null ? 28.0 : 58.0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Ornament(
              ornament: PaperfoldOrnament.circularWreath,
              width: ornamentSize,
              height: ornamentSize,
              tint: scheme.outlineVariant,
            ),
          ),
          SizedBox(height: largeText ? 2 : 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (onAction != null && actionLabel != null) ...[
            SizedBox(height: largeText ? 4 : 8),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookcaseBayPainter extends CustomPainter {
  _BookcaseBayPainter({
    required this.back,
    required this.board,
    required this.edge,
    required this.detail,
    required this.showTopRail,
    required this.showPlinth,
  }) : outlinePaint = Paint()
          ..color = detail.withValues(alpha: 0.34)
          ..strokeWidth = 1;

  final Color back;
  final Color board;
  final Color edge;
  final Color detail;
  final bool showTopRail;
  final bool showPlinth;
  final Paint outlinePaint;

  /// Drawn as furniture rather than as rectangles. The depth comes from four
  /// cheap things: a vignette inside the bay, an occlusion band under the shelf
  /// above, a lit gradient across each board, and a contact shadow where the
  /// books meet the timber. Flat fills were what made the first two builds look
  /// drawn instead of built.
  ///
  /// Everything here uses solid colour and linear gradients. There is no blur,
  /// noise, or image. [shouldRepaint] is false unless the palette changes, so
  /// this runs on theme change and resize, not per scrolled frame.
  @override
  void paint(Canvas canvas, Size size) {
    const sideWidth = 14.0;
    const boardThickness = 28.0;
    final shade = Color.lerp(edge, back, 0.48)!;
    final deepShade = Color.lerp(back, edge, 0.16)!;
    final sheen = Color.lerp(board, PaperfoldTokens.cover.foil, 0.24)!;

    // The back panel sits deepest, so it is darkest at the top of the bay
    // where least light reaches.
    final backRect = Rect.fromLTWH(
      sideWidth,
      0,
      math.max(0, size.width - sideWidth * 2),
      size.height,
    );
    canvas.drawRect(
      backRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [deepShade, back],
        ).createShader(backRect),
    );

    // The recessed panel has vertical walnut grain and two quiet join lines.
    // Stable geometry keeps this cheaper than a texture image or noise shader.
    final backGrainPaint = Paint()
      ..color = edge.withValues(alpha: 0.24)
      ..strokeWidth = 1;
    for (final t in <double>[0.17, 0.34, 0.58, 0.79]) {
      final x = sideWidth + backRect.width * t;
      canvas.drawLine(
          Offset(x, 22), Offset(x, size.height - 28), backGrainPaint);
    }
    for (final t in <double>[0.33, 0.67]) {
      final x = sideWidth + backRect.width * t;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height - boardThickness),
        Paint()
          ..color = shade.withValues(alpha: 0.42)
          ..strokeWidth = 1,
      );
    }

    // Ambient occlusion under the shelf above.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 18),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            deepShade.withValues(alpha: 0.55),
            deepShade.withValues(alpha: 0)
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 18)),
    );

    // Uprights, lit on their inner faces so the carcass reads as having sides.
    for (final left in <double>[0, size.width - sideWidth]) {
      final rect = Rect.fromLTWH(left, 0, sideWidth, size.height);
      final inner = left == 0;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: inner ? [edge, board] : [board, edge],
          ).createShader(rect),
      );
    }
    canvas.drawLine(
      const Offset(sideWidth, 0),
      Offset(sideWidth, size.height),
      outlinePaint,
    );
    canvas.drawLine(
      Offset(size.width - sideWidth, 0),
      Offset(size.width - sideWidth, size.height),
      outlinePaint,
    );

    if (showTopRail) {
      final railRect = Rect.fromLTWH(0, 0, size.width, 20);
      canvas.drawRRect(
        RRect.fromRectAndRadius(railRect, const Radius.circular(3)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [sheen, edge],
          ).createShader(railRect),
      );
      canvas.drawLine(
        const Offset(0, 19),
        Offset(size.width, 19),
        outlinePaint,
      );
    }

    final boardTop = size.height - boardThickness;

    // The books cast onto the board they stand on.
    final contactRect = Rect.fromLTWH(0, boardTop - 14, size.width, 14);
    canvas.drawRect(
      contactRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            deepShade.withValues(alpha: 0),
            deepShade.withValues(alpha: 0.5)
          ],
        ).createShader(contactRect),
    );

    // The board top catches light; the front lip below it falls into shadow.
    final boardRect =
        Rect.fromLTWH(0, boardTop, size.width, boardThickness - 8);
    canvas.drawRect(
      boardRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sheen, board],
        ).createShader(boardRect),
    );

    // Grain: a few long, faint strokes along the board. Deterministic offsets,
    // not noise, so the timber looks the same on every launch.
    final grainPaint = Paint()
      ..color = shade.withValues(alpha: 0.34)
      ..strokeWidth = 1;
    for (final t in <double>[0.18, 0.34, 0.55, 0.76]) {
      final y = boardTop + (boardThickness - 8) * t;
      canvas.drawLine(
          Offset(sideWidth, y), Offset(size.width - sideWidth, y), grainPaint);
    }

    final lipRect = Rect.fromLTWH(
      4,
      boardTop + boardThickness - 8,
      size.width - 8,
      8,
    );
    canvas.drawRect(
      lipRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [edge, shade],
        ).createShader(lipRect),
    );
    // A hairline highlight along the front top edge is what reads as an edge.
    canvas.drawLine(
      Offset(0, boardTop),
      Offset(size.width, boardTop),
      Paint()
        ..color = sheen
        ..strokeWidth = 1,
    );
    if (showPlinth) {
      canvas.drawLine(
        Offset(8, size.height - 2),
        Offset(size.width - 8, size.height - 2),
        outlinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BookcaseBayPainter oldDelegate) {
    return back != oldDelegate.back ||
        board != oldDelegate.board ||
        edge != oldDelegate.edge ||
        detail != oldDelegate.detail ||
        showTopRail != oldDelegate.showTopRail ||
        showPlinth != oldDelegate.showPlinth;
  }
}

class _ShelfLoadingView extends StatelessWidget {
  const _ShelfLoadingView({required this.controller});

  final ScrollController controller;

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
    final wood = PaperfoldTokens.wood(theme.brightness);
    final glass = PaperfoldGlassStyle.fromScheme(scheme);

    return Semantics(
      liveRegion: true,
      label: l10n.shelvesLoading,
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 32),
        itemCount: labels.length,
        itemBuilder: (context, index) => ExcludeSemantics(
          child: CustomPaint(
            painter: _BookcaseBayPainter(
              back: wood.back,
              board: wood.board,
              edge: wood.edge,
              detail: wood.onWood,
              showTopRail: index == 0,
              showPlinth: index == labels.length - 1,
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                16,
                index == 0 ? 20 : 0,
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
            icon: Icon(_showLog
                ? Icons.grid_view_outlined
                : Icons.view_list_outlined),
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
