# Paperfold 2.0

## Changes

Spines remain the default library view. The Book view control also offers Covers.
The application saves the view. Both views use the same shelves, filters, book actions, and reading positions.
Large text uses a list with horizontal titles. Reduced motion removes shelf animation.

Spine bands, small foil marks, and title sizes vary within the existing palette.
Books in a series keep matching bindings. The app retains its burgundy surfaces and separate reader theme.

The online hub separates direct downloads from external services.
Project Gutenberg and Ebooks libres et gratuits supply direct-download catalogs.
Standard Ebooks, Global Grey, Open Library, and Libby open in the browser.
Loans and protected books stay in their own services.
The application keeps custom catalogs and saved credentials.

Download controls offer supported formats, cancellation, and retry.
Purchase links and loan links no longer start a file import.
Catalog forms keep the entered values if a save fails.

## Performance measurements

The local benchmark uses 2,000 test books, two warmups, and nine alternating samples.
The table shows median times on this PC. These measurements do not describe phone startup or frame rate.

| Operation | Previous algorithm | Version 2.0 |
| --- | ---: | ---: |
| Sort by title | 87.140 ms | 2.827 ms |
| Sort by author | 120.410 ms | 1.038 ms |
| Group books | 1.765 ms | 0.069 ms |

The benchmark checks identical book order for every sort field and direction.
The sort cache lasts for one operation. Group lookup uses one pass through the books.

Run the benchmark with `flutter test tool/benchmark_book_list.dart --concurrency=1 --reporter expanded`.

Cover images use a display-width decode limit of 1,200 pixels.
One decode test uses a 2,000 by 3,000 pixel portrait image at a display size of 120 by 180 logical pixels.
At a device pixel ratio of three, the decoded image has 360 by 540 pixels.
Its RGBA surface uses 777,600 bytes instead of 24,000,000 bytes. This is an image-surface measurement, not total process memory.
The image loader shows a readable replacement during loading and after an image error.
After a library refresh, it retries a failed image at the same file path.
The cover grid creates nearby tiles as the reader scrolls.

## Checks

All 437 local tests passed. The checks include book imports, reading positions, journal data, cover recovery, and online download failures.
The analyzer reported no errors. The repository still has existing advisory findings.
The independent visual review found no material defects in the supplied phone, wide-screen, and large-text views.

## Sources

Source checks date: 2026-10-06. Each link leads to the publisher or service.

- [Moon+ Reader](https://www.moondownload.com/) and its [official screenshots](https://play.google.com/store/apps/details?id=com.flyersoft.moonreaderp) informed cover density and direct library controls.
- [Project Gutenberg catalog](https://www.gutenberg.org/ebooks.opds/) and [mobile help](https://www.gutenberg.org/help/mobile.html).
- [Ebooks libres et gratuits catalog](https://www.ebooksgratuits.com/opds/index.php).
- [Standard Ebooks downloads](https://standardebooks.org/ebooks) and [feed access](https://standardebooks.org/feeds). Its OPDS feeds require eligible access. Website downloads remain available.
- [Global Grey](https://www.globalgreyebooks.com/).
- [Open Library](https://openlibrary.org/).
- [Libby](https://www.overdrive.com/apps/libby).

Research used direct source fetches and the official Moon+ Reader screenshot gallery. No third-party search results supplied feature claims.
