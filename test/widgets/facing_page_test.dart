import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/widgets/reading_page/facing_page.dart';
import 'journal_test_host.dart';
class _Dao extends JournalDao {
  JournalPage? saved;
  bool later = false;
  @override
  Future<List<JournalPage>> entriesAt(int bookId, {double? progress, int? page, bool includeLater = false}) async {
    later = includeLater;
    return [const JournalPage(bookId: 1, pageIndex: 0, body: 'Earlier thought')];
  }
  @override
  Future<int> saveEntry(JournalPage entry, {int? physicalPage, int? totalPages}) async { saved = entry; return 1; }
}
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('save anchors the opening location and later entries are explicit', (tester) async {
    final dao = _Dao();
    await tester.pumpWidget(journalTestHost(FacingPage(book: Book.mock(), dao: dao, locator: 'epubcfi(/6/10)', progress: 0.24, label: 'Loomings')));
    await tester.pumpAndSettle();
    expect(find.text('Earlier thought'), findsOneWidget);
    await tester.tap(find.text('Show later entries')); await tester.pumpAndSettle();
    expect(dao.later, true);
    await tester.enterText(find.byType(TextField), 'Beside this passage');
    await tester.tap(find.text('Save')); await tester.pumpAndSettle();
    expect(dao.saved?.sourceLocator, 'epubcfi(/6/10)');
    expect(dao.saved?.sourceProgress, 0.24);
    expect(dao.saved?.body, 'Beside this passage');
  });
}
