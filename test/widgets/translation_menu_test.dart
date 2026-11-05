import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/lang_list.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/context_menu/translation_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    Prefs().translateFrom = LangListEnum.auto;
    Prefs().translateTo = LangListEnum.english;
  });

  testWidgets('choosing a target language takes effect in the popup',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: [
        L10n.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: L10n.supportedLocales,
      home: const Scaffold(
        body: Row(children: [
          TranslationMenu(
            content: 'Dzień dobry',
            decoration: BoxDecoration(),
            axis: Axis.horizontal,
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    // Auto-detect is offered as a source only.
    expect(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text('Auto'),
      ),
      findsNothing,
    );
    await tester.ensureVisible(find.text('Deutsch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();

    expect(Prefs().translateTo, LangListEnum.german);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('English'), findsNothing);
  });
}
