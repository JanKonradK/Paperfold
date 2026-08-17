---
name: Paperfold
description: A living bookshelf with antique craft, warm paper, true-black nights, and modern glass Material 3 chrome.
colors:
  sage-green: "#98A086"
  dusty-rose: "#A76D5E"
  golden-tan: "#C4A071"
  warm-beige: "#DFCCB1"
  terracotta-brown: "#846044"
  paper: "#FAF6EE"
  paper-ink: "#3A2E28"
  paper-ink-soft: "#5C4A3F"
  paper-low: "#F3ECDF"
  paper-mid: "#EDE1D0"
  paper-high: "#E6D7C0"
  true-black: "#000000"
  true-black-low: "#050506"
  true-black-mid: "#0C0C0E"
  true-black-high: "#141417"
  true-black-highest: "#1C1C20"
  near-black: "#0E0E10"
  near-black-lowest: "#08080A"
  near-black-mid: "#1B1B1F"
  near-black-high: "#232327"
  near-black-highest: "#2C2C31"
  night-ink: "#EDE6DA"
  night-ink-soft: "#A39B90"
  walnut-board-light: "#B08A5E"
  walnut-edge-light: "#8A6A45"
  walnut-back-light: "#6B4F35"
  walnut-on-light: "#2A1F14"
  walnut-edge-dark: "#5A4028"
  walnut-back-dark: "#3E2C1C"
  cover-burgundy: "#4A1528"
  foil-gold: "#E7C77B"
typography:
  display:
    fontFamily: Philosopher
    fontWeight: 400
  headline:
    fontFamily: Philosopher
    fontWeight: 400
  title:
    fontFamily: Philosopher
    fontWeight: 400
  body:
    fontFamily: Philosopher
    fontWeight: 400
  label:
    fontFamily: SourceSans3
    fontWeight: 600
  spine-title:
    fontFamily: Philosopher
    fontWeight: 700
rounded:
  shelf-rail: "3dp"
  spine-top: "5dp"
  cover: "10dp"
  glass-panel: "12dp"
  round-control: "24dp"
  navigation-shell: "28dp"
spacing:
  hairline: "2dp"
  compact: "4dp"
  close: "6dp"
  touch-gap: "8dp"
  small: "10dp"
  content: "12dp"
  bookcase-side: "14dp"
  page-gutter: "16dp"
  shelf-top: "20dp"
  state: "24dp"
  shelf-board: "28dp"
  page-end: "32dp"
components:
  shelf-header:
    typography: "{typography.headline}"
    rounded: "{rounded.glass-panel}"
    padding: "6dp 8dp"
    height: "48dp minimum"
  shelf-count:
    backgroundColor: "{colors.warm-beige}"
    typography: "{typography.label}"
    rounded: "{rounded.glass-panel}"
    padding: "4dp 9dp"
  bookshelf-stage:
    height: "318dp"
  book-spine:
    typography: "{typography.spine-title}"
    padding: "18dp 7dp 16dp"
    width: "48-64dp"
    height: "220-280dp"
  navigation-shell:
    rounded: "{rounded.navigation-shell}"
    padding: "4dp"
    height: "56dp"
  navigation-tab:
    rounded: "{rounded.round-control}"
    padding: "6dp"
    height: "48dp"
  cover-tile:
    rounded: "{rounded.glass-panel}"
    padding: "4dp"
  book-model:
    typography: "{typography.title}"
    hardback-trim: "0.645"
    hardback-squares: "0.023"
    hardback-spine-round: "0.08"
    softback-trim: "0.680"
    softback-squares: "0"
    softback-spine-round: "0.06"
    shelf-zoom: "0.50"
    shelf-yaw: "1.30rad"
    cover-angle: "2.30rad"
    open-duration: "720ms"
    close-duration: "560ms"
---

# Design System: Paperfold

## Overview

**Creative North Star: "The Candlelit Bookcase"**

Paperfold is a modern interface around an antique library. The chrome is thin, quiet, and contemporary. The bookcase is the ornate object.

The home rejects a cover-grid first view. It also rejects an all-over vintage skin. A person opens the application onto a bookcase and selects a familiar spine.

The dark design keeps a candlelight atmosphere on a true-black ground. The default dark ground is black, not brown. Warm color comes from books, foil, plants, and furniture.

**Key Characteristics:**

