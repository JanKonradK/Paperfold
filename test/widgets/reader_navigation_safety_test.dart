import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/sync_status.dart';
import 'package:paperfold/page/book_player/epub_player.dart';
import 'package:paperfold/providers/sync_status.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/service/book_player/book_player_server.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
// Keep the real database inside the test directory.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _WaitingStatus extends SyncStatus {
  _WaitingStatus(this.wait);
  final Future<SyncStatusModel> Function() wait;

  @override
  Future<SyncStatusModel> build() => wait();
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;

  @override
  Future<String> getApplicationDocumentsPath() async => path;
  @override
  Future<String> getApplicationSupportPath() async => path;
}

class _WebView extends Fake implements InAppWebViewController {
  final handlers = <String, Function>{};
  bool fail = false;

  @override
  void addJavaScriptHandler(
      {required String handlerName, required Function callback}) {
    handlers[handlerName] = callback;
  }

  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({
    required String functionBody,
    Map<String, dynamic> arguments = const {},
    ContentWorld? contentWorld,
  }) async =>
      fail
          ? CallAsyncJavaScriptResult(error: 'Navigation failed')
          : CallAsyncJavaScriptResult(value: arguments['targetCfi']);

  void relocate(String cfi, double percentage) {
    handlers['onRelocated']!([
      {
        'cfi': cfi,
        'percentage': percentage,
        'bookmark': {'exists': false, 'cfi': ''},
      },
    ]);
  }
}

class _Player extends EpubPlayer {
  const _Player({required super.key, required super.book})
      : super(
          initialThemes: const [],
          showOrHideAppBarAndBottomBar: _noop,
          onLoadEnd: _noop,
          updateParent: _noop,
        );

  static void _noop([Object? value]) {}

  @override
  ConsumerState<EpubPlayer> createState() => _PlayerState();
}

class _PlayerState extends EpubPlayerState {
  @override
  bool get isDarkMode => false;

  @override
  Widget buildWebviewWithIOSWorkaround(BuildContext context) =>
      const SizedBox();
}

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('reader brightness follows saved mode instead of app chrome',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    final player = EpubPlayerState();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: const SizedBox(),
    ));
    expect(player.isDarkMode, isFalse);
    await Prefs().saveThemeModeToPrefs('dark');
    expect(player.isDarkMode, isTrue);
    await Prefs().saveThemeModeToPrefs('system');
    expect(player.isDarkMode, isTrue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    expect(player.isDarkMode, isFalse);
    await Prefs().saveThemeModeToPrefs('dark');
    Prefs().eInkMode = true;
    expect(player.isDarkMode, isFalse);
  });

  testWidgets('opening awaits failed downloads and tolerates a removed caller',
      (tester) async {
    var status = Completer<SyncStatusModel>();
    var showSource = true;
    late StateSetter changeSource;
    late WidgetRef sourceRef;
    late Future<void> opening;
    var completed = false;
    final book = Book.mock()..filePath = 'file/missing-navigation-test.epub';
    await tester.pumpWidget(ProviderScope(
      overrides: [
        syncStatusProvider
            .overrideWith(() => _WaitingStatus(() => status.future)),
      ],
      child: _app(StatefulBuilder(builder: (context, setState) {
        changeSource = setState;
        return showSource
            ? Consumer(builder: (context, ref, _) {
                sourceRef = ref;
                return TextButton(
                  onPressed: () {
                    completed = false;
                    opening = pushToReadingPage(ref, context, book)
                      ..then((_) => completed = true);
                  },
                  child: const Text('Open'),
                );
              })
            : const SizedBox();
      })),
    ));
    // MaterialApp waits for its localization delegates before building home.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(completed, isFalse);
    status.completeError(StateError('Remote status unavailable'));
    await tester.pumpAndSettle();
    await opening;
    expect(find.text('Failed'), findsOneWidget);
    expect(tester.takeException(), isNull);

    status = Completer<SyncStatusModel>();
    sourceRef.invalidate(syncStatusProvider);
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(completed, isFalse);
    changeSource(() => showSource = false);
    await tester.pump();
    status.completeError(StateError('Remote status unavailable'));
    await tester.pumpAndSettle();
    await opening;
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'passage previews preserve progress until the return is confirmed',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('paperfold-preview-'),
    ))!;
    final originalPaths = PathProviderPlatform.instance;
    final originalDocumentPath = documentPath;
    PathProviderPlatform.instance = _Paths(directory.path);
    documentPath = directory.path;
    await tester.runAsync(() async {
      await DBHelper.close();
      await DBHelper().database;
      await Server().start();
    });
    addTearDown(() async {
      await Server().stop();
      await DBHelper.close();
      PathProviderPlatform.instance = originalPaths;
      documentPath = originalDocumentPath;
      await directory.delete(recursive: true);
    });
    final book = Book.mock()
      ..id = -1
      ..lastReadPosition = 'saved-location';
    book.id = (await tester.runAsync(() => bookDao.insertBook(book)))!;
    final key = GlobalKey<EpubPlayerState>();
    // Resolve deferred localization libraries before mounting a widget whose
    // opening animation deliberately keeps scheduling frames.
    await tester.pumpWidget(ProviderScope(child: _app(const SizedBox())));
    await tester.pumpAndSettle();
    await tester
        .pumpWidget(ProviderScope(child: _app(_Player(key: key, book: book))));
    final player = key.currentState!;
    final webView = _WebView();
    player.webViewController = webView;
    await player.setHandler(webView);
    webView.relocate('reading-location', 0.6);
    await tester.runAsync(() => player.previewPassage('old-passage'));
    webView.relocate('old-passage', 0.2);
    await player.saveReadingProgress(immediate: true);
    expect(book.lastReadPosition, 'reading-location');
    await tester.pump();
    expect(find.text('Return to reading'), findsOneWidget);

    // A failed return must keep the old reading position protected.
    webView.fail = true;
    await player.returnToReading();
    await player.saveReadingProgress(immediate: true);
    expect(book.lastReadPosition, 'reading-location');
    webView.fail = false;

    // JS can finish before the native relocation callback reaches Dart.
    await player.returnToReading();
    await player.saveReadingProgress(immediate: true);
    expect(book.lastReadPosition, 'reading-location');
    webView.relocate('reading-location', 0.6);
    webView.relocate('next-reading-location', 0.7);
    await tester.runAsync(() => player.saveReadingProgress(immediate: true));
    expect(book.lastReadPosition, 'next-reading-location');

    // The reverse event order must also resume normal saving.
    await tester.runAsync(() => player.previewPassage('another-passage'));
    webView.relocate('another-passage', 0.3);
    webView.relocate('next-reading-location', 0.7);
    await player.returnToReading();
    webView.relocate('final-reading-location', 0.8);
    await tester.runAsync(() => player.saveReadingProgress(immediate: true));
    expect(book.lastReadPosition, 'final-reading-location');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    // This integration test uses the app's native Windows database bootstrap.
    // Linux CI still runs the portable DAO and migration tests; the app does
    // not yet implement a native Linux database platform.
  }, skip: !Platform.isWindows);
}
