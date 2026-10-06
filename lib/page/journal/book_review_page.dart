import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/book_review.dart';
import 'package:paperfold/page/journal/dot_pages_page.dart';
import 'package:paperfold/providers/journal_home.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/widgets/common/load_failure.dart';

/// The review sheet for one book. plan.md Section 3.2 fixes the six ratings.
///
/// The sheet saves on leaving rather than behind a Save button: this is a
/// journal, and a reader who writes a thought and presses Back should not lose
/// it. An untouched sheet writes nothing, so opening a review never creates a
/// row.
class BookReviewPage extends ConsumerStatefulWidget {
  const BookReviewPage({super.key, required this.book, this.dao});

  final Book book;

  /// Injected in tests so the sheet can run against an in-memory database.
  /// Production passes nothing and gets the shared DAO.
  final JournalDao? dao;

  @override
  ConsumerState<BookReviewPage> createState() => _BookReviewPageState();
}

class _BookReviewPageState extends ConsumerState<BookReviewPage> {
  JournalDao get _dao => widget.dao ?? journalDao;
  BookReview? _review;
  Object? _loadError;
  bool _dirty = false;
  bool _saving = false;
  bool _allowPop = false;
  bool _openingPages = false;
  late final TextEditingController _genre;
  late final TextEditingController _format;
  late final TextEditingController _character;
  late final TextEditingController _quote;
  late final TextEditingController _thoughts;

  @override
  void initState() {
    super.initState();
    _genre = TextEditingController();
    _format = TextEditingController();
    _character = TextEditingController();
    _quote = TextEditingController();
    _thoughts = TextEditingController();
    for (final controller in [_genre, _format, _character, _quote, _thoughts]) {
      controller.addListener(() => _dirty = true);
    }
    _load();
  }

  @override
  void dispose() {
    _genre.dispose();
    _format.dispose();
    _character.dispose();
    _quote.dispose();
    _thoughts.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final review = await _dao.reviewOrEmpty(widget.book.id);
      if (!mounted) return;
      setState(() {
        _review = review;
        _genre.text = review.genre;
        _format.text = review.format;
        _character.text = review.favoriteCharacter;
        _quote.text = review.favoriteQuote;
        _thoughts.text = review.thoughts;
        _dirty = false;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  BookReview get _current =>
      (_review ?? BookReview(bookId: widget.book.id)).copyWith(
        genre: _genre.text,
        format: _format.text,
        favoriteCharacter: _character.text,
        favoriteQuote: _quote.text,
        thoughts: _thoughts.text,
      );

  Future<bool> _save() async {
    if (_saving) return false;
    if (_review == null || !_dirty) return true;
    final review = _current;
    setState(() => _saving = true);
    try {
      final id = await _dao.saveReview(review);
      if (!mounted) return false;
      // Keep the generated id for the next save. A cleared review has no row.
      _review = BookReview.fromDb({...review.toDb(), 'id': id});
      _dirty = false;
      ref.invalidate(journalHomeProvider);
      return true;
    } catch (error, stackTrace) {
      AnxLog.warning('Could not save book review', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).journalSaveFailed)),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    if (!await _save() || !mounted || _allowPop) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  void _setRating(BookReview Function(BookReview) apply) {
    if (_saving || _allowPop) return;
    setState(() {
      _review = apply(_current);
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final review = _review;

    return PopScope(
      canPop: _allowPop || _review == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.book.title),
          actions: [
            IconButton(
              tooltip: l10n.reviewOpenPages,
              icon: const Icon(Icons.article_outlined),
              // Save before leaving: the dot pages write to the same journal,
              // and coming back to a stale sheet would lose this one's edits.
              onPressed: review == null || _saving || _openingPages
                  ? null
                  : () async {
                      if (_openingPages) return;
                      setState(() => _openingPages = true);
                      try {
                        if (!await _save() || !context.mounted) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => DotPagesPage(
                                book: widget.book, dao: widget.dao),
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _openingPages = false);
                      }
                    },
            ),
          ],
        ),
        body: _loadError != null
            ? LoadFailure.page(
                title: l10n.journalLoadFailed,
                error: _loadError,
                onRetry: _load,
              )
            : review == null
                ? const Center(child: CircularProgressIndicator())
                : AbsorbPointer(
                    absorbing: _saving || _allowPop,
                    child: ListView(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        // The keyboard must never sit on top of the field being
                        // typed into. plan.md Section 5.3 makes the IME inset
                        // non-negotiable.
                        bottom: 32 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      children: [
                        _RatingRow(
                          label: l10n.reviewRatingOverall,
                          value: review.ratingOverall,
                          onChanged: (value) => _setRating(
                            (r) => r.copyWith(ratingOverall: value),
                          ),
                        ),
                        _RatingRow(
                          label: l10n.reviewRatingPlot,
                          value: review.ratingPlot,
                          onChanged: (value) =>
                              _setRating((r) => r.copyWith(ratingPlot: value)),
                        ),
                        _RatingRow(
                          label: l10n.reviewRatingEnding,
                          value: review.ratingEnding,
                          onChanged: (value) => _setRating(
                              (r) => r.copyWith(ratingEnding: value)),
                        ),
                        _RatingRow(
                          label: l10n.reviewRatingWorld,
                          value: review.ratingWorld,
                          onChanged: (value) =>
                              _setRating((r) => r.copyWith(ratingWorld: value)),
                        ),
                        _RatingRow(
                          label: l10n.reviewRatingCharacters,
                          value: review.ratingCharacters,
                          onChanged: (value) => _setRating(
                              (r) => r.copyWith(ratingCharacters: value)),
                        ),
                        _RatingRow(
                          label: l10n.reviewRatingSpice,
                          value: review.ratingSpice,
                          // Drawn with a chili rather than a star. The stored value
                          // is the same number.
                          icon: Icons.local_fire_department_rounded,
                          onChanged: (value) =>
                              _setRating((r) => r.copyWith(ratingSpice: value)),
                        ),
                        const SizedBox(height: 8),
                        _Field(
                            label: l10n.reviewGenre,
                            controller: _genre,
                            readOnly: _saving || _allowPop),
                        _Field(
                            label: l10n.reviewFormat,
                            controller: _format,
                            readOnly: _saving || _allowPop),
                        _Field(
                          label: l10n.reviewFavoriteCharacter,
                          controller: _character,
                          readOnly: _saving || _allowPop,
                        ),
                        _Field(
                          label: l10n.reviewFavoriteQuote,
                          controller: _quote,
                          readOnly: _saving || _allowPop,
                          maxLines: 3,
                        ),
                        _Field(
                          label: l10n.reviewThoughts,
                          controller: _thoughts,
                          readOnly: _saving || _allowPop,
                          maxLines: 8,
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// One rating, 0 to 5. Zero means "not rated", not "bad", so tapping the mark
/// that is already the value clears it back to zero.
class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon = Icons.star_rounded,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marks = [
      for (var mark = 1; mark <= 5; mark++)
        IconButton(
          tooltip: '$label $mark',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => onChanged(value == mark ? 0 : mark),
          icon: Icon(
            mark <= value ? icon : Icons.star_border_rounded,
            color: mark <= value
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(builder: (context, constraints) {
        final heading = Text(label, style: theme.textTheme.titleSmall);
        if (constraints.maxWidth >= 360 &&
            MediaQuery.textScalerOf(context).scale(16) <= 20) {
          return Row(children: [Expanded(child: heading), ...marks]);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, Wrap(children: marks)],
        );
      }),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    required this.readOnly,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