- A five-shelf bookcase is the primary home artifact.
- Warm paper and near-neutral black form the page grounds.
- Saturated bookcloth and foil belong to books and furniture.
- Philosopher supplies the literary voice.
- Source Sans 3 supplies the modern chrome voice.
- Glass panels separate chrome from the antique object world.
- Material 3 supplies navigation, dialogs, sheets, menus, and Back behavior.
- All layouts support RTL, large text, and reduced motion.

**The Book-and-Chrome Rule.** The book can be expressive. Application chrome must keep Material 3 structure and behavior.

**The Candlelight-on-Black Rule.** Use candlelight as atmosphere. Do not use a brown dark-page ground.

## Colors

The frontmatter is the normative color source. Components use `ColorScheme` roles. Components do not embed theme-specific color values.

### Primary

- **Terracotta Brown** is the light-theme `primary` accent.
- **Golden Tan** is the dark-theme `primary` accent.
- The theme makes this change. A component only asks for `primary`.

### Secondary

- **Sage Green** is the `secondary` surface color in the brand scheme.
- Sage Green can also supply a deterministic bookcloth source.

### Tertiary

- **Golden Tan** is the light-theme `tertiary` color.
- **Warm Beige** is the dark-theme `tertiary` color.
- **Dusty Rose** supplies the dark `outlineVariant` role and a bookcloth source.

### Neutral

- **Paper**, **Paper Low**, **Paper Mid**, **Paper High**, and **Warm Beige** make the light surface ramp.
- **Paper Ink** supplies `onSurface`. **Paper Ink Soft** supplies `onSurfaceVariant` and `outline`.
- **True Black** is the default dark ground. Its surface ramp ends at **True Black Highest**.
- **Near Black** is the optional dark ground. Its separate ramp ends at **Near Black Highest**.
- **Night Ink** and **Night Ink Soft** supply the dark foreground roles.

### Furniture and cover colors

- The token set defines light and dark walnut colors for bookcase furniture.
- Current shelf bays request semantic surface-container roles from the active theme.
- **Cover Burgundy** is the main saturated cover and spine source.
- **Foil Gold** is for fine book detail. Do not use it as a page fill.

### Contrast

- Body text and glass foregrounds must have a minimum 4.5:1 contrast ratio.
- Large text and non-text controls must have a minimum 3:1 contrast ratio.
- The glass resolver tests its foreground against black and white backdrops.
- The glass tint has a minimum opacity of 0.76.
- A spine selects the best tested foreground from the scheme.
- If a spine fails 4.5:1, it uses the Paper and Paper Ink pair.

**The Surface-Palette Rule.** A surface color is not automatically a text color. Use the tested `on...` role.

**The One-Accent-Role Rule.** Use `primary`. Do not change accent colors inside a component.

## Typography

**Display Font:** Philosopher (with Flutter platform fallback)

**Body Font:** Philosopher (with Flutter platform fallback)

**Label Font:** Source Sans 3 (with Flutter platform fallback)

**CJK support:** Keep the system Chinese-font substitution and the bundled Source Han Serif assets.

**Character:** Philosopher makes the content literary without reducing body-text legibility. Source Sans 3 keeps controls and metadata plain and direct.

### Hierarchy

- **Display** (Philosopher, weight 400, italic, Material display role): Use for rare page-scale statements.
- **Headline** (Philosopher, weight 400, italic, Material headline role): Use for page and shelf headings.
- **Title** (Philosopher, weight 400, upright, Material title role): Use for book titles and content headings.
- **Body** (Philosopher, weight 400, upright, Material body role): Use for journal and explanatory text.
- **Label** (Source Sans 3, weight 600, upright, Material label role): Use for navigation, controls, counts, menus, and metadata.
- **Spine title** (Philosopher, weight 700, Material title role): Use for the rotated book title. Use label-small for the author.

The Material 3 type scale supplies font size, line height, and letter spacing. The Paperfold theme changes family, style, and weight only.

All text follows the system text scale. Shelf headings allow two lines. Spine titles keep one rotated line and a full semantic label.

A spine shows the author only when its width is at least 56dp. It also hides the author when scaled label text exceeds 24sp.

Spine text has an effective minimum size of 11sp. It does not reduce the system text scale.

**The Roles-Not-Sizes Rule.** Select a Material text role. Do not make a new local text size.

## Layout

The home contains five continuous shelf sections in this order:

1. Reading now
2. All time favourites
3. To be read
4. Finished
5. Books to buy

To be read records reading intent. Books to buy records purchase intent. Do not combine these shelves.

The shelf list uses a 12dp directional gutter, an 8dp top inset, and a 32dp end inset. Adjacent sections have no gap.

