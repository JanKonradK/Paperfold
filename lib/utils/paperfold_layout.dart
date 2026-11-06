import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Window geometry for one design on every screen.
///
/// Portrait stacks content in one column that fills the width. Landscape
/// saves height: the navigation moves to the start edge and two-part screens
/// may sit side by side. Read it in a build method or a LayoutBuilder.
@immutable
class PaperfoldLayout {
  const PaperfoldLayout._({
    required this.window,
    required this.landscape,
    required this.tablet,
    required this.width,
  });

  /// [constraints] is the local width a screen has, when it differs from the
  /// window (for example, beside the side navigation).
  factory PaperfoldLayout.of(
    BuildContext context, {
    BoxConstraints? constraints,
  }) {
    final window = MediaQuery.sizeOf(context);
    final width = constraints != null && constraints.hasBoundedWidth
        ? constraints.maxWidth
        : window.width;
    return PaperfoldLayout._(
      window: window,
      // A square window counts as portrait.
      landscape: window.width > window.height,
      // From the short side, so rotation never changes it.
      tablet: window.shortestSide >= 600,
      width: width,
    );
  }

  final Size window;
  final bool landscape;
  final bool tablet;

  /// The width this screen lays out in, before gutters.
  final double width;

  /// Side margin of page content.
  double get gutter => tablet ? 24 : 16;

  /// Padding inside a pane.
  double get panePadding => tablet ? 24 : 16;

  /// Content width inside the gutters.
  double get content => math.max(0, width - 2 * gutter);

  /// How many cells of at least [minWidth] fit across [content], up to [max].
  int columns(double minWidth, {double gap = 12, int max = 12}) =>
      ((content + gap) / (minWidth + gap)).floor().clamp(1, max);

  /// Landscape with room for the vertical navigation bar on the start edge.
  bool sideNavigation(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final height = window.height - safe.vertical;
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 18;
    return landscape &&
        window.width - safe.horizontal >= 600 &&
        height >= (largeText ? 432 : 320);
  }

  /// The default library covers per row in portrait.
  int get defaultCoversPerRow => tablet ? 5 : 3;

  /// Library cover columns and width for a saved [preference] (0 = Auto).
  ///
  /// Portrait shows the chosen count. Landscape keeps the portrait cover
  /// size, so more columns appear. A cover is never narrower than 72.
  ({int columns, double coverWidth}) covers(int preference, {double gap = 12}) {
    final portraitContent = window.shortestSide - 2 * gutter;
    final most = math.max(1, ((portraitContent + gap) / (72 + gap)).floor());
    final perRow = (preference <= 0 ? defaultCoversPerRow : preference).clamp(
      1,
      most,
    );
    final reference = (portraitContent - (perRow - 1) * gap) / perRow;
    final count = landscape
        ? math.max(1, ((content + gap) / (reference + gap)).floor())
        : math.min(perRow, math.max(1, ((content + gap) / (72 + gap)).floor()));
    return (columns: count, coverWidth: (content - (count - 1) * gap) / count);
  }
}
