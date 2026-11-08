// The settings tree opens as lazy routes.
//
// plan.md Section 11.2 lists the settings page as the fifth most likely source
// of jank: 204 KB of Dart in one tree. Every row used to hand the list a built
// screen, so all six settings screens existed as soon as the list drew,
// whether or not the reader opened one. These tests hold that shut.
//
//   flutter test test/widgets/settings_lazy_routes_test.dart

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/page/settings_page/settings_page.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
    ),
    home: child,
  );
}

void main() {
  testWidgets('a settings screen is not built until its row is tapped',
      (WidgetTester tester) async {
    int built = 0;

    await tester.pumpWidget(
      _host(
        Scaffold(
          body: ListView(
            children: <Widget>[
              SettingsPageBuilder(
                icon: const Icon(Icons.color_lens_outlined),
                title: 'Appearance',
                sections: (BuildContext context) {
                  built++;
                  return const Text('the appearance settings');
                },
                subTitles: const <String>['Theme'],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(built, 0, reason: 'drawing the row must not build the screen');
    expect(find.text('the appearance settings'), findsNothing);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(built, 1);
    expect(find.text('the appearance settings'), findsOne);
  });

  testWidgets('the settings shell is Material, not Cupertino',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        SettingsPageBody(
          title: 'Appearance',
          sections: (BuildContext context) =>
              ListView(children: const <Widget>[Text('body')]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The chrome rule is Material behaviour with a custom appearance. An iOS
    // navigation bar inside a Material application is neither, and it brought
    // an iOS back gesture and an iOS title with it.
    expect(find.byType(CupertinoPageScaffold), findsNothing);
    expect(find.byType(CupertinoSliverNavigationBar), findsNothing);
    expect(find.byType(SliverAppBar), findsOne);
    expect(find.text('Appearance'), findsWidgets);
  });
}
