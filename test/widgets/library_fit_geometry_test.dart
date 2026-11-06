import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final width in [360.0, 412.0, 600.0, 1095.0]) {
    testWidgets('Auto grid fills $width at double text size', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().initPrefs();
      final height = width < 600 ? 915.0 : 1750.0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, height);
      addTearDown(tester.view.reset);
      await tester.binding.setSurfaceSize(Size(width, height));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            L10n.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: L10n.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ShelfStage(
              showCovers: true,
              books: List.generate(
                20,
                (i) => ShelfBook(
                  id: '$i',
                  title: 'A long book title that wraps across two lines',
                  author: 'Author',
                  binding: BookBinding.hardback,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final count = width < 600 ? 3 : 5;
      final gutter = width < 600 ? 16 : 24;
      final expected = (width - gutter * 2 - (count - 1) * 12) / count;
      final first = find.byKey(const ValueKey('shelf-cover-0'));
      expect(tester.getSize(first).width, closeTo(expected, .01));
      expect(
        tester.getTopLeft(find.byKey(ValueKey('shelf-cover-${count - 1}'))).dy,
        tester.getTopLeft(first).dy,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
