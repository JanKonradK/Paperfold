import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/service/cover_image.dart';
import 'package:paperfold/service/reading_reminder.dart';
import 'package:paperfold/service/receive_file/receive_share.dart';
import 'package:paperfold/utils/check_update.dart';
import 'package:paperfold/widgets/bookshelf/physical_progress_sheet.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('paper book progress', () {
    final day = DateTime(2026, 11, 5);

    test('the first page starts the book and the last page finishes it', () {
      final book = Book.physical()..totalPages = 200;
      applyPhysicalProgress(book, 50, now: day);
      expect(book.status, BookStatus.reading);
      expect(book.startedOn, day);
      expect(book.readingPercentage, 0.25);
      expect(book.finishedOn, isNull);

      applyPhysicalProgress(book, 200, now: day.add(const Duration(days: 3)));
      expect(book.status, BookStatus.finished);
      expect(book.startedOn, day);
      expect(book.finishedOn, day.add(const Duration(days: 3)));
      expect(book.readingPercentage, 1);
    });

    test('going back from the last page returns the book to reading', () {
      final book = Book.physical()..totalPages = 100;
      applyPhysicalProgress(book, 100, now: day);
      applyPhysicalProgress(book, 80, now: day);
      expect(book.status, BookStatus.reading);
      expect(book.finishedOn, isNull);
    });

    test('an unknown total keeps the page and shows no percentage', () {
      final book = Book.physical();
      applyPhysicalProgress(book, 30, now: day);
      expect(book.currentPage, 30);
      expect(book.readingPercentage, 0);
      expect(book.status, BookStatus.reading);

      applyPhysicalProgress(book, 30, totalPages: 60, now: day);
      expect(book.totalPages, 60);
      expect(book.readingPercentage, 0.5);
    });

    test('a page past the end is held at the last page', () {
      final book = Book.physical()..totalPages = 10;
      applyPhysicalProgress(book, 99, now: day);
      expect(book.currentPage, 10);
    });
  });

  group('cover images', () {
    Uint8List jpegWithGps(int width, int height) {
      final image = img.Image(width: width, height: height);
      image.exif.imageIfd['Orientation'] = 6;
      image.exif.imageIfd['ImageDescription'] = 'At home';
      image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(52, 1);
      return img.encodeJpg(image);
    }

    test('a photo is turned upright, resized, and loses its location', () {
      final source = jpegWithGps(4000, 3000);
      expect(img.decodeJpgExif(source)!.gpsIfd.isEmpty, isFalse);

      final cover = normaliseCover(source);
      expect(cover.extension, 'jpg');
      final result = img.decodeJpg(cover.bytes)!;
      // Orientation 6 is a 90 degree turn: the landscape photo becomes upright.
      expect(result.width, 1536);
      expect(result.height, coverLongEdge);
      final exif = img.decodeJpgExif(cover.bytes);
      expect(exif == null || exif.gpsIfd.isEmpty, isTrue);
      expect(exif?.imageIfd['ImageDescription'], isNull);
    });

    test('a PNG stays a PNG and a small image is not enlarged', () {
      final cover = normaliseCover(
        img.encodePng(img.Image(width: 300, height: 450, numChannels: 4)),
      );
      expect(cover.extension, 'png');
      expect(img.decodePng(cover.bytes)!.width, 300);
    });

    test('other formats and damaged files are refused', () {
      expect(
        () => normaliseCover(img.encodeGif(img.Image(width: 4, height: 4))),
        throwsA(isA<CoverImageException>()),
      );
      expect(
        () => normaliseCover(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0, 1, 2])),
        throwsA(isA<CoverImageException>()),
      );
      expect(
        () => normaliseCover(Uint8List(coverMaxBytes + 1)),
        throwsA(isA<CoverImageException>()),
      );
    });

    test('shared JPG and PNG files open as a paper book cover', () {
      expect(isCoverPhoto('/cache/IMG_1.JPG'), isTrue);
      expect(isCoverPhoto('/cache/cover.png'), isTrue);
      expect(isCoverPhoto('/cache/book.epub'), isFalse);
    });
  });

  test('the reminder fires today when the time is ahead, else tomorrow', () {
    tz_data.initializeTimeZones();
    final zone = tz.getLocation('Europe/Warsaw');
    final morning = tz.TZDateTime(zone, 2026, 3, 28, 9);
    expect(
      ReadingReminder.nextAt(20 * 60, morning),
      tz.TZDateTime(zone, 2026, 3, 28, 20),
    );
    // The clocks change overnight. The reminder keeps the local time.
    final evening = tz.TZDateTime(zone, 2026, 3, 28, 21);
    final next = ReadingReminder.nextAt(20 * 60, evening);
    expect(next, tz.TZDateTime(zone, 2026, 3, 29, 20));
    expect(next.hour, 20);
  });

  group('backups', () {
    test('passwords and API keys stay on the device', () {
      final stripped = Prefs.withoutSecrets(jsonEncode({
        'url': 'https://dav.example',
        'username': 'reader',
        'password': 'hunter2',
        'api_key': 'abc',
      }));
      expect(jsonDecode(stripped), {
        'url': 'https://dav.example',
        'username': 'reader',
      });
    });

    test('a restore keeps the local password', () {
      final restored = Prefs.keepSecrets(
        jsonEncode({'url': 'https://new.example'}),
        jsonEncode({'url': 'https://old.example', 'password': 'hunter2'}),
      );
      expect(jsonDecode(restored), {
        'url': 'https://new.example',
        'password': 'hunter2',
      });
    });
  });

  group('updates', () {
    test('beta versions compare without a crash', () {
      List<int> v(String value) => versionParts(value);
      bool newer(String a, String b) {
        final x = v(a), y = v(b);
        for (var i = 0; i < x.length; i++) {
          if (x[i] != y[i]) return x[i] > y[i];
        }
        return false;
      }

      expect(newer('0.1.0-beta.2', '0.1.0-beta.1'), isTrue);
      expect(newer('0.1.0', '0.1.0-beta.9'), isTrue);
      expect(newer('0.1.0-beta.1', '0.1.0'), isFalse);
      expect(newer('2.1.0', '0.1.0-beta.1'), isTrue);
    });

    test('only a Paperfold GitHub APK with a digest is installed', () {
      const digest =
          'sha256:0000000000000000000000000000000000000000000000000000000000000000';
      const good =
          'https://github.com/JanKonradK/Paperfold/releases/download/v0.2.0/Paperfold-universal.apk';
      expect(
        releaseApk([
          {'browser_download_url': good, 'digest': digest},
        ])?.url,
        good,
      );
      expect(releaseApk([{'browser_download_url': good}]), isNull);
      expect(
        releaseApk([
          {
            'browser_download_url':
                'https://evil.example/JanKonradK/Paperfold/releases/download/v1/x-universal.apk',
            'digest': digest,
          },
        ]),
        isNull,
      );
    });
  });
}
