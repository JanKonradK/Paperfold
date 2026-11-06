# Paperfold fit specification — revision 1

## 1. Decision and evidence

- Preserve one Paperfold design: current type, colors, BookLight, glass, shelves, and motion.
- Adapt the arrangement to the window. Do not introduce a plain NavigationRail or master-detail shell.
- Use Android window dimensions in logical dp. Do not infer dp from screenshot pixels.
- Reference target: approximately 1095 × 1750 dp, subject to device measurement.
- Inspected: one_journal.png (Library), one_settings.png, g_journal.png, g_stats.png, and g_reader_menu.png (Book detail).
- Also inspected g_reader_chrome.png. That image shows a book page, not the open controls.
- Library: the 44 × 66 cover makes Continue reading look like a notification.
- ShelfStage currently divides width by 120. This creates approximately eight small covers on the reference tablet.
- Journal and Settings impose 760 dp caps. Book detail imposes 600 dp caps.
- Statistics switches to unrelated parallel columns above 600 dp, regardless of orientation.
- ReaderChrome starts with icons. StyleWidget exposes animation before several useful adjustments.
- Some empty space comes from one book or one entry. Do not invent content to fill that space.

## 2. Corrections to the starting positions

1. Use orientation AND available space. Landscape alone does not justify two content columns.
2. Keep five tablet covers as the default. Treat three visible rows as a target, not a fixed viewport division.
3. Use radius 32 for outer surfaces. Preserve concentric corners for nested surfaces.
4. Keep object radius 4. A book must still look like a book.
5. Enlarge Continue reading, but do not use a tablet display font on every title.
6. Keep recent Journal entries in date order. Use regular rows on tablets, not masonry.
7. Expose useful Settings values. Do not create a dashboard of oversized category tiles.
8. Separate reading mode from animation. Paged versus scroll belongs in quick settings.
9. Add only a library density preference. Do not add an ambiguous global Layout density preference.

## 3. One layout helper

Proposed new file: `lib/utils/paperfold_layout.dart`.
Use a small immutable value object. Do not add a provider, inherited service, or dependency.

```dart
final layout = PaperfoldLayout.of(context, constraints: constraints);
// landscape, compactHeight, gutter, useSideNavigation, navigationExtent
// contentWidth, referenceCoverWidth, coverColumns, coverWidth
// columns(minWidth: ..., gap: ..., max: ...)
```

- Read full window W and H from MediaQuery.sizeOf(context).
- Set landscape = W > H. Set compactHeight = safe window height < 480.
- Keyboard insets must not change orientation or navigation placement.
- Optional BoxConstraints describe local content width. Never subtract navigation twice.
- Navigation placement uses the full safe window. Component columns use local constraints.
- Gutter g = 16 when min(W,H) < 600. Otherwise g = 24.
- Use side navigation in landscape when safe height >= 320 and safe width >= 600.
- The large-text rail needs safe height >= 432. Otherwise use bottom navigation.
- Side navigation reserves 88 dp: 12 inset + 64 shell + 12 separation.
- At large text, reserve 120 dp: 12 + 96 + 12.
- Content width A = local allocated width minus 2g, unless the caller already applied gutters.
- Define columns(m,gap,max) = clamp(floor((A+gap)/(m+gap)), 1, max).
- Use this formula for component grids. Do not export a universal tablet column count.
- Treat square windows as portrait. Android split-screen follows its actual window dimensions.
- Apply SafeArea once per shell edge. Keep system insets separate from component padding.
- Use LayoutBuilder on each affected screen. Do not use device names or physical display size.
- This helper contains geometry only. Keep shapes in PaperfoldShape and preferences in Prefs.

## 4. Shape, spacing, and type

Required foundation changes for the implementation owner:
`lib/config/paperfold_system.dart` and `lib/utils/color_scheme.dart`.
The existing build brief protects these files. Record this change request before implementation.
This design task changes neither file.

