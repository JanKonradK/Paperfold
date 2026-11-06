import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Frozen at the P7 handoff. Only files owned by the other build agents remain.
// Entries can be removed as those agents migrate them; never add new entries.
const _baseline = <String, List<String>>{
  'lib/page/book_detail.dart': ['BorderRadius.circular(2)'],
  'lib/page/home_page.dart': ['BorderRadius.circular(24)'],
  'lib/page/home_page/shelf_home_page.dart': [
    'BorderRadius.circular(12)',
    'BorderRadius.circular(12)',
  ],
  'lib/page/journal/book_review_page.dart': ['BorderRadius.circular(12)'],
  'lib/page/journal/month_tracker_page.dart': [
    'BorderRadius.circular(3)',
    'BorderRadius.circular(12)',
  ],
  'lib/page/journal/reading_challenge_page.dart': [
    'BorderRadius.circular(16)',
    'BorderRadius.circular(3)',
  ],
  'lib/widgets/bookshelf/book_binding_sheet.dart': [
    'BorderRadius.circular(12)',
  ],
  'lib/widgets/bookshelf/bookcase.dart': [
    'Radius.circular(24)',
    'BorderRadius.circular(24)',
  ],
  'lib/widgets/bookshelf/continue_reading_banner.dart': [
    'BorderRadius.circular(12)',
  ],
  'lib/widgets/bookshelf/shelf_controls/shelf_book_actions.dart': [
    'BorderRadius.circular(12)',
  ],
  'lib/widgets/bookshelf/shelf_stage.dart': [
    'Radius.circular(2)',
    'BorderRadius.circular(2)',
    'BorderRadius.circular(12)',
    'BorderRadius.circular(2)',
  ],
  'lib/widgets/reading_page/reader_chrome.dart': [
    'BorderRadius.circular(12)',
    'BorderRadius.circular(28)',
    'BorderRadius.circular(24)',
    'BorderRadius.circular(24)',
  ],
};

void main() {
  test('new numeric radii must use PaperfoldShape', () {
    final raw = RegExp(
      r'(?:BorderRadius|Radius)\.circular\(\s*\d+(?:\.\d+)?\s*\)',
    );
    final violations = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || path.startsWith('lib/config/')) continue;
      final allowed = List<String>.of(_baseline[path] ?? const []);
      for (final match in raw.allMatches(file.readAsStringSync())) {
        final value = match.group(0)!;
        if (!allowed.remove(value)) violations.add('$path: $value');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
