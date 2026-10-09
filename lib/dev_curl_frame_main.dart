// Development entry point for the curl frame-time benchmark.
//
// Not part of the shipped application. It answers plan.md Section 11.1:
// 16 ms per frame at 60 Hz, no dropped frame across a full turn, with the
// raster thread and the UI thread reported apart.
//
//   flutter build apk --profile -t lib/dev_curl_frame_main.dart

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/page/dev/curl_frame_bench.dart';

void main() {
  runApp(const CurlFrameBenchApp());
}