| Role | Proposed shape | Application |
| --- | --- | --- |
| object | radius 4 | Covers, spines, book images |
| pane | radius 32 | Continue pane, cards, settings groups |
| frame | radius 32 | Floating bars, dialogs, sheet top corners |
| control | StadiumBorder | Single-line buttons, chips, segments, one-line fields |
| inset surface | max(0, outerRadius - inset) | Indicator, inner panel, selected theme tile |
| editor | radius 16 | Multiline fields, CSS editor, note composer |

- Keep existing names where possible. Change pane from 24 to 32 and controlShape to StadiumBorder.
- Keep control = 16 for multiline editors. Add editorRadius alias to make its purpose explicit.
- Single-line field borders need a capsule OutlineInputBorder. Do not give multiline fields capsule corners.
- For any small outer surface, effective radius = min(32, width/2, height/2).
- FAB 52 × 52 therefore has radius 26. A 64-high bar has radius 32.
- Insets are real geometry: a surface inset 16 inside radius 32 gets radius 16.
- Do not round each Settings row inside an already rounded group.
- Gaps: 8 within controls, 12 between compact items, 16 between cards, 24 between sections.
- Pane padding: 16 phone, 24 tablet. This supersedes the current 14 for these screens.
- Controls draw at 40 high. Primary buttons draw at 48. Touch targets remain at least 48 × 48.
- Chips draw at 32 high inside 48-high targets. Keep 8 dp between targets where practical.
- App bars: 56 portrait, 48 landscape, excluding system inset. Never shrink touch targets.
- Use existing Philosopher for book/entry headings and Source Sans 3 for interface text.
- Type roles: body 16/24, supporting 14/20, labels 14/20, page heading 24/32.
- These are theme role values in sp, not fixed pixel heights. Honor TextScaler.
- Use no new color recipes. Reuse current surface roles and visual policy.
- Allow glass blur only on floating bars or a sheet. Cards use solid or existing glassine over BookLight.

## 5. Navigation bar and vertical bar

- Portrait phone: current four destinations in the floating bottom shell.
- Portrait tablet: the same bottom shell. Keep maxWidth 560 rather than stretch four targets across 1095 dp.
- Bottom shell width = min(safeWidth - 24, 560), height 64, radius 32.
- Keep 4 dp internal padding and 8 dp slot gaps. Selected indicator uses nested radius 28.
- Bottom offset = max(system bottom padding, gesture inset) + 8.
- Reserve actual shell height + bottom offset + 4 above scroll content.
- Landscape: transpose the same shell to the start edge. Keep icons, labels, tint, and selected motion.
- Standard vertical shell: width 64, four slots 64 high, gaps 8, padding 4. Total height 288.
- Center the vertical shell in the safe height. Use radius 32 and start inset 12.
- At text scale above 1.5, use width 96 and slots 96 high. Total height 416.
- Keep labels visible. If labels exceed slots, use bottom navigation with the existing large-text reflow.
- Bottom large-text fallback: 104 high, or the existing 136-high two-row arrangement below 480 dp width.
- The page heading stays at the top of its content. Do not add a sidebar header or secondary destination list.
- Files: home_page.dart, paperfold_layout.dart. Theme changes are in section 4.
- Flutter risks: preserve IndexedStack identity, destination history, lazy mounting, focus exclusion, and Library Back handling.
- Delete obsolete width-only rail decisions and stale comments about extendBody being off.
- Do not delete the 560 cap: it limits navigation, not content.

## 6. FAB

- Library: one Add book FAB. Journal: one New entry FAB. No FAB on the other named screens.
- Portrait phone and tablet: 52 high, trailing inset g, bottom 16 above the navigation shell.
- Add book is 52 × 52 with radius 26. New entry uses the existing extended FAB at height 52.
- Landscape: trailing/bottom safe inset 16. No extra bottom allowance for a side bar.
- With large text, let the extended FAB grow vertically. Radius stays min(32, height/2).
- Scroll padding includes FAB height + 16 beyond the navigation exclusion where the FAB overlaps content.
- Files: shelf_home_page.dart, journal_home_page.dart, component theme.
- Flutter risks: preserve FAB keys and the composer origin rectangle for the container transform.
- Delete per-screen square corner overrides. Do not add a second capture FAB.

