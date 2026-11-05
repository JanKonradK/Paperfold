# Changelog

## 0.2.0

- Add a paper book. Choose a JPG or PNG cover, or take a photo of the cover.
- Share a cover photo to Paperfold to start a new paper book.
- Log the current page of a paper book. The page sets the progress and the status.
- Turn on a daily reading reminder in Reading settings. Select the time.
- Move the slider in the library to change between spines and covers.
- See sharper covers on the book model.
- Find free books in Wikisource and Internet Archive.
- Receive books from book finder apps, such as PageDrop, and from file managers.
- A backup file no longer contains the WebDAV password or translation API keys.
- An update installs only when its file matches the digest on GitHub.
- A shared file cannot write outside the app cache.
- Web pages cannot read books from the local reader server.

The database changes to version 11. Update Paperfold on every device that syncs.

## 0.1.0

First public Paperfold beta for Android.

- Read EPUB and PDF books with page curl and reading controls.
- Organize books on shelves and track reading progress.
- Keep notes, reviews, and a reading journal.
- Browse OPDS catalogs and use WebDAV sync.
- Choose Cream, Burgundy, Dark, or System themes.

Beta software: back up your library before installing.

## 2.1.0

- Select Cream, Burgundy, Dark, or System for the app theme.
- Use warm cream surfaces in light mode and burgundy surfaces for the middle theme.
- See more binding colors from the Paperfold palette.
- Open a book screen with its cover, full title, author, and reading progress.
- Find Journal, Details, Shelves, and Customise in labeled buttons.
- Start or continue reading with the fixed button below the details.
- Use complete translations in all 16 locale files.
- Use the updated Flutter, Dart, Android, and reader tools.

## 1.15.0

Paperfold's first version under its own name.

Paperfold began as a fork of Anx Reader and keeps its reading engine, its
library and its sync. Everything below is what has changed since the fork; the
version number carries on from where the fork was taken, so that a reader
updating in place is never offered a lower number than the one they have.

- The library is a bookcase. Books stand on a shelf as solid objects with real
  covers, spines and paper, and a book is taken down and opened rather than
  selected from a list.
- A new visual world: the Paperfold palette, Philosopher and Source Sans 3, the
  ornament set, and a true-black night that leaves an OLED screen switched off.
- Pages turn with a real curl, drawn by a fragment shader. The application
  opens onto a book that opens itself.
- A reading journal: reviews, dot pages, shelves, a reading challenge and a
  month tracker.
- Books can be found and downloaded from OPDS catalogues.
- Removed: the AI assistant, text-to-speech and in-app purchases.
