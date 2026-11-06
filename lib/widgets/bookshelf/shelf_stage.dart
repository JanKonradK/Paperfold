import 'package:paperfold/utils/paperfold_layout.dart';
import 'package:paperfold/config/shared_preference_provider.dart';

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/bookshelf/book_detail_route.dart';
import 'package:paperfold/widgets/common/paperfold_pane.dart';
import 'package:paperfold/widgets/ornament.dart';

/// The shelf also holds wishlist entries, so it does not depend on a database row.
@immutable
class ShelfBook {
  const ShelfBook({
    required this.id,
    required this.title,
    required this.author,
    required this.binding,
    this.blurb,
    this.coverPath,
    this.progress = 0,
    this.finished = false,
    this.isWishlist = false,
    this.isPhysical = false,
    this.series,
    this.volume,
    this.pageCount,
  });

  final String id;
  final String title;
  final String author;
  final String? blurb;
  final String? coverPath;
  final BookBinding binding;
  final double progress;
  final bool finished;
  final bool isWishlist;

  /// A paper book: opening it logs a page instead of starting the reader.
  final bool isPhysical;
  final String? series;
  final String? volume;
  final int? pageCount;

  String get bindingKey => series?.trim().isNotEmpty == true
      ? 'series:${series!.trim().toLowerCase()}'
      : '$author:$title';

  // A minimum 48-pixel spine also keeps each book a usable touch target.
  double get spineWidth => pageCount != null && pageCount! > 0
      ? (42 + pageCount! * 0.075).clamp(48.0, 104.0)
      : 60;

  double get spineHeightFactor => series?.trim().isNotEmpty == true
      ? 0.96
      : binding == BookBinding.hardback
      ? 1
      : 0.92;

  double get openAt => finished ? 1 : progress.clamp(0.0, 1.0);
}

@immutable
class ShelfRow {
  const ShelfRow({required this.name, required this.books});
  final String name;
  final List<ShelfBook> books;
  bool get isEmpty => books.isEmpty;
}

// Kept for callers migrating from the old stage. Books always stay shelved.
enum ShelfPhase { shelved, held, opening }

class ShelfStage extends StatefulWidget {
  const ShelfStage({
    super.key,
    required this.books,
    this.shelfName,
    this.initialIndex = 0,
    this.onOpen,
    this.onIndexChanged,
    this.onPickedUp,
    this.onReturned,
    this.onPhaseChanged,
    this.optionsBuilder,
    this.onOptions,
    this.pickUpHint,
    this.openHint,
    this.showCovers = false,
  });
  final List<ShelfBook> books;
  final String? shelfName;
  final int initialIndex;
  final ValueChanged<ShelfBook>? onOpen, onPickedUp, onReturned, onOptions;
  final ValueChanged<int>? onIndexChanged;
  final ValueChanged<ShelfPhase>? onPhaseChanged;
  final Widget Function(BuildContext, ShelfBook)? optionsBuilder;
  final String? pickUpHint, openHint;
  final bool showCovers;
  static const headBand = 64.0, footBand = 96.0;
  static const runDuration = PaperfoldMotion.move;
  static const liftDuration = PaperfoldMotion.move;
  static const returnDuration = PaperfoldMotion.move;
  static const openDuration = PaperfoldMotion.move;
  @override
  State<ShelfStage> createState() => ShelfStageState();
}

