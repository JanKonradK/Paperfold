import 'package:paperfold/utils/paperfold_layout.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/widgets/book_light.dart';
import 'package:paperfold/widgets/common/paperfold_pane.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';

/// Page turns update [Book.updateTime], the library's existing last-read order.
/// Use the current shelf objects so deleted or finished books cannot linger.
Book? continueReadingBook(Iterable<Book> books) {
  Book? latest;
  for (final book in books) {
    if (book.isDeleted || book.status != BookStatus.reading) {
      continue;
    }
    if (latest == null || book.updateTime.isAfter(latest.updateTime)) {
      latest = book;
    }
  }
  return latest;
}

/// One action that returns to the saved position without taking a book down.
class ContinueReadingBanner extends StatelessWidget {
  const ContinueReadingBanner({
    super.key,
    required this.book,
    required this.onOpen,
    this.compact = false,
  });

  final Book book;
  final VoidCallback? onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = L10n.of(context);
    final actionLabel = book.isPhysical
        ? l10n.physicalBookLogProgress
        : l10n.tileContinueReadingTitle;
    final progress = book.readingPercentage.isFinite
        ? book.readingPercentage.clamp(0.0, 1.0)
        : 0.0;
    final progressLabel = l10n.notesReadPercentage(
      '${(progress * 100).round()}%',
    );

    final layout = PaperfoldLayout.of(context);
    final landscape = compact || layout.landscape;
    final padding = landscape ? 16.0 : layout.panePadding;
    return LayoutBuilder(
      builder: (context, bounds) {
        final coverWidth = landscape
            ? 80.0
            : layout.tablet
            ? ((bounds.maxWidth - 2 * padding) * .22).clamp(144.0, 180.0)
            : 96.0;
        final wideButton =
            bounds.maxWidth - 2 * padding < 320 ||
            MediaQuery.textScalerOf(context).scale(16) >= 24;
        final button = FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onOpen,
          child: Text(actionLabel, textAlign: TextAlign.center),
        );
        final progressWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              progressLabel,
              style: layout.tablet && !landscape
                  ? theme.textTheme.bodyLarge
                  : theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, minHeight: 2),
          ],
        );
        return BookLight(
          coverPath: book.coverFullPath,
          fallback: BookSpine.resolveVisual(
            'book-${book.id}',
            scheme,
          ).background,
          fade: false,
          borderRadius: PaperfoldShape.paneRadius,
          child: PaperfoldPressable(
            child: Material(
              color: Colors.transparent,
              borderRadius: PaperfoldShape.paneRadius,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: MediaQuery.withNoTextScaling(
                            child: BookCover(
                              book: book,
                              width: coverWidth,
                              height: coverWidth * 1.5,
                            ),
                          ),
                        ),
                        SizedBox(width: padding),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: layout.tablet && !landscape
                                    ? theme.textTheme.headlineMedium
                                    : theme.textTheme.headlineSmall,
                              ),
                              if (book.author.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  book.author,
                                  style: layout.tablet && !landscape
                                      ? theme.textTheme.bodyLarge
                                      : theme.textTheme.bodyMedium,
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (landscape && !wideButton)
                                Row(
                                  children: [
                                    Expanded(child: progressWidget),
                                    const SizedBox(width: 16),
                                    Flexible(child: button),
                                  ],
                                )
                              else ...[
                                progressWidget,
                                if (!wideButton) ...[
                                  const SizedBox(height: 12),
                                  button,
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (wideButton) ...[
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, child: button),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
