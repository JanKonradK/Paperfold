import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/dao/challenge.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/journal/book_review_page.dart';
import 'package:paperfold/providers/reading_challenge.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/widgets/ornament.dart';

/// The reading challenge: the year's real books on a shelf, and the goal as a
/// ruled line above them.
///
/// The shelf paints one spine per book that exists. A target of 999 used to
/// mean 999 painted spines, 999 hit-test rectangles and 1000 semantics nodes
/// carrying no information. The remainder is a length of rule instead.
class ReadingChallengePage extends ConsumerWidget {
  const ReadingChallengePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = L10n.of(context);
    final AsyncValue<ReadingChallengeData> challenge =
        ref.watch(readingChallengeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.challengeTitle),
        actions: <Widget>[
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
        error: (Object error, StackTrace stackTrace) => Center(
          child: _ChallengeMessage(
            title: l10n.shelfLoadErrorTitle,
            body: l10n.shelfLoadErrorBody,
            actionLabel: l10n.commonRetry,
            onAction: () =>
                ref.read(readingChallengeProvider.notifier).refresh(),
          ),
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
    final int? chosen = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => _TargetDialog(target: data.target),
    );

    if (chosen != null && context.mounted) {
      await ref.read(readingChallengeProvider.notifier).setTarget(chosen);
    }
  }
}

/// The target picker.
///
/// The field owns its controller, so nothing here can dispose one while the
/// dialog is still animating out and still attached to the keyboard.
class _TargetDialog extends StatefulWidget {
  const _TargetDialog({required this.target});

  final int target;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late String _text = widget.target.toString();
  String? _error;

