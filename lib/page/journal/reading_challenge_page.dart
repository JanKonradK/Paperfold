import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/dao/challenge.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/journal/book_review_page.dart';
import 'package:paperfold/providers/reading_challenge.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/widgets/ornament.dart';

/// The reading challenge: one painted spine for every book of the year.
///
/// plan.md Section 8 lists the challenge page and the tracker shelf as two
/// pages. They are one page here, because they are one shelf: the spines are
/// the challenge, and the three-state legend is what the tracker shelf added.
class ReadingChallengePage extends ConsumerWidget {
  const ReadingChallengePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = L10n.of(context);
    final AsyncValue<ReadingChallengeData> challenge =
        ref.watch(readingChallengeProvider);
    final int selectedYear = ref.watch(trackedChallengeYearProvider);
    final int currentYear = DateTime.now().year;

    void stepYear(int amount) {
      ref.read(trackedChallengeYearProvider.notifier).state =
          selectedYear + amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.challengeTitle),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('challenge-previous-year'),
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.challengePreviousYear,
            onPressed: selectedYear > 1 ? () => stepYear(-1) : null,
          ),
          IconButton(
            key: const ValueKey<String>('challenge-next-year'),
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.challengeNextYear,
            onPressed: selectedYear < currentYear ? () => stepYear(1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: l10n.challengeSetTarget,
            onPressed: challenge.hasValue
                ? () => _editTarget(context, ref, challenge.requireValue)
                : null,
          ),
        ],
      ),
      body: challenge.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _ChallengeMessage(
          title: l10n.shelfLoadErrorTitle,
          body: l10n.shelfLoadErrorBody,
          actionLabel: l10n.commonRetry,
          onAction: () => ref.read(readingChallengeProvider.notifier).refresh(),
        ),
        data: (ReadingChallengeData data) => _ChallengeView(data: data),
      ),
    );
  }

  Future<void> _editTarget(
    BuildContext context,
    WidgetRef ref,
    ReadingChallengeData data,
  ) async {
    final L10n l10n = L10n.of(context);
    final TextEditingController controller =
        TextEditingController(text: data.target.toString());

    final int? chosen = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.challengeSetTarget),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            labelText: l10n.challengeTargetLabel,
            helperText: l10n.challengeTargetRange,
          ),
          onSubmitted: (String value) =>
              Navigator.of(context).pop(int.tryParse(value.trim())),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text.trim())),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();

    if (chosen != null) {
      await ref.read(readingChallengeProvider.notifier).setTarget(chosen);
    }
  }
}

class _ChallengeView extends ConsumerWidget {
  const _ChallengeView({required this.data});

  final ReadingChallengeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = L10n.of(context);
    final ThemeData theme = Theme.of(context);
    final int over = data.finishedCount - data.target;
    final int pace = data.paceDelta;
    final String paceLabel = pace > 0
        ? l10n.challengePaceAhead(pace)
        : pace < 0
            ? l10n.challengePaceBehind(-pace)
            : l10n.challengePaceOnTrack;

    return RefreshIndicator(
      onRefresh: () => ref.read(readingChallengeProvider.notifier).refresh(),
      child: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          // The floating glass bar overlays content, so the shelf needs room to
          // clear it as well as the gesture inset.
          bottom: 96 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: <Widget>[
          Text(
            l10n.challengeYearTitle(data.year.toString()),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.challengeProgress(data.finishedCount, data.target),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    pace < 0
                        ? Icons.trending_down
                        : pace > 0
                            ? Icons.trending_up
                            : Icons.trending_flat,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(paceLabel, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          l10n.challengePaceExpected(data.expectedFinished),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (over > 0) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              l10n.challengeOverTarget(over),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
          const SizedBox(height: 16),
          const _ChallengeLegend(),
          const SizedBox(height: 20),
          if (data.finished.isEmpty && data.readingNow.isEmpty) ...<Widget>[
            _ChallengeEmptyState(
              title: l10n.challengeEmptyTitle,
              body: l10n.challengeEmptyBody,
            ),
            const SizedBox(height: 20),
          ],
          _ChallengeShelf(data: data),
        ],
      ),
    );
  }
}

class _ChallengeLegend extends StatelessWidget {
  const _ChallengeLegend();

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: <Widget>[
        _LegendKey(
          color: scheme.primary,
          label: l10n.challengeLegendFinished,
        ),
        _LegendKey(
          color: scheme.secondary,
          label: l10n.challengeLegendReading,
        ),
        _LegendKey(
          color: null,
          outline: scheme.outlineVariant,
          label: l10n.challengeLegendEmpty,
        ),
      ],
    );
  }
}

