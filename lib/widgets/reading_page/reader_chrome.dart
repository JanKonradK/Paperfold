import 'dart:math' as math;

import 'package:paperfold/utils/paperfold_layout.dart';
import 'package:paperfold/widgets/common/paperfold_transition.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';

/// Which reader tool holds the bottom panel.
///
/// Contents is in this list even though it opens the drawer rather than a
/// panel, because the reader still needs to see which tool they asked for.
enum ReaderTool { none, contents, search, bookmarks, notes, progress, style }

/// The chrome that sits over the book: one glass bar at each end.
///
/// The bars belong to the modern side of Paperfold, so they keep Material
/// structure and behaviour and take their character from the glass, the type
/// roles and the spacing. They never cover the page while reading; they arrive
/// only when the reader asks for them, and they leave on a tap anywhere else.
class ReaderChrome extends StatelessWidget {
  const ReaderChrome({
    super.key,
    required this.visible,
    required this.title,
    required this.bookmarkExists,
    required this.activeTool,
    required this.onDismiss,
    required this.onBack,
    required this.onBookmark,
    required this.onCopyChapter,
    required this.onBookDetails,
    required this.onContents,
    required this.onNotes,
    required this.onProgress,
    required this.onStyle,
    this.onSearch,
    this.onBookmarks,
    this.onAdvanced,
    this.chapter = '',
    this.percentage = 0,
    this.panel,
    this.onFacingPage,
  });

  final VoidCallback? onSearch;
  final VoidCallback? onBookmarks;
  final VoidCallback? onAdvanced;
  final String chapter;
  final double percentage;
  final bool visible;
  final String title;
  final bool bookmarkExists;
  final ReaderTool activeTool;
  final VoidCallback onDismiss;
  final VoidCallback onBack;
  final VoidCallback onBookmark;
  final VoidCallback onCopyChapter;
  final VoidCallback onBookDetails;
  final VoidCallback onContents;
  final VoidCallback onNotes;
  final VoidCallback onProgress;
  final VoidCallback onStyle;
  final Widget? panel;
  final VoidCallback? onFacingPage;

  static const Curve _curve = PaperfoldMotion.settle;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final duration = paperfoldTransitionDuration(
      context,
      PaperfoldMotion.shift,
    );