class ShelfStageState extends State<ShelfStage>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  final _focus = <String, FocusNode>{};
  late final AnimationController _layout;
  int _index = 0;
  List<Rect> _lastRects = [];
  int? _anchor;
  double _anchorInset = 0;
  ShelfPhase get phase => ShelfPhase.shelved;
  int get index => _index;
  ShelfBook? get current => widget.books.isEmpty
      ? null
      : widget.books[_index.clamp(0, widget.books.length - 1)];
  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _layout = AnimationController(
      vsync: this,
      value: widget.showCovers ? 1 : 0,
    );
    _scroll.addListener(_scrolled);
  }

  void _scrolled() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ShelfStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showCovers != widget.showCovers) {
      if (_scroll.hasClients && _lastRects.isNotEmpty) {
        final i = _lastRects.indexWhere((r) => r.bottom > _scroll.offset);
        if (i >= 0) {
          _anchor = i;
          _anchorInset = _scroll.offset - _lastRects[i].top;
        }
      }
      _layout.animateTo(
        widget.showCovers ? 1 : 0,
        duration: bookDetailDuration(context),
        curve: PaperfoldMotion.settle,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _layout.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> pickUpAt(int index) async {
    if (index < 0 || index >= widget.books.length) return;
    _index = index;
    widget.onIndexChanged?.call(index);
    widget.onOpen?.call(widget.books[index]);
  }

  Future<void> pickUp() => pickUpAt(_index);
  Future<void> openBook() => pickUp();
  Future<void> putBack() async {}
  void reset() {
    if (current != null) _focus[current!.id]?.requestFocus();
  }

  void _options(ShelfBook book) {
    if (widget.onOptions != null) {
      widget.onOptions!(book);
      return;
    }
    if (widget.optionsBuilder == null) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(PaperfoldSpace.sheetGutter),
        child: widget.optionsBuilder!(context, book),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final layout = PaperfoldLayout.of(context, constraints: bounds);
      final density = layout.covers(Prefs().libraryCoversPerRow);
      final columns = density.columns;
      final coverWidth = density.coverWidth;
      final width = layout.content;
      final captionStyle = Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontSize: 14, height: 20 / 14);
      final caption = TextPainter(
        text: TextSpan(text: 'Ag\nAg', style: captionStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: coverWidth);
      final coverHeight = coverWidth * 1.5 + 8 + caption.height;
      caption.dispose();
      final portraitCount = Prefs().libraryCoversPerRow <= 0
          ? layout.defaultCoversPerRow
          : Prefs().libraryCoversPerRow;
      final portraitContent = layout.window.shortestSide - 2 * layout.gutter;
      final count = portraitCount.clamp(
        1,
        ((portraitContent + 12) / 84).floor().clamp(1, 100),
      );
      final chosenWidth = (portraitContent - (count - 1) * 12) / count;
      final defaultWidth =
          (portraitContent - (layout.defaultCoversPerRow - 1) * 12) /
          layout.defaultCoversPerRow;
      final scale = chosenWidth / defaultWidth;
      final spineHeight = (240 * scale).clamp(144.0, 320.0);
      final spineRects = <Rect>[];
      final coverRects = <Rect>[];
      final labels = <(double, String)>[];
      double x = 0, y = 36;
      bool? physical;
      var groupStart = 0;
      for (var i = 0; i < widget.books.length; i++) {
        final book = widget.books[i];
        if (physical != book.isPhysical && !book.isWishlist) {
          if (physical != null) {
            y += spineHeight + 32;
          }
          x = 0;
          groupStart = i;
          physical = book.isPhysical;
          final count = widget.books
              .where((b) => b.isPhysical == physical)
              .length;
          labels.add((
            y - 28,
            '${book.isPhysical ? L10n.of(context).libraryPaperBooks : L10n.of(context).libraryEbooks} · $count',
          ));
        }
        final spineWidth = math.max(48.0, book.spineWidth * scale);
        if (x + spineWidth > width && x > 0) {
          x = 0;
          y += spineHeight + 16;
        }
        // Books stand on the board: hardbacks full height, paperbacks a
        // little shorter, a series at one shared height.
        final bookHeight = spineHeight * book.spineHeightFactor;
        spineRects.add(
          Rect.fromLTWH(
            x + layout.gutter,
            y + spineHeight - bookHeight,
            spineWidth,
            bookHeight,
          ),
        );
        // Each group has its own grid origin, resolved below.
        coverRects.add(
          Rect.fromLTWH(
            layout.gutter + ((i - groupStart) % columns) * (coverWidth + 12),
            0,
            coverWidth,
            coverHeight,
          ),
        );
        x += spineWidth + 4;
      }
      double gridY = 36;
      physical = null;
      groupStart = 0;
      final gridLabels = <double>[];
      for (var i = 0; i < widget.books.length; i++) {
        final book = widget.books[i];
        if (physical != book.isPhysical && !book.isWishlist) {
          if (physical != null) {
            gridY +=
                ((i - groupStart + columns - 1) ~/ columns) *
                    (coverHeight + 16) +
                36;
          }
          groupStart = i;
          physical = book.isPhysical;
          gridLabels.add(gridY - 28);
        }
        coverRects[i] = coverRects[i].shift(
          Offset(0, gridY + ((i - groupStart) ~/ columns) * (coverHeight + 16)),
        );
      }
      return AnimatedBuilder(
        animation: _layout,
        builder: (context, _) {
          final spatial = PaperfoldVisualPolicy.motionAllowed(context);
          final t = spatial
              ? _layout.value
              : widget.showCovers
              ? 1.0
              : 0.0;
          final rects = [
            for (var i = 0; i < spineRects.length; i++)
              Rect.lerp(spineRects[i], coverRects[i], t)!,
          ];
          _lastRects = rects;
          if (_anchor != null && _anchor! < rects.length) {
            final top = rects[_anchor!].top + _anchorInset;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_scroll.hasClients) return;
              final offset = top.clamp(0.0, _scroll.position.maxScrollExtent);
              if ((_scroll.offset - offset).abs() > .5) _scroll.jumpTo(offset);
              if (!_layout.isAnimating) _anchor = null;
            });
          }
          final height = rects.fold<double>(0, (v, r) => math.max(v, r.bottom));
          final offset = _scroll.hasClients ? _scroll.offset : 0.0;
          return Opacity(
            opacity: spatial ? 1 : (1 - (t - _layout.value).abs()),
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent || widget.books.isEmpty)
                  return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space) {
                  pickUp();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                    event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  final step =
                      (event.logicalKey == LogicalKeyboardKey.arrowRight) ==
                          (Directionality.of(context) == TextDirection.ltr)
                      ? 1
                      : -1;
                  _index = (_index + step).clamp(0, widget.books.length - 1);
                  _scroll.jumpTo(
                    (rects[_index].top - 36).clamp(
                      0,
                      _scroll.position.maxScrollExtent,
                    ),
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _focus[current?.id]?.requestFocus();
                  });
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: ListView(
                controller: _scroll,
                key: ValueKey(
                  widget.showCovers ? 'shelf-covers' : 'shelf-spines',
                ),
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.paddingOf(context).bottom +
                      PaperfoldSize.fab +
                      PaperfoldSpace.lg,
                ),
                children: [
                  SizedBox(
                    height: height + 16,
                    child: Stack(
                      children: [
                        if (t < 1)
                          for (final bottom
                              in spineRects.map((r) => r.bottom).toSet())
                            Positioned(
                              left: 8,
                              right: 8,
                              top: bottom,
                              height: 12,
                              child: Opacity(
                                opacity: 1 - t,
                                child: _ShelfBoard(
                                  scheme: Theme.of(context).colorScheme,
                                ),
                              ),
                            ),
                        for (var j = 0; j < labels.length; j++)
                          PositionedDirectional(
                            start: 16,
                            top: labels[j].$1 * (1 - t) + gridLabels[j] * t,
                            child: Text(
                              labels[j].$2,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        for (var i = 0; i < rects.length; i++)
                          if (rects[i].bottom >= offset - 240 &&
                              rects[i].top <= offset + bounds.maxHeight + 240)
                            Positioned.fromRect(
                              rect:
                                  Directionality.of(context) ==
                                      TextDirection.rtl
                                  ? Rect.fromLTWH(
                                      bounds.maxWidth - rects[i].right,
                                      rects[i].top,
                                      rects[i].width,
                                      rects[i].height,
                                    )
                                  : rects[i],
                              child: _tile(i, t),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  Widget _tile(int i, double t) {
    final book = widget.books[i];
    final visual = BookSpine.resolveVisual(
      book.bindingKey,
      Theme.of(context).colorScheme,
    );
    final cover = _FlatCover(book: book);
    final spine = ColoredBox(
      color: visual.background,
      child: _FlatSpine(book: book, visual: visual),
    );
    final node = _focus.putIfAbsent(book.id, FocusNode.new);
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '${book.title}, ${book.author}',
        onTap: () => pickUpAt(i),
        onLongPress: () => _options(book),
        child: PaperfoldPressable(
          child: InkWell(
            key: ValueKey(
              '${widget.showCovers ? 'shelf-cover' : 'shelf-spine'}-${book.id}',
            ),
            focusNode: node,
            onFocusChange: (focused) {
              if (focused) _index = i;
            },
            onTap: () => pickUpAt(i),
            onLongPress: () => _options(book),
            onSecondaryTap: () => _options(book),
            child: ExcludeSemantics(
              child: BookDetailHero(
                id: book.id,
                spine: !widget.showCovers,
                cover: cover,
                child: t == 0
                    ? spine
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Opacity(
                                  opacity: (1 - t * 2).clamp(0, 1),
                                  child: spine,
                                ),
                                Opacity(
                                  opacity: (t * 2 - 1).clamp(0, 1),
                                  child: cover,
                                ),
                              ],
                            ),
                          ),
                          if (t > .5) ...[
                            const SizedBox(height: 8),
                            Text(
                              book.title,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontSize: 14, height: 20 / 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlatSpine extends StatelessWidget {
  const _FlatSpine({required this.book, required this.visual});
  final ShelfBook book;
  final BookSpineVisual visual;

  @override
  Widget build(BuildContext context) {
    final ink = visual.foreground;
    final bindingStyle = BookSpine.stableHash(book.bindingKey) % 3;
    final title = book.volume == null
        ? book.title
        : book.title.replaceFirst(
            RegExp(
              r'[,\s:–—-]*(?:vol(?:ume)?\.?|book)\s*\d+(?:\.\d+)?\s*$',
              caseSensitive: false,
            ),
            '',
          );
    return Ink(
      decoration: BoxDecoration(
        // A shallow binding crease; the book remains square to the shelf.
        gradient: LinearGradient(
          stops: const [0, 0.07, 0.16, 0.88, 1],
          colors: [
            Colors.black.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.06),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.16),
          ],
        ),
        border: Border.symmetric(
          vertical: BorderSide(color: ink.withValues(alpha: 0.12)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 230;
          final scaler = MediaQuery.textScalerOf(context);
          final titleSize = constraints.maxWidth >= 68 ? 16.0 : 14.0;
          final titleLineHeight = scaler.scale(titleSize) * 1.1;
          final authorHeight = scaler.scale(10) * 1.1 + 6;
          final textSpace = constraints.maxWidth - 12;
          final showAuthor =
              !compact &&
              book.author.isNotEmpty &&
              textSpace >= titleLineHeight + authorHeight;
          final titleLines =
              ((textSpace - (showAuthor ? authorHeight : 0)) / titleLineHeight)
                  .floor()
                  .clamp(1, 2);
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 6,
              vertical: compact ? 8 : 14,
            ),
            child: Column(
              children: [
                _band(ink, bindingStyle),
                if (!compact && bindingStyle == 1) ...[
                  const SizedBox(height: 12),
                  _seal(ink),
                ],
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: compact ? 8 : 18),
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: titleLines,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ink,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w400,
                                fontFamily: PaperfoldTypeTokens.journalFamily,
                                height: 1.1,
                              ),
                            ),
                          ),
                          if (showAuthor) ...[
                            const SizedBox(height: 6),
                            Text(
                              book.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ink,
                                fontFamily: PaperfoldTypeTokens.chromeFamily,
                                fontSize: 10,
                                height: 1.1,
                                letterSpacing: 0.25,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                _band(ink, bindingStyle),
                if (book.volume != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    book.volume!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontFamily: PaperfoldTypeTokens.journalFamily,
                      fontSize: compact ? 16 : 20,
                      height: 1.1,
                    ),
                  ),
                ] else if (!compact) ...[
                  const SizedBox(height: 10),
                  _seal(ink),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _rule(Color ink) => SizedBox(
    height: 0.75,
    width: double.infinity,
    child: ColoredBox(color: ink.withValues(alpha: 0.55)),
  );

  Widget _band(Color ink, int style) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _rule(ink),
      if (book.binding == BookBinding.hardback || style == 2) ...[
        SizedBox(height: style == 2 ? 5 : 3),
        _rule(ink),
      ],
    ],
  );

  Widget _seal(Color ink) => SizedBox(
    width: 7,
    height: 7,
    child: Transform.rotate(
      angle: math.pi / 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: ink.withValues(alpha: 0.7), width: 0.8),
        ),
      ),
    ),
  );
}

class _FlatCover extends StatelessWidget {
  const _FlatCover({required this.book});
  final ShelfBook book;

  @override
  Widget build(BuildContext context) {
    final visual = BookSpine.resolveVisual(
      book.bindingKey,
      Theme.of(context).colorScheme,
    );
    final fallback = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ColoredBox(
          color: visual.background,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: EdgeInsets.all(width * 0.07),
                child: Ornament(
                  ornament: PaperfoldOrnament.rectangularVineFrame,
                  tint: visual.foreground.withValues(alpha: 0.65),
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(width * 0.17),
                  child: MediaQuery.withNoTextScaling(
                    child: Text(
                      book.title,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: PaperfoldTypeTokens.journalFamily,
                        fontSize: (width * 0.12).clamp(12.0, 24.0),
                        height: 1.2,
                        color: visual.foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.22),
            offset: const Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: PaperfoldShape.objectRadius,
        child: BookCoverImage(path: book.coverPath, fallback: fallback),
      ),
    );
  }
}

/// The board a row of books stands on: a lit front edge and a soft shadow.
class _ShelfBoard extends StatelessWidget {
  const _ShelfBoard({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final light = scheme.brightness == Brightness.light;
    return DecoratedBox(
      key: const ValueKey('shelf-board'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(PaperfoldShape.object),
        ),
        border: Border(
          top: BorderSide(color: scheme.primary.withValues(alpha: 0.45)),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: light ? 0.12 : 0.32),
            offset: const Offset(0, 6),
            blurRadius: 9,
          ),
        ],
      ),
    );
  }
}
