import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';

/// The whole piece of furniture: several shelves, one above another.
///
/// The view climbs it. A shelf is not a page in a list that happens to be laid
/// out vertically - it is a board at a height, and the one above it is a board
/// at a greater height. Dragging up moves the reader down the bookcase, and
/// what arrives is the board that was always there.
///
/// The vertical run and the horizontal run through each shelf's books are two
/// nested pagers rather than one gesture recogniser doing both. Nesting is what
/// gives each direction real physics and a real snap, and it is what lets the
/// gesture arena decide which of the two a drag belongs to without either of
/// them having to guess from an angle.
class Bookcase extends StatefulWidget {
  const Bookcase({
    super.key,
    required this.shelves,
    this.initialShelf = 0,
    this.onOpen,
    this.onShelfChanged,
    this.optionsBuilder,
    this.emptyBuilder,
    this.onHoldingChanged,
    this.pickUpHint,
    this.openHint,
    this.showSignposts = true,
    this.showCovers = false,
  });

  final List<ShelfRow> shelves;
  final int initialShelf;

  /// Called once a book has opened and the stage has arrived.
  final ValueChanged<ShelfBook>? onOpen;

  final ValueChanged<int>? onShelfChanged;

  /// The options shown across the top of a held book.
  final Widget Function(BuildContext context, ShelfBook book)? optionsBuilder;

  /// What stands on a shelf with nothing on it.
  final Widget Function(BuildContext context, ShelfRow shelf)? emptyBuilder;

  /// Told when a book comes off a shelf and when it goes back. Whoever owns
  /// the back gesture needs to know: a held book is something to return.
  final ValueChanged<bool>? onHoldingChanged;

  final String? pickUpHint;
  final String? openHint;
  final bool showSignposts;
  final bool showCovers;

  @override
  State<Bookcase> createState() => BookcaseState();
}

class BookcaseState extends State<Bookcase> {
  late final PageController _climb;
  final Map<int, GlobalKey<ShelfStageState>> _stages = {};

  int _shelf = 0;
  double _page = 0;

  /// Climbing is off while a book is off the shelf. A reader holding a book
  /// has taken it out of the row; moving the furniture under it would leave
  /// them holding something from a shelf they can no longer see.
  bool _holding = false;

  int get shelf => _shelf;

  ShelfStageState? get activeStage => _stages[_shelf]?.currentState;

  @override
  void initState() {
    super.initState();
    _shelf =
        widget.initialShelf.clamp(0, math.max(0, widget.shelves.length - 1));
    _page = _shelf.toDouble();
    _climb = PageController(initialPage: _shelf)..addListener(_readClimb);
  }

