// Development entry point for the WebView capture benchmark.
//
// Not part of the shipped application. It answers the open risk in plan.md
// Section 4.2: what it costs to capture a WebView page to a bitmap so the
// curl shader can sample it.
//
// Run it in PROFILE mode. A debug build reports timings that are not real.
//
//   flutter build apk --profile -t lib/dev_capture_main.dart
//   adb logcat | grep CAPTURE_BENCH

import 'package:flutter/material.dart';
import 'package:paperfold/page/dev/capture_bench.dart';

void main() {
  runApp(const CaptureBenchApp());
}
