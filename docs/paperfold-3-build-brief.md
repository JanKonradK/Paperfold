# Paperfold 3 build brief

This brief is the build contract. Where it differs from
[paperfold-3-design-plan.md](paperfold-3-design-plan.md), this brief wins.
The mockups are a direction, not pixels: the owner asked for rounder, thinner,
denser.

## Owner changes (2026-11-06)

- Corners more rounded, less square.
- Controls thinner; fit more on the screen.
- Animations must be outstanding.
- In scope now: notifications (actions), photo of the page, home-screen
  widgets, Settings redesign. A5 PDF export waits.
- Performance target: the owner's tablet, which is slower than the phone.

## Foundation (already built, commit f83cd0e2)

Use these. Do not add raw radii, durations, or colours.

| What | Where |
| --- | --- |
| Corners: object 4, control 16, pane 24, frame 32, full (native only) | `lib/config/paperfold_system.dart` `PaperfoldShape` |
| Spacing: 4 8 12 16 24 32 48; gutter 16, sheet 20, float inset 12, pane 14 | `PaperfoldSpace` |
| Sizes: control 40 (target 48), primary 48, chip 32, FAB 52, nav bar 64, app bar 56, row 56, icon 22, small icon 18 | `PaperfoldSize` |
| Glass: floating 0.88 + blur 12, glassine 0.64 (only over BookLight), solid | `lib/widgets/paperfold_glass_surface.dart` (`PaperfoldGlassTier`) |
| Policy: no blur and no decorative motion under eInk, Remove animations, high contrast, battery saver | `lib/config/paperfold_visual_policy.dart` |
| Motion: none 0, tick 120, shift 200, move 300, open 450; curves turn, settle, depart, land (small overshoot) | `lib/config/paperfold_motion.dart` (`PaperfoldMotion.of(context, d)`) |
| BookLight: cached two-colour cover glow, clamped per theme | `lib/service/book_light.dart`, `lib/widgets/book_light.dart` |
| Pane with press feel (0.97 under the finger, lands back) | `lib/widgets/common/paperfold_pane.dart` |
| Component themes (buttons, FAB, chips, segments, fields, sheets, dialogs, menus, nav, snackbars) | `lib/utils/color_scheme.dart` `paperfoldComponentTheme` |
| Floating glass nav bar, rail at >= 600 dp, destination fade, `extendBody: true` | `lib/page/home_page.dart` |
| Quick capture entry point (notifications, widgets, share, in-app) | `lib/service/quick_capture.dart` |

Wordmark colour: `PaperfoldBrand.wordmark(scheme)`.
Pages under the floating nav bar must honour `MediaQuery.paddingOf(context).bottom`
so the last item scrolls above the bar and any FAB.

## Motion bar

The owner rates motion highest. Every moving thing must feel physical and
intentional, and nothing may move at rest.

- One clock per transition, from the five speeds. Use `land` only for small
  distances (indicators, chips, a pressed pane returning).
- Shared-element moves over cross-fades: spine to cover (Hero, axis-aligned
  host, rotate inside the shuttle), FAB to composer (container transform),
  Spines to Covers (each book moves from its spine box to its grid box).
- Sheets rise on `settle`; content inside fades in after the sheet lands.
- Reduced motion: spatial moves become a 120 ms dissolve. Remove animations
  and eInk: 0 ms.
- Measure on a mid-range tablet: no dropped frames in profile mode during the
  main transitions; at most two blur regions on screen.

## Rules for every agent

- Work only in the files your task names, plus new files. Do not edit
  `lib/utils/color_scheme.dart`, `lib/config/*`, or
  `lib/widgets/paperfold_glass_surface.dart`; ask in your report if you need
  a foundation change.
- New strings: add to all 16 files in `lib/l10n/` with real translations
  (the parity test checks this), then run `flutter gen-l10n`.
- Keep behaviour, Back handling, large text (200%), RTL, TalkBack labels,
  eInk, and 48 dp targets.
- Run `dart run build_runner build --delete-conflicting-outputs` after a
  Riverpod or Freezed source change, and the tests for the files you changed.
  Run `flutter test --concurrency=1` before you finish.
- Commit on your branch with clear messages ending with the co-author line
  your harness gives you.