class _ChallengeEmptyState extends StatelessWidget {
  const _ChallengeEmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.auto_stories_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendKey extends StatelessWidget {
  const _LegendKey({required this.color, required this.label, this.outline});

  final Color? color;
  final Color? outline;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            border: color == null
                ? Border.all(color: outline ?? theme.colorScheme.outline)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.labelLarge),
      ],
    );
  }
}

/// The shelf itself.
///
/// One canvas, not one widget per spine. plan.md Section 11.2 names a hundred
/// laid-out widgets on one screen as the third most likely source of jank in
/// the project, and the target can go higher than a hundred.
class _ChallengeShelf extends StatelessWidget {
  const _ChallengeShelf({required this.data});

  final ReadingChallengeData data;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextDirection textDirection = Directionality.of(context);
    // The whole shelf grows with the system text setting, because the numbers
    // are painted into the spines and cannot grow on their own.
    final double scale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _ChallengeLayout layout = _ChallengeLayout(
          width: constraints.maxWidth,
          slots: data.target,
          scale: scale,
        );

        void openSlot(int slot) {
          final Book? book = data.bookForSlot(slot);
          if (book == null) {
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => BookReviewPage(book: book),
            ),
          );
        }

        return GestureDetector(
          onTapUp: (TapUpDetails details) {
            final int? slot = layout.slotAt(details.localPosition);
            if (slot == null) {
              return;
            }
            openSlot(slot);
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, layout.height),
            painter: _ChallengeShelfPainter(
              data: data,
              layout: layout,
              scheme: scheme,
              textDirection: textDirection,
              wood: PaperfoldTokens.wood(scheme.brightness),
              shelfLabel: l10n.challengeShelfSemanticLabel(
                data.finishedCount,
                data.target,
                data.readingNow.length,
              ),
              slotLabel: (int slot) {
                final Book? book = data.bookForSlot(slot);
                return book == null
                    ? l10n.challengeSlotEmpty(slot)
                    : l10n.challengeSlotFilled(slot, book.title);
              },
              onSlotTap: openSlot,
            ),
          ),
        );
      },
    );
  }
}

/// Where every spine sits. Shared by the painter and by hit testing, so a tap
/// can never land on a spine the paint did not draw there.
class _ChallengeLayout {
  _ChallengeLayout({
    required this.width,
    required int slots,
    required this.scale,
  }) : slots = slots.clamp(
          ChallengeDao.minimumTarget,
          ChallengeDao.maximumTarget,
        ) {
    columns = (width / touchExtent).floor().clamp(1, this.slots);
    rows = (this.slots / columns).ceil();
    final double rowWidth = columns * touchExtent;
    leftPadding = (width - rowWidth) / 2;
  }

  static const double _baseSpineWidth = 26;
  static const double _baseTouchExtent = 48;
  static const double _baseSpineHeight = 78;
  static const double _baseBoardThickness = 6;
  static const double _baseRowGap = 18;

  final double width;
  final int slots;
  final double scale;

  late final int columns;
  late final int rows;
  late final double leftPadding;

  double get spineWidth => _baseSpineWidth * scale;
  double get touchExtent => _baseTouchExtent * scale;
  double get spineHeight => _baseSpineHeight * scale;
  double get boardThickness => _baseBoardThickness * scale;
  double get rowGap => _baseRowGap * scale;

  double get rowHeight => spineHeight + boardThickness + rowGap;
  double get height => rows * rowHeight;

  /// The rectangle of a one-based [slot].
  Rect spineRect(int slot) {
    final int index = slot - 1;
    final int row = index ~/ columns;
    final int column = index % columns;
    final double cellLeft = leftPadding + column * touchExtent;
    final double left = cellLeft + (touchExtent - spineWidth) / 2;
    final double top = row * rowHeight;
    return Rect.fromLTWH(left, top, spineWidth, spineHeight);
  }

  /// The logical target for a one-based [slot]. It stays at least 48 dp wide
  /// even though the painted spine is narrow.
  Rect touchRect(int slot) {
    final int index = slot - 1;
    final int row = index ~/ columns;
    final int column = index % columns;
    return Rect.fromLTWH(
      leftPadding + column * touchExtent,
      row * rowHeight,
      touchExtent,
      math.max(spineHeight, touchExtent),
    );
  }

  /// The board under [row], zero-based.
  Rect boardRect(int row) {
    return Rect.fromLTWH(
      0,
      row * rowHeight + spineHeight,
      width,
      boardThickness,
    );
  }

  /// The one-based slot under [position], or null.
  int? slotAt(Offset position) {
    for (int slot = 1; slot <= slots; slot++) {
      if (touchRect(slot).contains(position)) {
        return slot;
      }
    }
    return null;
  }
}

typedef _SlotLabel = String Function(int slot);
typedef _SlotTap = void Function(int slot);

