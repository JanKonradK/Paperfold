import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/service/book_binding_settings.dart';
import 'package:paperfold/widgets/book_model/book_model.dart';

/// Asks how a newly installed book is bound, one book at a time.
///
/// The binding is the one thing about a book that Paperfold cannot read off
/// the file and cannot hide: it is the shape of the object on the shelf. The
/// resolver guesses it from the metadata and is wrong often enough that the
/// shelf fills up with cased Victorian novels that are really paperbacks. The
/// moment to ask is the moment the book arrives, while the reader still has it
/// in mind, and the question is answered by looking at two objects rather than
/// by reading two words.
///
/// Returns once every book has been answered for. A book the reader dismisses
/// keeps the guess, which is what [BookBindingChoice.automatic] already means.
Future<void> askBookBindings(BuildContext context, List<Book> books) async {
  for (final book in books) {
    if (!context.mounted) return;
    final choice = await showModalBottomSheet<BookBindingChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _BookBindingSheet(book: book),
    );
    if (choice != null && choice != BookBindingChoice.automatic) {
      Prefs().setBookBindingChoice(book.id, choice);
    }
  }
}

class _BookBindingSheet extends StatelessWidget {
  const _BookBindingSheet({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    // The guess, so the sheet opens with one of the two already argued for.
    final guess = book.binding();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.bookBindingAskTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.bookBindingAskBody(book.title),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _BindingChoice(
                    book: book,
                    binding: BookBinding.hardback,
                    label: l10n.bookBindingHardback,
                    suggested: guess == BookBinding.hardback,
                    onChosen: () => Navigator.pop(
                      context,
                      BookBindingChoice.hardback,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BindingChoice(
                    book: book,
                    binding: BookBinding.softback,
                    label: l10n.bookBindingSoftback,
                    suggested: guess == BookBinding.softback,
                    onChosen: () => Navigator.pop(
                      context,
                      BookBindingChoice.softback,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                BookBindingChoice.automatic,
              ),
              child: Text(l10n.bookBindingAskDecide),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the two answers: the book itself, drawn as it would stand.
///
/// Not a radio button with a word beside it. The difference between the two
/// bindings is a difference in the shape of an object, and the reader is being
/// asked to recognise their own copy, which is a thing they do by looking at
/// it.
class _BindingChoice extends StatelessWidget {
  const _BindingChoice({
    required this.book,
    required this.binding,
    required this.label,
    required this.suggested,
    required this.onChosen,
  });

  final Book book;
  final BookBinding binding;
  final String label;
  final bool suggested;
  final VoidCallback onChosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: suggested,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onChosen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 190,
                child: BookModel(
                  title: book.title,
                  author: book.author,
                  coverPath: book.coverFullPath,
                  stableId: 'book-${book.id}',
                  binding: binding,
                  open: 0,
                  tapToOpen: false,
                  dragToOpen: false,
                  turnToSeeBack: false,
                  semanticLabel: label,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: suggested
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: suggested ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
