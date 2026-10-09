// Two rules that were broken in the same way across many files, held shut
// here rather than one file at a time.
//
//   * Eleven user-facing places pinned `fontFamily: 'SourceHanSerif'`, so the
//     Journal, the statistics, the note lists and the cold-start cover were
//     set in a CJK serif whatever the reader's language. The theme already
//     substitutes a Chinese face where one is needed.
//   * Twenty places painted secondary text with `Colors.grey`, which measures
//     2.49:1 on Paperfold's light paper ground — under the 4.5:1 minimum in
//     DESIGN.md. The `onSurfaceVariant` role measures 7.77:1.
//
//   flutter test test/widgets/theme_conformance_test.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = math.max(la, lb);
  final double lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Shipped source only: the dev harnesses under `lib/page/dev/` and
/// `lib/dev_*.dart` are not part of the application.
Iterable<File> _shippedDartFiles() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File) continue;
    final String path = entity.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart')) continue;
    if (path.contains('/l10n/generated/')) continue;
    if (path.contains('/page/dev/')) continue;
    if (path.contains('/gen/')) continue;
    if (RegExp(r'lib/dev_[a-z_]+\.dart$').hasMatch(path)) continue;
    yield entity;
  }
}

void main() {
  test('the light scheme keeps secondary text above 4.5:1', () {
    final ColorScheme light = PaperfoldTokens.colorScheme(Brightness.light);
    final ColorScheme dark = PaperfoldTokens.colorScheme(Brightness.dark);

    expect(_contrast(light.onSurfaceVariant, light.surface),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(dark.onSurfaceVariant, dark.surface),
        greaterThanOrEqualTo(4.5));

    // The colour that was used instead. It is why the rule above matters.
    expect(_contrast(Colors.grey, light.surface), lessThan(4.5),
        reason: 'Colors.grey fails on the paper ground; keep it out of text');
  });

  test('no shipped widget paints text or icons with Colors.grey', () {
    final offenders = <String>[];
    // A flat `color: Colors.grey`, which is how it reached type and icons.
    // Decorative uses are a different thing and are allowed: a shadow or a
    // hairline written as `Colors.grey.withAlpha(...)` is not text, and the
    // excerpt share card paints a fixed palette of its own by design.
    final pattern = RegExp(r'color:\s*Colors\.grey\s*[,)]');

    for (final file in _shippedDartFiles()) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.endsWith('book_share/excerpt_share_card.dart')) continue;

      final lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'use a ColorScheme role; Colors.grey is 2.49:1 on paper');
  });

  test('no shipped widget pins the CJK serif as its font family', () {
    final offenders = <String>[];
    final pattern = RegExp(r"fontFamily:\s*'SourceHanSerif'");

    for (final file in _shippedDartFiles()) {
      final path = file.path.replaceAll(r'\', '/');
      // The excerpt card maps the reader's *chosen* font file to its family,
      // and the style sheet lists that font as an option. Both are correct.
      if (path.endsWith('book_share/excerpt_share_card.dart')) continue;
      if (path.endsWith('reading_page/style_widget.dart')) continue;

      final lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'take the family from the text theme, which already '
            'substitutes a Chinese face where one is needed');
  });

  test('no shipped page prints a raw exception at the reader', () {
    final offenders = <String>[];
    final pattern =
        RegExp(r"Text\('Error: \$error'\)|Text\(error\.toString\(\)\)");

    for (final file in _shippedDartFiles()) {
      final path = file.path.replaceAll(r'\', '/');
      // The replacement widget's own doc comment quotes the line it replaced,
      // and the global handler is what turns an exception into a report.
      if (path.endsWith('widgets/common/load_failure.dart')) continue;
      if (path.endsWith('utils/error_handler.dart')) continue;

      final lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'use LoadFailure: a localized message the reader can act on');
  });
}
