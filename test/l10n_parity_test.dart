import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every shipped locale covers the template and keeps its placeholders',
    () {
      final directory = Directory('lib/l10n');
      final english = jsonDecode(
        File('${directory.path}/app_en.arb').readAsStringSync(),
      ) as Map;
      final keys = english.keys.cast<String>().where(
        (key) => !key.startsWith('@'),
      );
      final arguments = RegExp(r'\{([a-zA-Z_]\w*)\s*[,}]');
      final pluralCases = RegExp(
        r'\b(?:zero|one|two|few|many|other)\s*\{|=\d+\s*\{',
      );
      Set<String> placeholders(String value) => arguments
          .allMatches(value.replaceAll(pluralCases, ' '))
          .map((match) => match[1]!)
          .toSet();

      for (final file in directory.listSync().whereType<File>()) {
        if (!file.path.endsWith('.arb')) continue;
        final messages = jsonDecode(file.readAsStringSync()) as Map;
        expect(
          keys.where((key) => !messages.containsKey(key)),
          isEmpty,
          reason: '${file.path} must not fall back to English',
        );
        for (final key in keys) {
          final translated = messages[key];
          expect(translated, isA<String>(), reason: '${file.path}: $key');
          expect(
            (translated as String).trim(),
            isNotEmpty,
            reason: '${file.path}: $key',
          );
          expect(
            placeholders(translated),
            placeholders(english[key] as String),
            reason: '${file.path}: $key must preserve message arguments',
          );
        }
      }
    },
  );
}
