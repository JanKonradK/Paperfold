# The WebView capture path — what the code actually does

`plan.md` Section 4.2 names this the open risk of the project and the least
known cost. This note records what the pinned dependency actually does, read
from its source on 2026-08-11, and the numbers measured on a device the same day.

## What the plan assumed

> The likely answer is the `InAppWebViewController` screenshot method, which
> gives a bitmap you curl instead of the live view. If it exists and is fast
> enough, the design below works.

It exists. **It does not give you a bitmap.**

## What `takeScreenshot` really does on Android

Source: the pinned fork `Anxcye/flutter_inappwebview` at `4a275c3`, file
`flutter_inappwebview_android/.../webview/in_app_webview/InAppWebView.java`,
lines 754 to 826.

Each call performs these steps in order:

1. `mainLooperHandler.post(...)` — the work runs on the **Android main thread**.
2. `Bitmap.createBitmap(width, height, ARGB_8888)` — a full-size bitmap.
   At 1440 x 3088 that is about **17.8 MB** per capture.
3. `draw(canvas)` — a **software rasterization** of the whole WebView.
4. `screenshotBitmap.compress(PNG, 100, stream)` — a **PNG encode at quality
   100** of that bitmap.
5. The bytes cross the platform method channel into Dart.
6. Dart must then **decode the PNG back** into a `ui.Image` before a shader can
   sample it.

So the real path is:

```
draw -> PNG encode -> channel copy -> PNG decode -> texture upload
```

Not "give me the texture".

## Why this matters for the curl

A curl needs the next and the previous page as textures **before** the finger
moves. `plan.md` Section 4.2 already states the load-bearing rule:

> capture the next and previous page before the finger touches the screen.
> A capture during the gesture is too slow.

The source confirms that rule is not caution. It is a requirement. A capture
during the gesture would block the Android main thread on a software draw and a
PNG encode, which is a guaranteed dropped frame.

## The two levers the API gives us

`ScreenshotConfiguration` accepts:

| Lever | Effect |
|---|---|
| `compressFormat: JPEG` with a quality below 100 | Much cheaper than PNG. PNG at quality 100 is the worst case in the default path. |
| `snapshotWidth` | Downscales before encoding. A smaller bitmap is cheaper to encode, to transfer, and to decode. |
| `rect` | Captures a region instead of the whole view. |

A curl distorts the page, so a small loss of sharpness during the turn may be
invisible. The page is sharp again the moment it settles, because the live
WebView returns. This is worth measuring against full-resolution PNG.

## MEASURED — 2026-08-11, first pass

> **The worst-frame column in this first table is wrong.** It reads zero for the
> JPEG cases because the app was idle and rendered no frames, so nothing was
> timed. The corrected table is in the next section. The capture and decode
> timings here are sound.

Harness: `lib/page/dev/capture_bench.dart`, run through
`lib/dev_capture_main.dart`. **Profile build**, Samsung SM-S918B, Android 16.
WebView 1440 x 1776 logical pixels, showing a page of styled prose with a
heading, a drop capital, justified text, and an inline illustration.
Nine runs per case, first discarded, median reported.

| Case | Capture | Decode | **Total** | Bytes | Decoded size | Worst frame |
|---|---:|---:|---:|---:|---|---:|
| **PNG q100 full** | 142 ms | 23 ms | **165 ms** | 350 KB | 1440x1776 | **158 ms** |
| JPEG q80 full | 40 ms | 32 ms | **72 ms** | 245 KB | 1440x1776 | 0 |
| JPEG q60 full | 33 ms | 30 ms | **63 ms** | 183 KB | 1440x1776 | 0 |
| JPEG q80 half width | 38 ms | 9 ms | **47 ms** | 92 KB | 720x888 | 0 |
| JPEG q80 third width | 32 ms | 4 ms | **36 ms** | 58 KB | 480x592 | 0 |

### What this says

1. **The default is the trap.** `CompressFormat.PNG` at quality 100 is what you
   get if you pass no configuration. It costs 165 ms and it stalled a Flutter
   frame for 158 ms, about ten frames at 60 Hz. Never use the default.
2. **JPEG is the single biggest win.** Switching format alone takes the total
   from 165 ms to 72 ms. The PNG encode, not the bitmap allocation or the
   software draw, was the dominant cost. It does **not** remove the frame
   stall, only shrink it; see the corrected table below.
3. **Downscaling mostly helps the decode.** Half width cuts the Dart-side decode
   from 32 ms to 9 ms while the platform call barely moves, 40 ms to 38 ms. The
   draw and encode still work on the full view; only the output shrinks.
