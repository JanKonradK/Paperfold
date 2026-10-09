---
name: Paperfold
description: Cream, Burgundy, and Dark app surfaces with independent reader themes.
colors:
  cover: "#350D18"
  dark-sienna: "#391214"
  foil: "#B7A179"
  cream: "#F3EBDD"
  cream-low: "#EDE2D1"
  burgundy: "#3D1723"
  burgundy-low: "#46202A"
  burgundy-gold: "#C8B28F"
  dark-low: "#211714"
  true-black: "#000000"
  true-black-low: "#0C0908"
  paper: "#F6F2EA"
  ink: "#160F0C"
  secondary-ink: "#52423D"
  stone: "#887D77"
  rose: "#8B625F"
  dove: "#C0BAB3"
  binding-rose: "#78434B"
  binding-burgundy: "#5A2636"
  binding-cream: "#E8D8BC"
  binding-tan: "#AD8C66"
  binding-dusty-rose: "#B89B91"
typography:
  headline:
    fontFamily: Philosopher
    fontWeight: 400
    lineHeight: 1.2
  body:
    fontFamily: SourceSans3
    lineHeight: 1.45
    letterSpacing: "0px"
  body-large:
    fontFamily: SourceSans3
    lineHeight: 1.5
    letterSpacing: "0px"
  body-small:
    fontFamily: SourceSans3
    lineHeight: 1.4
    letterSpacing: "0px"
  title-small:
    fontFamily: SourceSans3
    fontWeight: 600
    letterSpacing: "0px"
  label:
    fontFamily: SourceSans3
    fontWeight: 600
    letterSpacing: "0.1px"
  spine-title:
    fontFamily: Philosopher
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.1
  spine-title-wide:
    fontFamily: Philosopher
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.1
  spine-author:
    fontFamily: SourceSans3
    fontSize: "10px"
    lineHeight: 1.1
    letterSpacing: "0.25px"
rounded:
  book: "2px"
  action: "12px"
  surface: "16px"
  sheet-top: "20px"
  navigation-selection: "24px"
  navigation: "28px"
spacing:
  small: "8px"
  control: "12px"
  medium: "16px"
  cover-gap: "20px"
  large: "24px"
  wide-summary-gap: "32px"
components:
  read-cream:
    backgroundColor: "{colors.dark-sienna}"
    textColor: "{colors.cream}"
    typography: "{typography.label}"
    rounded: "{rounded.action}"
    padding: "16px 24px"
  read-burgundy:
    backgroundColor: "{colors.burgundy-gold}"
    textColor: "{colors.burgundy}"
    typography: "{typography.label}"
    rounded: "{rounded.action}"
    padding: "16px 24px"
  read-dark:
    backgroundColor: "{colors.foil}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.action}"
    padding: "16px 24px"
  book-action:
    typography: "{typography.label}"
    rounded: "{rounded.action}"
    padding: "12px"
  card-cream:
    backgroundColor: "{colors.cream-low}"
    textColor: "{colors.ink}"
    rounded: "{rounded.surface}"
  card-burgundy:
    backgroundColor: "{colors.burgundy-low}"
    textColor: "{colors.cream}"
    rounded: "{rounded.surface}"
  card-dark-near-black:
    backgroundColor: "{colors.dark-low}"
    textColor: "{colors.paper}"
    rounded: "{rounded.surface}"
  card-dark-true-black:
    backgroundColor: "{colors.true-black-low}"
    textColor: "{colors.paper}"
    rounded: "{rounded.surface}"
---

# Paperfold design

## Overview

**Creative North Star: "A personal library"**

Flat book spines stand on straight shelves.
Bookcloth colors, cream paper, and gold details connect the library to the supplied identity assets.
The app offers Cream, Burgundy, Dark, and System.
The selected app mode applies to Library, Journal, Statistics, Settings, and their controls.
Burgundy is the initial mode when a new installation uses the brand theme.
Journal uses plain surfaces with no paper texture or dot grid.
The reader keeps its separate page theme.

Upright spines remain the initial library view.
The saved Covers view shows the same library as a cover grid.
Book bands, small foil marks, and matching series bindings give each shelf its book form.

