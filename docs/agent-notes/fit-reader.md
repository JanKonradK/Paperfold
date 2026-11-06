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
