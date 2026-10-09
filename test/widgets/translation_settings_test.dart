import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/lang_list.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart' show navigatorKey;
import 'package:paperfold/page/settings_page/translate.dart';
import 'package:paperfold/service/config/config_item.dart';
import 'package:paperfold/service/translate/index.dart';
import 'package:paperfold/widgets/settings/service_config_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    locale: const Locale('en'),
    localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: L10n.supportedLocales,
    theme: ThemeData(colorScheme: PaperfoldTokens.colorScheme(brightness)),
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });

  testWidgets('service fields keep the caret and composing range while editing',
      (tester) async {
    var config = <String, dynamic>{'url': 'abcdef'};
    await tester.pumpWidget(_host(StatefulBuilder(builder: (context, setState) {
      return ServiceConfigForm(
        configItems: [
          ConfigItem(key: 'url', label: 'API URL', type: ConfigItemType.text),
        ],
        initialConfig: config,
        onConfigChanged: (value) => setState(() => config = value),
      );
    })));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.showKeyboard(field);
    const editing = TextEditingValue(
      text: 'abXcdef',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 2, end: 3),
    );
    tester.testTextInput.updateEditingValue(editing);
    await tester.pump();

    expect(tester.widget<TextField>(field).controller!.value, editing);
    expect(config['url'], 'abXcdef');
  });

  testWidgets(
      'password visibility preserves the draft and external updates work',
      (tester) async {
    var config = <String, dynamic>{'key': 'secret'};
    late StateSetter rebuild;
    await tester.pumpWidget(_host(StatefulBuilder(builder: (context, setState) {
      rebuild = setState;
      return ServiceConfigForm(
        configItems: [
          ConfigItem(
              key: 'key', label: 'API key', type: ConfigItemType.password),
        ],
        initialConfig: config,
        onConfigChanged: (value) => config = value,
      );
    })));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.enterText(field, 'new-secret');
    await tester.pump();
    final controller = tester.widget<TextField>(field).controller!;
    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(tester.widget<TextField>(field).obscureText, isFalse);
    expect(controller.text, 'new-secret');
    expect(controller.selection.baseOffset, 3);
    expect(find.byTooltip('Hide password'), findsOneWidget);

    rebuild(() => config = {'key': 'restored-secret'});
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, 'restored-secret');
  });

  testWidgets(
      'language pickers mark the choice and only detect source language',
      (tester) async {
    Prefs().translateFrom = LangListEnum.auto;
    Prefs().translateTo = LangListEnum.english;
    Prefs().fullTextTranslateTo = LangListEnum.english;
    await tester.pumpWidget(_host(const TranslateLangPicker(isFrom: true)));
    await tester.pumpAndSettle();
    final source = tester.widget<ListTile>(find.ancestor(
      of: find.text('Auto'),
      matching: find.byType(ListTile),
    ));
    expect(source.selected, isTrue);

    for (final isFullText in [false, true]) {
      await tester.pumpWidget(_host(TranslateLangPicker(
        isFrom: false,
        isWebView: isFullText,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Auto'), findsNothing);
      final target = tester.widget<ListTile>(find.ancestor(
        of: find.text('English'),
        matching: find.byType(ListTile),
      ));
      expect(target.selected, isTrue);
      expect(find.byIcon(Icons.check), findsOneWidget);
    }
  });

  testWidgets('translation service controls fit a narrow dark settings pane',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: ListView(children: const [
          TranslateSettingItem(service: TranslateService.microsoftApi),
        ]),
      ),
      brightness: Brightness.dark,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceConfigForm), findsOneWidget);
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
