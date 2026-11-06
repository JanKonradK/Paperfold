import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/service/capture_launch.dart';
import 'package:paperfold/service/quick_capture.dart';
import 'package:paperfold/service/home_widgets.dart';
import 'package:paperfold/models/book.dart';

void main() {
  tearDown(() {
    QuickCapture.take();
    CaptureLaunch.takeOpenBook();
  });
  test('all capture kinds wait for the consumer and are consumed once', () {
    for (final kind in QuickCaptureKind.values) {
      expect(
        CaptureLaunch.handle('paperfold://capture?kind=${kind.name}&book=12'),
        isTrue,
      );
      final request = QuickCapture.take()!;
      expect(request.kind, kind);
      expect(request.bookId, 12);
      expect(request.source, 'widget');
      expect(QuickCapture.take(), isNull);
    }
  });
  test('notification actions and body have separate destinations', () {
    for (final kind in ['note', 'progress']) {
      expect(
        CaptureLaunch.handle(
          'paperfold://open',
          source: 'notification',
          action: kind,
        ),
        isTrue,
      );
      expect(QuickCapture.take()!.source, 'notification');
      expect(CaptureLaunch.openBook.value, isNull);
    }
    expect(CaptureLaunch.handle('paperfold://open?book=12'), isTrue);
    expect(CaptureLaunch.takeOpenBook()!.bookId, 12);
    expect(CaptureLaunch.takeOpenBook(), isNull);
    expect(
      CaptureLaunch.handle('paperfold://open', source: 'notification'),
      isTrue,
    );
    expect(CaptureLaunch.takeOpenBook()!.bookId, isNull);
  });
  test('invalid or ambiguous input cannot produce a request', () {
    for (final input in [
      null,
      '',
      'https://capture?kind=note',
      'paperfold://capture?kind=bad',
      'paperfold://capture',
      'paperfold://open?book=abc',
      'paperfold://open?kind=unknown',
      'paperfold://capture?kind=%ZZ',
      'paperfold://open?book=-1',
      'paperfold://open?book=0',
      'paperfold://open?book=1.5',
      'paperfold://open?book=1&book=2',
      'paperfold://capture?kind=note&kind=quote',
      'paperfold://user@open',
      'paperfold://open:123',
      'paperfold://open/path',
      'paperfold://open#book=12',
    ]) {
      expect(CaptureLaunch.handle(input), isFalse, reason: input);
      expect(QuickCapture.pending.value, isNull);
      expect(CaptureLaunch.openBook.value, isNull);
    }
    expect(
      CaptureLaunch.handle(
        'paperfold://open',
        source: 'notification',
        action: 'unknown',
      ),
      isFalse,
    );
  });
  test('snapshot is JSON-safe, bounded and uses the chosen palette', () {
    final book = Book.mock()
      ..title = 'A \"quoted\" title'
      ..readingPercentage = 1.7;
    final data = jsonDecode(
      jsonEncode(HomeWidgets.snapshot(book, burgundy: true)),
    );
    expect(data['book'], 1);
    expect(data['physical'], isTrue);
    expect(data['progress'], 100);
    expect(data['ground'], '#3D1723');
    book.readingPercentage = double.nan;
    expect(HomeWidgets.snapshot(book, burgundy: false)['progress'], 0);
    final empty = HomeWidgets.snapshot(null, burgundy: false);
    expect(empty['book'], isNull);
    expect(empty['ground'], '#F3EFE8');
    expect(empty['cover'], '');
  });
}
