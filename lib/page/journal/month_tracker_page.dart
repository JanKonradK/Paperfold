import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/providers/month_tracker.dart';

/// The circular month tracker: one segment per day, keyed by pages read.
///
/// tb_reading_time already stores minutes per day and the statistics page
/// draws those. This is the other measure, and the reference sheet asks for a
/// ring rather than a bar chart. plan.md Section 8.
class MonthTrackerPage extends ConsumerWidget {
  const MonthTrackerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = L10n.of(context);
    final AsyncValue<MonthTrackerData> tracker =
        ref.watch(monthTrackerProvider);
    final DateTime month = ref.watch(trackedMonthProvider);

    void step(int months) {
      ref.read(trackedMonthProvider.notifier).state =
          DateTime(month.year, month.month + months);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.monthTrackerTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.monthTrackerPreviousMonth,
            onPressed: () => step(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.monthTrackerNextMonth,
            onPressed: () => step(1),
          ),
        ],
      ),
      body: tracker.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Text(l10n.shelfLoadErrorTitle),
        ),
        data: (MonthTrackerData data) => _MonthTrackerView(data: data),
      ),
    );
  }
}

class _MonthTrackerView extends ConsumerWidget {
  const _MonthTrackerView({required this.data});

  final MonthTrackerData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = L10n.of(context);
    final ThemeData theme = Theme.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);

    return ListView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 96 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: <Widget>[
        Text(
          material.formatMonthYear(DateTime(data.year, data.month)),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.monthTrackerPagesTotal(data.totalPages),
          style: theme.textTheme.bodyLarge,
        ),
        Text(
          l10n.monthTrackerDaysRead(data.daysRead),
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        _MonthRing(data: data),
      ],
    );
  }
}

class _MonthRing extends ConsumerWidget {
  const _MonthRing({required this.data});

  @visibleForTesting
  static const double maximumDiameter = 320;

  final MonthTrackerData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = L10n.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double diameter =
            math.min(constraints.maxWidth, maximumDiameter);
        final _RingLayout layout = _RingLayout(
          diameter: diameter,
          days: data.dayCount,
        );

        return Center(
          child: GestureDetector(
            onTapUp: (TapUpDetails details) {
              final int? day = layout.dayAt(details.localPosition);
              if (day != null) {
                _editDay(context, ref, day);
              }
            },
            child: CustomPaint(
              size: Size.square(diameter),
              painter: _MonthRingPainter(
                data: data,
                layout: layout,
                scheme: scheme,
                ringLabel: l10n.monthTrackerRingSemanticLabel(
                  data.daysRead,
                  data.totalPages,
                ),
                dayLabel: (int day) => l10n.monthTrackerDaySemanticLabel(
                  day,
                  data.pagesByDay[day] ?? 0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editDay(BuildContext context, WidgetRef ref, int day) async {
    final L10n l10n = L10n.of(context);
    final TextEditingController controller = TextEditingController(
      text: (data.pagesByDay[day] ?? 0).toString(),
    );

    final int? pages = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.monthTrackerEditDay(day)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.monthTrackerPagesLabel),
          onSubmitted: (String value) =>
              Navigator.of(context).pop(int.tryParse(value.trim())),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pop(int.tryParse(controller.text.trim())),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();

    if (pages != null) {
      await ref.read(monthTrackerProvider.notifier).setPages(
            DateTime(data.year, data.month, day),
            pages,
          );
    }
  }
}

/// Where every day segment sits. Shared by the painter and by hit testing.
class _RingLayout {
  _RingLayout({required this.diameter, required this.days});

  /// The ring starts at the top and runs clockwise, the way a clock and a
  /// printed month wheel both do.
  static const double startAngle = -math.pi / 2;

  final double diameter;
  final int days;

  double get radius => diameter / 2;
  Offset get centre => Offset(radius, radius);

  /// Thick enough to read a fill level in, thin enough to leave the middle for
  /// the month total.
  double get thickness => diameter * 0.17;

  double get outerRadius => radius - 2;
  double get innerRadius => outerRadius - thickness;

  double get sweepPerDay => 2 * math.pi / days;

  /// The hairline that keeps two busy days apart.
  double get gapAngle => sweepPerDay * 0.12;

  double angleFor(int day) => startAngle + (day - 1) * sweepPerDay;

  /// The one-based day under [position], or null when the tap missed the ring.
  int? dayAt(Offset position) {
    final Offset fromCentre = position - centre;
    final double distance = fromCentre.distance;
    if (distance < innerRadius || distance > outerRadius) {
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
    final Offset point = centre +
        Offset(math.cos(middle), math.sin(middle)) * middleRadius;
    final double side = math.max(thickness, 24);
    return Rect.fromCenter(center: point, width: side, height: side);
  }
}

typedef _DayLabel = String Function(int day);

class _MonthRingPainter extends CustomPainter {
  const _MonthRingPainter({
    required this.data,
    required this.layout,
    required this.scheme,
    required this.ringLabel,
    required this.dayLabel,
  });

  final MonthTrackerData data;
  final _RingLayout layout;
  final ColorScheme scheme;
  final String ringLabel;
  final _DayLabel dayLabel;

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
    }

    _paintCentre(canvas);
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
    final TextPainter total = TextPainter(
      text: TextSpan(
        text: '${data.totalPages}',
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: layout.diameter * 0.15,
          fontFamily: PaperfoldTypeTokens.journalFamily,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    total.paint(
      canvas,
      layout.centre - Offset(total.width / 2, total.height / 2),
    );
    total.dispose();
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder {
    return (Size size) {
      final List<CustomPainterSemantics> nodes = <CustomPainterSemantics>[
        CustomPainterSemantics(
          rect: Offset.zero & size,
          properties: SemanticsProperties(
            label: ringLabel,
            textDirection: TextDirection.ltr,
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
              textDirection: TextDirection.ltr,
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
        oldDelegate.layout.days != layout.days;
  }

  @override
  bool shouldRebuildSemantics(covariant _MonthRingPainter oldDelegate) =>
      shouldRepaint(oldDelegate);
}