  void _submit() {
    final int? value = int.tryParse(_text.trim());
    if (value == null ||
        value < ChallengeDao.minimumTarget ||
        value > ChallengeDao.maximumTarget) {
      setState(() => _error = L10n.of(context).challengeTargetRange);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);

    return AlertDialog(
      title: Text(l10n.challengeSetTarget),
      content: TextFormField(
        key: const ValueKey<String>('challenge-target-field'),
        initialValue: widget.target.toString(),
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(
          labelText: l10n.challengeTargetLabel,
          helperText: l10n.challengeTargetRange,
          errorText: _error,
        ),
        onChanged: (String value) {
          _text = value;
          if (_error != null) {
            setState(() => _error = null);
          }
        },
        onFieldSubmitted: (String _) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

class _ChallengeView extends ConsumerWidget {
  const _ChallengeView({required this.data});

  final ReadingChallengeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = L10n.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int selectedYear = ref.watch(trackedChallengeYearProvider);
    final int currentYear = DateTime.now().year;
    final int over = data.finishedCount - data.target;
    final int pace = data.paceDelta;
    final bool hasBooks =
        data.finished.isNotEmpty || data.readingNow.isNotEmpty;

    void stepYear(int amount) {
      ref.read(trackedChallengeYearProvider.notifier).state =
          selectedYear + amount;
    }

    final String paceLabel = pace > 0
        ? l10n.challengePaceAhead(pace)
        : pace < 0
            ? l10n.challengePaceBehind(-pace)
            : l10n.challengePaceOnTrack;

    return RefreshIndicator(
      onRefresh: () => ref.read(readingChallengeProvider.notifier).refresh(),
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 4,
          // The floating glass bar overlays content, so the shelf needs room to
          // clear it as well as the gesture inset.
          bottom: 96 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        itemCount: 1 + data.finished.length + data.readingNow.length,
        itemBuilder: (BuildContext context, int index) {
          if (index > 0) {
            final Book book = data.bookForSlot(index)!;
            final bool finished = index <= data.finishedCount;
            final String status = finished
                ? l10n.challengeLegendFinished
                : l10n.challengeLegendReading;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(finished ? Icons.check : Icons.bookmark_outline,
                  color: scheme.primary),
              title: Text(book.title),
              subtitle: Text('$status · ${book.author}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => BookReviewPage(book: book),
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The year sits with the control that changes it.
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.challengeYearTitle(data.year.toString()),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
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
                    onPressed:
                        selectedYear < currentYear ? () => stepYear(1) : null,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.challengeProgress(data.finishedCount, data.target),
                style:
                    theme.textTheme.titleLarge?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 10),
              // The whole year as one rule. The adjacent text already states it,
              // so the rule stays out of the semantics tree.
              ExcludeSemantics(
                child: SizedBox(
                  height: 3,
                  child: ColoredBox(
                    color: scheme.outlineVariant,
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: data.progress.clamp(0.0, 1.0),
                      child: ColoredBox(color: scheme.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      pace < 0
                          ? Icons.trending_down
                          : pace > 0
                              ? Icons.trending_up
                              : Icons.trending_flat,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(paceLabel, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          l10n.challengePaceExpected(data.expectedFinished),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (over > 0) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            l10n.challengeOverTarget(over),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: scheme.primary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (hasBooks) ...<Widget>[
                _ChallengeShelf(data: data),
                const SizedBox(height: 16),
                _ChallengeLegend(data: data),
                const SizedBox(height: 20),
              ] else
                _ChallengeMessage(
                  title: l10n.challengeEmptyTitle,
                  body: l10n.challengeEmptyBody,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Only the states actually standing on the shelf get a key.
class _ChallengeLegend extends StatelessWidget {
  const _ChallengeLegend({required this.data});

  final ReadingChallengeData data;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color sample = PaperfoldTokens.surfaces.warmBeige;

    return Wrap(
      spacing: 20,
      runSpacing: 8,
      children: <Widget>[
        if (data.finished.isNotEmpty)
          _LegendKey(
            fill: sample,
            outline: scheme.outlineVariant,
            band: PaperfoldTokens.light.ink,
            label: l10n.challengeLegendFinished,
          ),
        if (data.readingNow.isNotEmpty)
          _LegendKey(
            fill: sample,
            outline: scheme.outlineVariant,
            ribbon: scheme.secondary,
            label: l10n.challengeLegendReading,
          ),
      ],
    );
  }
}

class _LegendKey extends StatelessWidget {
  const _LegendKey({
    required this.fill,
    required this.outline,
    required this.label,
    this.band,
    this.ribbon,
  });

  final Color fill;
  final Color outline;
  final Color? band;
  final Color? ribbon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 16,
          height: 24,
          child: CustomPaint(
            painter: _SpinePainter(
              fill: fill,
              outline: outline,
              band: band,
              ribbon: ribbon,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.labelLarge),
      ],
    );
  }
}

/// One spine. The legend and the shelf draw the same marks, so a key means
/// what it says: a foil band is a finished book, a ribbon is one in hand.
void _paintSpine(
  Canvas canvas,
  Rect rect, {
  required Color fill,
  required Color outline,
  required double scale,
  Color? band,
  Color? ribbon,
}) {
  final RRect spine = RRect.fromRectAndCorners(
    rect,
    topLeft: Radius.circular(3 * scale),
    topRight: Radius.circular(3 * scale),
  );
  canvas
    ..drawRRect(spine, Paint()..color = fill)
    ..drawRRect(
      spine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = outline,
    );

  if (band != null) {
    final Paint bandPaint = Paint()..color = band;
    final double inset = math.max(2, rect.width * 0.2);
    for (final double at in const <double>[0.22, 0.30]) {
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left + inset,
          rect.top + rect.height * at,
          rect.width - inset * 2,
          math.max(1, 1.5 * scale),
        ),
        bandPaint,
      );
    }
  }

  if (ribbon != null) {
    final double width = math.max(2, 4 * scale);
    canvas.drawRect(
      Rect.fromLTWH(
        rect.center.dx - width / 2,
        rect.top,
        width,
        rect.height * 0.42,
      ),
      Paint()..color = ribbon,
    );
  }
}

class _SpinePainter extends CustomPainter {
  const _SpinePainter({
    required this.fill,
    required this.outline,
    this.band,
    this.ribbon,
  });

  final Color fill;
  final Color outline;
  final Color? band;
  final Color? ribbon;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSpine(
      canvas,
      Offset.zero & size,
      fill: fill,
      outline: outline,
      scale: 1,
      band: band,
      ribbon: ribbon,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinePainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.outline != outline ||
        oldDelegate.band != band ||
        oldDelegate.ribbon != ribbon;
  }
}

/// The shelf itself: one canvas, and one spine per book that exists.
class _ChallengeShelf extends StatelessWidget {
  const _ChallengeShelf({required this.data});

  final ReadingChallengeData data;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextDirection textDirection = Directionality.of(context);
    // The shelf grows with the system text setting, because a spine has no
    // text of its own to grow.
    final double scale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final int count = data.finished.length + data.readingNow.length;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _ChallengeLayout layout = _ChallengeLayout(
          width: constraints.maxWidth,
          slots: count,
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
          key: const ValueKey<String>('challenge-shelf'),
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
              slotLabel: (int slot) => l10n.challengeSlotFilled(
                slot,
                data.bookForSlot(slot)?.title ?? '',
              ),
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
  }) : slots = math.max(1, slots) {
    columns = (width / touchExtent).floor().clamp(1, this.slots);
    rows = (this.slots / columns).ceil();
    leftPadding = (width - columns * touchExtent) / 2;
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
    final double cellLeft = leftPadding + (index % columns) * touchExtent;
    return Rect.fromLTWH(
      cellLeft + (touchExtent - spineWidth) / 2,
      (index ~/ columns) * rowHeight,
      spineWidth,
      spineHeight,
    );
  }

  /// The logical target for a one-based [slot]. It stays at least 48 dp wide
  /// even though the painted spine is narrow.
  Rect touchRect(int slot) {
    final int index = slot - 1;
    return Rect.fromLTWH(
      leftPadding + (index % columns) * touchExtent,
      (index ~/ columns) * rowHeight,
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

  /// The one-based slot under [position], or null. Arithmetic, not a scan of
  /// every slot on the shelf.
  int? slotAt(Offset position) {
    final int row = (position.dy / rowHeight).floor();
    final int column = ((position.dx - leftPadding) / touchExtent).floor();
    if (row < 0 || column < 0 || column >= columns) {
      return null;
    }
    final int slot = row * columns + column + 1;
    if (slot < 1 || slot > slots) {
      return null;
    }
    return touchRect(slot).contains(position) ? slot : null;
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

    for (int slot = 1; slot <= layout.slots; slot++) {
      final Book? book = data.bookForSlot(slot);
      if (book == null) {
        continue;
      }
      // The bookcloth and stamped foil the rest of the app already uses,
      // contrast-checked and cached per book.
      final BookSpineVisual visual =
          BookSpine.resolveVisual('${book.id}-${book.title}', scheme);
      final bool reading =
          data.stateForSlot(slot) == ChallengeSlotState.reading;

      _paintSpine(
        canvas,
        layout.spineRect(slot),
        fill: reading
            ? visual.background.withValues(alpha: 0.55)
            : visual.background,
        outline: scheme.outlineVariant,
        scale: layout.scale,
        band: reading ? null : visual.foreground,
        ribbon: reading ? scheme.secondary : null,
      );
    }
  }

  /// A painted shelf has no widgets, so the semantics are built here: one node
  /// per book, plus the shelf summary. A book that does not exist gets no
  /// node, so a 999-book target is no longer read out 997 times.
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
        if (data.bookForSlot(slot) == null) {
          continue;
        }
        nodes.add(
          CustomPainterSemantics(
            rect: layout.touchRect(slot),
            properties: SemanticsProperties(
              label: slotLabel(slot),
              button: true,
              onTap: () => onSlotTap(slot),
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

    return ConstrainedBox(
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
    );
  }
}
