import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/book_player/epub_player.dart';
import 'package:paperfold/widgets/reading_page/widgets/book_toc.dart';
import 'package:paperfold/widgets/reading_page/widgets/bookmark.dart';
import 'package:material_ui/material_ui.dart';

class TocWidget extends StatefulWidget {
  const TocWidget({
    super.key,
    required this.epubPlayerKey,
    required this.hideAppBarAndBottomBar,
    required this.closeDrawer,
  });

  final GlobalKey<EpubPlayerState> epubPlayerKey;
  final Function hideAppBarAndBottomBar;
  final VoidCallback closeDrawer;

  @override
  State<TocWidget> createState() => _TocWidgetState();
}

class _TocWidgetState extends State<TocWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: L10n.of(context).readingContents),
            Tab(text: L10n.of(context).readingBookmark),
          ],
        ),
        Expanded(
          // Horizontal inset only. Padding on all four sides put a dead band
          // above and below the list, so chapters scrolled to a stop short of
          // the drawer's own edges instead of running under them.
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16.0),
            child: TabBarView(
              controller: _tabController,
              children: [
                buildBookToc(),
                buildBookmarkList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildBookmarkList() {
    return BookmarkWidget(
      epubPlayerKey: widget.epubPlayerKey,
      onNavigate: () {
        widget.hideAppBarAndBottomBar(false);
        widget.closeDrawer();
      },
    );
  }

  BookToc buildBookToc() {
    return BookToc(
      epubPlayerKey: widget.epubPlayerKey,
      hideAppBarAndBottomBar: widget.hideAppBarAndBottomBar,
      closeDrawer: widget.closeDrawer,
    );
  }
}
