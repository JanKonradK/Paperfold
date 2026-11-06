import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';

/// Gives [child] the Paperfold press: it settles to [pressedScale] under the
/// finger in 120 ms and lands back with a small overshoot when released.
///
/// The press is decoration only. Taps, focus, and semantics belong to the
/// [InkWell] or button inside; this widget only listens to pointers.
class PaperfoldPressable extends StatefulWidget {
  const PaperfoldPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.97,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<PaperfoldPressable> createState() => _PaperfoldPressableState();
}

class _PaperfoldPressableState extends State<PaperfoldPressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down || !mounted) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !PaperfoldVisualPolicy.motionAllowed(context)) {
      return widget.child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: _down ? PaperfoldMotion.tick : PaperfoldMotion.move,
        curve: _down ? PaperfoldMotion.settle : PaperfoldMotion.land,
        child: widget.child,
      ),
    );
  }
}

/// A container: radius 24, padding 14, one of the three materials.
///
/// With [onTap] it becomes a pressable, focusable, ink-rippled target.
class PaperfoldPane extends StatelessWidget {
  const PaperfoldPane({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(PaperfoldSpace.pane),
    this.tier = PaperfoldGlassTier.solid,
    this.color,
    this.borderRadius = PaperfoldShape.paneRadius,
    this.semanticLabel,
    this.outlined = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final PaperfoldGlassTier tier;

  /// Overrides the solid tint (for example a surface level).
  final Color? color;
  final BorderRadius borderRadius;
  final String? semanticLabel;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = PaperfoldGlassStyle.fromScheme(scheme);
    final live =
        tier == PaperfoldGlassTier.glassine &&
        PaperfoldVisualPolicy.glassAllowed(context);
    final fill = color ?? style.tintFor(tier, live: live);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);

    Widget body = Padding(padding: padding, child: child);
    if (onTap != null || onLongPress != null) {
      body = InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        child: body,
      );
    }

    Widget pane = Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: outlined
            ? BorderSide(color: style.edge, width: hairline)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: body,
    );

    if (semanticLabel != null) {
      pane = Semantics(
        label: semanticLabel,
        button: onTap != null,
        container: true,
        child: pane,
      );
    }

    return PaperfoldPressable(
      enabled: onTap != null || onLongPress != null,
      child: pane,
    );
  }
}
