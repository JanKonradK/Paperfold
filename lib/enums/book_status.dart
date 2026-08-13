import 'package:paperfold/utils/log/common.dart';

const bookStatusNotStarted = 'not_started';
const bookStatusReading = 'reading';
const bookStatusFinished = 'finished';

enum BookStatus {
  notStarted(bookStatusNotStarted),
  reading(bookStatusReading),
  finished(bookStatusFinished);

  const BookStatus(this.databaseValue);

  final String databaseValue;

  static BookStatus fromDatabase(String? value) {
    return switch (value) {
      null => BookStatus.notStarted,
      bookStatusNotStarted => BookStatus.notStarted,
      bookStatusReading => BookStatus.reading,
      bookStatusFinished => BookStatus.finished,
      _ => _fallbackFromUnknown(value),
    };
  }

  static BookStatus _fallbackFromUnknown(String value) {
    AnxLog.warning(
      'BookStatus: unknown database value "$value"; using '
      '$bookStatusNotStarted.',
    );
    return BookStatus.notStarted;
  }
}