## 7. Library

- Preserve shelves, view switch, sort, filter, wishlist, paper books, and selection behavior.
- Portrait phone: default three covers. Portrait tablet: default five covers.
- Resolve the default from min(W,H) < 600, so rotation does not change the density preference.
- Let n be the selected portrait count. Gap d = 12.
- Portrait reference width P = min(W,H) - 2g.
- Maximum permitted n = max(1, floor((P+12)/84)), which guarantees at least 72 dp per cover.
- Clamp the saved count for this window without overwriting the saved preference.
- Reference cover width c0 = (P - (n-1)d)/n.
- Portrait columns = n. Landscape columns = max(1, floor((A+d)/(c0+d))).
- Actual cover width c = (A - (columns-1)d)/columns. Fill the available row.
- Landscape therefore retains approximately the portrait cover size, with at most one cell of rounding variation.
- Cover image ratio = 2:3. Preserve the artwork ratio within this box without distortion.
- Title below: gap 8, two lines at 14/20. Row pitch = 1.5c + 8 + measured two-line height + 16.
- At 200% text, measure the caption extent. Do not multiply the entire tile by text scale.
- One book occupies one normal cell at the start. Do not center it or expand it across the shelf.
- Keep E-books/Paper books group labels, 24 high minimum, with 12 before the first row.
- At 1095 dp: A=1047, c=199.8, image≈300 high, row pitch≈364 at normal text.
- A 318-high hero, 56-high app bar, controls, insets, and navigation leave roughly 2–3 rows.
- Approximately three rows is correct. Do not shorten covers or crop captions to guarantee three full rows.
- Spines: use density scale k=c0/defaultReferenceCoverWidth, from the same window and default count.
- Multiply existing spineWidth and base spine height by k. Preserve binding height factors and series relationships.
- Spine targets stay at least 48 wide. Base height = clamp(240k,144,320). Shelf gap = 16.
- Retain the existing spine/cover rectangle interpolation, group order, cached art, and visible-item culling.
- Do not replace ShelfStage with a second grid engine.
- Put the hero and toolbar before the book rectangle stack in the active ShelfStage ListView. They scroll out of short windows.
- Pass one header builder through Bookcase to ShelfStage. Include it for empty shelves. Account for its measured height in anchors and culling.
- Files: shelf_home_page.dart, shelf_stage.dart, bookshelf/bookcase.dart, shared_preference_provider.dart, paperfold_layout.dart.
- Apply the same cover formula to ShelfCollectionPage, wishlist tiles, and any active collection grid.
- Flutter risks: rectangle extent includes text, Hero IDs stay unique, rotation preserves book ID plus relative scroll offset.
- Delete the width/120 column rule, fixed 240 spine height, duplicated 16 dp stage gutters, and competing collection density rules.
- Remove the independently scrolling half-height header. Preserve each shelf scroll offset and exclude offstage headers from focus and semantics.

## 8. Continue reading

- Reuse ContinueReadingBanner and continueReadingBook. Keep last-read selection and physical-book behavior.
- Portrait phone: pane width A, radius 32, padding 16, gap 16, cover 96 × 144.
- Title uses headlineSmall 24/32, at most three lines. Author uses bodyMedium 14/20.
- Progress uses bodyMedium. Add a visible Continue button, height 48, below the progress.
- Natural pane height is at least 208. Let text increase it.
- Portrait tablet: padding 24, gap 24, cover width clamp(0.22A,144,180), height 1.5 × width.
- Tablet title uses headlineMedium 28/36. Author and progress use bodyLarge 16/24.
- At the reference width, cover is 180 × 270 and pane minimum height is 318.
- Landscape: keep a full-width horizontal pane in document flow. Cover 80 × 120, padding 16, gap 16.
- Landscape title uses 24/32. Put progress and the 48-high Continue button beside each other when text fits.
- This yields approximately 152 high at normal text. The pane scrolls out with the header.
- Below A=320 or with large text, put the primary button below the cover/text row across the pane.
- Keep cover, title, author, and progress at large text. Never replace the whole pane with an anonymous Continue button.
- Show estimated time remaining only if an existing reliable estimate is available. Otherwise show progress alone.
- For paper books use Log progress, current page, and total pages when known. Do not show an invented time estimate.
- Keep BookLight static at rest. Reuse the cached glow and press feedback.
- Files: continue_reading_banner.dart and shelf_home_page.dart.
- Flutter risks: do not exclude the real button from semantics or create nested conflicting tap actions.
- Delete the 44 × 66 thumbnail, arrow-only action, and compact mode that removes book identity.

