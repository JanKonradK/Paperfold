import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/utils/paperfold_layout.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';

/// Shared by Appearance and Settings home. Uses the shelf's geometry and data.
class LibraryLayoutControl extends ConsumerWidget {
  const LibraryLayoutControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(shelfHomeProvider).asData?.value;
    final books = {
      for (final book in [
        ...?data?.readingNow,
        ...?data?.favourites,
        ...?data?.toBeRead,
        ...?data?.finished,
      ])
        book.id: book,
    }.values.toList();
    return ListenableBuilder(
      listenable: Prefs(),
      builder: (context, _) => LayoutBuilder(
        builder: (context, bounds) {
          final layout = PaperfoldLayout.of(context, constraints: bounds);
          final saved = Prefs().libraryCoversPerRow;
          final density = layout.covers(saved);
          final portraitContent =
              layout.window.shortestSide - 2 * layout.gutter;
          final maximum = math.min(
            layout.tablet ? 8 : 5,
            math.max(1, ((portraitContent + 12) / 84).floor()),
          );
          final minimum = math.min(maximum, layout.tablet ? 3 : 2);
          final value = (saved == 0 ? layout.defaultCoversPerRow : saved).clamp(
            minimum,
            maximum,
          );
          final l10n = L10n.of(context);
          return Padding(
            padding: EdgeInsets.all(layout.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.libraryCoversPerRow,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => Prefs().libraryCoversPerRow = 0,
                      child: Semantics(
                        selected: saved == 0,
                        child: Text(l10n.libraryLayoutAuto),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.libraryLayoutFewer,
                      onPressed: value > minimum
                          ? () => Prefs().libraryCoversPerRow = value - 1
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '$value',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.libraryLayoutMore,
                      onPressed: value < maximum
                          ? () => Prefs().libraryCoversPerRow = value + 1
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.libraryLayoutHelp(density.columns),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < density.columns; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        SizedBox(
                          width: density.coverWidth,
                          height: density.coverWidth * 1.5,
                          child: MediaQuery.withNoTextScaling(
                            child: i < books.length
                                ? BookCover(book: books[i], radius: 4)
                                : BookCoverImage(
                                    path: null,
                                    fallback: ColoredBox(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: Center(
                                        child: Icon(
                                          Icons.menu_book_outlined,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
