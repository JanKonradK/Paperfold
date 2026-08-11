// WebView capture benchmark.
//
// plan.md Section 4.2 calls the WebView capture path the open risk of the
// project and the least known cost. This measures it.
//
// The reader is foliate-js inside flutter_inappwebview. On Android that is a
// platform view, which Flutter's AnimatedSampler cannot capture, so a page
// must be captured to a bitmap before a shader can curl it.
//
// takeScreenshot on Android allocates a full-size ARGB_8888 bitmap, software
// draws the whole WebView into it on the Android main thread, compresses it,
// and returns encoded bytes. Dart then decodes those bytes back into an image.
// This bench times each of those phases apart, because they land on different
// threads and only some of them can be moved off the critical path.
//
// Run it in PROFILE mode. On this project a debug build reported cold start
// about four times slower than profile, so a debug timing here would be
// meaningless.
//
//   flutter build apk --profile -t lib/dev_capture_main.dart
//
// Results also go to the log with the prefix CAPTURE_BENCH, so they can be
// read with: adb logcat | grep CAPTURE_BENCH

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CaptureBenchApp extends StatelessWidget {
  const CaptureBenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Capture bench',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF846044),
        useMaterial3: true,
      ),
      home: const CaptureBenchPage(),
    );
  }
}

/// One capture configuration under test.
class _BenchCase {
  const _BenchCase({
    required this.label,
    required this.format,
    required this.quality,
    this.widthFraction,
  });

  final String label;
  final CompressFormat format;
  final int quality;

  /// Fraction of the WebView width to scale the capture to, or null for full.
  final double? widthFraction;
}

/// The measured result of one configuration.
class _BenchResult {
  _BenchResult(this.label);

  final String label;
  final List<int> captureMicros = <int>[];
  final List<int> decodeMicros = <int>[];
  int bytes = 0;
  int decodedWidth = 0;
  int decodedHeight = 0;
  double worstFrameMillis = 0.0;
  String? error;

  int _median(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.from(values)..sort();
    return sorted[sorted.length ~/ 2];
  }

  int get captureMedianMs => (_median(captureMicros) / 1000).round();
  int get captureMinMs =>
      captureMicros.isEmpty ? 0 : (captureMicros.reduce((a, b) => a < b ? a : b) / 1000).round();
  int get captureMaxMs =>
      captureMicros.isEmpty ? 0 : (captureMicros.reduce((a, b) => a > b ? a : b) / 1000).round();
  int get decodeMedianMs => (_median(decodeMicros) / 1000).round();
  int get totalMedianMs => captureMedianMs + decodeMedianMs;
}

class CaptureBenchPage extends StatefulWidget {
  const CaptureBenchPage({super.key});

  @override
  State<CaptureBenchPage> createState() => _CaptureBenchPageState();
}

class _CaptureBenchPageState extends State<CaptureBenchPage> {
  /// Runs per configuration. The first is discarded as warm-up.
  static const int _runsPerCase = 9;

  static const List<_BenchCase> _cases = <_BenchCase>[
    // The current default, and the baseline plan.md Section 4.2 assumed.
    _BenchCase(label: 'PNG q100 full', format: CompressFormat.PNG, quality: 100),
    _BenchCase(label: 'JPEG q80 full', format: CompressFormat.JPEG, quality: 80),
    _BenchCase(label: 'JPEG q60 full', format: CompressFormat.JPEG, quality: 60),
    _BenchCase(
      label: 'JPEG q80 half width',
      format: CompressFormat.JPEG,
      quality: 80,
      widthFraction: 0.5,
    ),
    _BenchCase(
      label: 'JPEG q80 third width',
      format: CompressFormat.JPEG,
      quality: 80,
      widthFraction: 1 / 3,
    ),
  ];

  InAppWebViewController? _controller;
  final List<_BenchResult> _results = <_BenchResult>[];
  bool _running = false;
  bool _pageReady = false;
  String _status = 'Waiting for the page to load.';

  // Frame timing captured only while a capture is in flight.
  bool _watchingFrames = false;
  double _worstFrameMillis = 0.0;
  TimingsCallback? _timingsCallback;

