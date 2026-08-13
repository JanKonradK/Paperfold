// Development entry point for the WebView platform-view probe.
//
// Not part of the shipped application. It answers one question from
// plan.md Section 3.6: does the pinned Anxcye/flutter_inappwebview fork put
// pixels on the screen under Android 16, and in which composition mode.
//
// The reader sets `useHybridComposition: true`, which sends the fork down
// PlatformViewsService.initExpensiveAndroidView. This probe shows both modes
// side by side on one screen, with no book, no server and no foliate-js, so a
// blank pane means the platform view itself, not the reader.
//
//   flutter run -t lib/dev_webview_main.dart -d <device>
//
// Read the result off the screen: each pane must show its own coloured block
// and its own label.

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  runApp(const WebViewProbeApp());
}

/// Painted by the page itself, so the colour only appears if the WebView
/// surface reaches the screen.
String _page(String label, String color) {
  return Uri.dataFromString(
    '<!doctype html><html><body style="margin:0;background:$color">'
    '<div style="font:700 28px sans-serif;color:#fff;padding:24px">'
    '$label</div></body></html>',
    mimeType: 'text/html',
  ).toString();
}

class WebViewProbeApp extends StatelessWidget {
  const WebViewProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebView probe',
      home: Scaffold(
        appBar: AppBar(title: const Text('WebView probe')),
        body: Column(
          children: const [
            Expanded(
              child: _Probe(
                label: 'hybrid composition',
                color: '#1b5e20',
                hybrid: true,
              ),
            ),
            Divider(height: 2),
            Expanded(
              child: _Probe(
                label: 'texture layer',
                color: '#0d47a1',
                hybrid: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Probe extends StatefulWidget {
  const _Probe({
    required this.label,
    required this.color,
    required this.hybrid,
  });

  final String label;
  final String color;
  final bool hybrid;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  String _state = 'created';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(_page(widget.label, widget.color)),
            ),
            initialSettings: InAppWebViewSettings(
              // The reader's own settings, so the probe fails the way the
              // reader fails.
              supportZoom: false,
              transparentBackground: true,
              isInspectable: true,
              useHybridComposition: widget.hybrid,
            ),
            onLoadStop: (controller, uri) {
              debugPrint('WEBVIEW_PROBE ${widget.label}: loaded $uri');
              setState(() => _state = 'loaded');
            },
            onReceivedError: (controller, request, error) {
              debugPrint('WEBVIEW_PROBE ${widget.label}: error $error');
              setState(() => _state = 'error $error');
            },
            onConsoleMessage: (controller, message) {
              debugPrint('WEBVIEW_PROBE ${widget.label}: console $message');
            },
          ),
        ),
        // Flutter-drawn, so it proves the pane has size even when the platform
        // view paints nothing.
        Positioned(
          left: 8,
          bottom: 8,
          child: ColoredBox(
            color: Colors.black,
            child: Text(
              '${widget.hybrid ? 'HC' : 'TLHC'} $_state',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
