import 'package:flutter/material.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';

/// Which reader tool holds the bottom panel.
///
/// Contents is in this list even though it opens the drawer rather than a
/// panel, because the reader still needs to see which tool they asked for.
enum ReaderTool {
  none,
  contents,
  notes,
  progress,
  style,
}

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
    this.panel,
  });

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

  static const Duration _duration = Duration(milliseconds: 240);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final duration = media.disableAnimations ? Duration.zero : _duration;

    return ExcludeFocus(
      excluding: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: IgnorePointer(
          ignoring: !visible,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: duration,
                  curve: _curve,
                  child: GestureDetector(
                    onTap: onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child:
                        ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
                  ),
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
                    child: _constrain(_topBar(context)),
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
                    child: _constrain(_bottomShell(context, media)),
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
  Widget _constrain(Widget child) => Align(
        alignment: Alignment.center,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: child,
        ),
      );

  Widget _topBar(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
      child: PaperfoldGlassSurface(
        blurSigma: 10,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 56,
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
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomShell(BuildContext context, MediaQueryData media) {
    final l10n = L10n.of(context);
    final open = panel != null;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
      child: PaperfoldGlassSurface(
        blurSigma: 18,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (open)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: media.size.height * 0.5,
                  ),
                  child: panel,
                ),
              Row(
                children: [
                  _Tab(
                    icon: Icons.toc,
                    label: l10n.readingContents,
                    selected: activeTool == ReaderTool.contents,
                    onPressed: onContents,
                  ),
                  _Tab(
                    icon: Icons.edit_outlined,
                    label: l10n.notes,
                    selected: activeTool == ReaderTool.notes,
                    onPressed: onNotes,
                  ),
                  _Tab(
                    icon: Icons.data_usage,
                    label: l10n.bookshelfProgress,
                    selected: activeTool == ReaderTool.progress,
                    onPressed: onProgress,
                  ),
                  _Tab(
                    icon: Icons.palette_outlined,
                    label: l10n.readingPageStyle,
                    selected: activeTool == ReaderTool.style,
                    onPressed: onStyle,
                  ),
                ],
              ),
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
      offset: visible ? Offset.zero : from,
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
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return Expanded(
      child: Padding(
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
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: duration,
                  curve: ReaderChrome._curve,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        selected ? scheme.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected ? scheme.onPrimaryContainer : null,
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
