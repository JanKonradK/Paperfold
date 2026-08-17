import 'package:flutter/material.dart';

/// Centres a short message — an empty state, a failure — and scrolls it only
/// when there is a bounded height to scroll inside.
///
/// The guard is the whole point. A [SingleChildScrollView] given an unbounded
/// height takes an infinite extent, and the parent then reports an overflow of
/// about a hundred thousand pixels. These blocks get dropped into bare
/// [Column]s and into [FittedBox]es, both of which measure their children with
/// unbounded height, so the same widget has to be correct in both.
class MessageBlock extends StatelessWidget {
  const MessageBlock({
    super.key,
    required this.child,
    this.maxWidth = 440,
    this.padding = const EdgeInsets.all(24),
  });

  /// Use a column with [MainAxisSize.min]; it is measured under an unbounded
  /// height whenever the parent is unbounded.
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Widget block = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedHeight) {
          return Center(child: Padding(padding: padding, child: block));
        }
        return Center(
          child: SingleChildScrollView(padding: padding, child: block),
        );
      },
    );
  }
}
