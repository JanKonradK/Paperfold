# Reader tap guide

- Branch: t3/first-open-reader-guide. Do not push.
- Read AGENTS.md, Ponytail full, and Impeccable onboarding guidance.
- Share the tap action resolver with EpubPlayer, including custom zones, swap, and disabled tap turns.
- Show the guide after reader load. Save one device-wide seen preference on dismissal.
- Use connected regions from the existing 3 by 3 layout. Keep arrows aligned with reader direction.
- Implemented: guide gate after onLoadEnd, connected zone paths, pane labels, two arrow pulses, reduced motion, settings replay, and six English strings.
- Added tests for persistence, replay, tap blocking, all five presets, custom/swap/disabled actions, RTL/semantics, and requested sizes at 200% text.
- This fresh worktree lacked generated models/providers. Ran flutter pub get and build_runner to prepare checks. No dependencies changed.
- Targeted checks: all 15 guide tests pass, including portrait and landscape at 200% text.
- Analyze: no errors or warnings. Two existing info diagnostics in shared_preference_provider.dart (deprecated value and missing type annotation).
- Full suite found the locale parity test requires every key in every locale. Added translations for the six strings in the 15 other ARBs; no English fallbacks.
- Locale parity and all 15 guide tests pass together (16 tests).
- First full run: 512 passed; only locale parity failed before the translations were added.
- Final flutter test --concurrency=1: all 513 tests passed (498 baseline plus 15 new tests), exit 0.
- Final changed-file dart analyze: exit 0, no errors or warnings; only the two existing info diagnostics above.
- flutter gen-l10n and dart run build_runner build --delete-conflicting-outputs completed.
- Final test log: %TEMP%/paperfold-reader-guide-tests-final.log.
- Removed only tool-generated platform registrant changes. No packages or unrelated source files changed.
- Base paperfold-3-open-vitrine is an ancestor of this branch. Nothing was pushed.
- Implementation commits: 08832c51, 8f305c34, 3f5d8ac4. Each has the requested co-author trailer.
- Reader keyboard focus returns after guide dismissal.
- Manual Android and TalkBack checks have not been run. Translations have not had a native-speaker review.
- Required checks: changed-file dart analyze and flutter test --concurrency=1.

## Changed files

- lib/config/shared_preference_provider.dart
- lib/page/book_player/epub_player.dart
- lib/page/reading_page.dart
- lib/widgets/reading_page/reader_tap_guide.dart
- lib/widgets/reading_page/more_settings/other_settings.dart
- lib/widgets/reading_page/more_settings/page_turning/types_and_icons.dart
- lib/l10n/app_*.arb (all 16 locales; six new strings only)
- test/widgets/reader_tap_guide_test.dart
- docs/agent-notes/reader-guide.md