## 9. Journal

- Portrait phone: date summary, tools, Recent entries/Book journals switch, chronological entry list.
- Tools precede the feed, so pagination cannot push them below all entries.
- Tool cards: Challenge, Month tracker, Highlights. Each shows its real value or a clear empty state.
- Tool columns = columns(160,12,max:3). Minimum height 88, padding 16, radius 32.
- At narrow phone widths these cards form two rows. Do not hide labels to force three columns.
- Portrait tablet: same sections across A. Recent entries use two regular cells when A >= 840.
- Entry width = (A-16)/2. Otherwise use one column. Keep date headers full width.
- Read entries in row order, newest first. No masonry, column-first ordering, or featured entry promotion.
- Entry card: radius 32, padding 16, title 18/24, date 14/20, excerpt/body 16/24.
- Preview body at six lines and excerpt at four lines. Open the existing journal route for complete content.
- Photos retain aspect ratio, with preview height at most 240. Do not stretch a photo to equalize rows.
- Book journals view uses columns(280,16,max:3), with the same title/count/open action on all devices.
- Landscape: same tool row and feed. Recent-entry columns = columns(400,16,max:3).
- Keep a single vertical scroll. A short landscape window does not justify permanent tool panes.
- One entry keeps its normal cell width. Empty space below one entry is valid.
- Files: journal_home_page.dart. Reuse book_journal_page.dart routes, providers, JournalPhoto, and existing trackers.
- Flutter risks: lazy row construction, 30-entry pagination, stable entry keys, row-order semantics, photo memory.
- Delete _JournalColumn and its 760 cap, floating tool text buttons, and duplicate glow borders around one featured entry.

## 10. Statistics

- Portrait phone and tablet: one scroll in this order: period, summary, chart, trackers, books for that period.
- Do not confuse summary tile columns with two independent page columns.
- Summary columns = columns(200,12,max:4). At 360 dp this is one, at 412 dp usually one, at 600 dp two.
- Permit two compact numeric tiles at A>=320: use minWidth 154 only for days/books/time summary metrics.
- Thus normal phones show two compact metrics, and the reference tablet shows four summary columns.
- Rich tiles span at least two compact columns. Quote and book tiles need 320 dp minimum when possible.
- Reuse the staggered reorder system. A logical summary column maps to two existing column units.
- Preserve saved tile order. Do not reinterpret the stored order when column count changes.
- Tile minimum height 96, padding 16, radius 32. Large text increases row units or opens a full-width tile.
- Main reading-time chart fills A. Plot height 220 phone, 280 tablet. Labels and legend add natural height.
- Trackers use columns(360,16,max:2), after the chart. Keep minutes and pages clearly distinct.
- Book list rows: cover 56 × 84, text gap 16, padding 16, minimum height 116, radius 32.
- Landscape: split summary/chart/trackers | period book list only when A >= 1000 and safe H >= 480.
- Left width = 0.60(A-24), right width = 0.40(A-24). Each side scrolls independently.
- Otherwise retain one scroll. Phone landscape usually retains one scroll with wider metric rows.
- Both panes share the same period state. Keep swipe-delete/undo and load behavior intact.
- Files: statistics_page.dart, widgets/statistic/statistics_dashboard.dart, dashboard_tiles/dashboard_tile_base.dart, affected tile widgets, statistic_card.dart.
- Chart implementation: lib/widgets/statistic/statistic_card.dart and lib/widgets/statistic/statistic_chart.dart.
- Flutter risks: fixedCellHeight 90 currently conflicts with text growth. Adapt cell spans, not text scale suppression.
- Keep lazy DateBooks slivers. Add bottom occlusion padding to every active scroll viewport.
- Delete the maxWidth > 600 page split, fixed 80 bottom spacer, and width/200 unit rule after replacement.

