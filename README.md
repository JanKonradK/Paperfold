# Paperfold

Paperfold is an e-book reader, a note application, and a reading journal.

## Fork notice

Paperfold is a fork of [Anx Reader](https://github.com/anxcye/anx-reader) by
Anxcye. The author of Anx Reader does not endorse Paperfold.

## What Paperfold does

### Read a book

- Open EPUB, MOBI, AZW3, FB2, TXT, CBZ, and PDF files. The reader engine is
  foliate-js.
- Turn a page with a page curl. A fragment shader draws the curl.
- Change the type, the margins, and the colors of the page.

### Keep notes

- Attach a note or a highlight to a location in a book.
- Export the notes and the highlights to TXT, Markdown, or CSV.

### Keep a journal

- Write a review of a book.
- Use the dot pages, the month tracker, and the reading challenge.
- Read the reading time statistics and the heatmap.

### Hold a library

- The home screen is a bookcase with upright spines. Select a spine to show
  the cover, progress, and book actions.
- Put a book on one of five shelves.
- Get more books from an OPDS catalog.

### Other functions

- Sync the books and the notes through WebDAV.
- Translate text with bingWeb, googleWeb, microsoftApi, googleApi, or deepl.
- Use the application in 16 languages.

## What Paperfold does not have

- Artificial intelligence functions
- Text-to-speech
- In-app purchases

## Platforms

Android is the tested release target. The project also contains iOS, Windows,
macOS, Linux, and OpenHarmony targets. These targets need further device tests.
Linux support is incomplete.

## Build

Use the Flutter version in [`.github/flutter-version`](.github/flutter-version).
Then do these steps in the project directory:

1. Get the packages.

   ```sh
   flutter pub get
   ```

2. Run the code generation.

   ```sh
   dart run build_runner build --delete-conflicting-outputs
   ```

3. Start the application.

   ```sh
   flutter run
   ```

Do not skip step 2. The `*.g.dart` and `*.freezed.dart` files are not in Git, so
a new clone does not compile before the code generation.

If you skip step 2, the compiler shows errors that look unrelated to each other.
Two examples are an undefined Riverpod provider, and a switch that is not
exhaustive. The missing generated files cause both errors.

Run step 2 again each time you change a Riverpod source file or a Freezed source
file.

### Release build for Android

A release build needs the file `android/key.properties`. That file is not in
Git. It gives the location of the keystore and its passwords. Without the file,
Gradle does not sign the build.

In `key.properties`, write the keystore path with forward slashes. A
`.properties` file reads the backslash as an escape character, and a Windows
path with backslashes fails without a message.

## Tests

Run the tests one file at a time:

```sh
flutter test --concurrency=1
```

The single-worker setting limits memory use during the full test suite.

## Development tools

### Preview images

The files in `tool/` draw a screen to PNG contact sheets. Read the PNG files to
see a result without a device. Example:

```sh
flutter test tool/preview_book_model.dart
```

The tool writes the images to `tool/preview/`, which Git ignores.

The main preview tools load the app fonts and Material icons.

### Recover build storage

Copy an APK that you want to keep out of `build/`. Then run `flutter clean`.
This removes generated build files. The next build creates them again.
Run the package and code generation steps again before the next build.
Keep `android/key.properties` and the signing keystore outside version control.

### One-screen entry points

Each `lib/dev_*_main.dart` file starts one screen alone. Example:

```sh
flutter run -t lib/dev_shelf_main.dart
```

## License

Paperfold uses the [MIT License](./LICENSE). The `LICENSE` file keeps the
`Copyright (c) 2025 Anxcye` notice.

Paperfold includes these third-party works:

- [`assets/foliate-js`](./assets/foliate-js) is the reader engine. It comes from
  [johnfactotum/foliate-js](https://github.com/johnfactotum/foliate-js) and uses
  the MIT License.
- [Philosopher](https://fonts.google.com/specimen/Philosopher) is the heading
  face. It uses the SIL Open Font License 1.1. See
  [`assets/fonts/OFL-Philosopher.txt`](./assets/fonts/OFL-Philosopher.txt).
- [Source Sans 3](https://github.com/adobe-fonts/source-sans) is the body and label face.
  It uses the SIL Open Font License 1.1. See
  [`assets/fonts/OFL-SourceSans3.txt`](./assets/fonts/OFL-SourceSans3.txt).
- [Adobe Source Han Serif](https://github.com/adobe-fonts/source-han-serif) is
  the Chinese face. It uses the SIL Open Font License 1.1. See
  [`assets/fonts/OFL.txt`](./assets/fonts/OFL.txt).