  @override
  void didUpdateWidget(covariant Bookcase oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An empty-state widget replaces the stage, so it cannot report a return.
    if (_holding &&
        (_shelf >= widget.shelves.length || widget.shelves[_shelf].isEmpty)) {
      _holding = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_holding) widget.onHoldingChanged?.call(false);
      });
    }
  }

  @override
  void dispose() {
    _climb
      ..removeListener(_readClimb)
      ..dispose();
    super.dispose();
  }

  void _readClimb() {
    if (!_climb.hasClients) return;
    if (!_climb.position.hasContentDimensions) return;
    final page = _climb.page;
    if (page == null || page == _page) return;
    setState(() => _page = page);
    final settled =
        page.round().clamp(0, math.max(0, widget.shelves.length - 1)).toInt();
    if (settled != _shelf && (page - settled).abs() < 0.5) {
      _shelf = settled;
      widget.onShelfChanged?.call(settled);
    }
  }

  GlobalKey<ShelfStageState> _keyFor(int index) =>
      _stages.putIfAbsent(index, () => GlobalKey<ShelfStageState>());

  @override
  Widget build(BuildContext context) {
    if (widget.shelves.isEmpty) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _climb,
          scrollDirection: Axis.vertical,
          // The cover grid owns vertical scrolling. Shelf chips still switch
          // pages, without a grid gesture moving to a different collection.
          physics: _holding || widget.showCovers
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          itemCount: widget.shelves.length,
          itemBuilder: (context, index) {
            final shelf = widget.shelves[index];
            if (shelf.isEmpty && widget.emptyBuilder != null) {
              return widget.emptyBuilder!(context, shelf);
            }
            return ShelfStage(
              key: _keyFor(index),
              books: shelf.books,
              shelfName: shelf.name,
              showCovers: widget.showCovers,
              onOpen: widget.onOpen,
              optionsBuilder: widget.optionsBuilder,
              pickUpHint: widget.pickUpHint,
              openHint: widget.openHint,
              onPhaseChanged: (phase) {
                final holding = phase != ShelfPhase.shelved;
                if (holding == _holding) return;
                setState(() => _holding = holding);
                widget.onHoldingChanged?.call(holding);
              },
            );
          },
        ),
        // The names of the boards above and below, so the reader knows what
        // climbing gets them before they climb. They fade out while a book is
        // held, because at that point there is nowhere to climb to.
        //
        // Faded, not deleted. They used to be dropped from the tree the instant
        // a book left the shelf, so two labels vanished mid-frame while the
        // book was still rising: the one motion on the screen had a hole cut in
        // it. IgnorePointer goes with the fade, or a signpost nobody can see
        // still takes the tap meant for the book.
        if (widget.showSignposts)
          IgnorePointer(
            ignoring: _holding,
            child: AnimatedOpacity(
              opacity: _holding ? 0 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: Stack(fit: StackFit.expand, children: _signposts()),
            ),
          ),
      ],
    );
  }

  List<Widget> _signposts() {
    final theme = Theme.of(context);
    // The way out of this shelf is not a footnote. These were set in the
    // smallest label the theme has, which made the one instruction on the
    // screen the least readable thing on it.
    final style = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurface,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w600,
    );

    return [
      if (_shelf > 0)
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: _Signpost(
            name: widget.shelves[_shelf - 1].name,
            icon: Icons.keyboard_arrow_up_rounded,
            iconFirst: true,
            style: style,
            onTap: () => climbTo(_shelf - 1),
          ),
        ),
      if (_shelf < widget.shelves.length - 1)
        Positioned(
          bottom: 6,
          left: 0,
          right: 0,
          child: _Signpost(
            name: widget.shelves[_shelf + 1].name,
            icon: Icons.keyboard_arrow_down_rounded,
            iconFirst: false,
            style: style,
            onTap: () => climbTo(_shelf + 1),
          ),
        ),
    ];
  }

  /// Moves to another shelf. Used by the signposts and by anything outside
  /// that wants to put the reader on a particular board.
  Future<void> climbTo(int index) async {
    if (_holding || index < 0 || index >= widget.shelves.length) return;
    if (!_climb.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _climb.jumpToPage(index);
      return;
    }
    await _climb.animateToPage(
      index,
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeInOutCubic,
    );
  }
}

/// The name of a neighbouring shelf, with the direction it lies in.
class _Signpost extends StatelessWidget {
  const _Signpost({
    required this.name,
    required this.icon,
    required this.iconFirst,
    required this.style,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final bool iconFirst;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      name.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    final arrow = Icon(icon, size: 26, color: style?.color);
    return Center(
      child: Semantics(
        button: true,
        label: name,
        onTap: onTap,
        excludeSemantics: true,
        // On its own plate, so the name is read against something rather than
        // against whatever part of the shelf happens to be behind it.
        child: PaperfoldGlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          // No backdrop filter. This plate sits over the row, and a blur is
          // the one effect that cannot be cached: the compositor reads the
          // scene back and blurs it again on every frame of a scroll. The
          // tint is already three quarters opaque, so it was buying almost
          // nothing and costing about a millisecond a frame.
          allowBlur: false,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: iconFirst
                      ? [
                          arrow,
                          const SizedBox(width: 8),
                          Flexible(child: label)
                        ]
                      : [
                          Flexible(child: label),
                          const SizedBox(width: 8),
                          arrow,
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
