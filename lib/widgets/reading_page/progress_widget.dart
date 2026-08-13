import 'dart:async';

import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/book_player/epub_player.dart';
import 'package:paperfold/page/reading_page.dart';
import 'package:flutter/material.dart';

class ProgressWidget extends StatefulWidget {
  final GlobalKey<EpubPlayerState> epubPlayerKey;
  final Function(bool) showOrHideAppBarAndBottomBar;

  const ProgressWidget({
    super.key,
    required this.epubPlayerKey,
    required this.showOrHideAppBarAndBottomBar,
  });

  @override
  State<ProgressWidget> createState() => _ProgressWidgetState();
}

class _ProgressWidgetState extends State<ProgressWidget> {
  Timer? _sliderTimer;
  double _readProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _readProgress = epubPlayerKey.currentState!.percentage;
  }

  @override
  void dispose() {
    _sliderTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final player = widget.epubPlayerKey.currentState!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            player.chapterTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n.pageTurnActionPrev,
                onPressed: () => setState(player.prevChapter),
              ),
              Expanded(
                child: Slider(
                  value: _readProgress,
                  semanticFormatterCallback: (value) =>
                      '${(value * 100).round()}%',
                  onChanged: (value) {
                    setState(() {
                      _readProgress = value;
                    });
                    _sliderTimer?.cancel();
                    _sliderTimer = Timer(
                      const Duration(milliseconds: 100),
                      () async {
                        await player.goToPercentage(value);
                        Timer(const Duration(milliseconds: 300), () {
                          if (mounted) setState(() {});
                        });
                      },
                    );
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n.pageTurnActionNext,
                onPressed: () => setState(player.nextChapter),
              ),
            ],
          ),
          Row(
            children: [
              ProgressDisplay(
                mainText: player.chapterCurrentPage.toString(),
                subText: l10n.readingPageCurrentPage,
              ),
              ProgressDisplay(
                mainText: player.chapterTotalPages.toString(),
                subText: l10n.readingPageChapterPages,
              ),
              ProgressDisplay(
                mainText: (player.percentage * 100).toStringAsFixed(1),
                subText: '%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One figure with its caption.
///
/// The figure takes the title role and the caption the label role, so both
/// follow the system text scale instead of a size fixed here.
class ProgressDisplay extends StatelessWidget {
  const ProgressDisplay({
    super.key,
    required this.mainText,
    required this.subText,
  });

  final String mainText;
  final String subText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Semantics(
        label: '$subText $mainText',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              mainText,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              subText,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
