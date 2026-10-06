import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/providers/month_tracker.dart';
import 'package:paperfold/utils/log/common.dart';

/// Daily page totals, with both a visual ring and a native date entry path.
class MonthTrackerPage extends ConsumerWidget {
  const MonthTrackerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final tracker = ref.watch(monthTrackerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.monthTrackerTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: tracker.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _MonthMessage(
                title: l10n.commonLoadFailedTitle,
                body: l10n.statisticTrackerLoadError,
                actionLabel: l10n.commonRetry,
                onAction: () =>
                    ref.read(monthTrackerProvider.notifier).refresh(),
              ),
              data: (data) => _MonthTrackerView(data: data),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthTrackerView extends ConsumerWidget {
  const _MonthTrackerView({required this.data});

  final MonthTrackerData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    final month = ref.watch(trackedMonthProvider);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    void step(int amount) {
      ref.read(trackedMonthProvider.notifier).state =
          DateTime(month.year, month.month + amount);
    }

    Future<void> chooseDay() async {
      final day = await showDatePicker(
        context: context,
        helpText: l10n.monthTrackerChooseDay,
        initialDate: DateTime(data.year, data.month, data.today ?? 1),
        firstDate: DateTime(data.year, data.month),
        lastDate: DateTime(data.year, data.month + 1, 0),
      );
      if (day != null && context.mounted) {
        await _editTrackerDay(context, ref, data, day.day);
      }
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(monthTrackerProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey<String>('month-tracker-previous'),
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n.monthTrackerPreviousMonth,
                onPressed:
                    month.year > 1 || month.month > 1 ? () => step(-1) : null,
              ),
              Expanded(
                child: Text(
                  material.formatMonthYear(DateTime(data.year, data.month)),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              IconButton(
                key: const ValueKey<String>('month-tracker-next'),
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n.monthTrackerNextMonth,
                onPressed: month.isBefore(currentMonth) ? () => step(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 20,
            runSpacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.monthTrackerPagesTotal(data.totalPages),
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    l10n.monthTrackerDaysRead(data.daysRead),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: chooseDay,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: Text(l10n.monthTrackerRecordPages),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.monthTrackerPagesPerDay,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          MonthTrackerRing(data: data),
          const SizedBox(height: 20),
          const _RingLegend(),
          const SizedBox(height: 24),
          if (data.daysRead == 0) ...[
            _MonthEmptyState(
              title: l10n.monthTrackerEmptyTitle,
              body: l10n.monthTrackerEmptyBody,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            l10n.monthTrackerManualEntryHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared by the tracker and Statistics. Each day remains directly editable.
class MonthTrackerRing extends ConsumerWidget {
  const MonthTrackerRing({
    super.key,
    required this.data,
    this.maximumDiameter = 360,
  });

  @visibleForTesting
  final double maximumDiameter;
  final MonthTrackerData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textDirection = Directionality.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter =
            math.min(constraints.maxWidth, maximumDiameter * scale);
        final layout = _RingLayout(
          diameter: diameter,
          days: data.dayCount,
          scale: scale,
        );
        void openDay(int day) => _editTrackerDay(context, ref, data, day);
        return Center(
          child: GestureDetector(
            onTapUp: (details) {
              final day = layout.dayAt(details.localPosition);
              if (day != null) openDay(day);
            },
            child: CustomPaint(
              size: Size.square(diameter),
              painter: _MonthRingPainter(
                data: data,
                layout: layout,
                scheme: scheme,
                textDirection: textDirection,
                ringLabel: l10n.monthTrackerRingSemanticLabel(
                  data.daysRead,
                  data.totalPages,
                ),
                dayLabel: (day) => l10n.monthTrackerDaySemanticLabel(
                  day,
                  data.pagesFor(day),
                ),
                centreUnit: l10n.monthTrackerCentreUnit,
                onDayTap: openDay,
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _editTrackerDay(
  BuildContext context,
  WidgetRef ref,
  MonthTrackerData data,
  int day,
) =>
    showDialog<void>(
      context: context,
      builder: (_) => _DayPagesDialog(
        day: DateTime(data.year, data.month, day),
        currentPages: data.isRecorded(day) ? data.pagesFor(day) : null,
        onSave: (pages) => ref.read(monthTrackerProvider.notifier).setPages(
              DateTime(data.year, data.month, day),
              pages,
            ),
      ),
    );

class _DayPagesDialog extends StatefulWidget {
  const _DayPagesDialog({
    required this.day,
    required this.currentPages,
    required this.onSave,
  });

  final DateTime day;
  final int? currentPages;
  final Future<void> Function(int) onSave;

  @override
  State<_DayPagesDialog> createState() => _DayPagesDialogState();
}

class _DayPagesDialogState extends State<_DayPagesDialog> {
  late String _text = widget.currentPages?.toString() ?? '';
  String? _error;
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving) return;
    final pages = int.tryParse(_text.trim());
    if (pages == null || pages < 0) {
      setState(() => _error = L10n.of(context).monthTrackerInvalidPages);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(pages);
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AnxLog.warning('Could not save daily pages', error, stackTrace);
      if (mounted) {
        setState(() => _error = L10n.of(context).monthTrackerSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title:
            Text(MaterialLocalizations.of(context).formatFullDate(widget.day)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.currentPages != null
                ? l10n.monthTrackerDayCurrentPages(widget.currentPages!)
                : l10n.monthTrackerDayNotRecorded),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey<String>('month-page-total-field'),
              initialValue: _text,
              enabled: !_saving,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.monthTrackerNewPagesLabel,
                suffixText: l10n.monthTrackerPagesLabel,
                errorText: _error,
                errorMaxLines: 3,
              ),
              onChanged: (value) {
                _text = value;
                if (_error != null) setState(() => _error = null);
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

/// Where every day segment sits. Shared by the painter and by hit testing.
class _RingLayout {
  _RingLayout({
    required this.diameter,
    required this.days,
    required this.scale,
  });

  /// The ring starts at the top and runs clockwise, the way a clock and a
  /// printed month wheel both do.
  static const double startAngle = -math.pi / 2;

  final double diameter;
  final int days;
  final double scale;

  double get radius => diameter / 2;
  Offset get centre => Offset(radius, radius);

  /// Room for the day numbers outside the segments.
  double get labelBand => 22 * scale;

  /// Thick enough to read a fill level and to give the ring a 48 dp radial
  /// touch band.
  double get thickness => math.max(48, diameter * 0.16);

  double get outerRadius => radius - labelBand - 2;
  double get innerRadius => math.max(20, outerRadius - thickness);
  double get labelRadius => outerRadius + 13 * scale;

  double get sweepPerDay => 2 * math.pi / days;

  /// The hairline that keeps two busy days apart.
  double get gapAngle => sweepPerDay * 0.12;

  double angleFor(int day) => startAngle + (day - 1) * sweepPerDay;

  /// The one-based day under [position], or null when the tap missed the ring.
  int? dayAt(Offset position) {
    final Offset fromCentre = position - centre;
    final double distance = fromCentre.distance;
    // Include the day labels in the target. The painted segment and its number
    // act as one control.
    if (distance < innerRadius || distance > radius) {
      return null;
    }
    // atan2 returns -pi..pi measured from the positive x axis. Shift it so the
    // ring's own start angle is zero, then wrap into a full turn.
    double angle = math.atan2(fromCentre.dy, fromCentre.dx) - startAngle;
    while (angle < 0) {
      angle += 2 * math.pi;
    }
    final int day = (angle / sweepPerDay).floor() + 1;
    return day.clamp(1, days);
  }

  /// The square a day's segment sits in. Semantics needs a rectangle, and a
  /// segment is not one, so this is the tightest box that holds it.
  Rect boundsFor(int day) {
    final double middle = angleFor(day) + sweepPerDay / 2;
    final double middleRadius = (innerRadius + outerRadius) / 2;
    final Offset point =
        centre + Offset(math.cos(middle), math.sin(middle)) * middleRadius;
    final double side = math.max(thickness, 48);
    return Rect.fromCenter(center: point, width: side, height: side);
  }
}

typedef _DayLabel = String Function(int day);
typedef _DayTap = void Function(int day);

class _MonthRingPainter extends CustomPainter {
  const _MonthRingPainter({
    required this.data,
    required this.layout,
    required this.scheme,
    required this.textDirection,
    required this.ringLabel,
    required this.dayLabel,
    required this.centreUnit,
    required this.onDayTap,
  });

  final MonthTrackerData data;
  final _RingLayout layout;
  final ColorScheme scheme;
  final TextDirection textDirection;
  final String ringLabel;
  final _DayLabel dayLabel;
  final String centreUnit;
  final _DayTap onDayTap;

  static final Map<(String, Color, double, FontWeight), TextPainter>
      _dayNumberCache = <(String, Color, double, FontWeight), TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    for (int day = 1; day <= layout.days; day++) {
      final double fill = data.fillFor(day);
      final double start = layout.angleFor(day) + layout.gapAngle / 2;
      final double sweep = layout.sweepPerDay - layout.gapAngle;

      // The track first, so a day with no reading still shows its place in the
      // month rather than leaving a hole.
      _drawSegment(
        canvas,
        start: start,
        sweep: sweep,
        inner: layout.innerRadius,
        outer: layout.outerRadius,
        color: scheme.surfaceContainerHighest,
      );

      if (fill > 0) {
        _drawSegment(
          canvas,
          start: start,
          sweep: sweep,
          inner: layout.innerRadius,
          outer: layout.innerRadius +
              (layout.outerRadius - layout.innerRadius) * fill,
          color: scheme.primary,
        );
      }

      if (day == data.today) {
        _drawSegment(
          canvas,
          start: start,
          sweep: sweep,
          inner: layout.innerRadius,
          outer: layout.outerRadius,
          color: scheme.secondary,
          stroke: 1.5,
        );
      }

      _paintDayNumber(canvas, day);
    }

    _paintCentre(canvas);
  }

  void _paintDayNumber(Canvas canvas, int day) {
    final double angle = layout.angleFor(day) + layout.sweepPerDay / 2;
    final Offset centre = layout.centre +
        Offset(math.cos(angle), math.sin(angle)) * layout.labelRadius;
    final double fontSize = 10 * layout.scale;
    final String label = '$day';
    final FontWeight weight =
        day == data.today ? FontWeight.w700 : FontWeight.w600;
    final TextPainter number = _dayNumberCache.putIfAbsent(
      (label, scheme.onSurface, fontSize, weight),
      () => TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: fontSize,
            fontFamily: PaperfoldTypeTokens.chromeFamily,
            fontWeight: weight,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    number.paint(
      canvas,
      centre - Offset(number.width / 2, number.height / 2),
    );
  }

  void _drawSegment(
    Canvas canvas, {
    required double start,
    required double sweep,
    required double inner,
    required double outer,
    required Color color,
    double? stroke,
  }) {
    final Path path = Path()
      ..addArc(
        Rect.fromCircle(center: layout.centre, radius: outer),
        start,
        sweep,
      )
      ..arcTo(
        Rect.fromCircle(center: layout.centre, radius: inner),
        start + sweep,
        -sweep,
        false,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = stroke == null ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = stroke ?? 0,
    );
  }

  void _paintCentre(Canvas canvas) {
    final double maximumWidth = layout.innerRadius * 1.65;
    double totalSize = 38 * layout.scale;
    TextPainter total = _centreText(
      '${data.totalPages}',
      scheme.onSurface,
      totalSize,
      PaperfoldTypeTokens.chromeFamily,
    );
    if (total.width > maximumWidth && total.width > 0) {
      totalSize *= maximumWidth / total.width;
      total.dispose();
      total = _centreText(
        '${data.totalPages}',
        scheme.onSurface,
        totalSize,
        PaperfoldTypeTokens.chromeFamily,
      );
    }
    final TextPainter unit = _centreText(
      centreUnit,
      scheme.onSurfaceVariant,
      12 * layout.scale,
      PaperfoldTypeTokens.chromeFamily,
    );
    final double gap = 3 * layout.scale;
    final double groupHeight = total.height + gap + unit.height;

    total.paint(
      canvas,
      Offset(
        layout.centre.dx - total.width / 2,
        layout.centre.dy - groupHeight / 2,
      ),
    );
    unit.paint(
      canvas,
      Offset(
        layout.centre.dx - unit.width / 2,
        layout.centre.dy - groupHeight / 2 + total.height + gap,
      ),
    );
    total.dispose();
    unit.dispose();
  }

  TextPainter _centreText(
    String text,
    Color color,
    double size,
    String family,
  ) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: family,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: textDirection,
    )..layout();
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder {
    return (Size size) {
      final List<CustomPainterSemantics> nodes = <CustomPainterSemantics>[
        CustomPainterSemantics(
          rect: Offset.zero & size,
          properties: SemanticsProperties(
            label: ringLabel,
            textDirection: textDirection,
          ),
        ),
      ];
      for (int day = 1; day <= layout.days; day++) {
        nodes.add(
          CustomPainterSemantics(
            rect: layout.boundsFor(day),
            properties: SemanticsProperties(
              label: dayLabel(day),
              button: true,
              onTap: () => onDayTap(day),
              textDirection: textDirection,
            ),
          ),
        );
      }
      return nodes;
    };
  }

  @override
  bool shouldRepaint(covariant _MonthRingPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.scheme != scheme ||
        oldDelegate.layout.diameter != layout.diameter ||
        oldDelegate.layout.days != layout.days ||
        oldDelegate.layout.scale != layout.scale ||
        oldDelegate.textDirection != textDirection;
  }

  @override
  bool shouldRebuildSemantics(covariant _MonthRingPainter oldDelegate) =>
      shouldRepaint(oldDelegate);
}

class _RingLegend extends StatelessWidget {
  const _RingLegend();

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: <Widget>[
        _RingLegendKey(
          label: l10n.monthTrackerLegendNoPages,
          track: scheme.surfaceContainerHighest,
          fill: scheme.primary,
          fillFraction: 0,
        ),
        _RingLegendKey(
          label: l10n.monthTrackerLegendFewerPages,
          track: scheme.surfaceContainerHighest,
          fill: scheme.primary,
          fillFraction: 0.4,
        ),
        _RingLegendKey(
          label: l10n.monthTrackerLegendMorePages,
          track: scheme.surfaceContainerHighest,
          fill: scheme.primary,
          fillFraction: 1,
        ),
        _RingLegendKey(
          label: l10n.monthTrackerLegendToday,
          track: scheme.surfaceContainerHighest,
          fill: scheme.primary,
          fillFraction: 0,
          outline: scheme.secondary,
        ),
      ],
    );
  }
}

class _RingLegendKey extends StatelessWidget {
  const _RingLegendKey({
    required this.label,
    required this.track,
    required this.fill,
    required this.fillFraction,
    this.outline,
  });

  final String label;
  final Color track;
  final Color fill;
  final double fillFraction;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 24,
          height: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(3),
              border: outline == null
                  ? null
                  : Border.all(color: outline!, width: 1.5),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: fillFraction,
                child: ColoredBox(color: fill),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
      ],
    );
  }
}

class _MonthEmptyState extends StatelessWidget {
  const _MonthEmptyState({required this.title, required this.body});

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
              Icons.edit_calendar_outlined,
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

class _MonthMessage extends StatelessWidget {
  const _MonthMessage({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.donut_large_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
