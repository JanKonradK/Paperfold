# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

Paperfold builds for Android, iOS, Windows, macOS, Linux and ohos, inherited
from the fork. **Android is the design target for version 1.** iOS is
explicitly out of scope for version 1 (`plan.md` Section 10). The desktop
targets build but are not designed for yet.

## Users

**Primary user: the project owner.** Paperfold is built first as the reading
journal its author wants to use. Design decisions resolve toward that taste.
Others are welcome, and a public release is a bonus rather than the driver.

The situation: someone who reads books and wants to keep a considered record of
them — ratings, a favourite quote, a character they liked, and free space to
write whatever they actually thought — without leaving the application they
read in.

## Product Purpose

A reading journal, reader, and note application in one. It opens and turns
pages like a real book.

The journal is the product. The reader exists so that reading and recording
happen in the same place, which is the thing no existing application does.

Success is that the owner keeps using it for their own reading.

## Positioning

`plan.md` Section 2.1 surveyed the field. It splits in two and nothing bridges
it:

- **Readers** are mature and strong. KOReader, Anx Reader, Book's Story.
- **Trackers** are weak, small, or self-hosted. Openreads, Jelu, Tome.

Four gaps, from Section 2.2, that Paperfold exists to close:

1. **No emotional design.** Every tracker is a list, a grid, or a spreadsheet.
2. **Notes are second-class.** Readers keep highlights. Trackers keep star
   ratings. Almost nothing gives a free page for your own thoughts.
3. **No true book metaphor.** Nothing turns pages like paper.
4. **Reader and journal stay apart.** You read in one application and record in
   another.

The mechanism a neighbouring product could not truthfully copy is the
combination: a real page curl, a journal that is the point rather than a
sidebar, and both living inside a working reader.

## Operating Context

Reading happens on a phone, often one-handed, often at night, often in bed.
Sessions are short and interruptible. The application is used in the dark as
much as in daylight, so the dark theme is a first-class scheme rather than an
inverted light theme.

The reader is foliate-js running inside a WebView. Books arrive as files the
owner already has, and later through OPDS catalogs (Milestone 7).

Everything stays on the device. Sync is the owner's own WebDAV server if they
want it. There is no account.

## Capabilities and Constraints

**Working today**, inherited from the fork and verified on device:

- EPUB, MOBI, AZW3, FB2, TXT, CBZ and PDF reading through foliate-js
- highlights and notes anchored to a location, exportable to TXT, Markdown, CSV
- reading time statistics and a heatmap
- WebDAV sync, export and import
- translation with five backends
- 16 locales, loaded on demand

**Built in Milestones 1 and 2:**

- a page curl fragment shader, measured at 4.8 ms worst on the raster thread
  against an 8.3 ms budget
- an opening sequence: a closed book that curls open on cold start
- database schema version 8, the journal tables

**Deliberately removed**, and not to be reintroduced without a decision:

- all AI features
- text to speech
- in-app purchase

**Not built yet:** the journal itself (reviews, dot pages, shelves, the reading
challenge), OPDS catalogs, and the Paperfold visual world.

**Technical constraints that bind future work:**

- The build does not compile from a clean checkout without
  `dart run build_runner build`. Generated files are gitignored.
- Six dependencies point at a single maintainer's personal forks.
  `flutter_inappwebview` cannot be dropped; it carries the reader.
- A WebView page must be captured to a bitmap before a shader can curl it, and
  **every capture stalls a frame**. Capture only when nothing is animating.
- Material Design 3 governs navigation, sheets, dialogs and system Back. The
  book metaphor applies to the page surface, not to the chrome.

**Undecided:** whether the reader page turn ships with the curl in version 1 or
follows later. The capture path is proven viable; the integration is Milestone 5.

## Brand Commitments

- **Name: Paperfold.** Package `paperfold`, application id `com.paperfold.app`.
- **Fork attribution is a licence duty.** Paperfold is a fork of Anx Reader by
  Anxcye, MIT. The `LICENSE` file keeps `Copyright (c) 2025 Anxcye`, the README
  links upstream, and nothing may imply the upstream author endorses Paperfold.
- **Ornaments and the application icon are the owner's own artwork**
  (`@FINE.ART.MUSE`): an oval floral frame, a rectangular vine frame, a corner
  spray, a circular wreath, a bow and ribbon, and a burgundy icon with a wreath
  and a `J` monogram. **The source files do not exist in the repository yet.**
  Confirmed 2026-08-11: build the ornament system with swappable placeholders
  and drop the real art in later without a code change.
- **Fonts must be embeddable.** Confirmed 2026-08-11: ship a face under the SIL
  Open Font License. The "Adobe Elegant Script" shown in the early slides is not
  used, because Adobe Fonts licences do not always permit application
  embedding.
- Bundled Source Han Serif stays; it is OFL 1.1 and its licence text now ships
  at `assets/fonts/OFL.txt`.

## Evidence on Hand

- `plan.md` — the living project plan, corrected against the code as work
  proceeds.
- `docs/paperfold/` — measured results, not estimates: WebView capture cost,
  Milestone 1 frame timings and gate decision, inherited dependency forks,
  font licences, Android developer verification.
- `test/dao/migration_v8_test.dart` — the migration proof.

**Absences that future work must not fabricate:** there are no users, no
downloads, no reviews, no press, and no benchmarks. Paperfold has never been
released. Any interface copy implying otherwise is false.

## Product Principles

1. **The journal is the product.** The reader is how the journal earns its
   place, not the other way round.
2. **Make it feel like paper, and keep the chrome honest.** Full expression on
   the page surface. Material 3 for navigation, sheets, dialogs and Back.
3. **Delight must be skippable.** Any animation a user cannot escape turns
   hostile by about the fifth launch.
4. **Local first.** The reader's books, notes and thoughts stay on their
   device. No account, no telemetry, nothing sent anywhere by default.
5. **Measure before optimising, and fix only what misses.** Budgets exist and
   are checked on hardware, not guessed.

## Accessibility & Inclusion

- **Right to left is a design constraint, not a translation task.** An Arabic
  interface opens the book from the other side and pages turn the other way.
  The curl takes a direction uniform for this reason.
- Body text needs 4.5:1 contrast; large text and interface elements need 3:1.
  The five palette colours are surfaces, not text colours, and an ink colour was
  added because the palette lacked one.
- Text scales with the system font size setting.
- The system "remove animations" setting is obeyed: the opening sequence does
  not play and the curl falls back to a cross-fade.
- Touch targets are 48 x 48 dp minimum, 8 dp apart.
- Dark theme is a first-class scheme, designed for reading in the dark.
- **Text to speech was removed by decision on 2026-08-10.** This is a real
  accessibility loss and is recorded as one in `plan.md` Section 3.3.2.