    final side =
        PaperfoldLayout.of(context).landscape &&
        media.size.width - media.padding.horizontal >= 840 &&
        panel != null;
    return ExcludeFocus(
      excluding: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: IgnorePointer(
          ignoring: !visible,
          child: Stack(
            children: [
              // A tap on the page hides the bars. The page itself is not
              // dimmed: the bars float over it, so the reader keeps the
              // passage in view.
              Positioned.fill(
                child: GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: _Reveal(
                  visible: visible,
                  duration: duration,
                  from: const Offset(0, -1),
                  child: SafeArea(
                    bottom: false,
                    child: _constrain(
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: side ? 384 : 0,
                        ),
                        child: _topBar(context),
                      ),
                    ),
                  ),
                ),
              ),
              if (side)
                PositionedDirectional(
                  end: media.padding.right + 12,
                  top: media.padding.top + 12,
                  bottom: media.padding.bottom + 12,
                  width: 360,
                  child: _Reveal(
                    visible: visible,
                    duration: duration,
                    from: const Offset(0, 1),
                    child: PaperfoldGlassSurface(
                      borderRadius: PaperfoldShape.frameRadius,
                      tier: PaperfoldGlassTier.solid,
                      child: panel!,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _Reveal(
                  visible: visible,
                  duration: duration,
                  from: const Offset(0, 1),
                  child: SafeArea(
                    top: false,
                    child: _constrain(
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: side ? 384 : 0,
                        ),
                        child: _bottomShell(context, media, side),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // heightFactor pins this to the height of the bar. Without it the alignment
  // would expand to the whole stack and park both bars in the middle of the
  // screen.
  Widget _constrain(Widget child) =>
      Align(alignment: Alignment.center, heightFactor: 1, child: child);

  Widget _topBar(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
      child: PaperfoldGlassSurface(
        borderRadius: PaperfoldShape.frameRadius,
        child: SizedBox(
          height: PaperfoldLayout.of(context).landscape ? 48 : 56,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.readingPageBookmark,
                isSelected: bookmarkExists,
                icon: const Icon(Icons.bookmark_border),
                selectedIcon: const Icon(Icons.bookmark),
                onPressed: onBookmark,
              ),
              PopupMenuButton<VoidCallback>(
                icon: const Icon(Icons.more_vert),
                tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                onSelected: (action) => action(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: onCopyChapter,
                    child: Text(l10n.readingPageCopyChapterContent),
                  ),
                  PopupMenuItem(
                    value: onBookDetails,
                    child: Text(l10n.readingPageBookDetails),
                  ),
                  if (onAdvanced != null)
                    PopupMenuItem(
                      value: onAdvanced,
                      child: Text(l10n.readerAdvancedSettings),
                    ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomShell(BuildContext context, MediaQueryData media, bool side) {
    final l10n = L10n.of(context);
    final layout = PaperfoldLayout.of(context);
    final safeH =
        media.size.height - media.padding.vertical - media.viewInsets.bottom;
    final open = panel != null && !side;
    final tools = [
      (Icons.tune, l10n.readerQuickSettings, ReaderTool.style, onStyle),
      (Icons.toc, l10n.readingContents, ReaderTool.contents, onContents),
      (
        Icons.search,
        l10n.contextMenuSearch,
        ReaderTool.search,
        onSearch ?? onContents,
      ),
      (
        Icons.bookmarks_outlined,
        l10n.readingBookmark,
        ReaderTool.bookmarks,
        onBookmarks ?? onContents,
      ),
      (Icons.edit_outlined, l10n.notes, ReaderTool.notes, onNotes),
    ];
    final progress = Semantics(
      label: l10n.bookshelfProgress,
      value: '$chapter ${(percentage * 100).round()}%',
      excludeSemantics: true,
      button: true,
      onTap: onProgress,
      selected: activeTool == ReaderTool.progress,
      child: InkWell(
        onTap: onProgress,
        borderRadius: PaperfoldShape.frameRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.data_usage, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chapter.isEmpty ? l10n.bookshelfProgress : chapter,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${(percentage * 100).round()}%'),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
    final toolRow = LayoutBuilder(
      builder: (context, constraints) {
        final wrap =
            constraints.maxWidth < 360 || media.textScaler.scale(12) > 18;
        final width = constraints.maxWidth / (wrap ? 3 : 5);
        return Wrap(
          children: [
            for (final tool in tools)
              SizedBox(
                width: width,
                child: _Tab(
                  icon: tool.$1,
                  label: tool.$2,
                  selected: activeTool == tool.$3,
                  onPressed: tool.$4,
                ),
              ),
          ],
        );
      },
    );
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        12,
        0,
        12,
        12 + media.viewInsets.bottom,
      ),
      child: PaperfoldGlassSurface(
        borderRadius: PaperfoldShape.frameRadius,
        tier: open ? PaperfoldGlassTier.solid : PaperfoldGlassTier.floating,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: math.max(0, safeH - 80)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (open)
                Flexible(
                  child: SizedBox(
                    height: layout.landscape
                        ? safeH * 0.60
                        : math.min(
                            layout.tablet ? 400 : 360,
                            safeH * (layout.tablet ? 0.40 : 0.48),
                          ),
                    child: panel,
                  ),
                ),
              if (layout.landscape &&
                  !side &&
                  media.size.width >= 720 &&
                  media.textScaler.scale(12) <= 18)
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: progress),
                      Expanded(flex: 5, child: toolRow),
                    ],
                  ),
                )
              else ...[
                progress,
                toolRow,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Slides a bar in from off screen and fades it, or places it at rest when the
/// system removes animations.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.visible,
    required this.duration,
    required this.from,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Offset from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible || !PaperfoldVisualPolicy.motionAllowed(context)
          ? Offset.zero
          : from,
      duration: duration,
      curve: ReaderChrome._curve,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: ReaderChrome._curve,
        child: child,
      ),
    );
  }
}

/// One tool in the bottom shell.
///
/// The 48dp target and the 8dp gap to its neighbour come from the shared rule.
/// The selected indicator matches the home navigation shell, so the two shells
/// read as one system.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = paperfoldTransitionDuration(
      context,
      PaperfoldMotion.shift,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: PaperfoldShape.controlShape,
              child: AnimatedContainer(
                duration: duration,
                curve: ReaderChrome._curve,
                constraints: const BoxConstraints(minHeight: 48),
                decoration: ShapeDecoration(
                  color: selected
                      ? scheme.primaryContainer
                      : Colors.transparent,
                  shape: PaperfoldShape.controlShape,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: selected ? scheme.onPrimaryContainer : null,
                      ),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