Each section has 16dp inner side padding. The first section has 20dp top padding. The 48dp-minimum header has a 6dp gap before the shelf stage.

The shelf stage is 318dp high. The painter uses 14dp side panels, a 20dp top rail, and a 28dp shelf board. The front lip is 8dp high.

Spines scroll horizontally and stay on the shelf board. Separate spine targets have an 8dp gap.

The collection uses a responsive grid. Its maximum item width is 190dp and its item height is 310dp. The cross-axis gap is 16dp. The main-axis gap is 24dp.

The collection page uses 16dp horizontal padding, 12dp top padding, and 32dp bottom padding.

### Navigation and width changes

- At widths of 600dp or less, use the 56dp glass navigation shell.
- The navigation order is Journal, Library, More.
- Library is the initial destination.
- Above 600dp, use a Material navigation rail.
- Above 1000dp, extend the navigation rail.
- Keep all destinations in an indexed stack.
- Keep destination history for system and predictive Back.

### Touch, insets, and RTL

- Each control has a minimum 48 x 48dp target.
- Separate targets have a minimum 8dp gap.
- Apply safe-area, system-gesture, cutout, and keyboard insets.
- Use directional padding and position values.
- In RTL, turn an upright spine title one quarter-turn clockwise.
- In LTR, turn an upright spine title three quarter-turns clockwise.
- Reverse lean and asymmetric bookends in RTL.

**The 48-and-8 Rule.** A target is at least 48dp. Separate targets stay at least 8dp apart.

**The Shelf-First Rule.** The bookshelf is the home. The cover grid is a shelf detail view.

## Elevation & Depth

The system has no custom shadow scale. The bookcase uses drawn geometry, tonal layers, and fine rules for depth.

Glass supplies depth for modern chrome. Shelf headers use a blur sigma of 10. The compact navigation shell uses a blur sigma of 18.

Each glass panel has a one-physical-pixel edge. High-contrast mode and reduced-motion mode use the opaque surface tint and no backdrop blur.

Book spines use edge highlights, cloth grain, bands, foil rules, and optional raised hubs. These details create depth without a drop shadow.

Material controls, menus, sheets, and dialogs can use standard Material elevation.

**The Tonal-First Rule.** Use surface levels and drawn edges before you add a shadow.

**The Bounded-Glass Rule.** Clip each blur to one small chrome surface. Do not blur the complete screen.

## Shapes

The system combines grounded books with softly rounded modern chrome.

- An upright spine is square or has only 5dp top corners.
- A horizontal spine and a shelf rail use a 3dp radius.
- Cover art uses a 10dp radius.
- Shelf headers, count badges, wishlist covers, and cover-tile targets use a 12dp radius.
- Tabs and 48dp controls use a 24dp radius.
- The compact navigation shell uses a 28dp radius.

Ornaments are transparent, single-color SVG assets. The shared component applies a semantic tint through `srcIn`.

The ornament set contains an oval floral frame, a rectangular vine frame, a corner spray, a circular wreath, a bow, and an icon wreath. It also contains a plant, a bookend, and a small urn.

Decorative ornaments are excluded from semantics. Add a semantic label only when the ornament gives information.

**The Grounded-Spine Rule.** Round the top of a spine. Keep the bottom flush with the shelf.

**The Single-Tint Rule.** Apply one semantic color to each ornament. Do not put a background into the SVG asset.

## Components

### Bookshelf section

A shelf section contains one glass header and one bookcase bay. The five bays join to make one piece of furniture.

The header is one semantic button. It combines the shelf name, count, and directional chevron in its semantic label.

The header has a 12dp radius and a blur sigma of 10. Its internal padding is 8dp horizontally and 6dp vertically.

The count uses `primaryContainer`, `onPrimaryContainer`, a 12dp radius, and 9dp by 4dp padding.

### Book spine

- Derive each visual from a stable identifier.
- Keep upright width from 48dp through 64dp.
- Keep upright height from 220dp through 280dp.
- Keep the upright height from four through six times its width.
- Make a horizontal spine 112dp through 148dp wide.
- Make a horizontal spine 48dp through 56dp high.
- Use the stable identifier for color, grain, bands, corners, foil, hubs, and lean.
- Keep title and author contrast at 4.5:1 or more.
- Keep the full title and author in the semantic label and tooltip.

### The book model

A book is drawn as a solid object, not as a cover with a strip beside it. The model has a front board, a spine, a back board, three cut paper edges, and the inside face of each board. The renderer sorts each face by depth, hides each face that turns away, and lights all faces from one direction.

