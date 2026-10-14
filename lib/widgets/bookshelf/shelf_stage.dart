import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
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

enum ShelfPhase { shelved, held, opening }

/// Upright, front-on spines on a straight board. Selecting one reveals its cover.
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
    this.pickUpHint,
    this.openHint,
    this.showCovers = false,
  });

  final List<ShelfBook> books;
  final String? shelfName;
  final int initialIndex;
  final ValueChanged<ShelfBook>? onOpen;
  final ValueChanged<int>? onIndexChanged;
  final ValueChanged<ShelfBook>? onPickedUp;
  final ValueChanged<ShelfBook>? onReturned;
  final ValueChanged<ShelfPhase>? onPhaseChanged;
  final Widget Function(BuildContext context, ShelfBook book)? optionsBuilder;
  final String? pickUpHint;
  final String? openHint;
  final bool showCovers;

  // The option bar also uses this height outside the stage.
  static const double headBand = 64;
  static const double footBand = 96;
  static const Duration runDuration = Duration(milliseconds: 220);
  static const Duration liftDuration = Duration(milliseconds: 220);
  static const Duration returnDuration = Duration(milliseconds: 180);
  static const Duration openDuration = Duration(milliseconds: 220);

  @override
  State<ShelfStage> createState() => ShelfStageState();
}

class ShelfStageState extends State<ShelfStage> {
  final ScrollController _row = ScrollController();
  final Map<String, FocusNode> _bookFocus = {};
  ShelfPhase _phase = ShelfPhase.shelved;
  int _index = 0;
  int _operation = 0;
  bool _accessibleList = false;
  int _coverColumns = 1;
  double _coverRowExtent = 0;

