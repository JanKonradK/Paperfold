# Paperfold 3 design plan: Open Vitrine

Status: approved for build after five review rounds (2026-11-06).
Authors: Claude (Opus 5.5) and GPT-6.1 Sol (high effort), on the owner's brief.
Mockups: [design canvas](https://claude.ai/artifact/BjfXcrktdege8sT9fwYqpQ) (private until shared).
Product truth: [PRODUCT.md](../PRODUCT.md).
This plan replaces the visual rules in [paperfold-design.md](paperfold-design.md) when phase P0 ships.
Write DESIGN.md from the built result at the end of the build, not before.

## 1. Direction

**Thesis.** The room is solid and quiet. Each book sits behind glass.
Color comes only through the glass, and only from a book.

| Kept from the current app | Changed |
| --- | --- |
| Upright spines, shelves, binding palette, wordmark | One shape scale, one motion scale, one glass recipe |
| Cream, Burgundy, Dark (with true black), System | Cream ground is cooler: `#F3EFE8` |
| Philosopher and Source Sans 3 | Philosopher only for book titles, spines, and saved quotes |
| Reader page themes, eInk mode, RTL, large text | The held-book staging on the shelf goes away |

Rejected ideas and the reasons:

- Live blur on cards and lists: battery cost, and text over blur is hard to read.
- A cover image enlarged behind the glass: it looks muddy and keeps hard edges.
- Projection, glow, or idle animation: battery cost, and it competes with reading.
- A vertical tab rail on phones: it takes width and shortens labels.

## 2. Foundation

### 2.1 Shape

| Token | dp | Use |
| --- | --- | --- |
| object | 2 | Spines, covers, thumbnails |
| control | 12 | Buttons, FAB, chips, segments, fields, snackbars |
| pane | 20 | Cards, placards, list groups, the vitrine case |
| frame | 28 | Sheets (top corners), dialogs, floating bars |
| full | — | Only native round parts: switch, slider, progress track, navigation indicator, sheet handle |

Concentric rule: inner radius = outer radius minus the real inset, only for tightly fitted parallel edges (frame 28, inset 8, pane 20).
A raw-radius tripwire test fails on a new numeric `BorderRadius.circular(...)` outside `lib/config/`.
Existing violations go in a frozen baseline that must be empty by P7.

### 2.2 Spacing

Scale: 4, 8, 12, 16, 24, 32, 48.
Route gutter 16. Sheet gutter 20. Floating bar inset 12. Card padding 16.
Bottom clearance = system inset + navigation height + gap + FAB obstruction. The last item must scroll fully above the floating controls.

### 2.3 Color

Verified semantic tokens (C Cream, B Burgundy, N Dark near-black, T Dark true-black):

| Token | C | B | N | T |
| --- | --- | --- | --- | --- |
| ground | #F3EFE8 | #3D1723 | #160F0C | #000000 |
| surfaceLow | #EDE2D1 | #46202A | #211714 | #0C0908 |
| surface | #E6DAC7 | #4C2932 | #2B201C | #17110F |
| surfaceHigh | #DED1BD | #503639 | #372924 | #211916 |
| onSurface | #160F0C | #F3EBDD | #F6F2EA | #F6F2EA |
| onSurfaceVariant | #52423D | #C0BAB3 | #C0BAB3 | #C0BAB3 |
| primary | #391214 | #C8B28F | #B7A179 | #B7A179 |
| onPrimary | #F3EBDD | #3D1723 | #160F0C | #160F0C |
| primaryContainer (tonal) | #E8DCD5 | #503639 | #44332D | #2D231F |
| onPrimaryContainer | #160F0C | #F3EBDD | #F6F2EA | #F6F2EA |
| outline | #52423D | #C0BAB3 | #887D77 | #887D77 |
| outlineVariant | #C0BAB3 | #52423D | #52423D | #52423D |
| error | #AC001F | #FFB4AB | #FFB4AB | #FFB4AB |
| brand (wordmark) | #9C7A52 | #C8B28F | #B7A179 | #B7A179 |

Spine colors do not change with the theme. Spine text uses gold only when it passes 4.5:1; otherwise use the stronger of paper `#F6F2EA` or ink `#160F0C`. Author text on spines is at full opacity.
Controls that need a visible edge use `outline` at alpha 1.0. The glass hairline is decoration only.

### 2.4 Glass

| Tier | Recipe | Where |
| --- | --- | --- |
| Solid | Theme surface, opaque | Writing, lists, reading, menus, large sheet bodies |
| Glassine | surfaceLow tint at **0.64**, no blur | Only over BookLight. Never over covers, spines, images, or reader pages |
| Floating glass | surfaceLow tint at **0.88**, blur sigma 12, clipped to its frame, no saturation change | Navigation bar, reader bars, compact sheet headers |

Edges: hairline onSurface at 0.16 alpha; top highlight white at 0.08 (Cream 0.18).
Limit: two floating-glass regions on screen. A modal makes the navigation bar opaque.
eInk, Remove animations, and battery saver make every glass layer opaque.
At 0.88, text passes 4.5:1 over any backdrop (worst case 5.05:1, Burgundy).
**Open check:** recompute glassine 0.64 against the final BookLight envelope before P1 ships (Sol R4 computed 5.44 to 7.50:1 minimum; re-certify on the implemented bands).

### 2.5 BookLight

The "window into the book": two muted colors from the cover, drawn as a diagonal gradient that fades to the ground over the bottom 40%.

1. Decode the cover at 64 × 64. Ignore pixels with alpha below 0.5.
2. Bin in OKLab; the heaviest bin is the dominant color; the next bin at distance ≥ 0.04 is the secondary.
3. Clamp in OKLCH to the theme band. Reduce chroma to fit sRGB; do not clip channels.
4. Cache the two colors by cover revision, theme, and rule version. Never re-extract during a transition.

| Theme | L band | C cap | Example (teal cover) |
| --- | --- | --- | --- |
| Cream | 0.85–0.88 | 0.045 | #B5DEE8 → #AFDAD3 |
| Burgundy | 0.32–0.39 | 0.050 | #204A54 → #113F3A |
| Dark near-black | 0.26–0.30 | 0.050 | #03333C → #012C28 |
| Dark true-black | 0.18–0.24 | 0.050 | — |

All text drawn directly on BookLight passes 4.5:1 inside these bands (lowest: Burgundy primary 4.53:1).
A missing or damaged cover uses its binding color.

### 2.6 Type

Source Sans 3 for all interface text and all editable text.
Philosopher (upright, never italic, because italic "I" reads as "l") for spines, the Book detail title, the journal title page, and saved quotations.
Roles in sp: headline 28/36, title large 22/28, title medium 16/24 semibold, body large 18/28, body 16/24, label 14/20 semibold, metadata 12/16 or 13/16.
Segment labels 14/20 semibold. Saved quotes 17/24.
Use the existing script fallbacks for all 16 locales.

### 2.7 Buttons and controls

| Control | Size | Notes |
| --- | --- | --- |
| Filled | 48 high, 20 side padding, 15/20 | One per decision area |
| Primary (bottom action) | 56 high, 20 side padding, 16/20 | Continue reading, Save |
| Tonal | 48 high | Secondary actions |
| Text | 48 target | Quiet way out |
| Icon button | 48 × 48, icon 24 | — |
| FAB | 56, radius 12 | Library: Add book. Journal: New entry |
| Chip | 32 visual, 48 hit region | Shelf filters |
| Segmented | 48 high | Shared perimeter, radius 12 |
| Field | ≥ 56 high (single line 48 in compact rows) | outline at alpha 1.0 |

Icons: 24 dp actions, 18 dp inside chips and segments, stroke 1.75.

### 2.8 Motion

| Token | ms | Use |
| --- | --- | --- |
| none | 0 | eInk, Remove animations |
| tick | 120 | Press, selection, reduced-motion dissolve |
| shift | 200 | Tabs, reader bars, navigation switch |
| move | 300 | Sheets, routes, spine to cover, Spines/Covers |
| open | 450 | Opening a book (replaces `coverTurn` 560) |

Curves: the existing `turn`, `settle`, `depart`. The page turn keeps 380 ms and its spring.
One clock per transition. No staggered cascades. Nothing moves when the user does not touch the screen.

## 3. Screens

| Screen | First viewport (412 × 915) | Primary action |
| --- | --- | --- |
| Navigation shell | Floating glass bar 80 high, 12 from the sides; rail at ≥ 600 dp | — |
| Library | Wordmark; Continue pane on BookLight (only when a book is active); shelf chips; count + Spines/Covers + sort; E-books and Paper books shelves with counts | Continue (paper book: Log progress); FAB Add book |
| Book detail | BookLight; cover in a glass vitrine case (pane 20); Philosopher title; progress pane ("12% through the book"); Journal and Shelves; summary | Continue reading / Start reading / Log progress |
| Journal | Date and pages today; Recent entries (default) / Books; entries with page anchors; records strip below the writing | FAB New entry |
| New entry | Sheet with glass header and opaque body; book picker; Note / Quote / Progress; fields; drafts survive closing | Save to *book* |
| Reader | Floating glass bars hidden by default | — |
| Facing page | Sheet over the reader; the anchored passage stays visible above it; earlier entries up to this location; write field | Save |

Tap a spine: Book detail. Long-press: quick actions. Continue skips Book detail.
"Photo of the page" is not in the approved design until its scope is decided.

## 4. Signature: the facing page

At any reading position, open the journal leaf that belongs beside that page.

- Opens from reader chrome and from a paper book's logged position.
- Shows entries at or before the current location; "Show later entries" reveals the rest.
- Each saved entry has an anchor ("Loomings · p. 3") that returns to the passage.
- E-books store the engine locator (EPUB CFI plus progress). Paper books store the page. Order by reading position, never by string comparison of CFIs.
- No generated prompts, streaks, or invented quotes.

## 5. Motion choreography

| Transition | Sequence |
| --- | --- |
| Library → Book detail | 300 ms, `turn`. Spine turns edge-on (0–120), cover turns face-on (120–300), placard fades in (180–300). Axis-aligned Hero host, rotation inside the shuttle, perspective 0.001 |
| Book detail → Reader | 450 ms, `turn`. Cover hinges 0 → −90° (mirrored in RTL); reader chrome fades in over the last 120 ms |
| Reader → Facing page | 300 ms, `settle`. Sheet rises; reader stays still; passage emphasis fades in over 120 ms |
| FAB → New entry | 300 ms, `settle`. Container transform from the FAB; radius 12 → 28; keyboard opens after the transform |
| Navigation switch | 200 ms, `settle`, fade-through, no travel |
| Shelf chip | Selection 120 ms; shelf contents fade-through 200 ms |
| Spines ↔ Covers | 300 ms, `settle`. Each book moves from its spine box to its grid box; crossfade at the midpoint; first visible book stays the scroll anchor |

Reduced motion: every spatial move becomes a 120 ms dissolve. Remove animations and eInk: 0 ms.
Predictive Back follows the gesture.

## 6. Build phases

Run the relevant tests at each phase and `flutter test --concurrency=1` before release.
Run `dart run build_runner build --delete-conflicting-outputs` when a Riverpod or Freezed source changes.

| Phase | Size | Goal | Main files |
| --- | --- | --- | --- |
| P0 Foundation | L | Tokens, shape, motion, glass policy, BookLight service, one theme path, tripwire | `lib/config/paperfold_tokens.dart`, `lib/config/paperfold_motion.dart`, `lib/utils/color_scheme.dart`, `lib/widgets/paperfold_library_theme.dart`; new `lib/service/book_light.dart`, `lib/config/paperfold_visual_policy.dart` |
| P1 Components | M | Panes, glass bar, sheet, BookLight widget, placard; component themes | `lib/widgets/paperfold_glass_surface.dart` (blur arguments do nothing today), `lib/widgets/common/*`; new `paperfold_pane.dart`, `glass_bar.dart`, `paperfold_sheet.dart`, `lib/widgets/book_light.dart`, `lib/widgets/bookshelf/book_placard.dart` |
| P2 Shell | M | Material `NavigationBar` in glass, rail at ≥ 600 (today `> 600`), FAB per destination, bottom clearance | `lib/page/home_page.dart` |
| P3 Library | L | Groups and counts, spines ≥ 48 that wrap, direct Book detail route, paper Continue | `lib/page/home_page/shelf_home_page.dart`, `lib/widgets/bookshelf/shelf_stage.dart`, `bookcase.dart`, `book_spine.dart`, `continue_reading_banner.dart`, `lib/providers/shelf_home.dart` |
| P4 Book detail | M | Vitrine, BookLight (replaces the sigma 28 blurred header), Hero by book ID | `lib/page/book_detail.dart`; new `lib/widgets/bookshelf/book_detail_route.dart` |
| P5 Journal | L | Recent entries query, New entry composer, drafts, migration v12 | `lib/providers/journal_home.dart`, `lib/dao/journal.dart`, `lib/dao/database.dart`; new `lib/page/journal/journal_home_page.dart`, `new_entry_sheet.dart`, `lib/service/journal/entry_draft.dart` |
| P6 Reader | L | Glass chrome, facing page, location queries | `lib/widgets/reading_page/reader_chrome.dart`, `lib/page/reading_page.dart`, `lib/page/book_player/epub_player.dart`; new `lib/widgets/reading_page/facing_page.dart` |
| P7 Rest | L | Settings, statistics, OPDS, dialogs adopt the system; empty the radius baseline; A5 PDF export | `lib/page/settings_page/*`, `lib/page/home_page/statistics_page.dart`, `lib/page/opds/*`; new `lib/service/journal/export_journal_pdf.dart` |

Database version 12 (P5, used by P6) adds to `tb_journal`:
`entry_kind TEXT NOT NULL DEFAULT 'note'`, `source_locator TEXT`, `source_progress REAL`, `source_page INTEGER`, `source_label TEXT`.
Existing `source_cfi`, `source_excerpt`, and `source_chapter` stay. A display label is never a locator.
Devices that sync must all update, as with version 11.

## 7. Acceptance contract

Each phase must pass:

- 48 dp touch targets, including chips and anchors (visual size may be smaller).
- Text 4.5:1 and required control edges 3:1 in all four themes.
- 200% text, RTL, reduced motion, Remove animations, eInk, high contrast.
- Keyboard-open layouts: editors scroll, the focused field and Save stay above the keyboard, and the sheet keeps ≥ 120 dp of reader context when space permits.
- TalkBack labels, selected states, focus order, and focus containment in sheets (on hardware).
- No writing loss: drafts survive closing, save failure, and process death.
- Golden tests for the eight approved compositions: new `test/widgets/paperfold_screens_golden_test.dart` with fixed fonts and cover fixtures.

## 8. Risks

1. Reader anchors that stay stable across reflow, formats, and paper books.
2. Writing loss during drafts, partial saves, and progress updates.
3. Blur cost over the WebView and scrolling content.
4. Back, scroll position, and Hero regressions when the held-book staging goes away.
5. Theme drift from the split Burgundy path and legacy overrides.

Measure on real Android devices: UI and raster frame times during scrolling, Hero transitions, and keyboard opening; cover-decode memory; battery and heat with blur on versus opaque mode at the same brightness. Test eInk ghosting on eInk hardware.

## 9. Open decisions

- Quick capture outside the app: home-screen widget, notification action, photo of a page.
- PDF renderer for the A5 export (dependency choice).
- Whether Book detail keeps any 3D book model (P4 removes it from this route).
