import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/widgets/bookshelf/book_detail_route.dart';

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';

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
    this.onOptions,
    this.headerBuilder,
  });

  final List<ShelfRow> shelves;
  final WidgetBuilder? headerBuilder;
  final int initialShelf;

  /// Opens the selected book detail.
  final ValueChanged<ShelfBook>? onOpen;
  final ValueChanged<ShelfBook>? onOptions;

  final ValueChanged<int>? onShelfChanged;

  /// Quick actions for the selected book.
  final Widget Function(BuildContext context, ShelfBook book)? optionsBuilder;

  /// What stands on a shelf with nothing on it.
  final Widget Function(BuildContext context, ShelfRow shelf)? emptyBuilder;

  /// Legacy callback; direct routes never hold a book.
  final ValueChanged<bool>? onHoldingChanged;

  final String? pickUpHint;
  final String? openHint;
  final bool showSignposts;
  final bool showCovers;

  @override
  State<Bookcase> createState() => BookcaseState();
}

class BookcaseState extends State<Bookcase>
    with SingleTickerProviderStateMixin {
  final _stages = <int, GlobalKey<ShelfStageState>>{};
  late int _shelf;
  late final AnimationController _selection;
  int get shelf => _shelf;
  ShelfStageState? get activeStage => _stages[_shelf]?.currentState;
  @override
  void initState() {
    super.initState();
    _shelf = widget.initialShelf.clamp(
      0,
      math.max(0, widget.shelves.length - 1),
    );
    _selection = AnimationController(vsync: this, value: 1);
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Future<void> climbTo(int index) async {
    if (index < 0 || index >= widget.shelves.length || index == _shelf) return;
    setState(() => _shelf = index);
    widget.onShelfChanged?.call(index);
    _selection.duration = bookDetailDuration(context) == Duration.zero
        ? Duration.zero
        : PaperfoldMotion.shift;
    _selection.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shelves.isEmpty) return const SizedBox.shrink();
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _selection,
        curve: const Interval(.3, 1, curve: PaperfoldMotion.settle),
      ),
      child: IndexedStack(
        index: _shelf,
        children: [
          for (var i = 0; i < widget.shelves.length; i++)
            if (i == _shelf || _stages.containsKey(i))
              ExcludeFocus(
                excluding: i != _shelf,
                child: HeroMode(
                  enabled: i == _shelf,
                  child: RepaintBoundary(
                    child: ShelfStage(
                      headerBuilder: widget.headerBuilder,
                      emptyBuilder: widget.emptyBuilder == null
                          ? null
                          : (context) => widget.emptyBuilder!(
                              context,
                              widget.shelves[i],
                            ),
                      key: _stages.putIfAbsent(
                        i,
                        GlobalKey<ShelfStageState>.new,
                      ),
                      books: widget.shelves[i].books,
                      shelfName: widget.shelves[i].name,
                      showCovers: widget.showCovers,
                      onOpen: widget.onOpen,
                      onOptions: widget.onOptions,
                      optionsBuilder: widget.optionsBuilder,
                      pickUpHint: widget.pickUpHint,
                      openHint: widget.openHint,
                    ),
                  ),
                ),
              )
            else
              const SizedBox.shrink(),
        ],
      ),
    );
  }
}
