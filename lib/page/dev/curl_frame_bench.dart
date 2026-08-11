// Curl frame-time benchmark.
//
// plan.md Section 11.1 sets the budget at 16 ms per frame at 60 Hz, with no
// dropped frame across a full turn, and says to watch the raster thread and
// the UI thread apart, because a shader that stutters shows on the raster
// thread while a rebuild storm shows on the UI thread.
//
// Flutter's frame timings are the right instrument. `adb shell dumpsys
// gfxinfo` reports zero frames for a Flutter app, because it tracks Android's
// HWUI pipeline and Flutter draws to its own surface.
//
// The curl is driven programmatically here rather than by a finger, so the
// numbers measure the shader and the widget, not the timing of injected
// touch events.
//
// Run it in PROFILE mode. A debug build reports timings that are not real.
//
//   flutter build apk --profile -t lib/dev_curl_frame_main.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:paperfold/widgets/page_curl/page_curl.dart';

class CurlFrameBenchApp extends StatelessWidget {
  const CurlFrameBenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Curl frame bench',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF846044),
        useMaterial3: true,
      ),
      home: const CurlFrameBenchPage(),
    );
  }
}

class _Stats {
  _Stats(this.label, this.values);

  final String label;
  final List<double> values;

  double get median {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    return sorted[sorted.length ~/ 2];
  }

  double get p95 {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    return sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)];
  }

  double get worst =>
      values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);

  int overBudget(double budgetMs) =>
      values.where((v) => v > budgetMs).length;
}

class CurlFrameBenchPage extends StatefulWidget {
  const CurlFrameBenchPage({super.key});

  @override
  State<CurlFrameBenchPage> createState() => _CurlFrameBenchPageState();
}

class _CurlFrameBenchPageState extends State<CurlFrameBenchPage>
    with SingleTickerProviderStateMixin {
  static const int _turns = 12;
  static const Duration _turnDuration = Duration(milliseconds: 900);

  late final AnimationController _drive;
  final PageCurlController _curl = PageCurlController();

  bool _running = false;
  bool _recording = false;
  String _status = 'Ready.';

  final List<double> _build = <double>[];
  final List<double> _raster = <double>[];
  final List<double> _total = <double>[];
  TimingsCallback? _callback;

  double _refreshHz = 60.0;

  @override
  void initState() {
    super.initState();
    _drive = AnimationController(vsync: this, duration: _turnDuration);
    _callback = (List<FrameTiming> timings) {
      if (!_recording) return;
      for (final t in timings) {
        _build.add(t.buildDuration.inMicroseconds / 1000.0);
        _raster.add(t.rasterDuration.inMicroseconds / 1000.0);
        _total.add(t.totalSpan.inMicroseconds / 1000.0);
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_callback!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final display = WidgetsBinding.instance.platformDispatcher.views.first.display;
      setState(() => _refreshHz = display.refreshRate);
      unawaited(PageCurl.warmUp());
    });
  }

  @override
  void dispose() {
    if (_callback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_callback!);
    }
    _drive.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _status = 'Warming the shader.';
      _build.clear();
      _raster.clear();
      _total.clear();
    });

    // Warm up first so shader compilation is not counted as a dropped frame.
    await PageCurl.warmUp();
    _drive.value = 0;
    await _drive.forward();
    _drive.value = 0;
    await Future<void>.delayed(const Duration(milliseconds: 300));

    setState(() => _status = 'Recording $_turns turns.');
    _recording = true;

    for (int i = 0; i < _turns; i++) {
      _drive.value = 0;
      await _drive.forward();
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    _recording = false;
    setState(() {
      _running = false;
      _status = 'Done. ${_total.length} frames recorded.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final budget = 1000.0 / _refreshHz;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: AnimatedBuilder(
                animation: _drive,
                builder: (context, _) {
                  if (_curl.isAttached) {
                    _curl.jumpTo(_drive.value);
                  }
                  return WidgetPageCurl(
                    controller: _curl,
                    interactive: false,
                    textDirection: TextDirection.ltr,
                    front: const _BenchPage(
                      title: 'Recto',
                      tint: Color(0xFFFAF6EE),
                      ink: Color(0xFF3A2E28),
                    ),
                    back: const _BenchPage(
                      title: 'Verso',
                      tint: Color(0xFFEDE3D2),
                      ink: Color(0xFF5C4A3F),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  FilledButton(
                    onPressed: _running ? null : _run,
                    child: Text(_running ? 'Running' : 'Run $_turns turns'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$_status\nDisplay ${_refreshHz.toStringAsFixed(0)} Hz, '
                      'budget ${budget.toStringAsFixed(1)} ms',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: _buildTable(budget),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(double budget) {
    if (_total.isEmpty) {
      return const Center(child: Text('Tap Run.'));
    }
    final rows = <_Stats>[
      _Stats('UI (build)', _build),
      _Stats('Raster', _raster),
      _Stats('Total span', _total),
    ];
    return SingleChildScrollView(
      child: Column(
        children: [
          DataTable(
            columnSpacing: 18,
            headingRowHeight: 30,
            dataRowMinHeight: 28,
            dataRowMaxHeight: 34,
            columns: const [
              DataColumn(label: Text('thread', style: TextStyle(fontSize: 12))),
              DataColumn(label: Text('median', style: TextStyle(fontSize: 12))),
              DataColumn(label: Text('p95', style: TextStyle(fontSize: 12))),
              DataColumn(label: Text('worst', style: TextStyle(fontSize: 12))),
              DataColumn(label: Text('over', style: TextStyle(fontSize: 12))),
            ],
            rows: rows
                .map(
                  (s) => DataRow(cells: [
                    DataCell(Text(s.label, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(s.median.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(s.p95.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(s.worst.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold))),
                    DataCell(Text('${s.overBudget(budget)}',
                        style: const TextStyle(fontSize: 12))),
                  ]),
                )
                .toList(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'frames=${_total.length}   '
              'over budget: UI ${_Stats("", _build).overBudget(budget)}, '
              'raster ${_Stats("", _raster).overBudget(budget)}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenchPage extends StatelessWidget {
  const _BenchPage({
    required this.title,
    required this.tint,
    required this.ink,
  });

  final String title;
  final Color tint;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tint,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          Container(
            width: 64,
            height: 2,
            margin: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFFC4A071),
          ),
          Expanded(
            child: Text(
              'Every map is an argument about what deserves to be remembered, '
              'and every cartographer is therefore a kind of editor, deciding '
              'in silence which rivers earn a name and which villages are '
              'permitted to vanish beneath a fold. I had drawn the northern '
              'coast eleven times before I understood this, and the twelfth '
              'drawing was the first honest one. The commission arrived in '
              'autumn, carried by a man who would not sit down. He set the '
              'papers on the table, weighted them with his glove, and told me '
              'the survey had to be finished before the passes closed.',
              style: TextStyle(fontSize: 16, height: 1.6, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
