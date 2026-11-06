import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';
import 'package:material_ui/material_ui.dart';

abstract class BaseRoundedContainer extends StatelessWidget {
  const BaseRoundedContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.radius,
    this.constraints,
    this.animationDuration = PaperfoldMotion.move,
    this.animationCurve = PaperfoldMotion.settle,
  });

  static const double _defaultRadius = PaperfoldShape.pane;

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final BoxConstraints? constraints;
  final Duration animationDuration;
  final Curve animationCurve;

  BorderRadiusGeometry get _borderRadius =>
      BorderRadiusGeometry.circular(radius ?? _defaultRadius);

  @override
  Widget build(BuildContext context) {
    final BorderRadiusGeometry borderRadius = _borderRadius;

    return AnimatedContainer(
      duration: PaperfoldVisualPolicy.motionAllowed(context)
          ? PaperfoldMotion.of(context, animationDuration)
          : Duration.zero,
      curve: animationCurve,
      margin: margin?.add(const EdgeInsets.all(1)) ?? const EdgeInsets.all(1),
      width: width,
      height: height,
      constraints: constraints,
      decoration: decoration(context, borderRadius),
      child: ClipRRect(
        borderRadius: borderRadius,
        // Paint row ink above the card fill, within its rounded clip.
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }

  ShapeDecoration decoration(
    BuildContext context,
    BorderRadiusGeometry borderRadius,
  );

  @protected
  ShapeDecoration buildShapeDecoration({
    Color? color,
    required BorderSide borderSide,
    required BorderRadiusGeometry borderRadius,
  }) {
    return ShapeDecoration(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: borderSide,
      ),
    );
  }
}
