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
typography:
  headline:
    fontFamily: Philosopher
    fontWeight: 400
    lineHeight: 1.2
  body:
    fontFamily: SourceSans3
---

# Paperfold design

## Overview

The default app theme uses burgundy surfaces and gold controls in all sections.
Journal uses plain surfaces with no paper texture or dot grid.
The user requested this change on 2026-10-06.
The reader keeps its separate page theme.

## Colors

`lib/config/paperfold_tokens.dart` defines the palette. Stone, rose, gold, dove, and brown distinguish bindings.
Keep saved reader themes, custom theme colors, both dark modes, and eInk mode.
The burgundy theme does not replace an explicit dark, custom, or eInk theme.

## Typography

Philosopher supplies headings, large titles, quotations, and spine titles. SourceSans3 supplies body text, controls, and labels.
Spine titles use 14 logical pixels, with smaller author credits and a separate volume number. Body line height ranges from 1.4 to 1.5.

## Layout

Shelf choices remain visible above straight shelves. Upright spines scroll horizontally. Navigation stays below the content or uses a rail above 600 logical pixels.
The destinations are Journal, Library, Statistics, and Settings. Library opens first.
On narrow screens with large text, the navigation uses two rows to keep each label readable.
Journal contains Reading challenge, Month tracker, Highlights, and book journals.
Journal forms use a maximum width of 760 logical pixels.
When text scales from 16 to at least 24 logical pixels, or shelf height is below 280, a vertical list shows horizontal titles.
Books in a series share a height and binding color. Spine width follows the EPUB print page count, or a text-length estimate when print pages are absent. Unknown lengths use a neutral width. Metadata loads in the background and does not delay the library.

## Elevation & Depth

Flat spines replace angled shelves. Small shadows separate the shelf board and selected cover.

## Components

Select a spine to show its cover, progress, and actions. Open the book or return to the shelf. Keyboard arrows change selection. Escape returns the book.
Reduced motion removes shelf animation. The opening uses the supplied cover and paper images.

Asset provenance: the user supplied `assets/images/paperfold_cover.jpg` and `assets/images/paperfold_paper.jpg` on 2026-09-17. Built-in Imagegen produced `assets/images/paperfold_wordmark.png` with this prompt:

> Extract ONLY the existing gold lowercase wordmark paperfold from the center of the supplied cover as a tightly framed wide transparent PNG for an app header. Preserve distinctive curled letterforms, spelling, proportions and muted gold; remove burgundy background to alpha; no extra text, ornament or shadow.
