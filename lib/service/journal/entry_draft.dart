import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One recoverable draft. Writes are serialized so an old edit cannot win.
class EntryDraft {
  static const key = 'journal.entry.draft';
  Future<void> _pending = Future.value();

  Future<Map<String, dynamic>?> read() async {
    await _pending;
    final value = (await SharedPreferences.getInstance()).getString(key);
    if (value == null) return null;
    try {
      return jsonDecode(value) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> write(Map<String, dynamic> value) {
    final snapshot = jsonEncode(value);
    final next = _pending.catchError((Object _) {}).then((_) async {
      if (!await (await SharedPreferences.getInstance()).setString(
        key,
        snapshot,
      )) {
        throw StateError('Draft could not be saved');
      }
    });
    _pending = next;
    return next;
  }

  Future<void> clear() {
    final next = _pending.then((_) async {
      if (!await (await SharedPreferences.getInstance()).remove(key)) {
        throw StateError('Draft could not be cleared');
      }
    });
    _pending = next;
    return next;
  }
}
