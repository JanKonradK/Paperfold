import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/search_journal_result.dart';
import 'package:paperfold/page/journal/book_review_page.dart';
import 'package:paperfold/page/journal/dot_pages_page.dart';
import 'package:paperfold/providers/search.dart';

class SearchJournalTile extends ConsumerWidget {
  const SearchJournalTile({
    super.key,
    required this.result,
    required this.query,
  });

  final SearchJournalResult result;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final review = result.kind == SearchJournalKind.review;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      leading:
          Icon(review ? Icons.rate_review_outlined : Icons.article_outlined),
      title: Text(
        result.book.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review
                ? l10n.searchJournalReview
                : l10n.searchJournalPage((result.pageIndex ?? 0) + 1),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            _excerpt(result.text, query),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        FocusScope.of(context).unfocus();
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => review
                ? BookReviewPage(book: result.book)
                : DotPagesPage(book: result.book, initialPageId: result.id),
          ),
        );
        if (context.mounted) ref.invalidate(searchResultProvider);
      },
    );
  }

  /// Keep the matching words in view, even when they are deep in a long page.
  static TextSpan _excerpt(String body, String query) {
    final text = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final keyword = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (keyword.isEmpty) return TextSpan(text: text);

    final literal = RegExp.escape(keyword);
    final context = RegExp(
      '.{0,18}$literal.{0,120}',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    final excerpt =
        context?.group(0) ?? String.fromCharCodes(text.runes.take(180));
    final matches = RegExp(literal, caseSensitive: false, unicode: true)
        .allMatches(excerpt);
    final spans = <TextSpan>[
      if (context != null && context.start > 0) const TextSpan(text: '…'),
    ];
    var offset = 0;
    for (final match in matches) {
      spans.add(TextSpan(text: excerpt.substring(offset, match.start)));
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      offset = match.end;
    }
    spans.add(TextSpan(text: excerpt.substring(offset)));
    if ((context?.end ?? excerpt.length) < text.length) {
      spans.add(const TextSpan(text: '…'));
    }
    return TextSpan(children: spans);
  }
}
