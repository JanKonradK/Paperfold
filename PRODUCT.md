# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

Android phones come first. Tablets, iOS, and desktop adapt from the phone design.
iOS still gets its OS guarantees: safe areas, Reduce Motion, and edge-swipe Back.

## Users

People who read a lot and want one quiet place for their reading life.
They read e-books in the app and printed books away from it.
They come back many times a day for short visits (log a page, save a quote, continue a book)
and stay for long evening sessions in the reader.

## Product Purpose

Paperfold is an e-book reader, a note application, and a reading journal in one app.
It keeps the reading and the record of the reading together, for books read in the app and books read on paper.
Success: the user reads more, remembers more of what they read, and wants to open the app.

## Positioning

Reader apps do not keep a journal, and journal apps do not open books.
Paperfold does both, and treats a printed book as a first-class book.

## Operating Context

- Reading sessions are long, often in the evening and in low light.
- Journal visits are short and frequent: log progress, capture a quote, check a challenge.
- Off-app reading is part of the job: printed books, quick capture from outside the app,
  and a journal that leaves the app in a good form (print, PDF, Markdown).
- The device is a phone on battery. The app must stay light on battery and moderate in size.

## Capabilities and Constraints

- Flutter app (Riverpod, sqflite). Reader engine: foliate-js in a WebView. Page curl: a fragment shader.
- Formats: EPUB, MOBI, AZW3, FB2, TXT, CBZ, PDF. Paper books have no file and use Log progress.
- Library: shelves, upright spines (default view) and a cover grid, filters, sort, series bindings.
- Journal: book journals, reviews, journal pages, highlights, reading challenge, month tracker, statistics.
- Online catalogs (OPDS, Wikisource, Gutenberg), WebDAV sync, daily reading reminder.
- 16 locale files, including right-to-left languages.
- The reader keeps its own page themes, separate from the app theme. eInk mode stays.
- Live background blur is allowed only on a few floating layers (navigation, sheets, reader bars).
  Other translucency uses tinted color with no blur. Reason: battery.
- Undecided: home-screen widget, notification actions, and photo-of-page capture
  (wanted as "quick capture", not yet built).

## Brand Commitments

- Name: Paperfold. Lowercase gold wordmark: `assets/images/paperfold_wordmark.png`.
- User-supplied identity images (2026-09-17): `assets/images/paperfold_cover.jpg`, `assets/images/paperfold_paper.jpg`.
- User-supplied reference colors: Soft Dove, Spiced Hot Chocolate, Moon Rock, Dark Sienna, Black Raspberry.
- The user's brief (2026-11-06): a library feel, a quiet reading corner with a reading chair,
  hints of minimalism, and translucent layers that read as a window into the imaginary world of the book.
  Every button, corner, and element must be extremely consistent.
  Animation and the fit of every element to the screen are first-class.
- Fork of Anx Reader. The Anx Reader author does not endorse Paperfold.
- Project documents use ASD-STE100 (Simplified Technical English).

## Evidence on Hand

- Fonts with licenses in `assets/fonts/` (Philosopher, Source Sans 3, Source Han Serif SC).
- Ornaments in `assets/ornaments/`.
- No user testimonials, usage numbers, or store ratings exist. Do not invent them.

## Product Principles

1. The book leads. Interface recedes when a book is open.
2. One system. One corner scale, one motion scale, one glass recipe, used everywhere.
3. Paper and screen are equal. A printed book gets the same care as an e-book.
4. Quiet by default, rich on attention. Calm at a glance; detail rewards a closer look.
5. Light on the device. Beauty that costs battery is spent only where the user looks.

## Accessibility & Inclusion

- System font scaling works at every size; large text changes layout before it removes information.
- Right-to-left layouts are supported.
- Reduced motion and the system "Remove animations" setting are respected.
- Translucent layers keep text contrast at 4.5:1 or better over any background.
- Touch targets are at least 48 x 48 dp.