4. **Two captures, next and previous, cost about 144 ms at full width or about
   94 ms at half width.** That fits in genuinely idle time between turns. It
   does not fit inside a gesture, which confirms the plan's rule.

### Re-measured with frames in flight — this changes the conclusion

The first run reported a worst frame of zero for every JPEG case. That was an
artifact: an idle Flutter app renders no frames, so a capture that blocks the
Android main thread has nothing to stall.

The bench now keeps a small animation running continuously, so there is always
a frame in flight. Re-measured, same device, same profile build:

| Case | Capture | Decode | **Total** | **Worst frame** |
|---|---:|---:|---:|---:|
| PNG q100 full | 148 ms | 25 ms | **173 ms** | **160 ms** |
| JPEG q80 full | 46 ms | 33 ms | **79 ms** | **45 ms** |
| JPEG q60 full | 41 ms | 32 ms | **73 ms** | **44 ms** |
| JPEG q80 half width | 35 ms | 9 ms | **44 ms** | **33 ms** |
| JPEG q80 third width | 28 ms | 6 ms | **34 ms** | **28 ms** |

**Every capture stalls a frame. There is no free option.** Even the cheapest,
JPEG at one third width, stalls 28 ms, which is more than three frames at
120 Hz and nearly two at 60 Hz.

The stall tracks the platform call, not the total. That is consistent with the
mechanism: the platform work happens on the Android main thread while the Dart
decode does not block the same thread.

### What this means for the design

The rule is stronger than "pre-capture before the finger lands". It is:

> **Capture only when nothing is animating.**

A capture during a page turn, during the opening sequence, or during any
transition will drop frames on any device. Capturing after a page has settled
and the reader is sitting still is invisible, because there are no frames to
lose.

Two consequences to handle in the reader:

1. **Debounce rapid turns.** If a user turns pages quickly, a capture started
   after one settle can still be running when the next gesture begins. Cancel or
   defer it rather than letting it overlap.
2. **Prefer the smaller capture.** One third width stalls 28 ms against 45 ms
   for full width, and the page is distorted mid-curl anyway.

### The device caveat

This is a flagship. A mid-range phone has slower memory bandwidth and a slower
CPU, and the dominant costs here are a full-size bitmap allocation, a software
draw, and an encode, all of which scale with that. Expect the mid-range numbers
to be materially worse. The ranking of the options should hold.

## Verdict for Milestone 1

**The reader can have a real curl**, on three conditions:

1. **Use JPEG, never the PNG default.** Quality 80 is enough; the page is
   distorted during the turn and the live WebView returns the moment it settles.
2. **Capture only when nothing is animating**, never inside a gesture or a
   transition. Every capture stalls a frame; the cheapest still costs 28 ms.
3. **Consider half width.** It costs 47 ms against 72 ms, quarters the memory,
   and the loss lands only on a page that is mid-curl.

The fallback in the plan, where the reader keeps a simple turn and only the
journal curls, is **not needed on this evidence**. Confirm on a mid-range phone
before treating it as settled.

## What was measured, for the record

1. Time `takeScreenshot` with PNG quality 100 at full size. This is the baseline
   the plan assumed.
2. Time it with JPEG at quality 80, and at 60.
3. Time it with `snapshotWidth` at half and at one third of the screen width.
4. Time the Dart-side decode to `ui.Image` for each.
5. Record the total, capture to sampleable texture, for each combination.
6. Watch for dropped frames **during** the capture, because step 1 runs on the
   Android main thread.

Budget: two captures, next page and previous page, must complete in the idle
time between page turns without a visible stall.

## If the numbers are bad

`plan.md` Section 12 requires the decision at Milestone 1, not Milestone 5.
The fallbacks, cheapest first:

1. **Downscale and use JPEG.** Likely enough on its own.
2. **Capture one page, not two.** Curl forward only, cross-fade backward.
3. **Capture during idle after each settle**, so the cost never lands inside a
   gesture.
4. **Reader keeps a simple turn. Only the journal curls.** This is the plan's
   own stated fallback. The journal is drawn in Flutter, has no platform view,
   and `AnimatedSampler` captures it directly. The journal is the product, so
   the best page turn still lands on the most important surface.

## Note on the fork

This behavior belongs to the vendored fork we inherited. `flutter_inappwebview`
is the one dependency Paperfold cannot drop, and it carries the reader. Any
future move back to the public package must retest this path, not only the
reader. See `docs/paperfold/inherited-dependency-forks.md`.
