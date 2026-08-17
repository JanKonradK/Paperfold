import 'dart:math' as math;

/// One line about reading, printed on the page the application opens onto.
class OpeningQuote {
  const OpeningQuote(this.words, this.source);

  /// The line itself, without quotation marks. The page draws those.
  final String words;

  /// Who said it. Always present: an unattributed quotation is a slogan.
  final String source;
}

/// What is printed on the first page of Paperfold.
///
/// Real lines by real writers, each one short enough to be read in the second
/// or two the page is on screen, and each one attributed. The page used to
/// carry one invented aphorism, which is a slogan on a splash screen however
/// well it is set.
///
/// **Not translated, on purpose.** A quotation is a thing somebody wrote in
/// their own words; run through a machine into thirteen languages it stops
/// being a quotation and becomes a paraphrase with a famous name under it.
/// Every writer here is out of copyright, which is also why the list can be
/// shipped whole rather than sampled.
abstract final class OpeningQuotes {
  static const List<OpeningQuote> all = [
    OpeningQuote(
      'A room without books is like a body without a soul.',
      'Cicero',
    ),
    OpeningQuote(
      'There is no frigate like a book to take us lands away.',
      'Emily Dickinson',
    ),
    OpeningQuote(
      'A good book is the precious lifeblood of a master spirit.',
      'John Milton',
    ),
    OpeningQuote(
      'Some books are to be tasted, others to be swallowed.',
      'Francis Bacon',
    ),
    OpeningQuote(
      'Books are the treasured wealth of the world.',
      'Henry David Thoreau',
    ),
    OpeningQuote(
      'Reading is to the mind what exercise is to the body.',
      'Joseph Addison',
    ),
    OpeningQuote(
      'He that loves reading has everything within his reach.',
      'William Godwin',
    ),
    OpeningQuote(
      'Once you learn to read, you will be forever free.',
      'Frederick Douglass',
    ),
    OpeningQuote(
      'Books are the quietest and most constant of friends.',
      'Charles W. Eliot',
    ),
    OpeningQuote(
      'The man who does not read has no advantage over the man who cannot.',
      'Mark Twain',
    ),
    OpeningQuote(
      'Books are lighthouses erected in the great sea of time.',
      'Edwin Percy Whipple',
    ),
    OpeningQuote(
      'No entertainment is so cheap as reading, nor any pleasure so lasting.',
      'Mary Wortley Montagu',
    ),
    OpeningQuote(
      'Old books are books of the world’s youth.',
      'Ralph Waldo Emerson',
    ),
    OpeningQuote(
      'A book is a garden carried in the pocket.',
      'Arabic proverb',
    ),
    OpeningQuote(
      'The reading of all good books is like conversation with the finest minds.',
      'René Descartes',
    ),
    OpeningQuote(
      'Books are men of higher stature.',
      'Elizabeth Barrett Browning',
    ),
    OpeningQuote(
      'Where they burn books, they will in the end burn people.',
      'Heinrich Heine',
    ),
    OpeningQuote(
      'To read without reflecting is like eating without digesting.',
      'Edmund Burke',
    ),
  ];

  /// A different line each time the application is started.
  ///
  /// Seeded from the clock rather than held in the preferences: the page is
  /// looked at for two seconds once a day, and a stored cursor would be one
  /// more thing to migrate for a line nobody is keeping track of.
  static OpeningQuote pick([math.Random? random]) =>
      all[(random ?? math.Random()).nextInt(all.length)];
}
