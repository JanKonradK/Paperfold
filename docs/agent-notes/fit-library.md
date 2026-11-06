# Library fit log

- Part 1: cover grid and collection grids use PaperfoldLayout.covers. Spines scale with portrait density; captions reserve scaled text height.
- Left: hero and shared scroll, FAB verification, density control and translations, checks.
- Appearance lives at lib/page/settings_page/appearance.dart (task path was stale).

- Part 2: larger identity-preserving hero with a real 48 dp button. Shared header scrolls in ShelfStage, including empty shelves; measured header extent feeds anchors and culling.

- Part 3: FAB inherits the existing 52 dp StadiumBorder theme. Tablet trailing gutter follows layout; landscape does not add bottom navigation clearance. No per-screen shape override exists.

- Part 4: LibraryLayoutControl is reusable, observes Prefs, previews actual first-row books with fallback art, and uses the real cover formula. Auto is stored separately. All 16 ARBs translated; flutter gen-l10n completed.
- Appearance placement uses the existing page/settings_page/appearance.dart. Removed the obsolete cover-width slider (no library caller reads it). The stored legacy preference remains untouched.
- Settings home owner: add LibraryLayoutControl below the theme shelf. settings_home_page.dart is outside this worker's scope.
- No foundation changes requested. Shape and FAB theme already supply radius 32 and StadiumBorder at 52.
- Checkout setup: ignored generated Dart files were missing. Restored 45 from the base checkout at the same source commit; no build_runner and no Riverpod/Freezed source edits.
- Analysis: six changed implementation files pass with no issues. Verification still running.