  ShelfPhase get phase => _phase;
  int get index => _index;
  ShelfBook? get current => widget.books.isEmpty ? null : widget.books[_index];
  bool get _instant => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, math.max(0, widget.books.length - 1));
    if (_index > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(_index));
    }
  }

  @override
  void didUpdateWidget(covariant ShelfStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showCovers != widget.showCovers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal(_index);
      });
    }
    final selectedId = oldWidget.books.isEmpty
        ? null
        : oldWidget.books[_index].id;
    final retained = widget.books.indexWhere((book) => book.id == selectedId);
    final previousIndex = _index;
    final previousPhase = _phase;
    _index = retained >= 0
        ? retained
        : _index.clamp(0, math.max(0, widget.books.length - 1));
    if (retained < 0) {
      _operation++;
      _phase = ShelfPhase.shelved;
    }
    final reordered =
        oldWidget.books.length == widget.books.length &&
        oldWidget.books.indexed.any(
          (entry) => entry.$2.id != widget.books[entry.$1].id,
        );
    if (reordered && _phase == ShelfPhase.shelved) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _row.hasClients && _phase == ShelfPhase.shelved) {
          _row.jumpTo(0);
        }
      });
    }
    final ids = widget.books.map((book) => book.id).toSet();
    for (final id in _bookFocus.keys.toList()) {
      if (!ids.contains(id)) _bookFocus.remove(id)!.dispose();
    }
    if (_index != previousIndex || _phase != previousPhase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_index != previousIndex) widget.onIndexChanged?.call(_index);
        if (_phase != previousPhase) widget.onPhaseChanged?.call(_phase);
      });
    }
  }

  @override
  void dispose() {
    _operation++;
    _row.dispose();
    for (final node in _bookFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(int value) {
    if (value == _index) return;
    setState(() => _index = value);
    widget.onIndexChanged?.call(value);
  }

  void _setPhase(ShelfPhase value) {
    setState(() => _phase = value);
    widget.onPhaseChanged?.call(value);
  }

  Future<void> pickUpAt(int index) async {
    if (_phase != ShelfPhase.shelved ||
        index < 0 ||
        index >= widget.books.length) {
      return;
    }
    _select(index);
    await pickUp();
  }

  Future<void> pickUp() async {
    final book = current;
    if (_phase != ShelfPhase.shelved || book == null) return;
    _setPhase(ShelfPhase.held);
    widget.onPickedUp?.call(book);
  }

  Future<void> putBack() async {
    if (_phase != ShelfPhase.held) return;
    final book = current;
    _setPhase(ShelfPhase.shelved);
    if (book != null) {
      widget.onReturned?.call(book);
      _focusAfterLayout(book.id);
    }
  }

  Future<void> openBook() async {
    if (_phase == ShelfPhase.opening || current == null) return;
    if (_phase == ShelfPhase.shelved) await pickUp();
    if (!mounted) return;
    final book = current;
    if (book == null) return;
    final operation = ++_operation;
    _setPhase(ShelfPhase.opening);
    if (!_instant) await Future<void>.delayed(ShelfStage.openDuration);
    if (!mounted || operation != _operation || current?.id != book.id) return;
    widget.onOpen?.call(current!);
  }

  void reset() {
    _operation++;
    if (mounted) _setPhase(ShelfPhase.shelved);
  }

  double _width(ShelfBook book) => book.spineWidth;

  void _focusAfterLayout(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _phase == ShelfPhase.shelved && current?.id == id) {
        _bookFocus[id]?.requestFocus();
      }
    });
  }

  Future<void> _reveal(int index, {bool focus = false}) async {
    if (!mounted || !_row.hasClients || index >= widget.books.length) return;
    final id = widget.books[index].id;
    if (widget.showCovers && !_accessibleList) {
      final top = (index ~/ _coverColumns) * _coverRowExtent;
      final position = _row.position;
      final bottom = top + _coverRowExtent;
      final offset = top < position.pixels
          ? top
          : bottom > position.pixels + position.viewportDimension
          ? bottom - position.viewportDimension
          : position.pixels;
      final bounded = offset.clamp(0.0, position.maxScrollExtent);
      if (_instant) {
        _row.jumpTo(bounded);
      } else {
        await _row.animateTo(
          bounded,
          duration: ShelfStage.runDuration,
          curve: Curves.easeOutCubic,
        );
      }
      if (mounted && focus) _focusAfterLayout(id);
      return;
    }
    if (_accessibleList) {
      final itemContext = _bookFocus[id]?.context;
      if (itemContext != null) {
        await _row.position.ensureVisible(
          itemContext.findRenderObject()!,
          duration: _instant ? Duration.zero : ShelfStage.runDuration,
        );
      }
      if (mounted && focus) _focusAfterLayout(id);
      return;
    }
    var left = 24.0;
    for (var i = 0; i < index; i++) {
      left += _width(widget.books[i]) + 4;
    }
    final right = left + _width(widget.books[index]);
    final position = _row.position;
    final offset = left < position.pixels
        ? left - 24
        : right > position.pixels + position.viewportDimension
        ? right - position.viewportDimension + 24
        : position.pixels;
    final bounded = offset.clamp(0.0, position.maxScrollExtent);
    if (_instant) {
      _row.jumpTo(bounded);
    } else {
      await _row.animateTo(
        bounded,
        duration: ShelfStage.runDuration,
        curve: Curves.easeOutCubic,
      );
    }
    if (mounted && focus) _focusAfterLayout(id);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        _phase == ShelfPhase.held) {
      unawaited(putBack());
      return KeyEventResult.handled;
    }
    if (_phase != ShelfPhase.shelved || widget.books.isEmpty) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final vertical = widget.showCovers || _accessibleList;
    if (key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight &&
        !(vertical &&
            (key == LogicalKeyboardKey.arrowUp ||
                key == LogicalKeyboardKey.arrowDown))) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final step = switch (key) {
      LogicalKeyboardKey.arrowUp => -(_accessibleList ? 1 : _coverColumns),
      LogicalKeyboardKey.arrowDown => _accessibleList ? 1 : _coverColumns,
      _ => (key == LogicalKeyboardKey.arrowRight) != rtl ? 1 : -1,
    };
    final target = (_index + step).clamp(0, widget.books.length - 1);
    _select(target);
    unawaited(_reveal(target, focus: true));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _accessibleList =
              MediaQuery.textScalerOf(context).scale(16) >= 24 ||
              constraints.maxHeight < 280;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Keep the native scroll position and focus nodes when a book is held.
              ExcludeFocus(
                excluding: _phase != ShelfPhase.shelved,
                child: Offstage(
                  offstage: _phase != ShelfPhase.shelved,
                  child: _shelf(constraints),
                ),
              ),
              if (_phase != ShelfPhase.shelved && current != null)
                _held(constraints, current!),
            ],
          );
        },
      ),
    );
  }

  Widget _shelf(BoxConstraints constraints) {
    if (_accessibleList) return _bookList();
    if (widget.showCovers) return _coverGrid(constraints);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final height = math.max(72.0, math.min(330.0, constraints.maxHeight - 100));
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: ListView.builder(
              key: const ValueKey('shelf-spines'),
              controller: _row,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: widget.books.length,
              itemBuilder: (context, index) {
                final book = widget.books[index];
                final visual = BookSpine.resolveVisual(book.bindingKey, scheme);
                final bookHeight = height * book.spineHeightFactor;
                final node = _bookFocus.putIfAbsent(book.id, () => FocusNode());
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: Semantics(
                      button: true,
                      label: [
                        book.title,
                        if (book.author.isNotEmpty) book.author,
                      ].join(', '),
                      hint: widget.pickUpHint,
                      onTap: () => pickUpAt(index),
                      excludeSemantics: true,
                      child: Tooltip(
                        message: book.title,
                        child: Material(
                          key: ValueKey('shelf-spine-${book.id}'),
                          color: visual.background,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                          child: InkWell(
                            focusNode: node,
                            onFocusChange: (focused) {
                              if (focused && _phase == ShelfPhase.shelved) {
                                _select(index);
                              }
                            },
                            onTap: () => pickUpAt(index),
                            focusColor: visual.foreground.withValues(
                              alpha: 0.18,
                            ),
                            hoverColor: visual.foreground.withValues(
                              alpha: 0.08,
                            ),
                            child: SizedBox(
                              width: _width(book),
                              height: bookHeight,
                              child: _FlatSpine(book: book, visual: visual),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            key: const ValueKey('shelf-board'),
            width: double.infinity,
            height: 13,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(color: scheme.primary.withValues(alpha: 0.65)),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.22),
                  offset: const Offset(0, 6),
                  blurRadius: 9,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Text(
              widget.pickUpHint ?? widget.shelfName ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverGrid(BoxConstraints constraints) {
    const gap = 20.0;
    final available = constraints.maxWidth - 48;
    _coverColumns = ((available + gap) / 116).floor().clamp(2, 8);
    final width = (available - gap * (_coverColumns - 1)) / _coverColumns;
    final scaler = MediaQuery.textScalerOf(context);
    final height = width / 0.68;
    final labelHeight = scaler.scale(14) * 2.4 + scaler.scale(12) * 1.3 + 22;
    _coverRowExtent = height + labelHeight + gap;
    final theme = Theme.of(context);
    return GridView.builder(
      key: const ValueKey('shelf-covers'),
      controller: _row,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _coverColumns,
        mainAxisExtent: height + labelHeight,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
      ),
      itemCount: widget.books.length,
      itemBuilder: (context, index) {
        final book = widget.books[index];
        final node = _bookFocus.putIfAbsent(book.id, () => FocusNode());
        return Semantics(
          button: true,
          label: [
            book.title,
            if (book.author.isNotEmpty) book.author,
          ].join(', '),
          hint: widget.pickUpHint,
          onTap: () => pickUpAt(index),
          excludeSemantics: true,
          child: InkWell(
            key: ValueKey('shelf-cover-${book.id}'),
            focusNode: node,
            onFocusChange: (focused) {
              if (focused && _phase == ShelfPhase.shelved) _select(index);
            },
            onTap: () => pickUpAt(index),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: height,
                  width: width,
                  child: _FlatCover(book: book),
                ),
                const SizedBox(height: 10),
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(height: 1.2),
                ),
                if (book.author.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// A short viewport or large print needs horizontal titles to remain readable.
  Widget _bookList() {
    final theme = Theme.of(context);
    return ListView.builder(
      key: const ValueKey('shelf-spines'),
      controller: _row,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: widget.books.length,
      itemBuilder: (context, index) {
        final book = widget.books[index];
        final visual = BookSpine.resolveVisual(
          book.bindingKey,
          theme.colorScheme,
        );
        final node = _bookFocus.putIfAbsent(book.id, () => FocusNode());
        return Semantics(
          button: true,
          label: [
            book.title,
            if (book.author.isNotEmpty) book.author,
          ].join(', '),
          hint: widget.pickUpHint,
          onTap: () => pickUpAt(index),
          excludeSemantics: true,
          child: InkWell(
            key: ValueKey('shelf-spine-${book.id}'),
            focusNode: node,
            onFocusChange: (focused) {
              if (focused && _phase == ShelfPhase.shelved) _select(index);
            },
            onTap: () => pickUpAt(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 72,
                    decoration: BoxDecoration(
                      color: visual.background,
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: visual.foreground,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title, style: theme.textTheme.titleMedium),
                        if (book.author.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            book.author,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _held(BoxConstraints constraints, ShelfBook book) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Localizations.of<L10n>(context, L10n);
    final enabled = _phase == ShelfPhase.held;
    final wide = constraints.maxWidth >= 700;
    final largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;
    final openLabel = book.isWishlist
        ? l10n?.shelfBooksToBuy ?? widget.shelfName ?? 'Books to buy'
        : l10n == null
        ? widget.openHint ?? 'Open book'
        : book.openAt > 0 && !book.finished
        ? l10n.tileContinueReadingTitle
        : l10n.journalReadBook;
    final coverWidth = wide
        ? 190.0
        : largeText
        ? 96.0
        : (constraints.maxWidth * 0.32).clamp(100.0, 144.0);
    final cover = SizedBox(
      width: coverWidth,
      height: coverWidth / 0.68,
      child: Semantics(
        button: enabled,
        label: book.title,
        hint: openLabel,
        onTap: enabled ? openBook : null,
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('held-book-cover'),
          onTap: enabled ? openBook : null,
          child: _FlatCover(book: book),
        ),
      ),
    );
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          key: const ValueKey('held-book-title'),
          style: wide
              ? theme.textTheme.headlineMedium
              : theme.textTheme.titleLarge,
        ),
        if (book.author.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            book.author,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (!book.isWishlist) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: book.openAt,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(book.openAt * 100).round()}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
    final secondary = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.optionsBuilder != null) ...[
          const SizedBox(height: 28),
          ExcludeFocus(
            excluding: !enabled,
            child: IgnorePointer(
              ignoring: !enabled,
              child: widget.optionsBuilder!(context, book),
            ),
          ),
        ],
        if (book.blurb?.isNotEmpty ?? false) ...[
          const SizedBox(height: 24),
          Text(book.blurb!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
    final summary = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cover,
        SizedBox(width: wide ? 32 : 20),
        Expanded(
          child: wide
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [details, secondary],
                )
              : details,
        ),
      ],
    );
    return TweenAnimationBuilder<double>(
      key: ValueKey('held-${book.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: _instant ? Duration.zero : ShelfStage.liftDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('held-book-details'),
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          key: const ValueKey('return-shelf-book'),
                          autofocus: true,
                          onPressed: enabled ? putBack : null,
                          icon: const Icon(Icons.arrow_back),
                          label: Text(
                            MaterialLocalizations.of(context).backButtonTooltip,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (largeText && !wide) ...[
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: cover,
                        ),
                        const SizedBox(height: 20),
                        details,
                      ] else
                        summary,
                      if (!wide) secondary,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('open-shelf-book'),
                    onPressed: enabled ? openBook : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      book.isWishlist
                          ? Icons.shopping_bag_outlined
                          : Icons.menu_book_outlined,
                    ),
                    label: Text(openLabel, textAlign: TextAlign.center),
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
        borderRadius: BorderRadius.circular(2),
        child: BookCoverImage(path: book.coverPath, fallback: fallback),
      ),
    );
  }
}
