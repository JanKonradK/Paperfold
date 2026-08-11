# Milestone 1 measurements

`plan.md` Sections 6.2, 11.1 and 14. Measured on 2026-08-11.

## Device — read this first

| Item | Value |
|---|---|
| Phone | Samsung SM-S918B, Galaxy S23 Ultra |
| Android | 16, API 36 |
| Screen | 1440 x 3088 |

**This is a flagship, not the mid-range phone Section 11.1 asks for.** It passes
budgets that a mid-range device can fail. Every number below is therefore a
best case, and the frame-rate verdict is **not** decided by it.

## Debug builds lie. The plan is right about this

`flutter build apk --debug` and `flutter build apk --profile`, same code, same
phone, cold start to first frame:

| Build | Cold start to first frame |
|---|---|
| debug | 1979, 2007, 2061 ms |
| **profile** | **518, 537, 543, 548 ms** |

Nearly four times apart. Never quote a debug number as a result.

## Cold start against the budget

Section 6.2 sets the budget as **1.2 s from first frame to interactive**.

| Measure | Value | Verdict |
|---|---|---|
| Cold start to first frame, profile | about 535 ms | — |
| Opening sequence duration | 1150 ms, fixed in code | — |
| **First frame to interactive** | **1150 ms** | **Passes, 50 ms of margin** |
| Launch to fully settled | about 1685 ms | — |

Two honest notes:

1. **The margin is 50 ms.** The sequence length is a constant, so it does not
   grow on a slower phone, but there is almost no room to make the animation
   longer. Treat 1150 ms as the ceiling, not a starting point.
2. **The app is interactive at the first frame regardless**, because a touch
   skips the sequence and the home screen is already built beneath it. A user
   who taps is not waiting 1150 ms.

## Curl frame time

Harness: `lib/page/dev/curl_frame_bench.dart` through
`lib/dev_curl_frame_main.dart`. Profile build. The curl is driven
programmatically, not by a finger, so the numbers measure the shader and the
widget rather than the timing of injected touch events.

**The display runs at 120 Hz, so the budget is 8.3 ms, not 16 ms.** Section
11.1 states both. The tighter one applies here.

Twelve full turns, 1307 frames recorded:

| Thread | Median | p95 | Worst | Frames over 8.3 ms |
|---|---:|---:|---:|---:|
| UI, build | 0.2 ms | 0.4 ms | 2.3 ms | **0** |
| Raster | 1.5 ms | 2.6 ms | 4.8 ms | **0** |
| Total span | 2.4 ms | 4.0 ms | 12.2 ms | 2 |

### Reading this correctly

Section 11.1 asks for the raster thread and the UI thread apart, because a
shader that stutters shows on the raster thread. **The raster thread never
exceeded 4.8 ms against an 8.3 ms budget**, so the shader has about 40 percent
headroom at 120 Hz, and roughly 3.5 times headroom against the 16.7 ms budget
at 60 Hz.

`totalSpan` shows two frames over budget, but it includes time waiting for
vsync, so it is not a count of dropped frames. Build and raster are the
figures the plan asks for and both are clean.

### What this suggests about a mid-range phone

The raster worst case is 4.8 ms at 120 Hz. A mid-range GPU might be two or
three times slower, which would put the worst case near 10 to 15 ms. That
still fits inside the 16.7 ms budget at 60 Hz, which is the refresh rate most
mid-range phones run. **This is an inference, not a measurement.** It is a
reason to expect a pass, not a substitute for testing.

## Section 14 checks

| Check | Result |
|---|---|
| Sequence plays on cold start | **Pass.** Burgundy cover, gold line art, curls open to warm paper |
| Sequence does not replay on resume | **Pass.** Home, then relaunch, shows the home screen with no cover |
| Tap skips it | **Pass.** A tap one second into launch lands on the home screen |
| Reduce-motion setting is obeyed | **Not tested on device.** The code reads `MediaQuery.disableAnimationsOf`. Testing it needs the system accessibility setting changed, which is the owner's to change |
| Frame time across a full turn | **Pass on this phone.** 1307 frames, zero over budget on UI or raster. Needs a mid-range phone to settle |

## Still open

- Frame time in profile on a **mid-range** Android phone. Everything here says
  it should pass, and nothing here proves it.
- The reduce-motion path, on a device with the setting switched on.
- Frame time while a WebView capture runs. The capture bench recorded no jank
  during the JPEG cases, but an idle app renders no frames, so nothing was
  timed. Measuring that needs a capture taken while the curl animates.

The WebView capture cost is answered. See
`docs/paperfold/webview-capture-cost.md`.

## Unrelated observation

The Android launcher icon is still Anx Reader's blue book, visible on the
native splash screen before the first Flutter frame. Milestone 3 replaces the
branding assets.
