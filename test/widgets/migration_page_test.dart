import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/migration_page.dart';
import 'package:paperfold/utils/get_path/macos_migration.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets('failed migration stays on its error screen and can retry',
      (tester) async {
    final root =
        Directory.systemTemp.createTempSync('paperfold-migration-page-');
    addTearDown(() => root.deleteSync(recursive: true));
    var completed = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: MigrationPage(
        checkResult: MigrationCheckResult(
            needsMigration: true,
            oldPath: p.join(root.path, 'missing'),
            newPath: p.join(root.path, 'new')),
        onMigrationComplete: () async {
          completed = true;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(completed, isFalse);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    expect(
        find.text('Migration failed. Data remains in the original location.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
