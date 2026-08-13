import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/settings_page/appearance.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('uniform-spines setting is localized, accessible, and persisted',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
    expect(Prefs().shelfUniformSpines, isFalse);

    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
        ),
        home: const Scaffold(body: AppearanceSetting()),
      ),
    );
    await tester.pumpAndSettle();

    final control = find.bySemanticsLabel('Uniform spines');
    expect(control, findsOneWidget);
    expect(tester.getSize(control).height, greaterThanOrEqualTo(48));

    tester.semantics.tap(find.semantics.byLabel('Uniform spines'));
    await tester.pump();

    expect(Prefs().shelfUniformSpines, isTrue);
    semantics.dispose();
  });
}
