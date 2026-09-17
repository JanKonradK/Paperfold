import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
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
    final selectedId =
        oldWidget.books.isEmpty ? null : oldWidget.books[_index].id;
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
    final reordered = oldWidget.books.length == widget.books.length &&
        oldWidget.books.indexed
            .any((entry) => entry.$2.id != widget.books[entry.$1].id);
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
      _bookFocus[book.id]?.requestFocus();
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

  Future<void> _reveal(int index, {bool focus = false}) async {
    if (!mounted || !_row.hasClients || index >= widget.books.length) return;
    final id = widget.books[index].id;
    if (_accessibleList) {
      final itemContext = _bookFocus[id]?.context;
      if (itemContext != null) {
        await Scrollable.ensureVisible(itemContext,
            duration: _instant ? Duration.zero : ShelfStage.runDuration);
      }
      if (mounted && focus) _bookFocus[id]?.requestFocus();
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
      await _row.animateTo(bounded,
          duration: ShelfStage.runDuration, curve: Curves.easeOutCubic);
    }
    if (mounted && focus) _bookFocus[id]?.requestFocus();
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
    if (key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final next = (key == LogicalKeyboardKey.arrowRight) != rtl;
    final target = (_index + (next ? 1 : -1)).clamp(0, widget.books.length - 1);
    _select(target);
    unawaited(_reveal(target, focus: true));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleKey,
      child: LayoutBuilder(builder: (context, constraints) {
        _accessibleList = MediaQuery.textScalerOf(context).scale(16) >= 24 ||
            constraints.maxHeight < 280;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Keep the native scroll position and focus nodes when a book is held.
            ExcludeFocus(
              excluding: _phase != ShelfPhase.shelved,
              child: Offstage(
                  offstage: _phase != ShelfPhase.shelved,
                  child: _shelf(constraints)),
            ),
            if (_phase != ShelfPhase.shelved && current != null)
              _held(constraints, current!),
          ],
        );
      }),
    );
  }

  Widget _shelf(BoxConstraints constraints) {
    if (_accessibleList) return _bookList();
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
                        if (book.author.isNotEmpty) book.author
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
                              top: Radius.circular(2)),
                          child: InkWell(
                            focusNode: node,
                            onFocusChange: (focused) {
                              if (focused && _phase == ShelfPhase.shelved) {
                                _select(index);
                              }
                            },
                            onTap: () => pickUpAt(index),
                            focusColor:
                                visual.foreground.withValues(alpha: 0.18),
                            hoverColor:
                                visual.foreground.withValues(alpha: 0.08),
                            child: SizedBox(
                                width: _width(book),
                                height: bookHeight,
                                child: _FlatSpine(book: book, visual: visual)),
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
                  top: BorderSide(
                      color: scheme.primary.withValues(alpha: 0.65))),
              boxShadow: [
                BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.22),
                    offset: const Offset(0, 6),
                    blurRadius: 9)
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Text(widget.pickUpHint ?? widget.shelfName ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
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
        final visual =
            BookSpine.resolveVisual(book.bindingKey, theme.colorScheme);
        final node = _bookFocus.putIfAbsent(book.id, () => FocusNode());
        return Semantics(
          button: true,
          label:
              [book.title, if (book.author.isNotEmpty) book.author].join(', '),
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
              child: Row(children: [
                Container(
                  width: 28,
                  height: 72,
                  decoration: BoxDecoration(
                    color: visual.background,
                    border: Border.symmetric(
                        horizontal:
                            BorderSide(color: visual.foreground, width: 2)),
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
                      Text(book.author,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ],
                )),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _held(BoxConstraints constraints, ShelfBook book) {
    final theme = Theme.of(context);
    final enabled = _phase == ShelfPhase.held;
    final wide = constraints.maxWidth >= 700;
    final coverHeight = (constraints.maxHeight * 0.47).clamp(140.0, 300.0);
    final cover = SizedBox(
      width: coverHeight * 0.68,
      height: coverHeight,
      child: Semantics(
        button: enabled,
        label: book.title,
        hint: widget.openHint,
        onTap: enabled ? openBook : null,
        excludeSemantics: true,
        child: InkWell(
            key: const ValueKey('held-book-cover'),
            onTap: enabled ? openBook : null,
            child: _FlatCover(book: book)),
      ),
    );
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(book.title,
            key: const ValueKey('held-book-title'),
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.headlineSmall),
        if (book.author.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(book.author,
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 16),
        Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 100,
              child: LinearProgressIndicator(value: book.openAt, minHeight: 2)),
          const SizedBox(width: 12),
          Text('${(book.openAt * 100).round()}%',
              style: theme.textTheme.labelLarge),
        ]),
        const SizedBox(height: 20),
        FilledButton.icon(
            key: const ValueKey('open-shelf-book'),
            onPressed: enabled ? openBook : null,
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(widget.openHint ?? 'Open book',
                textAlign: TextAlign.center)),
        if (widget.optionsBuilder != null) ...[
          const SizedBox(height: 20),
          IgnorePointer(
              ignoring: !enabled, child: widget.optionsBuilder!(context, book)),
        ],
        if (book.blurb?.isNotEmpty ?? false) ...[
          const SizedBox(height: 24),
          Text(book.blurb!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
    return TweenAnimationBuilder<double>(
      key: ValueKey('held-${book.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: _instant ? Duration.zero : ShelfStage.liftDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: SingleChildScrollView(
        key: const ValueKey('held-book-details'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(children: [
          Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                  key: const ValueKey('return-shelf-book'),
                  autofocus: true,
                  onPressed: enabled ? putBack : null,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                      MaterialLocalizations.of(context).backButtonTooltip))),
          const SizedBox(height: 12),
          Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    cover,
                    const SizedBox(width: 40),
                    Expanded(child: details)
                  ])
                : Column(
                    children: [cover, const SizedBox(height: 24), details]),
          )),
        ]),
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
    final title = book.volume == null
        ? book.title
        : book.title.replaceFirst(
            RegExp(r'[,\s:–—-]*(?:vol(?:ume)?\.?|book)\s*\d+(?:\.\d+)?\s*$',
                caseSensitive: false),
            '');
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
            vertical: BorderSide(color: ink.withValues(alpha: 0.12))),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxHeight < 230;
        final scaler = MediaQuery.textScalerOf(context);
        final titleLineHeight = scaler.scale(14) * 1.05;
        final authorHeight = scaler.scale(9) * 1.1 + 5;
        final textSpace = constraints.maxWidth - 12;
        final showAuthor = !compact &&
            book.author.isNotEmpty &&
            textSpace >= titleLineHeight + authorHeight;
        final titleLines =
            ((textSpace - (showAuthor ? authorHeight : 0)) / titleLineHeight)
                .floor()
                .clamp(1, 2);
        return Padding(
          padding:
              EdgeInsets.symmetric(horizontal: 6, vertical: compact ? 8 : 14),
          child: Column(children: [
            _rule(ink),
            if (book.binding == BookBinding.hardback) ...[
              const SizedBox(height: 3),
              _rule(ink),
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
                        child: Text(title,
                            maxLines: titleLines,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              fontFamily: PaperfoldTypeTokens.journalFamily,
                              height: 1.05,
                            )),
                      ),
                      if (showAuthor) ...[
                        const SizedBox(height: 5),
                        Text(book.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink,
                              fontFamily: PaperfoldTypeTokens.chromeFamily,
                              fontSize: 9,
                              height: 1.1,
                              letterSpacing: 0.25,
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _rule(ink),
            if (book.volume != null) ...[
              const SizedBox(height: 7),
              Text(book.volume!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontFamily: PaperfoldTypeTokens.journalFamily,
                    fontSize: compact ? 16 : 20,
                    height: 1.1,
                  )),
            ] else ...[
              const SizedBox(height: 3),
              _rule(ink),
            ],
          ]),
        );
      }),
    );
  }

  Widget _rule(Color ink) => SizedBox(
      height: 0.75,
      width: double.infinity,
      child: ColoredBox(color: ink.withValues(alpha: 0.55)));
}

class _FlatCover extends StatelessWidget {
  const _FlatCover({required this.book});
  final ShelfBook book;

  @override
  Widget build(BuildContext context) {
    final visual =
        BookSpine.resolveVisual(book.bindingKey, Theme.of(context).colorScheme);
    final fallback = ColoredBox(
      color: visual.background,
      child: Stack(fit: StackFit.expand, children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Ornament(
                ornament: PaperfoldOrnament.rectangularVineFrame,
                tint: visual.foreground.withValues(alpha: 0.65))),
        Center(
            child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(book.title,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: visual.foreground)))),
      ]),
    );
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(0, 8),
            blurRadius: 16)
      ]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: book.coverPath == null ||
                book.coverPath!.isEmpty ||
                kIsWeb ||
                !File(book.coverPath!).existsSync()
            ? fallback
            : Image.file(File(book.coverPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => fallback),
      ),
    );
  }
}
