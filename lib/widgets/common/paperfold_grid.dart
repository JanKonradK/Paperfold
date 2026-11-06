import 'package:material_ui/material_ui.dart';

/// Cells in rows of [columns], read left to right, top to bottom.
///
/// Each cell takes its natural height. With [equalHeight], the cells of a
/// row stretch to the tallest one; use it only for simple cells, since it
/// measures intrinsic sizes (a scrolling list inside cannot answer).
/// One column is a plain column, so a phone sees a list.
class PaperfoldGrid extends StatelessWidget {
  const PaperfoldGrid({
    super.key,
    required this.columns,
    required this.children,
    this.gap = 12,
    this.equalHeight = false,
  });

  final bool equalHeight;

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      if (columns <= 1) {
        rows.add(children[start]);
        continue;
      }
      final row = Row(
        crossAxisAlignment: equalHeight
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start,
        children: [
          for (var i = start; i < start + columns; i++) ...[
            if (i > start) SizedBox(width: gap),
            Expanded(
              child: i < children.length
                  ? children[i]
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      );
      rows.add(equalHeight ? IntrinsicHeight(child: row) : row);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
