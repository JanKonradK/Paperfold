# Reader fit pass

## Part 1 — chrome
- First tap opens quick settings with persistent, labeled tools and progress.
- Removed the 600 dp cap. Wide landscape uses a 360 dp end pane.
- Back closes panel, then chrome, then the book. PointerInterceptor retained.
- Added translated reader labels to all 16 locales; generated localization.
- Foundation request: none. Existing frame radius is 32.
- Next: quick controls, Android window bridge, direct Search/Bookmarks.

## Part 2 — quick settings
- Font size uses minus/percentage/plus with the original limits.
- Reordered swatches, line spacing, side margin, font and scroll mode.
- Publisher styles have an inline override; style writes read fresh preferences.
- Retained theme editing, fonts, CSS and existing advanced controls.
- Facing page now opens from Notes. Last paged effect is retained in the session.
- Initial test compile found missing generated models/providers in this fresh worktree.
  Running build_runner to restore ignored generated files (no source model changes).

## Part 3 — Android reader window
- Added a package-free method channel with validated window-only brightness.
- System/5–100% brightness and session rotation lock use one ReaderWindow.
- Flutter requests orientation; Android retains and restores the prior policy.
- Declines lock in multi-window and Android 16 large-display cases.
- Handles natural-landscape displays; activity recreation clears overrides.
- Session exit queues reset after pending updates. Resume reads actual host state.

## Part 4 — direct tools and secondary groups
- Search opens BookToc with initial focus; Bookmarks hosts BookmarkWidget directly.
- The real BookToc path is lib/widgets/reading_page/widgets/book_toc.dart,
  rather than the abbreviated path in the brief. Added one optional focus argument.
- Secondary settings now use named expandable groups. CSS keeps explicit Save.
- Hidden hover controls on Android. All preference/engine capabilities retained.
- Fixed asynchronous theme refresh replacing a newer panel and natural landscape lock.
- Validation underway: scoped analyze clean; navigation tests pass.

## Final checks and handoff
- Reader checks: 27 pass (18 chrome/layout, 1 style, 4 navigation, 4 window).
- Layout coverage: 360x800, 412x915, 600x960, 1095x1750 and reversed,
  plus a 480-wide split window, with RTL and 200% text. Motion-off checks pass.
- Scoped Flutter analyze: no errors or warnings. The existing hasFlag call in
  reader_chrome_test.dart has one deprecation info message.
- flutter gen-l10n completed for all 16 locales. No dependencies changed.
  flutter pub get restored missing worktree package metadata. build_runner
  restored ignored generated files. Generated platform registrant changes were reverted.
- Final flutter test --no-pub --concurrency=1: 492 pass, 1 fails.
  Failure: home_navigation_safety_test, four tabs at 320px/large text.
  It reports an overflow in protected shelf_home_page.dart:529 and a wrapped
  Statistics label. No protected source files were changed.
- Native compilation was attempted through gradlew, but this checkout has no
  android/gradlew.bat. Android device/emulator verification remains open:
  brightness restoration, rotation refusal/recreation, keyboard over a WebView,
  locator retention through real engine reflow, eInk and tablet frame timing.
- No foundation changes requested. All changes are committed. The line-ending
  follow-up preserves the CRLF style of the original reader source files.