One book unit is the height of the paper block. All proportions are fractions of that unit, so the object is correct at any size.

Two bindings are available. The binding changes the shape, not only the color.

| Part | Hardback | Softback |
|---|---|---|
| Boards | Stand proud of the paper on three edges | Trimmed flush with the paper |
| Spine | Rounded, with a groove at each joint | Flat, with a score line at each joint |
| Head and tail | Silk headbands | None |
| Inside board | Endpaper, with the cover material turned in | The back of the printed card |
| Surface | Cloth grain | Laminate highlight |
| Back board | Plain cloth, with a blind-stamped rule | The blurb, a device, and a barcode |

The application selects the binding from the book metadata. Manga, comics and light novels get the softback. A book first published in 1960 or later gets the softback. A book first published before 1960, or a public-domain transcription, gets the hardback. A stated format in the metadata has priority over the date.

The book detail page shows the reason for the binding. The reader can set Automatic, Hardback or Softback for each book. The Appearance settings set the default binding for a book that gives no signal.

Cover art wraps around the object. A front-only cover supplies the front board, a spine strip taken from the hinge edge, and a back cloth taken from the far edge. A wrap-around jacket supplies the back, the spine and the front directly. Printed matter on artwork keeps a minimum 4.5:1 contrast ratio.

A book with no artwork prints its own cover: a field, a frame, the title and the author.

The object is closed at all angles. The paper block is a box of six faces, and its sixth face is the bound edge at the spine. Each board has four edges, and the fourth edge is at the joint. The spine facets are two-sided.

A rounded spine turns away from the reader like a cylinder. If the model removes the facets that turn away, and the object is open behind them, the reader sees through the book. A closed object cannot do this at any angle.

Each face fills a small area outside its own edge in its own color. Two faces that touch are drawn separately, and antialiasing shows the background between them. The fill covers this line.

The sheets of the block are sorted by their position at the spine, not by the nearest corner. The distance across a sheet is much larger than the distance between two sheets. If the model sorts by a point on the sheet, a wide sheet goes behind a narrow sheet, and a turning page becomes invisible.

The bound edge of the block obeys the same rule. It is one tall face that runs the full thickness of the book, so on the nearest-corner rule it reaches nearer the camera than any single facet of the covering that wraps it, and the paper is drawn over the spine. Facets of a curve keep the nearest-corner rule; the long flat faces they meet are anchored.

The default camera shows the front cover. `BookCamera.threeQuarter` (yaw 0.92, pitch -0.40) is the mid-turn angle. The shelf stands its books at `ShelfStage.camera` (yaw 1.30, pitch -0.16, focal length 11), which is the angle almost every book in the application is seen at. The model must be correct through the full turn, from yaw -0.4 to yaw 3.5.

**The Solid-Object Rule.** Add a new surface as a face in book space. Do not paste a picture on top of the object.

**The Closed-Solid Rule.** Give each part all of its faces. A part with a missing face shows a hole at some angle.

### The opening

A tap or a horizontal drag opens the book. The front board turns on its joint. The first four leaves follow the board, each one less far than the leaf above it, and each leaf bends along its length. The board throws a shadow on the open page.

The leaves are the top sheets of the block. The printed first page is below all of them, and the leaves uncover it as they lift. After the board passes square it no longer holds the leaves, and they fall back on the block.

The cover opens for 720ms and closes for 560ms. The cover goes a little past its rest angle and returns. On closing, the cover lands, lifts a little, and settles.

A long press turns the book over, so the back board comes round to the reader. The turn takes 620ms. The long press has a screen-reader hint.

When the system removes animations, the book opens, closes and turns in one frame.

**The Paper-Bends Rule.** A board is rigid. A leaf is not. Build a leaf from panels that lie flatter toward the fore-edge.

### Compact navigation

The glass shell is 56dp high. It uses a 28dp radius, 12dp side margins, 4dp internal padding, and 8dp gaps.

Each tab is 48dp high. The selected indicator uses `primaryContainer` and a 24dp radius.

The indicator moves for 240ms with `easeOutCubic`. It moves instantly when the system removes animations.

Selected labels use weight 700. Unselected labels use weight 600. Icons are 18dp.

### Collection tile

A book tile uses the cover, a two-line title, and an optional one-line author. A tap opens the reader. A long press or secondary tap opens book options.

A wishlist tile uses its deterministic bookcloth color. It puts a rectangular vine frame around a centered title.

### Ornaments and shelf objects

The default ornament tint is `primary`. Empty and loading shelves use `outlineVariant`.

