# Milestone 1 — the gate

`plan.md` Section 12 makes Milestone 1 a go or no-go. This is the evidence and
what it supports. Written 2026-08-11.

## DECISION: GO — 2026-08-11

Taken on the evidence below, with the reader curl included. The two open items,
the mid-range measurement and the reduce-motion check, are **carried as known
gaps** rather than blocking the milestone. They stay listed in
"What this evidence does not cover" until they are closed.

## The question the gate exists to answer

Section 4.2 states the open risk plainly: a real curl needs each page as a GPU
texture, the reader is a WebView, and on Android a WebView is a platform view
that Flutter cannot capture directly. If the capture path is too slow, the
reader keeps a simple turn and only the journal curls. **The plan requires that
decision here, not at Milestone 5.**

## What was built

| Piece | State |
|---|---|
| Curl fragment shader | Built. One shader serves the page turn and the cover opening, as Section 6.1 asks |
| Full page resolution | Two `ui.Image` textures on two samplers. An earlier packed atlas halved horizontal resolution and was rejected |
| Right-to-left | `uDirection` is a uniform, so a mirrored curl needs no rebuild. Section 3.4.1 |
| Shader warm-up | `warmUp()` runs during the opening sequence, so the compile stall does not land on the first page turn. Section 11.2 |
| Reduced-motion fallback | The hinged fold from Step A, used when the caller asks for it or the shader is unavailable |
| Opening sequence | Cold start only, skippable from the first frame, a setting to disable, obeys the system reduce-motion flag |
| First paint unblocked | The database no longer blocks `runApp`. It loads behind the animation and callers join one shared future |
| Step C, paper grain | Deliberately not built. Section 7 orders it last |

## What was measured

Profile builds, Samsung SM-S918B, Android 16, 120 Hz display.

### Curl frame time — passes

Twelve turns, 1307 frames, budget 8.3 ms at 120 Hz:

| Thread | Median | p95 | Worst | Over budget |
|---|---:|---:|---:|---:|
| UI, build | 0.2 ms | 0.4 ms | 2.3 ms | **0** |
| Raster | 1.5 ms | 2.6 ms | 4.8 ms | **0** |

Section 11.1 asks for the raster thread apart, because a shader that stutters
shows there. It never exceeded 4.8 ms against 8.3 ms.

### Cold start — passes

| Measure | Value |
|---|---|
| Cold start to first frame | about 535 ms |
| Opening sequence | 1150 ms |
| First frame to interactive | 1150 ms against a 1200 ms budget |

The margin is 50 ms. Treat 1150 ms as a ceiling.

### WebView capture — works, with a strict rule

| Case | Total | Worst frame |
|---|---:|---:|
| PNG q100 full, the default | 173 ms | 160 ms |
| JPEG q80 full | 79 ms | 45 ms |
| JPEG q80 third width | 34 ms | 28 ms |

Every capture stalls a frame. The rule that follows is stronger than the
plan's: **capture only when nothing is animating**, not merely before the
finger lands.

## Recommendation: GO, with the reader curl included

The plan's fallback, where the reader keeps a simple turn and only the journal
curls, is not required by this evidence.

Conditions carried into Milestone 5:

1. JPEG, never the PNG default. The default is a 160 ms stall.
2. Capture only when nothing is animating. Not during a turn, not during the
   opening sequence, not during any transition.
3. Debounce rapid turns so a capture cannot overlap the next gesture.
4. Prefer a downscaled capture. The page is distorted mid-curl anyway.

## What this evidence does not cover

State these plainly rather than let them pass as settled.

1. **The phone is a flagship.** Section 11.1 asks for a mid-range device, and
   an S23 Ultra passes budgets a mid-range phone can fail. The curl has large
   headroom, so a pass is likely, but likely is not measured.
2. **The reduce-motion path is untested on a device.** The code reads
   `MediaQuery.disableAnimationsOf`. Confirming it needs the system
   accessibility setting switched on, which is the device owner's to change.
3. **The curl is not wired into the reader.** It was built in isolation on
   purpose, so the shader and the capture question stayed independent. Joining
   them is Milestone 5 work.
4. **The reader page turn has not been seen end to end.** The capture cost and
   the curl cost are each measured; the two have not yet run together.

## If the mid-range measurement fails

The fallbacks stay available and cost little, in order:

1. Downscale the capture further, or drop JPEG quality.
2. Capture one page instead of two: curl forward, cross-fade backward.
3. Reduce the curl radius, which shrinks the shaded band the shader computes.
4. The plan's own fallback: the reader keeps a simple turn, and only the
   journal curls. The journal is drawn in Flutter, needs no capture, and is
   the product.
