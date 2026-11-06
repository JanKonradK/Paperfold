import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/page/journal/journal_home_page.dart';
import 'journal_test_host.dart';
class _Dao extends JournalDao {
  @override
  Future<List<JournalPage>> recentEntries({int offset = 0, int limit = 30}) async => [const JournalPage(bookId: 0, pageIndex: 0, body: 'An unassigned thought')];
}
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('the first entry is on the first screen and Recent entries is the default', (tester) async {
    await tester.pumpWidget(journalTestHost(JournalHomePage(dao: _Dao(), books: const [])));
    await tester.pumpAndSettle();
    expect(find.text('An unassigned thought'), findsOneWidget);
    final segment = tester.widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>));
    expect(segment.selected, {false});
    // The tools are one short row above the feed, so paging never buries
    // them, and the writing still starts on the first screen.
    expect(tester.getTopLeft(find.text('Reading challenge')).dy, lessThan(tester.getTopLeft(find.text('An unassigned thought')).dy));
    expect(find.text('An unassigned thought').hitTestable(), findsOneWidget);
  });
}
