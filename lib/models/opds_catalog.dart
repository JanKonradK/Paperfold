/// How a catalog asks the reader to prove who they are.
///
/// Most self-hosted catalogs use HTTP Basic. plan.md Section 9.2 calls
/// authentication the real cost of the milestone.
enum OpdsAuthType {
  none('none'),
  basic('basic');

  const OpdsAuthType(this.databaseValue);

  final String databaseValue;

  static OpdsAuthType fromDatabase(String? value) {
    return switch (value) {
      'basic' => OpdsAuthType.basic,
      // An unknown or missing type reads as no authentication. A catalog that
      // needs one will say so with a 401, and the reader can set it then.
      _ => OpdsAuthType.none,
    };
  }
}

/// One OPDS catalog the reader has added.
///
/// **This never holds a password.** Only the type of authentication and the
/// user name live in SQLite. The password goes to the platform keystore
/// through [OpdsCredentials]. plan.md Section 9.2 calls this the one place
/// where a shortcut creates a real security problem, because these are the
/// reader's own server passwords.
class OpdsCatalog {
  const OpdsCatalog({
    required this.id,
    required this.name,
    required this.url,
    this.authType = OpdsAuthType.none,
    this.username,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final Uri url;
  final OpdsAuthType authType;
  final String? username;
  final int sortOrder;

  bool get needsPassword => authType != OpdsAuthType.none;

  factory OpdsCatalog.fromDb(Map<String, dynamic> row) {
    return OpdsCatalog(
      id: row['id'] as int,
      name: row['name'] as String? ?? '',
      url: Uri.parse(row['url'] as String? ?? ''),
      authType: OpdsAuthType.fromDatabase(row['auth_type'] as String?),
      username: row['username'] as String?,
      sortOrder: (row['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toDb() {
    return <String, Object?>{
      'name': name,
      'url': url.toString(),
      'auth_type': authType.databaseValue,
      'username': username,
      'sort_order': sortOrder,
    };
  }

  OpdsCatalog copyWith({
    String? name,
    Uri? url,
    OpdsAuthType? authType,
    String? username,
    int? sortOrder,
  }) {
    return OpdsCatalog(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      authType: authType ?? this.authType,
      username: username ?? this.username,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
