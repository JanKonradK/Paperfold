# The reader stutter

Recorded 2026-08-13, after the owner reported that flicking pages stutters in
both PDF and EPUB on a 400-page book.

## The cause found first, and it is not a rendering cost

`assets/foliate-js/index.html` loads `./dist/bundle.js`. `dist/` is a **committed
build artifact**. Nothing in the Flutter build, `release_build.sh`,
`release.dart`, `Fastfile` or any GitHub workflow runs `npm run build`.

Before this pass, the last commit to touch `dist/` was `aa590d8f`, 2026-04-19,
which is inherited from the fork. Every reader change Paperfold has made since
lived in `assets/foliate-js/src/` and **had never run on a device**. That
includes the whole of `7edb8a9e`:

- the per-frame `getVisibleRange` walk over the entire chapter body
- the `scrollLeft`-per-frame turn animation and its move to the compositor
- the settle-time relocate
- the turn easing

So the measured claim in that commit was true of the source and false of the
application. Any conclusion drawn about EPUB reader performance before
2026-08-13 was drawn about April's code.

**The rule this leaves behind: a change under `assets/foliate-js/src/` does
nothing until `npm run build` is run in `assets/foliate-js` and the rebuilt
`dist/` is committed with it.**

The build was also not reproducible. `webpack.config.js` excluded the vendored
PDF engine from Babel with a forward-slash pattern, which webpack matches
against a native path, so on Windows the exclude missed and Babel transpiled all
of pdf.js to ES5 — half again the bundle size and a slower PDF engine, decided
by which machine ran the build. With `[\\/]` for the separator,
`dist/pdf-legacy.js` and `dist/pdf-legacy.worker.js` rebuild byte-identical to
the versions that were committed.

## PDF, fixed by inspection

PDF and CBZ do not use the reflowable `Paginator` at all. They use
`FixedLayout`, which received none of the `7edb8a9e` work. Four defects
compounded, all of them structural rather than a matter of tuning:

| Defect | Where | Fix |
|---|---|---|
| Unbounded page cache, `revokeObjectURL` never called | `src/pdf.js` | Bounded LRU of 10, both blob URLs released on eviction |
| No lookahead; the render begins when the turn does | `src/pdf.js` | Neighbours rendered on `requestIdleCallback` |
| PNG encode per page | `src/pdf.js` | WebP at 0.92, PNG fallback |
| `replaceChildren()` and two new iframes per turn | `src/fixed-layout.js` | Two persistent slots, navigated |

The cache is the one that explains the shape of the complaint. A 400-page
document was never slow because of its page count — every page visited stayed
resident, holding a full-resolution image of itself, so it got heavier the
further into it you read.

Covered by `assets/foliate-js/test/` (`npm test`, 15 tests): the cache bound,
both URLs being released, concurrent loads of one page rendering once, prefetch,
frame reuse across a twenty-page read, and an overtaking turn.

## EPUB, not yet measured

**Open.** The reflowable path is now running code that has never run before, so
every previous observation of it is void. It must be re-measured before anything
further is changed, or the next fix will be a guess.

One provable waste was removed without measuring, because it is wrong at any
frame rate: every relocate called `setState` on `EpubPlayer`, **and** invoked
`updateParent`, which called `setState` on the whole `ReadingPage` — the Stack,
the chrome and the WebView subtree — to carry one boolean, `bookmarkExists`, to
one toggle in a top bar that is off screen while the reader is turning pages. It
is a `ValueNotifier` read by a `ValueListenableBuilder` around that toggle now.

### How to measure it

Needs the hardware. There is no attached Android device in the environment this
was written in, and a debug build is meaningless for this question.

```bash
flutter run --profile
```

Open a 400-page EPUB, flick 50 pages, and read the timeline in DevTools with the
UI and raster threads shown apart. The budget from `plan.md` Section 11.1 is
16 ms per frame at 60 Hz; the existing measurements in
`milestone-1-measurements.md` were taken on a Samsung SM-S918B, Android 16, so
use that device for a comparable number.

`lib/page/dev/curl_frame_bench.dart` shows the established shape for collecting
this — `SchedulerBinding.addTimingsCallback`, with `buildDuration` and
`rasterDuration` reported separately and a median, p95 and worst.

### Named suspects, in the order worth checking

1. **The curl capture.** `_capturePage` in
   `lib/page/book_player/epub_player.dart` is debounced 400 ms and only runs
   when the turn style is the shader curl, so it stays out of a fast flick — but
   `webview-capture-cost.md` measures JPEG q80 full width at **72 ms** total,
   and a flick with pauses in it pays that on each pause. Half width costs
   47 ms and third width 36 ms. Only worth changing if the timeline shows it.
2. **`EpubPlayer.setState` on relocate.** Eight fields, of which the footer
   needs a few; the rest of the Stack does not. The same `ValueNotifier`
   treatment applies if the rebuild shows up.
3. **pdf.js prefetch competing with a turn.** `requestIdleCallback` should keep
   it out of busy frames. Confirm it does on the real WebView rather than
   assuming the shim behaves.
