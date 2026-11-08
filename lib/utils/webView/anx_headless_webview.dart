
import 'package:paperfold/main.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AnxHeadlessWebView {
  HeadlessInAppWebView? _headlessWebView;
  OverlayEntry? _overlayEntry;

  final URLRequest initialUrlRequest;
  final InAppWebViewSettings? initialSettings;
  final void Function(InAppWebViewController controller)? onWebViewCreated;
  final void Function(InAppWebViewController controller, Uri? url)? onLoadStop;
  final void Function(
          InAppWebViewController controller, ConsoleMessage consoleMessage)?
      onConsoleMessage;
  final void Function(InAppWebViewController controller, Uri? url, int code,
      String message)? onLoadError;
  final void Function(InAppWebViewController controller, Uri? url,
      int statusCode, String description)? onLoadHttpError;

  AnxHeadlessWebView({
    required this.initialUrlRequest,
    this.initialSettings,
    this.onWebViewCreated,
    this.onLoadStop,
    this.onConsoleMessage,
    this.onLoadError,
    this.onLoadHttpError,
  });

  Future<void> run() async {
    {
      _headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: initialUrlRequest,
        initialSettings: initialSettings,
        onWebViewCreated: onWebViewCreated,
        onLoadStop: onLoadStop,
        onConsoleMessage: onConsoleMessage,
        onLoadError: onLoadError,
        onLoadHttpError: onLoadHttpError,
      );
      try {
        await _headlessWebView?.run();
      } catch (e) {
        AnxLog.info(
            "HeadlessInAppWebView failed to run, falling back to Overlay: $e");
        _headlessWebView = null;
        _runOverlay();
      }
    }
  }

  void _runOverlay() {
    final context = navigatorKey.currentContext;
    if (context == null) {
      AnxLog.severe("No context available for AnxHeadlessWebView overlay");
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Offstage(
        offstage: true,
        child: SizedBox(
          width: 1,
          height: 1,
          child: InAppWebView(
            initialUrlRequest: initialUrlRequest,
            initialSettings: initialSettings,
            onLoadStop: onLoadStop,
            onConsoleMessage: onConsoleMessage,
            onLoadError: onLoadError,
            onLoadHttpError: onLoadHttpError,
            onWebViewCreated: (controller) {
              onWebViewCreated?.call(controller);
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> dispose() async {
    if (_headlessWebView != null) {
      await _headlessWebView?.dispose();
      _headlessWebView = null;
    }
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }
}
