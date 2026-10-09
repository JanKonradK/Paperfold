import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/book_note.dart';
import 'package:paperfold/models/book_notes_state.dart';
import 'package:paperfold/page/book_notes_page.dart';
import 'package:paperfold/providers/book_notes.dart';
import 'package:paperfold/widgets/book_notes/book_notes_list.dart';
import 'package:paperfold/widgets/common/container/filled_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NotesController extends BookNotesController {
  List<BookNote> _notes(int count) => List.generate(
        count,
        (index) => BookNote(
          id: index + 1,
          bookId: 1,
          content: 'A passage to keep.',
          cfi: 'epubcfi(/6/2!/4/2:$index)',
          chapter: 'Chapter one',
          type: 'highlight',
          color: 'FFFF00',
          updateTime: DateTime(2026),
        ),
      );

  @override
  Future<BookNotesState> build(Book book) async => BookNotesState(
        book: book,
        allNotes: _notes(2),
        // A filtered list still reports the book's total in the page header.
        visibleNotes: [],
        viewSortMode: const NotesSortMode(
          field: NotesSortField.createdTime,
          direction: SortDirection.desc,
        ),
        exportSortMode: const NotesSortMode(
          field: NotesSortField.createdTime,
          direction: SortDirection.desc,
        ),
        showBookmarks: true,
        enabledTypeColors: {},
        selectedNoteIds: {},
      );

  void setCount(int count) {
    state = AsyncData(state.requireValue.copyWith(allNotes: _notes(count)));
  }
}

Future<void> _pumpNotes(
  WidgetTester tester,
  _NotesController controller,
) async {
  SharedPreferences.setMockInitialValues({});
  await Prefs().initPrefs();
  final book = Book.mock().copyWith(
    title: 'A long book title with a subtitle for a small screen',
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      bookNotesControllerProvider(book).overrideWith(() => controller),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
      supportedLocales: L10n.supportedLocales,
      locale: const Locale('en'),
      home: BookNotesPage(book: book, numberOfNotes: 42, isMobile: true),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the header follows loaded notes and keeps passages close',
      (tester) async {
    final controller = _NotesController();
    await _pumpNotes(tester, controller);
    final l10n = L10n.of(tester.element(find.byType(BookNotesPage)));
    expect(find.text(l10n.notesNotes(2)), findsOneWidget);
    expect(find.text(l10n.notesNotes(42)), findsNothing);
    expect(
      tester.getTopLeft(find.byType(BookNotesList)).dy -
          tester.getBottomLeft(find.byType(FilledContainer).first).dy,
      24,
    );

    controller.setCount(0);
    await tester.pumpAndSettle();
    expect(find.text(l10n.notesNotes(0)), findsOneWidget);
    final export = tester.widget<TextButton>(
      find.widgetWithText(TextButton, l10n.notesPageExport),
    );
    expect(export.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notes and export controls fit narrow screens and large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpNotes(tester, _NotesController());
    expect(tester.takeException(), isNull);

    final export = find.widgetWithText(TextButton, 'Export');
    await tester.ensureVisible(export);
    await tester.tap(export);
    await tester.pumpAndSettle();
    await tester.tap(find.text('By chapter'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('CSV'));
    expect(find.text('CSV').hitTestable(), findsOneWidget);
  });

  testWidgets('a failed export stays open and can be retried', (tester) async {
    final pending = Completer<Object?>();
    var calls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method != 'Clipboard.setData') return null;
      calls++;
      if (calls == 1) return pending.future;
      throw PlatformException(code: 'clipboard_unavailable');
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await _pumpNotes(tester, _NotesController());
    await tester.tap(find.widgetWithText(TextButton, 'Export'));
    await tester.pumpAndSettle();
    final copy = find.widgetWithText(OutlinedButton, 'Copy');
    await tester.tap(copy);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(copy).onPressed, isNull);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(calls, 1);

    pending.completeError(PlatformException(code: 'clipboard_unavailable'));
    await tester.pumpAndSettle();
    expect(
      find.text('Your notes could not be exported. Try again.'),
      findsOneWidget,
    );
    expect(tester.widget<OutlinedButton>(copy).onPressed, isNotNull);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}