This file records the current design.
See [README.md](../README.md) for product functions and [Paperfold 2.1](paperfold-2.1.md) for release changes and checks.
The [design sidecar](paperfold-design.json) records depth, motion, breakpoints, and component samples.
The final previews are local build outputs in `tool/preview/`:

- Cream: `v210-final-light.png`.
- Burgundy: `v210-final-burgundy.png`.
- Dark: `v210-final-dark.png`.
- Large text and Arabic layouts: `v210-final-accessibility.png`.
- Theme choices: `v210-final-choices.png`.

These local build outputs are outside version control.

**Key Characteristics:**

- Flat books and straight shelves.
- Three app palettes with the same control roles.
- Full book details and visible action labels.
- A separate reader theme.

## Colors

[paperfold_tokens.dart](../lib/config/paperfold_tokens.dart) defines the palette.
The frontmatter gives the color values.

### Primary

The primary color identifies actions and progress.
Cream uses Dark Sienna, Burgundy uses `burgundy-gold`, and Dark uses foil gold.
The Read control uses the primary color as its background and the matching `onPrimary` color for its text.

### Secondary

Soft Dove supplies secondary containers and selected shelf chips.
Spiced Hot Chocolate supplies secondary text in Cream and the highest Burgundy surface.
Foil gold remains the identity color for the cover and wordmark.

### Neutral

| App mode | Ground | Primary text | Secondary text | Low container |
| --- | --- | --- | --- | --- |
| Cream | `cream` | `ink` | `secondary-ink` | `cream-low` |
| Burgundy | `burgundy` | `cream` | `dove` | `burgundy-low` |
| Dark, true black off | `ink` | `paper` | `dove` | `dark-low` |
| Dark, true black on | `true-black` | `paper` | `dove` | `true-black-low` |

System selects the light or dark palette from the device appearance.
Dark retains the true-black option, which is on for a new installation.
Each app palette has separate container levels for cards, menus, controls, and messages.
The sidecar records the existing container colors from the token source.

### Bindings

The current bindings use all five supplied reference colors:

| Reference color | Token | Use |
| --- | --- | --- |
| Soft Dove | `dove` | Bindings and secondary text on dark surfaces |
| Spiced Hot Chocolate | `secondary-ink` | Bindings and raised app surfaces |
| Moon Rock | `stone` | Bindings and outlines |
| Dark Sienna | `dark-sienna` | Bindings and primary controls in Cream |
| Black Raspberry | `ink` | Bindings, dark surfaces, and text on light surfaces |

The five additional bindings use these tokens:

| Binding color | Token |
| --- | --- |
| Muted rose | `binding-rose` |
| Deep burgundy | `binding-burgundy` |
| Cream cloth | `binding-cream` |
| Tan cloth | `binding-tan` |
| Dusty rose | `binding-dusty-rose` |

Spines and replacement covers use this binding palette.
The binding color stays the same when the app mode changes.
The text color has at least 4.5:1 contrast against its binding.
Spine text uses gold only when this contrast is sufficient.

Keep saved reader themes, custom theme colors, the two dark modes, and eInk mode.
The eInk mode uses its separate black-and-white scheme.
The custom theme keeps its selected seed color and surfaces.

**The Theme Choice Rule.** Each app route uses the selected app mode.

**The Binding Contrast Rule.** Binding text keeps at least 4.5:1 contrast against its cloth color.

## Typography

Philosopher supplies headings, large titles, quotations, and spine titles.
SourceSans3 supplies body text, controls, and labels.
Display text, headlines, and large titles use Philosopher at weight 400 and line height 1.2.
Medium and small titles use SourceSans3 at weight 600.
Body line heights are 1.5 for large text, 1.45 for medium text, and 1.4 for small text.
Labels use weight 600 and letter spacing of 0.1 logical pixels.
The app uses the existing system font fallback for Chinese text.
The native text theme supplies sizes that the app does not override.
The size values in this document use Flutter logical pixels, except image decode widths.

Spines use `spine-title` by default.
A spine at least 68 logical pixels wide uses `spine-title-wide`.
Author credits use `spine-author` when the spine has sufficient space.
Short spines do not show the author credit.
Titles use one or two lines and an ellipsis when necessary.
A separate volume number uses 16 or 20 logical pixels, according to the spine height.

