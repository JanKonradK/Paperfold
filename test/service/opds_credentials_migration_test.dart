import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/service/opds/opds_credentials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Android credential migration keeps backups and never resets on error',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
      });
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'read');
        expect(call.arguments['key'], 'opds_catalog_password_7');
        final options = call.arguments['options'] as Map;
        expect(options['resetOnError'], 'false');
        expect(options['migrateOnAlgorithmChange'], 'true');
        expect(options['migrateWithBackup'], 'true');
        throw PlatformException(code: 'migration_failed');
      });

      await expectLater(
        const KeystoreOpdsCredentials().read(7),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
