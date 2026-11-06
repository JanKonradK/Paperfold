import 'dart:io';

import 'package:paperfold/service/book_player/book_player_server.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/book_player/epub_player.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/widgets/reading_page/style_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    Prefs().useBookStyles = false;
    dir = Directory.systemTemp.createTempSync('reader-style-');
    documentPath = dir.path;
    getFontDir().createSync();
    await Server().start();
  });
  tearDown(() async {
    await Server().stop();
    dir.deleteSync(recursive: true);
    documentPath = '';
  });
  testWidgets(
    'font controls persist percentages and Scroll restores the last effect',
    (tester) async {
      Prefs().pageTurnStyle = PageTurn.fold;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            L10n.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: L10n.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: StyleWidget(
              themes: const [],
              lastPagedTurn: PageTurn.fold,
              epubPlayerKey: GlobalKey<EpubPlayerState>(),
              setCurrentPage: (_) {},
              hideAppBarAndBottomBar: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = Prefs().bookStyle.fontSize;
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      expect(Prefs().bookStyle.fontSize, closeTo(before + 0.1, 0.001));
      expect(find.text('${((before + 0.1) * 100).round()}%'), findsOneWidget);
      final scroll = find.byType(SwitchListTile).first;
      await tester.ensureVisible(scroll);
      await tester.tap(scroll);
      await tester.pumpAndSettle();
      expect(Prefs().pageTurnStyle, PageTurn.scroll);
      await tester.tap(scroll);
      await tester.pumpAndSettle();
      expect(Prefs().pageTurnStyle, PageTurn.fold);
      expect(tester.takeException(), isNull);
    },
  );
}