Cover tiles show a title below the cover, with a maximum of two lines.
The author uses one line below the title.
The large-text list lets titles and authors wrap horizontally.
The selected book shows the full title without a line limit.
Its author and reading progress remain separate from its action labels.

**The Text Space Rule.** Large text changes the layout before it removes book information or action labels.

## Layout

The destinations are Journal, Library, Statistics, and Settings.
Library opens first.
Navigation stays below the content or uses a rail above 600 logical pixels.
On narrow screens with large text, the navigation uses two rows to keep each label readable.

Shelf chips stay above the books and scroll horizontally.
The current shelf name is beside the Book view, sort, and filter controls.
Upright spines scroll horizontally on a straight shelf board.
Vertical gestures change shelves in the spine view.

The cover grid scrolls vertically within the current shelf.
Shelf chips change the shelf in this view.
The grid uses two to eight columns, with 20 logical pixels between tiles.
The grid has side margins of 24 logical pixels.
It creates nearby tiles as the user scrolls.

When 16 logical pixels scale to at least 24, a vertical list replaces the spines or grid.
The same list applies when the shelf area has less than 280 logical pixels of height.
Each row has a small binding mark beside horizontal text.
The header can scroll within half the available library height.

The selected book uses a compact cover beside its title, author, and progress.
The cover width is 100 through 144 logical pixels on a standard narrow screen.
With large text on a narrow screen, the cover width is 96 logical pixels and the details move below it.
At widths of at least 700 logical pixels, the cover width is 190 and the details use the adjacent column.
The summary has a maximum width of 760 logical pixels.
The details scroll above a fixed Read control.

The four book actions use two columns with 12 logical pixels between controls.
With large text or an action area below 280 logical pixels, the actions use one column.
The theme selector becomes vertical below 300 logical pixels or when scaled text exceeds 21 logical pixels from a base of 16.

Journal contains Reading challenge, Month tracker, Highlights, and book journals.
Journal forms and online catalog pages have a maximum width of 760 logical pixels.
Online headings and descriptions wrap as text size increases.

## Elevation & Depth

Spines stay flat and upright.
A shallow crease and thin edge lines show the binding.
Small shadows separate the shelf board and book covers from the background.
App containers use the selected palette's surface levels.
Cards and app bars have no elevation or surface tint.
Navigation uses an opaque low container with a thin edge and no backdrop blur.

The shelf board shadow uses a downward offset (6 logical pixels) and blur radius (9 logical pixels).
The cover shadow uses a downward offset (8 logical pixels) and blur radius (16 logical pixels).
Both shadows use the theme shadow color at alpha 0.22.

Shelf transitions use 180 through 220 milliseconds.
The navigation indicator uses 240 milliseconds.
Reduced motion removes these transitions.

## Shapes

Spines have small rounded top corners (2 logical pixels).
Grid covers and selected covers have rounded corners of the same size.
Book actions, the Read control, and the standard Continue reading banner use rounded corners (12 logical pixels).
Cards, dialogs, and popup menus use rounded corners (16 logical pixels).
Bottom sheets have rounded top corners (20 logical pixels).
Bottom navigation uses a larger outer radius (28 logical pixels) and selection radius (24 logical pixels).
Other chips and buttons use the existing Material component shapes.

## Components

### Book view and selection

The Book view menu has Spines and Covers.
Its icon shows the saved view, and a check mark identifies that view in the menu.
The application saves the selection for the next session.
The two views use the same shelves, filters, reading positions, and book actions.

Select a spine, cover, or list row to show the compact cover, full title, author, progress, and actions.
Journal, Details, Shelves, and Customise use outlined buttons with visible labels and icons.
Each button has a minimum height of 56 logical pixels.
The book details can scroll when their contents need more than the available height.
The filled Read control stays below the scroll area.
Its label becomes Continue reading for an unfinished book with saved progress.
Wishlist books use Books to buy and omit reading progress.
The Read control has a minimum height of 56 logical pixels and padding of 16 vertically and 24 horizontally.

