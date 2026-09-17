import 'package:flutter/material.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/tag.dart';
import 'package:paperfold/providers/shelf_home.dart';

// The shelf's name, its sort control and its filter control used to live here,
// on a glass plate under the application bar. That plate said "Reading now"
// directly beneath a bar that said "My shelves", which is one row of chrome
// spent on nothing and one shelf's worth of height taken off the books. The
// name is the bar's title now, and the two controls are its actions.

class ShelfFilterChips extends StatelessWidget {
  const ShelfFilterChips({
    super.key,
    required this.controls,
    required this.tags,
  });

  final ShelfHomeControls controls;
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    if (!controls.hasFilters) return const SizedBox.shrink();
    final l10n = L10n.of(context);
    final tagsById = {for (final tag in tags) tag.id: tag};
    final chips = <Widget>[
      for (final status in BookStatus.values)
        if (controls.statusFilters.contains(status))
          _DismissibleFilterChip(
            key: ValueKey('shelf-filter-status-${status.name}'),
            label: _statusLabel(status, l10n),
            onDeleted: () => controls.toggleStatus(status),
          ),
      if (controls.minimumRating case final rating?)
        _DismissibleFilterChip(
          key: const ValueKey('shelf-filter-rating'),
          label: l10n.shelfRatingAtLeast(rating.round()),
          onDeleted: () => controls.setMinimumRating(null),
        ),
      for (final tagId in controls.tagFilters)
        _DismissibleFilterChip(
          key: ValueKey('shelf-filter-tag-$tagId'),
          label: tagsById[tagId]?.name ?? l10n.shelfUnknownTag,
          onDeleted: () => controls.toggleTag(tagId),
        ),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }
}

class _DismissibleFilterChip extends StatelessWidget {
  const _DismissibleFilterChip({
    super.key,
    required this.label,
    required this.onDeleted,
  });

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: L10n.of(context).shelfFilterChipSemantic(label),
      onTap: onDeleted,
      excludeSemantics: true,
      child: InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

Future<void> showShelfSortSheet(
  BuildContext context,
  ShelfHomeControls controls,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => AnimatedBuilder(
      animation: controls,
      builder: (context, child) {
        final l10n = L10n.of(context);
        return SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.shelfSortTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final field in ShelfSortField.values)
                ListTile(
                  key: ValueKey('shelf-sort-${field.name}'),
                  minTileHeight: 48,
                  title: Text(_sortFieldLabel(field, l10n)),
                  trailing: controls.sortField == field
                      ? const Icon(Icons.check_rounded)
                      : null,
                  selected: controls.sortField == field,
                  onTap: () => controls.setSortField(field),
                ),
              const SizedBox(height: 12),
              SegmentedButton<ShelfSortDirection>(
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(0, 48)),
                ),
                segments: [
                  ButtonSegment(
                    value: ShelfSortDirection.ascending,
                    label: Text(controls.sortField == ShelfSortField.series
                        ? l10n.shelfSortFirstToLast
                        : l10n.commonAscending),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                  ButtonSegment(
                    value: ShelfSortDirection.descending,
                    label: Text(controls.sortField == ShelfSortField.series
                        ? l10n.shelfSortLastToFirst
                        : l10n.commonDescending),
                    icon: const Icon(Icons.arrow_downward_rounded),
                  ),
                ],
                selected: {controls.sortDirection},
                onSelectionChanged: (selection) =>
                    controls.setSortDirection(selection.first),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> showShelfFilterSheet(
  BuildContext context,
  ShelfHomeControls controls,
  List<Tag> tags,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => AnimatedBuilder(
      animation: controls,
      builder: (context, child) {
        final l10n = L10n.of(context);
        return SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            16,
            0,
            16,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.shelfFilterTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(l10n.shelfFilterStatus,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in BookStatus.values)
                    FilterChip(
                      key: ValueKey('shelf-status-choice-${status.name}'),
                      label: Text(_statusLabel(status, l10n)),
                      selected: controls.statusFilters.contains(status),
                      onSelected: (_) => controls.toggleStatus(status),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(l10n.shelfFilterRating,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var rating = 1; rating <= 5; rating++)
                    FilterChip(
                      key: ValueKey('shelf-rating-choice-$rating'),
                      label: Text(l10n.shelfRatingAtLeast(rating)),
                      selected: controls.minimumRating == rating,
                      onSelected: (selected) => controls.setMinimumRating(
                        selected ? rating.toDouble() : null,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(l10n.shelfFilterTags,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (tags.isEmpty)
                Text(l10n.tagsEmptyHint)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in tags)
                      FilterChip(
                        key: ValueKey('shelf-tag-choice-${tag.id}'),
                        label: Text(tag.name),
                        selected: controls.tagFilters.contains(tag.id),
                        onSelected: (_) => controls.toggleTag(tag.id),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                  ],
                ),
              if (controls.hasFilters) ...[
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: controls.clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: Text(l10n.shelfClearFilters),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

String _sortFieldLabel(ShelfSortField field, L10n l10n) => switch (field) {
      ShelfSortField.title => l10n.bookshelfTitle,
      ShelfSortField.author => l10n.bookshelfAuthor,
      ShelfSortField.series => l10n.shelfSortSeries,
      ShelfSortField.dateAdded => l10n.shelfSortDateAdded,
      ShelfSortField.progress => l10n.bookshelfProgress,
      ShelfSortField.rating => l10n.shelfLogRating,
    };

String _statusLabel(BookStatus status, L10n l10n) => switch (status) {
      BookStatus.reading => l10n.bookshelfFilterReading,
      BookStatus.finished => l10n.bookshelfFilterFinished,
      BookStatus.notStarted => l10n.bookshelfFilterNotStarted,
    };
