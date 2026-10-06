---
name: Paperfold
description: Burgundy app surfaces, gold details, independent reader themes.
colors:
  cover: "#350D18"
  dark-sienna: "#391214"
  foil: "#B7A179"
  paper: "#F6F2EA"
  ink: "#160F0C"
  secondary-ink: "#52423D"
  stone: "#887D77"
  rose: "#8B625F"
  dove: "#C0BAB3"
  cloth-paper: "#E7DFD0"
typography:
  headline:
    fontFamily: Philosopher
    fontWeight: 400
    lineHeight: 1.2
  body:
    fontFamily: SourceSans3
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
---

# Paperfold design

## Overview

The default app theme uses burgundy surfaces and gold controls in all sections.
Journal uses plain surfaces with no paper texture or dot grid.
The reader keeps its separate page theme.

Version 2.0 keeps upright spines as the default library view.
The saved Covers view shows the same library as a cover grid.
Book bands, small foil marks, and matching series bindings give each shelf its book form.

This file records the current design.
See [README.md](../README.md) for product functions and [Paperfold 2.0](paperfold-2.0.md) for release checks and measurements.

## Colors

`lib/config/paperfold_tokens.dart` defines the palette.
The frontmatter gives the color values.
The current bindings use all five supplied reference colors:

| Reference color | Token | Use |
| --- | --- | --- |
| Soft Dove | `dove` | Bindings and secondary text on dark surfaces |
| Spiced Hot Chocolate | `secondary-ink` | Bindings and raised app surfaces |
| Moon Rock | `stone` | Bindings and outlines |
| Dark Sienna | `dark-sienna` | Bindings and the Continue reading surface |
| Black Raspberry | `ink` | Bindings, dark surfaces, and text on light surfaces |

The bindings also use cover burgundy, foil gold, and cloth paper.
Spines and replacement covers use this binding palette.
The text color has at least 4.5:1 contrast against its binding.
Spine text uses gold only when this contrast is sufficient.

Keep saved reader themes, custom theme colors, the two dark modes, and eInk mode.
An explicit dark, custom, or eInk theme keeps its selected surfaces.

## Typography

Philosopher supplies headings, large titles, quotations, and spine titles.
SourceSans3 supplies body text, controls, and labels.
Body line height is 1.4 through 1.5.
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

Journal contains Reading challenge, Month tracker, Highlights, and book journals.
Journal forms and online catalog pages have a maximum width of 760 logical pixels.
Online headings and descriptions wrap as text size increases.

## Elevation & Depth

Spines stay flat and upright.
A shallow crease and thin edge lines show the binding.
Small shadows separate the shelf board and book covers from the background.
Raised app surfaces use the existing burgundy and brown colors.

## Shapes

Spines have small rounded top corners (2 logical pixels).
Grid covers and selected covers have rounded corners of the same size.
The standard Continue reading banner uses a larger radius (12 logical pixels).
Chips and buttons use the existing Material component shapes.

## Components

### Book view and selection

The Book view menu has Spines and Covers.
Its icon shows the saved view, and a check mark identifies that view in the menu.
The application saves the selection for the next session.
The two views use the same shelves, filters, reading positions, and book actions.

Select a spine, cover, or list row to show the book cover, progress, and actions.
The actions open the book, details, shelf controls, binding controls, or journal.
The book details can scroll when their contents need more than the available height.
At widths of at least 700 logical pixels, the cover and details are beside each other.

Keyboard arrows move the selection through the current view.
Escape, the Back control, and the system back gesture return the selected book to the shelf.
The return keeps the scroll position and restores keyboard focus to the book.
Reduced motion removes shelf animation.

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

Asset provenance: the user supplied `assets/images/paperfold_cover.jpg` and `assets/images/paperfold_paper.jpg` on 2026-09-17. Built-in Imagegen produced `assets/images/paperfold_wordmark.png` with this prompt:

> Extract ONLY the existing gold lowercase wordmark paperfold from the center of the supplied cover as a tightly framed wide transparent PNG for an app header. Preserve distinctive curled letterforms, spelling, proportions and muted gold; remove burgundy background to alpha; no extra text, ornament or shadow.

## Do's and Don'ts

- Keep the burgundy and gold identity and all five reference colors.
- Keep upright spines as the initial view.
- Use the same book data and actions in each library view.
- Keep horizontal titles in the large-text list.
- Keep visible focus, screen reader labels, and the reduced-motion option.
- Keep direct catalogs separate from external services.
- Do not use an image failure to remove a book's title.
- Do not replace the reader's selected page theme with the app theme.
