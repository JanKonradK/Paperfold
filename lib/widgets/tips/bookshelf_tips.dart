import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/common/message_block.dart';
import 'package:paperfold/widgets/ornament.dart';
import 'package:material_ui/material_ui.dart';

/// The bookshelf empty state.
///
/// It showed a kaomoji at 50 points in `Colors.grey` — inherited styling that
/// measured 2.49:1 on the light paper ground and belonged to no part of
/// Paperfold. DESIGN.md gives empty states an ornament and a block no wider
/// than 440 dp.
///
/// It lays out through [MessageBlock] because this widget is dropped into a
/// bare `Column` in the reader's note list and into a `FittedBox` on the
/// statistics dashboard, and both measure it with an unbounded height.
class BookshelfTips extends StatelessWidget {
  const BookshelfTips({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MessageBlock(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Ornament(
            ornament: PaperfoldOrnament.circularWreath,
            width: 112,
            height: 112,
            tint: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 28),
          Text(
            L10n.of(context).bookshelfTips_1,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            L10n.of(context).bookshelfTips_2,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
