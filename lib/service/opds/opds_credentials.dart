import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where an OPDS catalog password lives.
///
/// Not in SQLite. plan.md Section 9.2 calls this the one place in the project
/// where a shortcut creates a real security problem, because these are the
/// reader's own server passwords, and the database is copied by the export
/// path and by WebDAV sync.
///
/// The store is behind an interface so that a test can prove the contract
/// without a platform keystore, and so that no other layer can reach the
/// plugin directly.
abstract interface class OpdsCredentials {
  /// The password for [catalogId], or null when none was stored.
  Future<String?> read(int catalogId);

  /// Stores [password], including an explicitly empty password. Some servers
  /// require a user name with no password. Use [delete] to remove credentials.
  Future<void> write(int catalogId, String password);

  /// Removes the password for [catalogId]. Safe to call when none exists.
  Future<void> delete(int catalogId);
}

/// The real store, backed by the platform keystore.
class KeystoreOpdsCredentials implements OpdsCredentials {
  const KeystoreOpdsCredentials({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: false,
              migrateWithBackup: true,
            ),
          );

  final FlutterSecureStorage _storage;

  /// Keys are namespaced, because the keystore is shared with everything else
  /// the application may ever store.
  static String keyFor(int catalogId) => 'opds_catalog_password_$catalogId';

  @override
  Future<String?> read(int catalogId) => _storage.read(key: keyFor(catalogId));

  @override
  Future<void> write(int catalogId, String password) {
    return _storage.write(key: keyFor(catalogId), value: password);
  }

  @override
  Future<void> delete(int catalogId) => _storage.delete(key: keyFor(catalogId));
}

/// An in-memory store, for tests and for platforms with no keystore.
class InMemoryOpdsCredentials implements OpdsCredentials {
  final Map<int, String> _passwords = <int, String>{};

  @override
  Future<String?> read(int catalogId) async => _passwords[catalogId];

  @override
  Future<void> write(int catalogId, String password) async {
    _passwords[catalogId] = password;
  }

  @override
  Future<void> delete(int catalogId) async => _passwords.remove(catalogId);
}