  @override
  void initState() {
    super.initState();
    _timingsCallback = (List<FrameTiming> timings) {
      if (!_watchingFrames) return;
      for (final timing in timings) {
        final total = timing.totalSpan.inMicroseconds / 1000.0;
        if (total > _worstFrameMillis) _worstFrameMillis = total;
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
  }

  @override
  void dispose() {
    if (_timingsCallback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_timingsCallback!);
    }
    super.dispose();
  }

  Future<void> _runSuite() async {
    final controller = _controller;
    if (controller == null || _running) return;

    setState(() {
      _running = true;
      _results.clear();
      _status = 'Running.';
    });

    final size = MediaQuery.of(context).size;
    developer.log(
      'CAPTURE_BENCH start logicalSize=${size.width.toStringAsFixed(0)}'
      'x${size.height.toStringAsFixed(0)} '
      'dpr=${MediaQuery.of(context).devicePixelRatio}',
      name: 'CAPTURE_BENCH',
    );

    for (final benchCase in _cases) {
      final result = _BenchResult(benchCase.label);
      setState(() => _status = 'Running ${benchCase.label}.');

      // Let the tree settle so the warm-up run is not measuring a rebuild.
      await Future<void>.delayed(const Duration(milliseconds: 250));

      _worstFrameMillis = 0.0;
      _watchingFrames = true;

      for (int run = 0; run < _runsPerCase; run++) {
        try {
          final config = ScreenshotConfiguration(
            compressFormat: benchCase.format,
            quality: benchCase.quality,
            snapshotWidth: benchCase.widthFraction == null
                ? null
                : size.width * benchCase.widthFraction!,
          );

          final captureWatch = Stopwatch()..start();
          final bytes = await controller.takeScreenshot(
            screenshotConfiguration: config,
          );
          captureWatch.stop();

          if (bytes == null) {
            result.error = 'takeScreenshot returned null';
            break;
          }

          final decodeWatch = Stopwatch()..start();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          decodeWatch.stop();

          final image = frame.image;

          // Discard the first run as warm-up.
          if (run > 0) {
            result.captureMicros.add(captureWatch.elapsedMicroseconds);
            result.decodeMicros.add(decodeWatch.elapsedMicroseconds);
          }
          result.bytes = bytes.length;
          result.decodedWidth = image.width;
          result.decodedHeight = image.height;

          image.dispose();
          codec.dispose();
        } catch (error) {
          result.error = error.toString();
          break;
        }

        // Yield so the frame timings callback can deliver.
        await Future<void>.delayed(const Duration(milliseconds: 32));
      }

      _watchingFrames = false;
      result.worstFrameMillis = _worstFrameMillis;

      developer.log(
        'CAPTURE_BENCH ${result.label} '
        'capture_median=${result.captureMedianMs}ms '
        'capture_min=${result.captureMinMs}ms '
        'capture_max=${result.captureMaxMs}ms '
        'decode_median=${result.decodeMedianMs}ms '
        'total_median=${result.totalMedianMs}ms '
        'bytes=${result.bytes} '
        'decoded=${result.decodedWidth}x${result.decodedHeight} '
        'worst_frame=${result.worstFrameMillis.toStringAsFixed(1)}ms '
        'error=${result.error ?? "none"}',
        name: 'CAPTURE_BENCH',
      );

      setState(() => _results.add(result));
    }

    developer.log('CAPTURE_BENCH done', name: 'CAPTURE_BENCH');
    setState(() {
      _running = false;
      _status = 'Done.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // The page under capture. Full width, a realistic share of the
            // height, so the captured bitmap is close to a real reader page.
            Expanded(
              flex: 3,
              child: InAppWebView(
                initialData: InAppWebViewInitialData(
                  data: _bookPageHtml,
                  mimeType: 'text/html',
                  encoding: 'utf-8',
                ),
                initialSettings: InAppWebViewSettings(
                  transparentBackground: false,
                  supportZoom: false,
                ),
                onWebViewCreated: (controller) => _controller = controller,
                onLoadStop: (controller, url) {
                  setState(() {
                    _pageReady = true;
                    _status = 'Page loaded. Ready.';
                  });
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        FilledButton(
                          onPressed: (_pageReady && !_running) ? _runSuite : null,
                          child: Text(_running ? 'Running' : 'Run suite'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _status,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildResults()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Tap Run suite.\nAll times in milliseconds.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 14,
          headingRowHeight: 30,
          dataRowMinHeight: 26,
          dataRowMaxHeight: 32,
          columns: const [
            DataColumn(label: Text('case', style: TextStyle(fontSize: 11))),
            DataColumn(label: Text('cap', style: TextStyle(fontSize: 11))),
            DataColumn(label: Text('dec', style: TextStyle(fontSize: 11))),
            DataColumn(label: Text('total', style: TextStyle(fontSize: 11))),
            DataColumn(label: Text('KB', style: TextStyle(fontSize: 11))),
            DataColumn(label: Text('px', style: TextStyle(fontSize: 11))),
            DataColumn(label: Text('worst f', style: TextStyle(fontSize: 11))),
          ],
          rows: _results.map((r) {
            return DataRow(cells: [
              DataCell(Text(r.label, style: const TextStyle(fontSize: 11))),
              DataCell(Text('${r.captureMedianMs}',
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text('${r.decodeMedianMs}',
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text('${r.totalMedianMs}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold))),
              DataCell(Text('${(r.bytes / 1024).round()}',
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text('${r.decodedWidth}x${r.decodedHeight}',
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text(r.worstFrameMillis.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 11))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

/// A page of styled prose with a heading and an inline illustration.
///
/// This stands in for a rendered book page. The cost of takeScreenshot is
/// dominated by the bitmap allocation, the software draw of the view, and the
/// encode, so what matters is that the view is full width, text heavy, and
/// carries at least one raster element. The illustration is an inline SVG data
/// URI, so the bench needs no asset and no network.
final String _bookPageHtml = '''
<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { margin: 0; padding: 28px 26px; background: #FAF6EE; color: #3A2E28;
         font-family: Georgia, 'Times New Roman', serif; line-height: 1.62;
         font-size: 17px; }
  h1 { font-size: 25px; margin: 0 0 6px; font-weight: 600; letter-spacing: .2px; }
  .rule { width: 74px; height: 2px; background: #C4A071; margin: 12px 0 20px; }
  p { margin: 0 0 14px; text-align: justify; hyphens: auto; }
  .drop::first-letter { font-size: 46px; float: left; line-height: .82;
                        padding: 6px 8px 0 0; color: #846044; }
  figure { margin: 18px 0; text-align: center; }
  figcaption { font-size: 13px; color: #5C4A3F; font-style: italic; margin-top: 6px; }
  .folio { margin-top: 22px; text-align: center; color: #5C4A3F; font-size: 13px; }
</style></head><body>
<h1>The Cartographer's Apology</h1>
<div class="rule"></div>
<p class="drop">Every map is an argument about what deserves to be remembered, and every
cartographer is therefore a kind of editor, deciding in silence which rivers earn a name
and which villages are permitted to vanish beneath a fold. I had drawn the northern
coast eleven times before I understood this, and the twelfth drawing was the first
honest one.</p>
<p>The commission arrived in autumn, carried by a man who would not sit down. He set the
papers on the table, weighted them with his glove, and told me the survey had to be
finished before the passes closed. I asked which passes. He said it did not matter,
which is how I knew the work was political.</p>
<figure>
<img alt="compass" width="120" height="120" src="data:image/svg+xml;utf8,
<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 120 120'>
<circle cx='60' cy='60' r='54' fill='none' stroke='%23846044' stroke-width='2'/>
<circle cx='60' cy='60' r='42' fill='none' stroke='%23C4A071' stroke-width='1'/>
<path d='M60 16 L70 60 L60 104 L50 60 Z' fill='%23846044'/>
<path d='M16 60 L60 50 L104 60 L60 70 Z' fill='%23C4A071'/>
<circle cx='60' cy='60' r='4' fill='%233A2E28'/></svg>">
<figcaption>Fig. 4 — the rose, redrawn after the second survey</figcaption>
</figure>
<p>What the glove did not say, and what I learned only in the third week, was that the
survey existed to settle a dispute that had already been settled by force. My lines were
to be the record after the fact, the calm hand that makes a seizure look like a border.
I drew them. I am not going to pretend otherwise.</p>
<p>But I drew the villages too, all of them, including the four that were no longer
there. I gave them their names in the same weight of ink as the towns that still had
roofs. If anyone ever compares my sheet against the ground, the discrepancy will be the
only testimony left, and it will be in my handwriting.</p>
<p>The passes closed early that year. The man with the glove did not come back, and the
sheet went north without a covering letter. I have thought about it every autumn since,
which is the sentence I would put beneath the title if a map were allowed one.</p>
<div class="folio">— 147 —</div>
</body></html>
''';
