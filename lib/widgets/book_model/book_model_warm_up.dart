import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/service/book_art.dart';
import 'package:paperfold/widgets/book_model/book_model.dart';
import 'package:paperfold/widgets/book_model/book_model_builder.dart';

/// Draws the books a shelf is about to show, once, onto a canvas nobody sees.
///
/// There is no shader warm-up to do here and there has not been for some time:
/// the engine renders with Impeller, which compiles its shaders when the engine
/// itself is built rather than when a pipeline is first used, and the tooling
/// that bundled a captured SkSL cache went with the backend it belonged to.
/// What is left of "the first frame is the expensive one" is all in this
/// application's own caches, and those are ours to fill.
///
/// The costly part of drawing a book is laying out its type. A title and an
/// author are laid out at a thousand times the book and drawn back down, and
/// the result is held by [BookTextRun]; the colours are a dozen blends and four
/// luminances, held by [BookModelPalette]; the artwork is a file read and an
/// image decode, held by [BookArtCache]. None of that is touched until the
/// first frame that actually paints the book — which is the frame the shelf
/// arrives on, for every book on it at once.
///
/// So the object is painted here instead, into a discarded picture, before the
/// reader ever sees it. It is deliberately the real renderer and the real spec
/// rather than a list of the things worth warming: the cache keys are built
/// deep inside the painters, out of sizes the model works out for itself, and
/// anything that tried to guess them would warm the wrong entries the first
/// time one of those sizes changed and never say so.
///
/// **It owns no timers and schedules no frames.** The first attempt handed the
/// work to `SchedulerBinding.scheduleTask` at idle priority, which is the right
/// API for "only when nothing else wants the CPU" and the wrong one here: under
/// a test binding the queue is drained by the test's own pumping, so a widget
/// test of any page that warmed up never went idle and never completed. A slice
/// runs inside a post-frame callback the caller already has, and if the frames
/// stop, so does the warming — which is correct, because a still screen has no
/// jank to protect.
abstract final class BookModelWarmUp {
  /// How long one slice is allowed to run for.
  ///
  /// Well inside a frame at 120 Hz, which is 8.3 ms. A slice happens after the
  /// frame is already on the wire, so it eats into the idle time before the
  /// next one rather than into the frame itself — but only if it is short
  /// enough to finish there. The whole errand is not to become the jank.
  static const Duration budget = Duration(milliseconds: 3);

  /// The books already warmed, so a rebuild does not do the work again.
  static final Set<String> _done = {};

  @visibleForTesting
  static void reset() => _done.clear();

  @visibleForTesting
  static int get warmed => _done.length;

  /// Draws as many of [specs] as fit in [budget], newest work first.
  ///
  /// Returns true when there is more left to do, so the caller can ask again on
  /// a later frame. Books already drawn are skipped, so this is cheap to call
  /// repeatedly and safe to call from a build.
  static bool slice(
    List<BookModelSpec> specs, {
    required String Function(BookModelSpec spec) keyOf,
    Size box = const Size(220, 300),
    Duration budget = budget,
  }) {
    final clock = Stopwatch()..start();
    for (final spec in specs) {
      if (!_done.add(keyOf(spec))) continue;
      _draw(spec, box);
      if (clock.elapsed >= budget) {
        // Something was drawn and the budget is gone. Whether anything is left
        // is the next call's business, and asking is a scan of a small list.
        return specs.any((candidate) => !_done.contains(keyOf(candidate)));
      }
    }
    return false;
  }

  /// Reads and decodes the cover files, so the first sight of a book is the
  /// book rather than the printed cover it falls back to.
  ///
  /// Deduplicated and cached by [BookArtCache]; this only starts it early, the
  /// same way [BookModel] does when it is built. A book whose file has gone
  /// keeps its printed cover, which is the cache's business and not this one's.
  static void warmArt(Iterable<String> coverPaths, {bool mirror = false}) {
    for (final path in coverPaths) {
      if (path.isEmpty) continue;
      if (BookArtCache.peek(path) != null) continue;
      BookArtCache.load(path, mirror: mirror);
    }
  }

  static void _draw(BookModelSpec spec, Size box) {
    final recorder = ui.PictureRecorder();
    BookModelRenderer.paint(Canvas(recorder), box, spec);
    // The picture is never rasterised and never composited. Recording it is
    // what runs the painters, and running the painters is the whole errand.
    recorder.endRecording().dispose();
  }
}
