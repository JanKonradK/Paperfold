class EnvVar {
  /// Play builds (`--dart-define=isPlayStore=true`) must not update themselves.
  static const bool isPlayStore =
      String.fromEnvironment('isPlayStore', defaultValue: 'false') == 'true';

  static bool get enableCheckUpdate => !isPlayStore;
}