## 11. Settings and Appearance

- Portrait phone: full-width theme shelf, library density control, then the existing category list.
- Group rows are at least 56 high, normally 72 with a subtitle. Radius 32 applies to each group boundary.
- Portrait tablet: theme shelf and density remain full width. Categories use two columns when A >= 720.
- Landscape: category columns = columns(344,16,max:3). Keep one scroll and ordinary routes.
- Portrait category columns = columns(344,16,max:2). Phone-width windows still use one.
- Cards use radius 32, padding 16, header 48 high, and one or two useful inline rows where available.
- Appearance: language value/action and eInk switch. The theme shelf already handles the theme.
- Reading: current font and reading mode actions open their exact setting, not a generic landing page.
- Library & books: storage status and existing import/data actions. Journal: existing notes/book-journal actions.
- Sync & backup: current sync state and existing sync action. Keep credentials in its existing route.
- Catalogs, Translate, Advanced, About stay compact navigation rows without fabricated inline controls.
- Keep category order across layouts. Cards have natural heights in row order, not masonry.
- Theme shelf: three equal swatches, gap 8, minimum height 96, radius 32 outer, nested radius 16.
- System remains an explicit 48-high control. True black remains the existing dark-theme option.
- At large text or narrow width, let theme labels wrap and the shelf increase height.
- Add Appearance > Library layout > Covers per row (portrait), with Auto, minus, value, plus.
- Auto resolves to 3 below a 600 dp short side and 5 otherwise. Store Auto separately from explicit values.
- Choices: phone 2–5, tablet 3–8, further limited by the 72 dp minimum cover width.
- Explicit values persist across rotations. A temporarily narrower window only clamps the displayed count.
- Show helper text: landscape adds columns at the same approximate cover size. Show the resolved count.
- Live preview: first row of actual library covers, with safe fallback covers. Use the real layout formula.
- Preview can scale artwork only, never interface labels. Keep its controls at 48 dp and its height content-driven.
- Show the same control on Settings home and Appearance through one small reusable widget.
- No second global density preference. Do not change reader typography when library density changes.
- Files: settings_home_page.dart, appearance.dart, settings_section.dart, theme_mode.dart, shared_preference_provider.dart, new library layout control widget.
- Flutter risks: Prefs rebuilds must update preview and library, without importing reader globals into Settings home.
- Delete the 760 cap, unused wide-layout settingsDetail/selectedIndex branch after route checks, and duplicate category summary labels.

## 12. Book detail

- Portrait phone: cover/text header, progress, primary action, description, metadata, journal preview, highlights preview.
- Header cover = clamp(0.30A,96,144), ratio 2:3, object radius 4. Text gap 16.
- Below A=320 or at large text, stack the cover above title/author. Keep all subsequent content in one scroll.
- Portrait tablet: one page sequence. Header cover 180 × 270, text/action beside it, gap 24.
- Header pane fills A with padding 24 and radius 32. It is a header, not a permanent second pane.
- Title uses 24/32 phone or 28/36 tablet. Author 16/24. Metadata uses wrapping label/value rows.
- Put the primary 48-high Continue/Start/Log progress button in the header, immediately after progress.
- Keep Journal and Shelves as secondary actions. Use a Wrap at 8 dp gaps for narrow/large-text layouts.
- Description preview: six lines plus Read more. Omit the section if metadata has no description.
- Expose rating, tags, format, progress dates, and reading time with existing data. Do not hide all details under overflow.
- Show up to two journal entries and three highlights. Each section links to the existing complete list.
- For no entries, show a compact New entry action. For no highlights, omit the preview.
- Landscape split only when A >= 900 and safe H >= 480: left header/actions width 300, right information width A-324.
- The left pane scrolls if necessary. The right pane scrolls independently. No global home navigation on this route.
- Below that threshold use the same one-scroll page with a compact 120 × 180 header cover.
- Files: book_detail.dart. Reuse BookJournalPage, BookNotesList, tag editor, metadata and reading-time builders, and DAOs.
- Flutter risks: retain wishlist/paper branches, async refresh after edits, Hero identity, sanitized description display, and source locators.
- Delete the 600 content cap, large bottom gap created by the detached primary footer, and redundant cover frame decoration.
- Move useful details out of the overflow sheet. Keep binding customization and destructive actions there.

