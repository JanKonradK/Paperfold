import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/service/book_binding.dart';

/// The binding of a real book, with the reader's settings applied.
///
/// [BookBindingResolver] is deliberately pure: it knows nothing about the
/// library, the database or the preferences, so it can be tested with a line
/// of metadata and no fixtures. This is the one place that joins it to a
/// stored book and to what the reader has asked for.
extension BookBindingForBook on Book {
  /// The binding this book is drawn with, and why.
  BookBindingVerdict bindingVerdict({Iterable<String> tags = const []}) {
    return BookBindingResolver.resolve(
      title: title,
      author: author,
      description: description,
      tags: tags,
      choice: Prefs().bookBindingChoice(id),
      fallback: Prefs().defaultBookBinding,
    );
  }

  BookBinding binding({Iterable<String> tags = const []}) =>
      bindingVerdict(tags: tags).binding;
}
