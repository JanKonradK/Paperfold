# Library fit log

- Part 1: cover grid and collection grids use PaperfoldLayout.covers. Spines scale with portrait density; captions reserve scaled text height.
- Left: hero and shared scroll, FAB verification, density control and translations, checks.
- Appearance lives at lib/page/settings_page/appearance.dart (task path was stale).

- Part 2: larger identity-preserving hero with a real 48 dp button. Shared header scrolls in ShelfStage, including empty shelves; measured header extent feeds anchors and culling.

- Part 3: FAB inherits the existing 52 dp StadiumBorder theme. Tablet trailing gutter follows layout; landscape does not add bottom navigation clearance. No per-screen shape override exists.