## 13. Reader chrome and quick settings

- Preserve an unobstructed page while chrome is hidden. Never show the home navigation in the reader.
- First page tap opens Quick settings plus a persistent tool row. Useful controls need no preliminary Style tap.
- Top bar: Back, current title, add/remove bookmark, More. Height 56 portrait or 48 landscape, radius 32.
- More contains Book details, Copy chapter, and Advanced reader settings. No rare controls in the first panel.
- Bottom tools: Quick settings, Contents, Search, Bookmarks, Notes. Five equal slots, minimum 48-high targets.
- Keep visible labels at 12/16. At large text or constrained width, use a wrapping two-row tool layout.
- Facing page stays available as a Notes action. Progress stays available as a chapter/progress strip.
- Progress strip: 48 high, current chapter, percentage, and position action. Position opens existing ProgressWidget.
- Portrait phone: full safe width minus 24. Pane radius 32, internal padding 16.
- Initial quick panel height = min(360, safeH * 0.48). This excludes the tools and progress strip.
- First rows: font size − / value / +, brightness, page-theme swatches. Keep these above the initial scroll fold.
- Remaining rows: line spacing, side margins, font, Paged/Scroll, rotation lock, More appearance settings.
- Each adjustment row is at least 56 high. Labels sit above sliders on narrow widths.
- Portrait tablet: pane width A, padding 24, two adjustment columns when inner width >= 720, gap 24.
- Keep the same priority order in row-order traversal. No 600 dp cap around the entire controls pane.
- Tablet initial panel height = min(400, safeH * 0.40). Use normal-size controls, not stretched sliders across the whole tablet.
- Landscape: keep a 56-high bottom tool/progress shell. Combine chapter and tool controls only when they fit.
- At safeW >= 840, open quick settings in an end pane width 360, radius 32, 12 from safe edges.
- End pane height = safeH - 24, with independent scroll. It overlays the page without repagination.
- At smaller landscape widths, use a bottom panel capped at safeH * 0.60, excluding its 48-high tool row.
- At very short heights, More expands into a full-height sheet. Keep Close and Back available.
- Close the panel first on Back, then chrome, then the book. Outside tap dismisses without turning a page.
- Preserve locator and selection through font, mode, and orientation changes. Restore position after engine reflow.
- Reuse StyleWidget, StyleSlider, themeSelector, ProgressWidget, BookToc search, BookmarkWidget, and BookNotesList.
- Search opens existing search with initial focus. Bookmarks opens the existing bookmark list directly.
- Add initial search/focus parameters to BookToc. Host the existing widgets/bookmark.dart list directly for Bookmarks.
- Font size keeps the existing 0.5–3.0 range and 0.1 increment. Display a percentage, not unexplained decimal units.
- Line spacing keeps existing engine values 0–3. Do not relabel these values as typographic multiples without checking conversion.
- Side margin keeps existing 0–20 units. Present presets or a labeled slider without claiming these are dp.
- When publisher styles disable changes, show Use custom text styles inline. Do not leave unexplained disabled sliders.
- Paged/Scroll maps to existing PageTurn.scroll. Keep the last paged animation choice when the user selects Scroll.
- Rotation: Follow system by default, Lock current orientation as a session choice. Restore app policy on reader exit.
- Brightness: System or reader-only 5–100% slider. Restore system control on exit, error, or activity recreation.
- No brightness or rotation control exists in the inspected reader. These are new behavior, not rearranged widgets.
- Use Flutter SystemChrome for supported orientation requests and the existing Android channel host for window brightness.
- Check existing Android channel code first. Do not add a brightness package solely for this control.
- If Android refuses rotation in multi-window or on a large display, show actual state and preserve system behavior.
- Files: reader_chrome.dart, style_widget.dart, more_settings/*.dart, reading_page.dart, widgets/book_toc.dart, notes_widget.dart, preference storage.
- Android host: android/app/src/main/kotlin/com/paperfold/app/MainActivity.kt. Add a small Dart bridge and a reader-window channel.
- Flutter risks: WebView pointer interception, keyboard insets, global player keys, async theme load races, and stale local BookStyle copies.
- Prevent sheet rebuilds from recreating the WebView. Apply engine updates during adjustment and persist final values reliably.
- Delete icon-only first-use chrome, fixed 600 shell cap, and whole-dialog tab navigation as the route to common adjustments.
- Replace paired unlabeled sliders and the top-level page-animation dropdown. Preserve the underlying settings.

## 14. Current reader setting inventory

Legend: KEEP = common access. MOVE = named secondary group. REMOVE = remove that presentation only unless specified.

| Current item/source | Decision and destination |
| --- | --- |
| Font size / StyleWidget | KEEP first quick row, add minus/plus and percentage |
| Line spacing / StyleWidget | KEEP quick settings |
| Paragraph spacing / StyleWidget | MOVE More appearance > Paragraphs |
| Font family, bundled/book/system/custom fonts | KEEP quick picker, retain import at its end |
| PageTurn none/slide/fold/curl/scroll | KEEP Scroll as mode, MOVE paged effects to More > Page turns |
| Theme swatches / StyleWidget | KEEP quick settings, distinct from app theme |
| New theme, theme edit/delete | MOVE theme picker overflow/editor, preserve delete behavior |
| Text/background color editor | MOVE More appearance > Custom theme |
| Background image / BgimgSelector | MOVE More appearance > Background |
| Publisher styles / StyleSettings | KEEP inline override when a quick control is disabled, also More appearance |
| Side margin / StyleSettings | KEEP quick settings |
| Top/bottom margins, vertical-writing variants | MOVE More appearance > Margins |
| Paragraph indent | MOVE More appearance > Paragraphs |
| Letter spacing | MOVE More appearance > Text |
| Font weight | MOVE More appearance > Text |
| Heading font size | MOVE More appearance > Headings |
| Text alignment auto/left/center/right/justify | MOVE More appearance > Paragraphs |
| Custom CSS enable/editor/validate/save/reset | MOVE Advanced > Custom CSS, preserve validation and explicit Save |
| Writing direction auto/vertical/horizontal | MOVE More > Language and direction |
| Translation original/translated/bilingual | MOVE More > Translation, retain per-book state |
| Columns auto/single/double | KEEP in quick settings on wide paged books, MOVE below mode on phones |
| Automatic column threshold 400–1200 | MOVE Advanced > Columns, show only in Auto |
| Chinese conversion original/simplified/traditional | MOVE More > Language and direction |
| Code highlight off/light/dark plus named palettes | MOVE More appearance > Code blocks |
| Header/footer left/center/right information selectors | MOVE More > Page information |
| Header/footer margins, side offsets, font size | MOVE More > Page information |
| Full screen / OtherSettings | MOVE More > Screen |
| Keep awake 0–60 minutes | MOVE More > Screen, retain duration semantics |
| Volume-key page turn | MOVE More > Page turns, Android only |
| Swap page-turn areas | MOVE More > Page turns |
| Simple/custom tap mode, diagrams, nine custom cells | MOVE More > Page turns > Tap areas |
| Show menu on hover | REMOVE from Android settings, retain for pointer/desktop context |
| Keyboard shortcut page turn | KEEP desktop-only behavior, absent on Android touch UI |
| Auto-adjust reading theme | MOVE theme picker options, keep explicit reader/app distinction |
| Auto-translate selection | MOVE More > Selection actions |
| Auto-highlight selection | MOVE More > Selection actions |
| Contents / ReaderChrome | KEEP labeled tool |
| Notes / ReaderChrome | KEEP labeled tool, include Facing page action |
| Progress / ReaderChrome | KEEP compact strip and direct Position panel |
| Add/remove bookmark / ReaderChrome | KEEP top bar, add direct Bookmarks list tool |
| Search / BookToc | KEEP direct tool, reuse existing search state/results |
| Copy chapter, Book details | KEEP top More menu |
| Brightness, rotation lock | ADD quick settings, platform behavior specified above |

Do not delete reader preferences, CSS support, localization, or engine capabilities because they move out of the first panel.

## 15. Build order and acceptance

1. Implement the helper and approved shape/theme changes first. Reuse existing components.
2. Implement Library density, Continue reading, and navigation/FAB geometry together.
3. Remove content caps and correct Journal, Statistics, Settings, and Book detail arrangements.
4. Reorder reader controls. Add direct Search/Bookmarks access and the two platform controls.
5. Add new strings to all 16 locales with real translations. Run flutter gen-l10n.
6. Run build_runner after Riverpod/Freezed source changes. Use pub get only if dependencies change.
7. Check 360×800, 412×915, 600×960, and 1095×1750 windows, then each reversed orientation.
8. Also check a 480-wide split window, RTL, 200% text, keyboard, eInk, Remove animations, and high contrast.
9. Use populated samples: at least 20 books, 30 entries, long titles, missing covers, and long translated labels.
10. At normal text, confirm 3 phone covers and 5 tablet covers with Auto. Confirm live density changes and rotation anchors.
11. Confirm one Statistics scroll in portrait and no horizontal clipping on any named screen.
12. Confirm useful reader controls on the first tap, all tools while a panel is open, and unchanged book position after reflow.
13. Confirm the last item clears navigation/FAB in every scroll region. Confirm all targets remain at least 48 dp.
14. Profile main transitions on the Galaxy Tab S7+. Preserve cached BookLight, bounded blur, and existing motion policy.
15. Run relevant widget/layout checks, then flutter test --concurrency=1 before implementation handoff.

This output is a design specification only. No repository file changes form part of this task.


## 16. Amendments by Claude (these win)

1. Journal tool cards show an icon, a title, and one line of real status only
   where a provider already gives it cheaply. Do not add new queries for it.
2. Statistics: one summary grid with columns(154, 12, max: 4). Rich tiles span
   two columns. Do not add a second column rule.
3. Library header: keep one vertical scroll that holds the Continue pane, the
   toolbar and the shelves. If moving the header into ShelfStage is too risky,
   use a CustomScrollView with the header as a sliver and ShelfStage as a sliver
   child. Do not break shelf swipe, culling, or Back handling.
4. The covers-per-row preference is in the foundation
   (`Prefs().libraryCoversPerRow`, 0 = Auto). Do not add a second one.
5. Reader brightness and rotation lock use the existing Android channel host in
   `MainActivity.kt` and a new Dart file. No new package.
6. The whole fit pass is Android first. Do not add iOS, desktop, or web work.

## 17. Owners

| Owner | Files |
| --- | --- |
| Claude: foundation | `lib/utils/paperfold_layout.dart`, `lib/config/paperfold_system.dart`, `lib/utils/color_scheme.dart`, `lib/page/home_page.dart`, `Prefs` |
| Sol: Library | `shelf_home_page.dart`, `bookshelf/*`, collection grids, new `widgets/settings/library_layout_control.dart`, `widgets/settings/appearance.dart` |
| Sol: Reader | `reader_chrome.dart`, `style_widget.dart`, `more_settings/*`, `reading_page.dart`, `book_toc.dart`, `notes_widget.dart`, `MainActivity.kt`, new `service/reader_window.dart` |
| Claude: screens | Journal, Statistics, Settings home, Book detail |
