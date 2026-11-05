import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/service/notes/export_notes.dart';
import 'package:paperfold/utils/save_file_to_download.dart';

void main() {
  test('export titles cannot become paths or Windows device names', () {
    expect(safeDownloadFileName('../notes/Book: One?.md'),
        '.._notes_Book_ One_.md');
    expect(safeDownloadFileName(r'..\notes\Book.txt'), '.._notes_Book.txt');
    expect(safeDownloadFileName('CON.txt'), '_CON.txt');
    expect(safeDownloadFileName('lpt1.csv'), '_lpt1.csv');
    expect(safeDownloadFileName('... '), 'export');
    expect(safeDownloadFileName('漢字 📖.txt'), '漢字 📖.txt');
  });

  test('an empty notes export needs no active screen', () async {
    await exportNotes(Book.mock(), [], ExportType.csv);
  });
}
