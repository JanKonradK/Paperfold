import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paperfold/service/journal/entry_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('draft survives a new service and preserves the last edit', () async {
    final draft = EntryDraft();
    final writes = [
      draft.write({'text': 'first'}),
      draft.write({'text': 'last', 'photo': 'journal_photos/page.jpg'}),
    ];
    await Future.wait(writes);
    expect(await EntryDraft().read(), {
      'text': 'last',
      'photo': 'journal_photos/page.jpg',
    });
    await draft.clear();
    expect(await EntryDraft().read(), null);
  });
}
