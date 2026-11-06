import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/common/paperfold_pane.dart';
import 'package:paperfold/widgets/reading_page/more_settings/page_turning/diagram.dart';
import 'package:paperfold/widgets/reading_page/more_settings/page_turning/types_and_icons.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Keeps first-open policy separate from the WebView so it can be tested.
class ReaderTapGuideGate extends StatefulWidget {
  const ReaderTapGuideGate({
    super.key,
    required this.child,
    this.ready = true,
    this.onDismiss,
  });

  final Widget child;
  final bool ready;
  final VoidCallback? onDismiss;

  @override
  State<ReaderTapGuideGate> createState() => ReaderTapGuideGateState();
}

class ReaderTapGuideGateState extends State<ReaderTapGuideGate> {
  late bool _visible = !Prefs().readerGuideSeen;

  void show() => setState(() => _visible = true);

  void _dismiss() {
    Prefs().readerGuideSeen = true;
    setState(() => _visible = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible && widget.ready;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: visible,
          child: ExcludeSemantics(excluding: visible, child: widget.child),
        ),
        if (visible)
          PointerInterceptor(child: ReaderTapGuide(onDismiss: _dismiss)),
      ],
    );
  }
}

/// One connected area, including non-rectangular layouts such as an L shape.
class ReaderGuideRegion {
  ReaderGuideRegion(this.action, this.cells);

  final PageTurningType action;
  final Set<int> cells;

  // Find a rectangle inside the region for its label. No label crosses a zone.
  Rect labelRect(Size size, double bottom) {
    var best = Rect.zero;
    for (var top = 0; top < 3; top++) {
      for (var left = 0; left < 3; left++) {
        for (var endY = top + 1; endY <= 3; endY++) {
          for (var endX = left + 1; endX <= 3; endX++) {
            final inside = [
              for (var y = top; y < endY; y++)
                for (var x = left; x < endX; x++) y * 3 + x,
            ].every(cells.contains);
            if (!inside) continue;
            final rect = Rect.fromLTRB(
              left * size.width / 3,
              top * size.height / 3,
              endX * size.width / 3,
              math.min(endY * size.height / 3, bottom),
            );
            if (rect.width * rect.height > best.width * best.height) {
              best = rect;
            }
          }
        }
      }
    }
    // Custom layouts can put an action only beneath the footer.
    if (best.isEmpty) {
      final cell = cells.first;
      return Rect.fromLTWH(
        cell % 3 * size.width / 3,
        cell ~/ 3 * size.height / 3,
        size.width / 3,
        size.height / 3,
      );
    }
    return best;
  }
}

List<ReaderGuideRegion> readerGuideRegions(List<PageTurningType> actions) {
  final remaining = {for (var i = 0; i < 9; i++) i};
  final regions = <ReaderGuideRegion>[];
  while (remaining.isNotEmpty) {
    final first = remaining.first;
    final cells = <int>{};
    final pending = [first];
    while (pending.isNotEmpty) {
      final cell = pending.removeLast();
      if (!remaining.remove(cell)) continue;
      cells.add(cell);
      for (final next in [
        if (cell % 3 > 0) cell - 1,
        if (cell % 3 < 2) cell + 1,
        if (cell >= 3) cell - 3,
        if (cell < 6) cell + 3,
      ]) {
        if (remaining.contains(next) && actions[next] == actions[first]) {
          pending.add(next);
        }
      }
    }
    regions.add(ReaderGuideRegion(actions[first], cells));
  }
  return regions;
}

class ReaderTapGuide extends StatefulWidget {
  const ReaderTapGuide({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<ReaderTapGuide> createState() => _ReaderTapGuideState();
}

class _ReaderTapGuideState extends State<ReaderTapGuide>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!PaperfoldVisualPolicy.motionAllowed(context)) {
      _motion.stop();
      _motion.value = 1;
    } else if (_motion.value == 0 && !_motion.isAnimating) {
      _motion.forward();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final regions = readerGuideRegions(currentPageTurningActions());
    final rtl = Directionality.of(context) == TextDirection.rtl;
    String label(PageTurningType action) => switch (action) {
      PageTurningType.prev => l10n.readerGuidePrevious,
      PageTurningType.next => l10n.readerGuideNext,
      PageTurningType.menu => l10n.readerGuideMenu,
      PageTurningType.none => '',
    };
    IconData icon(PageTurningType action) => switch (action) {
      PageTurningType.prev => rtl ? Icons.arrow_forward : Icons.arrow_back,
      PageTurningType.next => rtl ? Icons.arrow_back : Icons.arrow_forward,
      _ => Icons.menu,
    };

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: widget.onDismiss,
        child: Material(
          color: scheme.surface.withValues(alpha: 0.45),
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) => Opacity(
              opacity: (_motion.value * 12).clamp(0, 1),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  final insets = MediaQuery.paddingOf(context);
                  final footerHeight = math.min(220.0, size.height * 0.40);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _RegionPainter(regions, scheme)),
                      for (final region in regions)
                        if (region.action != PageTurningType.none)
                          Positioned.fromRect(
                            rect: region.labelRect(
                              size,
                              size.height - footerHeight,
                            ),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                PaperfoldSpace.xs,
                                math.max(PaperfoldSpace.xs, insets.top),
                                PaperfoldSpace.xs,
                                PaperfoldSpace.xs,
                              ),
                              child: Center(
                                child: SingleChildScrollView(
                                  child: Semantics(
                                    label: label(region.action),
                                    container: true,
                                    excludeSemantics: true,
                                    child: PaperfoldPane(
                                      key: ValueKey(
                                        'guide-region-${region.cells.first}',
                                      ),
                                      padding: const EdgeInsets.all(
                                        PaperfoldSpace.xs,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Transform.scale(
                                            scale:
                                                region.action ==
                                                    PageTurningType.menu
                                                ? 1
                                                : 1 +
                                                      0.07 *
                                                          (1 -
                                                              math.cos(
                                                                _motion.value *
                                                                    4 *
                                                                    math.pi,
                                                              )) /
                                                          2,
                                            child: Icon(icon(region.action)),
                                          ),
                                          const SizedBox(
                                            height: PaperfoldSpace.xxs,
                                          ),
                                          Text(
                                            label(region.action),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      Positioned(
                        left: PaperfoldSpace.md,
                        right: PaperfoldSpace.md,
                        bottom: math.max(PaperfoldSpace.md, insets.bottom),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: footerHeight - PaperfoldSpace.md,
                          ),
                          child: PaperfoldPane(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: SingleChildScrollView(
                                    child: Text(
                                      l10n.readerGuideGestures,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: PaperfoldSpace.xs),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    shape: PaperfoldShape.controlShape,
                                  ),
                                  onPressed: widget.onDismiss,
                                  child: Text(l10n.readerGuideGotIt),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionPainter extends CustomPainter {
  _RegionPainter(this.regions, this.scheme);

  final List<ReaderGuideRegion> regions;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    for (final region in regions) {
      var path = Path();
      for (final cell in region.cells) {
        final rect = Rect.fromLTWH(
          cell % 3 * size.width / 3,
          cell ~/ 3 * size.height / 3,
          size.width / 3,
          size.height / 3,
        );
        path = Path.combine(PathOperation.union, path, Path()..addRect(rect));
      }
      final color = switch (region.action) {
        PageTurningType.prev => scheme.primary,
        PageTurningType.next => scheme.tertiary,
        PageTurningType.menu => scheme.secondary,
        PageTurningType.none => scheme.outline,
      };
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.12));
      canvas.drawPath(
        path,
        Paint()
          ..color = scheme.onSurface.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) => true;
}
