# Library implementation log

## Done

- Direct Book detail routes; no held-book Back interception.
- Format groups and counts, wrapped spines at least 48 dp, safe bottom clearance.
- Continue supports paper books and uses BookLight.
- BookLight detail, flat cover in a glassine vitrine, Philosopher title, progress, Journal/Shelves, fixed primary, overflow metadata/binding/tags/rating.
- ID-based Hero with an internal perspective turn, route-clock placard arrival, reverse curve.
- Spine/cover rectangle interpolation with midpoint crossfade and a scroll anchor; reduced spatial motion dissolves.
- Custom shelves loaded from existing membership tables; wishlist detail has no progress or reading action.
- Five strings translated in all 16 ARBs; localization and code generation run.

## Verification

- First focused run: 11 passed; one new wrap assertion fixed (fourth book wraps, three fit).
- Detail/transition/cover focused run: 5 passed.
- Full run 1 aborted by host out-of-memory / DartWorker thread creation failure.
- Full run 2 in progress. New real Hero flight test failed because it tapped before initial app settling; setup now fixed, needs rerun.
- Full suite is not yet certified green.

## Next

- Finish full-suite run, then rerun the real flight test and checks after latest cleanup.
- Analyze changed sources; restore Flutter-generated platform registrants before committing.
- Verify Android/tablet frame times, predictive Back, TalkBack and eInk on hardware.

## Limits / foundation follow-up

- Book has no stored chapter display label; detail shows actual paper page and started date, but cannot show an e-book chapter without a model/service source.
- Motion foundation conflates reduced motion and Remove animations. Local transitions use accessibleNavigation for a 120 ms dissolve, disableAnimations/eInk for zero.
- Layout uses computed row/grid rectangles rather than measuring two separately mounted render trees.
