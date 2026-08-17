// Development entry point for the 3D book model.
//
// This is not part of the shipped application. It exists so the object can be
// judged by eye, and its opening measured in profile mode, without starting
// the library, the database or the reader.
//
//   flutter run -t lib/dev_book_model_main.dart
//   flutter run -t lib/dev_book_model_main.dart --profile
//
// A debug build on an emulator will lie about frame time. The opening is a
// per-frame repaint of about forty painted faces, so it is worth measuring on
// a real mid-range phone before believing it.

import 'package:flutter/material.dart';
import 'package:paperfold/page/dev/book_model_demo.dart';

void main() {
  runApp(const BookModelDemoApp());
}
