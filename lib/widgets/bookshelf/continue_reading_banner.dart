import 'package:material_ui/material_ui.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';

/// Page turns update [Book.updateTime], the library's existing last-read order.
/// Use the current shelf objects so deleted or finished books cannot linger.
Book? continueReadingBook(Iterable<Book> books) {
  Book? latest;
  for (final book in books) {
    if (book.isDeleted ||
        book.status != BookStatus.reading ||
        book.filePath.trim().isEmpty) {
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
    final progress = book.readingPercentage.isFinite
        ? book.readingPercentage.clamp(0.0, 1.0)
        : 0.0;
    final progressLabel =
        l10n.notesReadPercentage('${(progress * 100).round()}%');

    return Semantics(
      button: true,
      enabled: onOpen != null,
      label: [
        l10n.tileContinueReadingTitle,
        book.title,
        if (book.author.trim().isNotEmpty) book.author,
        progressLabel,
      ].join(', '),
      onTap: onOpen,
      excludeSemantics: true,
      child: compact
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(l10n.tileContinueReadingTitle),
              ),
            )
          : Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      MediaQuery.withNoTextScaling(
                        child: BookCover(book: book, width: 44, height: 66),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 12,
                              runSpacing: 2,
                              children: [
                                Text(
                                  l10n.tileContinueReadingTitle,
                                  style: theme.textTheme.labelLarge
                                      ?.copyWith(color: scheme.primary),
                                ),
                                Text(
                                  progressLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 2,
                              color: scheme.primary,
                              backgroundColor:
                                  scheme.outlineVariant.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.arrow_forward_rounded, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
