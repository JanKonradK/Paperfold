# Platform implementation

## Commits

- 1f645e1d: Dart launch services, reminder actions, translations, and tests.
- This commit adds native widget resources and the DAO update hook.

## Completed

- URI parsing validates the scheme, action, capture kind, and book ID.
- QuickCapture retains capture requests until the composer consumes them.
- CaptureLaunch.openBook retains book requests until the home page consumes them.
- Reminder actions support cold and warm starts on Android and iOS.
- Reminder actions use translations from all 16 ARB files.
- Android widgets use native RemoteViews and one MethodChannel.
- Quick capture has Note, Quote, and Log pages buttons.
- Continue reading shows the cover, title, and progress.
- Paper books request progress capture.
- Widget data follows successful DAO writes and active-reader changes.
- Widget updates use a 300 ms debounce and omit unchanged data.
- Theme changes update the stored widget palette.
- No new package, alarm, polling task, or wake lock is necessary.

## Checks

- Five targeted tests passed, including cold and warm notification callbacks.
- flutter gen-l10n completed.
- build_runner completed and wrote 77 generated files.
- The native Kotlin widget classes compiled.
- The debug APK build is still in progress.
- The full test suite stopped after 40 passing tests: Dart reported insufficient memory.
- Static analysis also stopped because the host had insufficient memory.
- Several other worktrees have concurrent checks. Do not stop their processes.

## Next

1. Complete the debug APK build.
2. Repeat the full test suite with --concurrency=1 after the build.
3. Repeat static analysis after the test suite.
4. Restore temporary android/gradle.properties changes before the final commit.
5. Do not measure release size. android/key.properties is absent, so release signing has no key.

## UI integration

- Listen to CaptureLaunch.openBook after the home page is ready.
- Also check its initial value, because a cold-start request can precede the listener.
- Consume each request with CaptureLaunch.takeOpenBook().
- A null bookId means the current or most recent book.
- Use the existing pushToReadingPage path for digital books.
- For paper books, request QuickCaptureKind.progress with the book ID and request source.
- The composer agent consumes QuickCapture.take(). This implementation only produces requests.

## Limits

- iOS notification categories exist. No WidgetKit extension exists, as requested.
- The optional Photo button does not fit the three localized actions at 4x1.
- Device checks for widget layout, font scaling, RTL, restart, and timezone changes remain necessary.
- Native widgets follow the system locale. Reminder labels follow the app locale at initialization.
