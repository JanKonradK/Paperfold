// Development entry point for the page curl.
//
// This is not part of the shipped application. It exists so the curl can be
// judged by eye and measured in profile mode without starting the reader,
// the database, or the WebView.
//
//   flutter run -t lib/dev_curl_main.dart
//   flutter run -t lib/dev_curl_main.dart --profile
//
// plan.md Section 11.1 requires the profile measurement on a physical
// mid-range Android phone. A debug build and an emulator both lie about
// frame time.

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/page/dev/page_curl_demo.dart';

void main() {
  runApp(const PageCurlDemoApp());
}
