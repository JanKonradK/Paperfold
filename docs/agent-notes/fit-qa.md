# Fit QA resume log

- Date: 2026-11-06.
- Scope: test the fit pass and correct defects. Do not change the startup quote screen or OtherSettings.
- Read AGENTS.md, the fit specification, and the Library and reader notes.
- Added test/fit_matrix_test.dart. Tests use physicalSize, devicePixelRatio, and view.reset.
- Test windows: 320x640 with normal and double text, 412x915, 915x412, 800x1280, and 1280x800.
- Tests cover home tabs, rotation state, book detail, reader tool callbacks, and cover density.
- Initial test run could not compile. This checkout had no package metadata or generated source files.
- Ran flutter pub get. No dependency changes. Restored platform registrant files.
- Run build_runner to restore generated source files. No provider source changes.
- Next: run the matrix, correct defects, run dart analyze, then run the full test suite.
- Device checks remain necessary for Android brightness, orientation, reader reflow, and frame timing.

- Matrix result: 24 tests pass, including 30 Journal entries and 20 cover samples.
- Corrected the Statistics date control. Its label now wraps between the arrow buttons at 320 dp.
- Corrected Library FAB clearance when landscape uses bottom navigation.
- Added bottom clearance to both scroll panes in wide Statistics.
- Rotation tests retain the same Bookcase state.
- Reader tool tests confirm all six callbacks. Existing window tests cover reset after pending changes.
- Initial dart analyze result: no errors, 21 warnings, and 93 information messages. The result differs from the stated baseline.
- Additional warnings concern existing development entry points, Riverpod rules, and test imports. No unrelated source changes.
- Next: full test suite and final analysis.

- Added a seventh window: 915x412 with double text. All matrix windows include 24 dp top and bottom insets.
- Corrected side navigation at large text sizes. It remains on the side in landscape at widths of at least 600 dp.
- The side bar scrolls when the available height cannot contain all four targets.
- Corrected Settings category overflow. Removed equal-height rows so wrapped labels receive their natural height.
- Matrix and Settings tests: 32 pass. Reader window checks: 5 pass.
- Added a reader exit test after a successful brightness change and rotation lock. Reset occurs once and releases orientation.
- Final analysis: no errors, 21 existing warnings, 93 existing information messages. No new diagnostics.
- Final full suite remains in progress.

## Final result

- flutter test --concurrency=1: 527 tests pass. No failures.
- Final matrix rerun, including cover boundaries: 28 tests pass.
- Cover boundary checks cover 72, 155.9, 156, 239.9, and 240 dp of content width.
- The cover formula keeps at least 72 dp and fills the available content width. No formula change was necessary.
- dart analyze: no errors, 21 existing warnings, and 93 information messages. The expected three-warning baseline does not match this checkout.
- build_runner completed. No Riverpod or Freezed source changes. No new packages.
- Reader tool callbacks and reset order pass. No reader wiring defect was found.
- Device checks remain open. No adb command is available here. Confirm Android brightness reset, rotation policy, activity recreation, and real WebView reflow on hardware.
- Tab S7+ frame timing, eInk behavior, and physical keyboard checks also need hardware.
- The startup quote screen and other_settings.dart have no changes. No filler content or new features.
- Commits: ffb4753f, c88e1553, a2b95ab3, followed by this final test and log commit.
- No push. The working tree is clean after the final commit.
