import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/page/journal/new_entry_sheet.dart';
import 'package:paperfold/service/journal/entry_draft.dart';
import 'journal_test_host.dart';
class _Dao extends JournalDao {
  bool fail = true;
  JournalPage? saved;
  @override
  Future<int> saveEntry(JournalPage entry, {int? physicalPage, int? totalPages}) async {
    if (fail) throw StateError('disk full');
    saved = entry; return 1;
  }
}
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('failed save retains writing and recovery survives reopening', (tester) async {
    final dao = _Dao();
    await tester.pumpWidget(journalTestHost(NewEntrySheet(books: const [], dao: dao)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'A thought to keep');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await EntryDraft().read())?['text'], 'A thought to keep');
    await tester.pumpWidget(journalTestHost(const SizedBox()));
    await tester.pumpWidget(journalTestHost(NewEntrySheet(books: const [], dao: dao)));
    await tester.pumpAndSettle();
    expect(find.text('A thought to keep'), findsOneWidget);
    dao.fail = false;
    await tester.tap(find.text('Save')); await tester.pumpAndSettle();
    expect(dao.saved?.body, 'A thought to keep');
    expect(await EntryDraft().read(), null);
  });
  testWidgets('Save remains above the keyboard at large text', (tester) async {
    await tester.pumpWidget(journalTestHost(const NewEntrySheet(books: []), keyboard: 240, textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.widgetWithText(FilledButton, 'Save')).bottom, lessThanOrEqualTo(360));
    expect(tester.takeException(), null);
  });
}
