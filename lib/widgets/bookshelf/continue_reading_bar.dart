import 'package:flutter/material.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';

/// The way back into the book you are actually reading.
///
/// Reaching a book used to mean finding the right shelf, then finding the
/// right spine on it, which is a lot of looking for the one book the reader
/// almost always wants. This sits above the shelves and takes one tap.
///
/// It is deliberately the only filled, high-contrast object on the home
/// screen. Everything below it is glass and hairlines, so the eye lands here
/// first without the bar having to shout.
class ContinueReadingBar extends StatelessWidget {
  const ContinueReadingBar({
    super.key,
    required this.book,
    required this.onOpen,
  });

  final Book book;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = L10n.of(context);
    final percent = (book.readingPercentage.clamp(0.0, 1.0)).toDouble();
    final percentLabel = '${(percent * 100).round()}%';

    return Semantics(
      button: true,
      label: '${l10n.tileContinueReadingTitle}. ${book.title}. $percentLabel',
      onTap: onOpen,
      child: ExcludeSemantics(
        child: Material(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 44,
                      height: 62,
                      child: BookCover(book: book),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // The bar states the number as well as drawing it,
                        // because a track alone is not readable by a screen
                        // reader and not precise to a glance.
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  minHeight: 4,
                                  backgroundColor:
                                      scheme.onPrimaryContainer.withValues(
                                    alpha: 0.20,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    scheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              percentLabel,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.play_arrow_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
