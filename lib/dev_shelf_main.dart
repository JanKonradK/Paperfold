// Development entry point for the shelf.
//
// This is not part of the shipped application. It exists so the shelf, the
// taking of a book off it, and the opening can be judged by eye on a phone
// without starting the library, the database or the reader.
//
//   flutter run -t lib/dev_shelf_main.dart
//   flutter run -t lib/dev_shelf_main.dart --profile
//
// The deck repaints two books at most while it scrolls: a book more than one
// step behind the front holds a fixed camera, so its painter is not asked to
// build forty faces again for a move a Transform can do.

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/page/dev/shelf_stage_demo.dart';

void main() {
  runApp(const ShelfStageDemoApp());
}
