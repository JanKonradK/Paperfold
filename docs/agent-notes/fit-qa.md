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