Shelf objects are sparse and deterministic. A plant is 58 x 94dp. A bookend is 38 x 82dp. An urn is 46 x 66dp.

Keep these objects outside book hit areas. Reverse the directional bookends in RTL.

### The mark, the application icon, and the launch window

The Paperfold mark is the wreath ornament with the initials `HJ` in its inner ring. It is one tint, like every other ornament. `PaperfoldLogoMark` draws it, and it takes `primary` unless the caller gives a tint.

The name goes under the initials on the application icon only. It measures less than six percent of the mark, so below 160 dp the mark drops it. A smear is worse than no name.

The initials sit on their cap height, not on their line box, and the initials and the name center as one block. Letters that center on the line box look low inside the wreath.

The application icon is Foil Gold on Cover Burgundy. It does not read the theme, because a launcher shows one icon.

| Shape | Ground | Use |
|---|---|---|
| Card | Cover Burgundy | The legacy icon, and the master for all other platforms |
| Adaptive foreground | None | Android adaptive icon. The packager insets it by 16 percent |
| Monochrome | None | Android themed icon. The launcher supplies the color |

The icon is a widget, not stored artwork. `tool/generate_app_icons.dart` writes the three master files, and flutter_launcher_icons cuts each platform from them. Do not edit the master files.

The launch window is the page ground: Paper in light, True Black in dark. It shows no artwork, because the launcher already animates the icon and the opening sequence follows immediately.

### The trackers

The reading challenge and the month tracker are painted, not laid out. One canvas holds every spine and every day segment.

A painted control has no widgets, so it supplies its own semantics. Each spine and each day is a node, not one summary label for the whole shape. A painted control with no semantics is unusable.

The challenge shelf grows with the system text size, because its numbers are painted into the spines and cannot grow alone.

| Slot state | Paint |
|---|---|
| Read | The book's own bookcloth, with a `primary` outline |
| Reading | `secondary` at 55 percent, with a `secondary` outline |
| Want to read | An `outlineVariant` outline only |

The month ring keys on pages, not on minutes. The statistics page already draws minutes. A day that was read is never drawn as nothing, or a light day beside a heavy one disappears.

Both trackers open from the Journal destination. They are not destinations themselves.

### Empty, loading, error, and drag states

- An empty shelf keeps the complete 318dp bay.
- The standard empty-shelf wreath is 58dp. It can reduce to 28dp at large text when an action is present.
- Loading shows all five shelves at their final size. Each shelf has a 50dp wreath and no shimmer.
- A shelf error uses a 104dp wreath and a block no wider than 420dp.
- An empty collection uses a 112dp wreath.
- Journal and More placeholders use a 128dp ornament and a block no wider than 440dp.
- Desktop file drag uses a 92-percent opaque surface and a 48dp download icon.

### Motion

The bookshelf has no ambient animation. Material ink, routes, sheets, and refresh behavior supply direct feedback.

The cold-start cover is the one theatrical sequence. Its duration is 1150ms. The user can skip it from the first frame.

The book model on the book detail page opens only when the reader taps or drags it. It has no ambient motion.

When the system removes animations, finish the opening immediately. Replace page curl with the implemented cross-fade path.

**The Skippable-Delight Rule.** A signature animation must be optional, interruptible, direction-aware, and absent when the system removes animations.

## Do's and Don'ts

### Do:

- **Do** make books and journal entries the visual subject.
- **Do** keep modern glass chrome separate from the antique bookcase.
- **Do** use Material semantic color and type roles.
- **Do** use true black as the default dark ground.
- **Do** reserve warm saturated fields for books, foil, plants, and furniture.
- **Do** keep 48dp targets, 8dp target gaps, safe areas, system Back, RTL, large text, and reduced motion.
- **Do** localize visible text and semantic labels.
- **Do** keep ornaments replaceable and outside essential semantics.

### Don't:

- **Don't** replace the home bookcase with a cover grid.
- **Don't** use a warm-brown dark-page ground.
- **Don't** apply an all-over vintage skin to Material chrome.
- **Don't** change light and dark accents inside a widget.
- **Don't** use a surface color as body text without a contrast test.
- **Don't** use Cover Burgundy or Foil Gold as a broad page fill.
- **Don't** add arbitrary shadows, full-screen blur, shimmer, or ambient shelf motion.
- **Don't** hide full book information inside clipped spine text.
- **Don't** ship a fixed-direction spine, chevron, bookend, page, or curl.
- **Don't** add an unskippable opening sequence.
