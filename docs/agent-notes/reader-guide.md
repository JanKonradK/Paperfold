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
- In progress: regenerate localization and rerun the full suite.
- Required checks: changed-file dart analyze and flutter test --concurrency=1.
