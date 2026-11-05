import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/utils/color_scheme.dart';
import 'package:paperfold/widgets/common/async_skeleton_wrapper.dart';
import 'package:paperfold/widgets/common/load_failure.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/widgets/mini_metric.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: [
      L10n.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: L10n.supportedLocales,
    theme: paperfoldComponentTheme(
      ThemeData(colorScheme: PaperfoldTokens.colorScheme(Brightness.light)),
    ),
    home: Scaffold(
      body: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Center(child: child),
      ),
    ),
  );
}

void main() {
  for (final locale in const [Locale('en'), Locale('de'), Locale('ar')]) {
    testWidgets('compact errors keep localized retry at 2x text: $locale', (
      tester,
    ) async {
      await tester.runAsync(() => L10n.delegate.load(locale));
      final semantics = tester.ensureSemantics();
      var retries = 0;

      // The 320 dp dashboard leaves 65.5 x 64 dp inside a single-cell tile.
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 65.5,
            height: 64,
            child: AsyncSkeletonWrapper<int>(
              asyncValue: AsyncError(
                StateError('private database path'),
                StackTrace.empty,
              ),
              builder: (_, _) => const SizedBox.shrink(),
              onRetry: () async => retries++,
            ),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = L10n.of(tester.element(find.byType(LoadFailure)));
      final label = '${l10n.commonLoadFailedTitle} ${l10n.commonRetry}';
      expect(tester.takeException(), isNull);
      expect(find.byTooltip(label), findsOneWidget);
      final retry = tester
          .getSemantics(find.byType(IconButton))
          .getSemanticsData();
      expect(retry.tooltip, label);
      expect(retry.hasAction(SemanticsAction.tap), isTrue);
      expect(find.textContaining('private database path'), findsNothing);
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byType(IconButton));
      expect(retries, 1);
      semantics.dispose();
    });
  }

  testWidgets('larger errors scroll at 2x text and keep retry reachable', (
    tester,
  ) async {
    await tester.runAsync(() => L10n.delegate.load(const Locale('de')));
    var retries = 0;
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 167,
          height: 164,
          child: AsyncSkeletonWrapper<int>(
            asyncValue: AsyncError(
              StateError('private database path'),
              StackTrace.empty,
            ),
            builder: (_, _) => const SizedBox.shrink(),
            onRetry: () async => retries++,
          ),
        ),
        locale: const Locale('de'),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = L10n.of(tester.element(find.byType(LoadFailure)));
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.commonLoadFailedTitle), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(find.byType(TextButton));
    await tester.tap(find.byType(TextButton));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact errors without retry expose the localized failure', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const SizedBox(width: 65.5, height: 64, child: LoadFailure.inline()),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = L10n.of(tester.element(find.byType(LoadFailure)));
    expect(tester.takeException(), isNull);
    expect(find.byTooltip(l10n.commonLoadFailedTitle), findsOneWidget);
    final failure = tester.getSemantics(find.byType(Icon)).getSemanticsData();
    expect(failure.label, l10n.commonLoadFailedTitle);
    expect(find.byType(IconButton), findsNothing);
    semantics.dispose();
  });

  testWidgets('compact loading uses a spinner without overflowing a skeleton', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 65.5,
            height: 64,
            child: AsyncSkeletonWrapper<int>(
              asyncValue: const AsyncLoading(),
              mock: 12,
              builder: (_, _) {
                builds++;
                return const SizedBox(height: 200);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(builds, 0);
  });

  testWidgets('compact metrics keep large text and full values scrollable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 65.5,
          height: 64,
          child: DashboardMiniMetric(
            value: 1234,
            label: 'Reading days',
            icon: Icons.calendar_today_outlined,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Reading days'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    final value = tester.widget<Text>(find.text('1234'));
    expect(value.style?.fontSize, 36);
    await tester.ensureVisible(find.text('1234'));
    expect(tester.takeException(), isNull);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(scrollable.position.pixels, greaterThan(0));
  });
}
