# The WebView capture path — what the code actually does

`plan.md` Section 4.2 names this the open risk of the project and the least
known cost. This note records what the pinned dependency actually does, read
from its source on 2026-08-11. **The measurement is separate and comes next.**

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

## What to measure next, on a real device

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