Keyboard arrows move the selection through the current view.
Escape, the Back control, and the system back gesture return the selected book to the shelf.
The return keeps the scroll position and restores keyboard focus to the book.
Reduced motion removes shelf animation.

### App controls and containers

The Appearance control offers Cream, Burgundy, and Dark as three segments.
The System chip is a separate automatic choice.
The selected segment or chip shows its state.
The eInk option disables these app-mode controls.

Shelf chips show the current shelf through their selected state.
Buttons keep the native hover, focus, pressed, and disabled states.
Fields keep the native Material input style and visible labels.
Service forms use outlined fields.
Cards and menus use the selected palette's low container color.
Dialogs and sheets use the selected ground color.

Bottom navigation shows an icon and label for each destination.
The selected destination uses the primary container color.
The navigation rail retains the same destinations on wide screens.

### Bindings

Books in a series share a height and binding color.
Spine width uses the EPUB print page count or a text-length estimate when print pages are missing.
Spine widths are 48 through 104 logical pixels.
An unknown book length uses 60 logical pixels.
The library can show books before the metadata load completes.

Each binding uses a stable band pattern and small diamond foil marks.
Hardbacks use double bands.
Compact spines remove some marks to keep sufficient space for the title.

### Continue reading

Continue reading opens the most recent eligible book at its saved reading position.
The standard banner shows the cover, title, progress, and an arrow.
Large text or an available library height below 480 logical pixels uses a compact outlined button.
Its screen reader label keeps the book title, author, and progress.

### Cover images

The image loader shows a replacement cover until the first image frame is available.
It also shows the replacement if the image is missing or damaged.
Library covers use the binding color, a vine frame, and the book title as the replacement.
The shared thumbnail component uses the saved title and author display settings.
After a library refresh, the loader retries a failed image at the same file path.

The decode width uses the display width multiplied by the device pixel ratio.
The loader rounds this value upward and limits it to 96 through 1,200 image pixels.
An unbounded layout uses 400 logical pixels before this calculation.
This rule limits the decoded image size.
These values do not measure startup time, frame rate, or total process memory.

### Online books

Add books has device import and Find books online.
The online hub has two sections with different controls:

| Section | Sources | Control |
| --- | --- | --- |
| Read in Paperfold | Project Gutenberg, Ebooks libres et gratuits | Book icon and a chevron open an OPDS catalog |
| Explore on the web | Standard Ebooks, Global Grey, Open Library, Libby | Globe and external-link icons open the browser |

Saved custom catalogs stay in the direct catalog section.
Add a catalog accepts the catalog address and optional credentials.
The form keeps entered values after a save failure.

Download controls offer the supported formats, cancellation during download, and retry after a failure.
Catalog errors show a message and a Retry control.
Loans and protected books stay in their own services.
Purchase and loan links do not start a file import.

### Identity assets

The user supplied `assets/images/paperfold_cover.jpg` and `assets/images/paperfold_paper.jpg` on 2026-09-17.
Built-in Imagegen produced `assets/images/paperfold_wordmark.png` with this prompt:

> Extract ONLY the existing gold lowercase wordmark paperfold from the center of the supplied cover as a tightly framed wide transparent PNG for an app header. Preserve distinctive curled letterforms, spelling, proportions and muted gold; remove burgundy background to alpha; no extra text, ornament or shadow.

## Do's and Don'ts

### Do:

- **Do** use the selected app palette for each route and its controls.
- **Do** keep the cover and wordmark identity colors separate from the app ground.
- **Do** keep all five reference colors and the five additional binding colors.
- **Do** keep upright spines as the initial view.
- **Do** use the same book data and actions in each library view.
- **Do** keep horizontal titles in the large-text list.
- **Do** keep the full selected title and all four visible action labels.
- **Do** keep the Read control below the details scroll area.
- **Do** keep visible focus, screen reader labels, and the reduced-motion option.
- **Do** keep direct catalogs separate from external services.

### Do not:

- **Do not** apply Burgundy surfaces after the user selects another app mode.
- **Do not** show reading progress for a wishlist book.
- **Do not** use an image failure to remove a book's title.
- **Do not** replace the reader's selected page theme with the app theme.
