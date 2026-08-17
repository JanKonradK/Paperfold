# Paperfold

Paperfold is an e-book reader, note app and reading journal.

## Fork notice

Paperfold is a fork of [Anx Reader](https://github.com/anxcye/anx-reader) by Anxcye. The upstream author does not endorse Paperfold.

## Status

### Works now

- Read EPUB, MOBI, AZW3, FB2, TXT, CBZ, and PDF files with foliate-js.
- Attach notes and highlights to book locations.
- Export notes and highlights to TXT, Markdown, or CSV.
- View reading time statistics and a heatmap.
- Sync through WebDAV.
- Translate text with bingWeb, googleWeb, microsoftApi, googleApi, or deepl.
- Use the app in 16 locales.
- Build the app for Android, iOS, Windows, macOS, Linux, and ohos.

### Not included

- Paperfold does not include AI functions.
- Paperfold does not include text-to-speech.
- Paperfold does not include in-app purchases.

### Built, still being finished

- The Paperfold visual design: the token set, the theme, the ornaments, and a
  library that stands its books on a bookcase as three-dimensional objects.
- A reading journal: reviews, dot pages, shelves, a reading challenge, and a
  month tracker.
- A real page curl, drawn by a fragment shader, in the reader and the opening.
- OPDS catalogs, reachable from the library's add-books button.

These work, and the visual world is still under active change.

## Build

Install Flutter. Then run these commands from the project directory:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

The `*.g.dart` and `*.freezed.dart` files are not in Git. A clean checkout does not compile before code generation.

Do not skip the code generation command. If you skip it, the compiler reports confusing errors that look unrelated to each other. Examples include an undefined Riverpod provider, and a switch that is "not exhaustively matched". Both come from the missing generated files.

Run code generation again after you change a Riverpod or Freezed source file.

## License

Paperfold uses the [MIT License](./LICENSE). The `LICENSE` file keeps the `Copyright (c) 2025 Anxcye` notice.

Paperfold includes these third-party works:

- [`assets/foliate-js`](./assets/foliate-js) is the reader engine. It comes from [johnfactotum/foliate-js](https://github.com/johnfactotum/foliate-js) and uses the MIT License.
- [Adobe Source Han Serif](https://github.com/adobe-fonts/source-han-serif) uses the SIL Open Font License 1.1. See [`assets/fonts/OFL.txt`](./assets/fonts/OFL.txt).
- [Philosopher](https://fonts.google.com/specimen/Philosopher) is the display and body face. It uses the SIL Open Font License 1.1. See [`assets/fonts/OFL-Philosopher.txt`](./assets/fonts/OFL-Philosopher.txt).
- [Source Sans 3](https://github.com/adobe-fonts/source-sans) is the label face. It uses the SIL Open Font License 1.1. See [`assets/fonts/OFL-SourceSans3.txt`](./assets/fonts/OFL-SourceSans3.txt).