class _ChallengeShelfPainter extends CustomPainter {
  const _ChallengeShelfPainter({
    required this.data,
    required this.layout,
    required this.scheme,
    required this.textDirection,
    required this.wood,
    required this.shelfLabel,
    required this.slotLabel,
    required this.onSlotTap,
  });

  /// Painted number labels are the same handful of glyphs on every repaint, so
  /// they are laid out once for the life of the process rather than per frame.
  static final Map<(String, Color, double), TextPainter> _numberCache =
      <(String, Color, double), TextPainter>{};

  final ReadingChallengeData data;
  final _ChallengeLayout layout;
  final ColorScheme scheme;
  final TextDirection textDirection;
  final PaperfoldWoodPalette wood;
  final String shelfLabel;
  final _SlotLabel slotLabel;
  final _SlotTap onSlotTap;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint board = Paint()..color = wood.board;
    for (int row = 0; row < layout.rows; row++) {
      canvas.drawRect(layout.boardRect(row), board);
    }

    final List<Color> cloth = BookSpine.backgroundsFor(scheme.brightness);
    final double numberSize = 9 * layout.scale;

    for (int slot = 1; slot <= layout.slots; slot++) {
      final Rect rect = layout.spineRect(slot);
      final RRect spine = RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(3 * layout.scale),
        topRight: Radius.circular(3 * layout.scale),
      );
      final ChallengeSlotState state = data.stateForSlot(slot);

      switch (state) {
        case ChallengeSlotState.finished:
          // A finished book keeps its own bookcloth, so a full shelf reads as
          // a row of different books rather than one block of accent colour.
          final Book? book = data.bookForSlot(slot);
          final int hash = BookSpine.stableHash(
            book == null ? 'slot-$slot' : '${book.id}-${book.title}',
          );
          canvas
            ..drawRRect(spine, Paint()..color = cloth[hash % cloth.length])
            ..drawRRect(
              spine,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1
                ..color = scheme.primary,
            );
        case ChallengeSlotState.reading:
          canvas
            ..drawRRect(
              spine,
              Paint()..color = scheme.secondary.withValues(alpha: 0.55),
            )
            ..drawRRect(
              spine,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5 * layout.scale
                ..color = scheme.secondary,
            );
        case ChallengeSlotState.empty:
          canvas.drawRRect(
            spine,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = scheme.outlineVariant,
          );
      }

      final Color numberColor = state == ChallengeSlotState.empty
          ? scheme.onSurfaceVariant
          : scheme.onSurface;
      final TextPainter number = _number('$slot', numberColor, numberSize);
      number.paint(
        canvas,
        Offset(
          rect.center.dx - number.width / 2,
          rect.bottom - number.height - 4 * layout.scale,
        ),
      );
    }
  }

  TextPainter _number(String text, Color color, double fontSize) {
    return _numberCache.putIfAbsent((text, color, fontSize), () {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontFamily: PaperfoldTypeTokens.chromeFamily,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// A painted shelf has no widgets, so the semantics are built here.
  ///
  /// One node per spine, plus the shelf summary. A screen reader gets the same
  /// shelf a sighted reader gets, which a single summary label would not give.
  @override
  SemanticsBuilderCallback get semanticsBuilder {
    return (Size size) {
      final List<CustomPainterSemantics> nodes = <CustomPainterSemantics>[
        CustomPainterSemantics(
          rect: Offset.zero & size,
          properties: SemanticsProperties(
            label: shelfLabel,
            textDirection: textDirection,
          ),
        ),
      ];
      for (int slot = 1; slot <= layout.slots; slot++) {
        nodes.add(
          CustomPainterSemantics(
            rect: layout.touchRect(slot),
            properties: SemanticsProperties(
              label: slotLabel(slot),
              button: data.bookForSlot(slot) != null,
              onTap:
                  data.bookForSlot(slot) == null ? null : () => onSlotTap(slot),
              textDirection: textDirection,
            ),
          ),
        );
      }
      return nodes;
    };
  }

  @override
  bool shouldRepaint(covariant _ChallengeShelfPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.scheme != scheme ||
        oldDelegate.layout.slots != layout.slots ||
        oldDelegate.layout.width != layout.width ||
        oldDelegate.layout.scale != layout.scale ||
        oldDelegate.textDirection != textDirection;
  }

  @override
  bool shouldRebuildSemantics(covariant _ChallengeShelfPainter oldDelegate) =>
      shouldRepaint(oldDelegate);
}

class _ChallengeMessage extends StatelessWidget {
  const _ChallengeMessage({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Ornament(
              ornament: PaperfoldOrnament.circularWreath,
              width: 104,
              height: 104,
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
