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

## Section 14 checks

| Check | Result |
|---|---|
| Sequence plays on cold start | **Pass.** Burgundy cover, gold line art, curls open to warm paper |
| Sequence does not replay on resume | **Pass.** Home, then relaunch, shows the home screen with no cover |
| Tap skips it | **Pass.** A tap one second into launch lands on the home screen |
| Reduce-motion setting is obeyed | **Not tested on device.** The code reads `MediaQuery.disableAnimationsOf`. Testing it needs the system accessibility setting changed, which is the owner's to change |
| Frame time across a full turn | **Not measured.** Needs a mid-range phone |

## Still open

- Frame time in profile on a **mid-range** Android phone, watching the raster
  thread and the UI thread apart (Section 11.1).
- The WebView capture cost. See `docs/paperfold/webview-capture-cost.md`.
- The reduce-motion path, on a device with the setting switched on.

## Unrelated observation

The Android launcher icon is still Anx Reader's blue book, visible on the
native splash screen before the first Flutter frame. Milestone 3 replaces the
branding assets.
