import 'package:flutter/foundation.dart';

/// What the reader asked to capture from outside the composer.
enum QuickCaptureKind { note, quote, progress, photo }

/// One request to open the New entry composer.
///
/// Notification actions, home-screen widgets, the share sheet, and in-app
/// buttons all create one of these. The Journal listens to [QuickCapture]
/// and opens the composer with this kind and book selected.
@immutable
class QuickCaptureRequest {
  const QuickCaptureRequest({
    required this.kind,
    this.bookId,
    this.text,
    this.source = 'app',
  });

  final QuickCaptureKind kind;

  /// The book to preselect, or null to use the last-read book.
  final int? bookId;

  /// Prefilled text, for example from the share sheet.
  final String? text;

  /// Where the request came from: app, notification, widget, share.
  final String source;

  @override
  String toString() =>
      'QuickCaptureRequest($kind, book: $bookId, source: $source)';
}

/// The single entry point to the New entry composer.
///
/// Producers call [request]. The Journal consumes the pending request with
/// [take] once it can show the composer, so a request made during a cold
/// start waits for the home page instead of being lost.
abstract final class QuickCapture {
  static final ValueNotifier<QuickCaptureRequest?> pending =
      ValueNotifier<QuickCaptureRequest?>(null);

  static void request(QuickCaptureRequest request) {
    pending.value = request;
  }

  /// Returns and clears the pending request.
  static QuickCaptureRequest? take() {
    final request = pending.value;
    pending.value = null;
    return request;
  }
}
