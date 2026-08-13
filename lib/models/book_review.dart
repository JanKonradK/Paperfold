/// The review sheet for one book. plan.md Section 3.2.
///
/// All six ratings are 0 to 5, where 0 means "not rated" rather than "bad".
/// `ratingSpice` is drawn with a chili mark instead of stars, but that is a
/// view choice; the stored value is just the number.
class BookReview {
  const BookReview({
    this.id,
    required this.bookId,
    this.genre = '',
    this.format = '',
    this.ratingOverall = 0,
    this.ratingPlot = 0,
    this.ratingEnding = 0,
    this.ratingWorld = 0,
    this.ratingCharacters = 0,
    this.ratingSpice = 0,
    this.favoriteCharacter = '',
    this.favoriteQuote = '',
    this.thoughts = '',
  });

  /// Null until the row has been written.
  final int? id;
  final int bookId;
  final String genre;
  final String format;
  final int ratingOverall;
  final int ratingPlot;
  final int ratingEnding;
  final int ratingWorld;
  final int ratingCharacters;
  final int ratingSpice;
  final String favoriteCharacter;
  final String favoriteQuote;
  final String thoughts;

  /// True when the reader has not put anything in the sheet yet. An empty
  /// review is worth keeping in memory but not worth writing to the database.
  bool get isEmpty =>
      ratingOverall == 0 &&
      ratingPlot == 0 &&
      ratingEnding == 0 &&
      ratingWorld == 0 &&
      ratingCharacters == 0 &&
      ratingSpice == 0 &&
      genre.trim().isEmpty &&
      format.trim().isEmpty &&
      favoriteCharacter.trim().isEmpty &&
      favoriteQuote.trim().isEmpty &&
      thoughts.trim().isEmpty;

  static int _rating(Object? value) {
    final raw = value is int ? value : int.tryParse('${value ?? ''}') ?? 0;
    // A rating outside 0 to 5 means a bad write or a hand-edited database.
    // Clamp rather than throw: the reader's other notes are still readable.
    return raw.clamp(0, 5);
  }

  factory BookReview.fromDb(Map<String, dynamic> row) {
    return BookReview(
      id: row['id'] as int?,
      bookId: row['book_id'] as int? ?? 0,
      genre: row['genre'] as String? ?? '',
      format: row['format'] as String? ?? '',
      ratingOverall: _rating(row['rating_overall']),
      ratingPlot: _rating(row['rating_plot']),
      ratingEnding: _rating(row['rating_ending']),
      ratingWorld: _rating(row['rating_world']),
      ratingCharacters: _rating(row['rating_characters']),
      ratingSpice: _rating(row['rating_spice']),
      favoriteCharacter: row['favorite_character'] as String? ?? '',
      favoriteQuote: row['favorite_quote'] as String? ?? '',
      thoughts: row['thoughts'] as String? ?? '',
    );
  }

  Map<String, Object?> toDb() {
    return {
      'book_id': bookId,
      'genre': genre,
      'format': format,
      'rating_overall': ratingOverall,
      'rating_plot': ratingPlot,
      'rating_ending': ratingEnding,
      'rating_world': ratingWorld,
      'rating_characters': ratingCharacters,
      'rating_spice': ratingSpice,
      'favorite_character': favoriteCharacter,
      'favorite_quote': favoriteQuote,
      'thoughts': thoughts,
    };
  }

  BookReview copyWith({
    int? id,
    String? genre,
    String? format,
    int? ratingOverall,
    int? ratingPlot,
    int? ratingEnding,
    int? ratingWorld,
    int? ratingCharacters,
    int? ratingSpice,
    String? favoriteCharacter,
    String? favoriteQuote,
    String? thoughts,
  }) {
    return BookReview(
      id: id ?? this.id,
      bookId: bookId,
      genre: genre ?? this.genre,
      format: format ?? this.format,
      ratingOverall: ratingOverall ?? this.ratingOverall,
      ratingPlot: ratingPlot ?? this.ratingPlot,
      ratingEnding: ratingEnding ?? this.ratingEnding,
      ratingWorld: ratingWorld ?? this.ratingWorld,
      ratingCharacters: ratingCharacters ?? this.ratingCharacters,
      ratingSpice: ratingSpice ?? this.ratingSpice,
      favoriteCharacter: favoriteCharacter ?? this.favoriteCharacter,
      favoriteQuote: favoriteQuote ?? this.favoriteQuote,
      thoughts: thoughts ?? this.thoughts,
    );
  }
}
