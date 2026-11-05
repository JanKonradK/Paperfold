import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/sync_direction.dart';
import 'package:paperfold/enums/sync_protocol.dart';
import 'package:paperfold/enums/sync_trigger.dart';
import 'package:paperfold/models/sync_status.dart';
import 'package:paperfold/providers/sync.dart';
import 'package:paperfold/providers/sync_status.dart';
import 'package:paperfold/service/sync/sync_client_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TransferStatus extends SyncStatus {
  final uploading = <String>{};
  final downloading = <String>{};

  @override
  Future<SyncStatusModel> build() async => const SyncStatusModel(
        localOnly: [],
        remoteOnly: [],
        both: [],
        nonExistent: [],
        downloading: [],
        uploading: [],
      );
  @override
  Future<void> addUploading(String path) async => uploading.add(path);
  @override
  Future<void> removeUploading(String path) async => uploading.remove(path);
  @override
  Future<void> addDownloading(String path) async => downloading.add(path);
  @override
  Future<void> removeDownloading(String path) async => downloading.remove(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('transfer failures clear progress and simultaneous syncs share a guard',
      () async {
    final originalOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final temporary =
        await Directory.systemTemp.createTemp('paperfold_transfer_');
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    Prefs().setSyncInfo(SyncProtocol.webdav, {
      'url': 'http://127.0.0.1:${server.port}',
      'username': 'reader',
      'password': 'secret',
    });
    SyncClientFactory.resetCurrentClient();
    final status = _TransferStatus();
    final container = ProviderContainer(overrides: [
      syncStatusProvider.overrideWith(() => status),
    ]);
    const connectivity =
        MethodChannel('dev.fluttercommunity.plus/connectivity');
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(connectivity, null);
      container.dispose();
      SyncClientFactory.resetCurrentClient();
      HttpOverrides.global = originalOverrides;
      await server.close(force: true);
      await temporary.delete(recursive: true);
    });
    server.listen((request) async {
      await request.drain<void>();
      request.response.statusCode = switch (request.method) {
        'OPTIONS' => 200,
        'MKCOL' => 201,
        _ => 503,
      };
      await request.response.close();
    });
    final sync = container.read(syncProvider.notifier);
    await container.read(syncStatusProvider.future);
    final local =
        await File('${temporary.path}/book.epub').writeAsString('book');

    await expectLater(sync.uploadFile(local.path, 'anx/data/file/book.epub'),
        throwsA(isA<DioException>()));
    expect(status.uploading, isEmpty);
    expect(container.read(syncProvider).isSyncing, isFalse);
    await expectLater(sync.downloadFile('anx/data/file/book.epub', local.path),
        throwsA(isA<DioException>()));
    expect(status.downloading, isEmpty);
    expect(container.read(syncProvider).isSyncing, isFalse);

    Prefs().saveWebdavStatus(true);
    final finishRestore = Completer<void>();
    final restore = sync.runBackupOperation(() => finishRestore.future);
    await expectLater(sync.runBackupOperation(() async {}), throwsStateError);
    await sync.syncData(SyncDirection.both, null, trigger: SyncTrigger.manual);
    finishRestore.complete();
    await restore;

    Prefs().onlySyncWhenWifi = true;
    Prefs().syncCompletedToast = false;
    final checkedConnectivity = Completer<void>();
    final connectivityResult = Completer<List<String>>();
    var checks = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivity, (call) async {
      checks++;
      if (!checkedConnectivity.isCompleted) checkedConnectivity.complete();
      return connectivityResult.future;
    });
    final first =
        sync.syncData(SyncDirection.both, null, trigger: SyncTrigger.manual);
    await checkedConnectivity.future;
    final second =
        sync.syncData(SyncDirection.both, null, trigger: SyncTrigger.manual);
    connectivityResult.complete(['none']);
    await Future.wait([first, second]);
    expect(checks, 1);
    expect(container.read(syncProvider).isSyncing, isFalse);
  });
}
