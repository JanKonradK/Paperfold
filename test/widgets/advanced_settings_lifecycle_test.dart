import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/md5_statistics.dart';
import 'package:paperfold/page/settings_page/advanced.dart';
import 'package:paperfold/widgets/settings/settings_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _stats = MD5Statistics(
  totalBooks: 10,
  booksWithMd5: 5,
  booksWithoutMd5: 5,
  localFilesCount: 10,
  localFilesWithoutMd5: 5,
);

Widget _host(Future<MD5Statistics> Function() load) => MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: AdvancedSetting(loadMd5Statistics: load)),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });

  testWidgets(
      'checksum calculation waits for statistics and tolerates disposal',
      (tester) async {
    final pending = Completer<MD5Statistics>();
    await tester.pumpWidget(_host(() => pending.future));
    await tester.pumpAndSettle();
    final tile = find.byWidgetPredicate((widget) =>
        widget is SettingsTile &&
        widget.title is Text &&
        (widget.title as Text).data == 'Calculate Missing MD5');
    expect(tile, findsOneWidget);
    expect(tester.widget<SettingsTile>(tile).enabled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(_stats);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed checksum statistics can be retried', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(_host(() async {
      if (attempts++ == 0) throw StateError('Read failed');
      return _stats;
    }));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
