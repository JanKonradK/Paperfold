import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/l10n/generated/L10n.dart';

/// A two-position slider between the spine view and the cover view.
///
/// A tap on either half selects it, and a horizontal drag moves the thumb.
/// Each half is a labelled button with a selected state for screen readers.
class ShelfViewSwitch extends StatelessWidget {
  const ShelfViewSwitch({
    super.key,
    required this.showCovers,
    required this.onChanged,
  });

  final bool showCovers;

  /// Null disables the control.
  final ValueChanged<bool>? onChanged;

  static const double _segment = 44;
  static const double _height = 36;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    Widget segment(bool covers, IconData icon, String label) {
      final selected = covers == showCovers;
      return Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: selected,
          enabled: enabled,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            key: ValueKey(covers ? 'shelf-view-covers' : 'shelf-view-spines'),
            onTap: enabled && !selected ? () => onChanged!(covers) : null,
            radius: _segment / 2,
            child: SizedBox(
              width: _segment,
              height: 48,
              child: Icon(
                icon,
                size: 20,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: l10n.shelfBookView,
      child: GestureDetector(
        key: const ValueKey('shelf-view-control'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: enabled
            ? (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity == 0) return;
                // Toward the end edge selects covers, in either direction.
                final covers = rtl ? velocity < 0 : velocity > 0;
                if (covers != showCovers) onChanged!(covers);
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: SizedBox(
            width: _segment * 2 + 4,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: _height,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(_height / 2),
                  ),
                ),
                AnimatedAlign(
                  duration: duration,
                  curve: PaperfoldMotion.settle,
                  alignment: showCovers
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      width: _segment,
                      height: _height - 4,
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(_height / 2),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    segment(
                      false,
                      Icons.view_week_outlined,
                      l10n.shelfViewSpines,
                    ),
                    segment(true, Icons.grid_view_rounded, l10n.shelfViewCoverGrid),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
