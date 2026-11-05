# Contribute to Paperfold

Paperfold is a fork of [Anx Reader](https://github.com/Anxcye/anx-reader).
The Anx Reader author does not endorse Paperfold.
Send Paperfold changes to this repository.
Send issues specific to Anx Reader to the upstream project.
For security problems, use [the security policy](SECURITY.md).

## Prerequisites

- Install the Flutter version in [`.github/flutter-version`](.github/flutter-version).
- Install the platform tools for your build target.
- For reader changes, install a Node.js version that meets `assets/foliate-js/package.json` requirements.

## Prepare and check the app

Run these commands in the project directory:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --concurrency=1
```

The generated Dart files are not in Git.
Run code generation again after changes to Riverpod or Freezed source files.
Correct analyzer errors before you submit a pull request.
The PR check treats analyzer warnings and information messages as advisory findings.
The test command uses one worker to limit memory use.

## Build the reader engine

Run these commands in `assets/foliate-js`:

```sh
npm ci --no-fund
npm run build
```

The `build` script runs Webpack.
The `npm test` script is a placeholder that always fails.

## Messages and documents

Add every new message to all 16 `lib/l10n/app_*.arb` files.
Keep message keys and ICU placeholders consistent across the files.
Run `flutter gen-l10n` after message changes.

Use ASD-STE100 Simplified Technical English for documents.
Use short sentences and active voice.
Give one instruction in each sentence.

## Submit a change

Keep the change within the scope of its issue.
Complete the pull request template.
Give the check results.
Attach screenshots for UI changes.
