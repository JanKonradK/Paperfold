# Journal implementation

- Built: v12 migration, entry fields, recent-entry pagination, numeric location queries, atomic paper progress + daily tracker + entry save, stable draft IDs for safe retries.
- Built in working tree: Journal home, recoverable composer, QuickCapture consumer, container route, glass reader bars, Facing page, hardened page photos and full view.
- First focused run: 36 tests passed (DAO, v12 migration, draft, composer, Facing page, home, reader chrome). A new atomic progress/retry test is running.
- Code generation: default AOT compilation ran out of memory. `dart run build_runner build --delete-conflicting-outputs --force-jit` passed (77 outputs).
- Next: commit each part, finish integration checks, run the full suite.
- OCR: upstream google_mlkit_text_recognition Android build.gradle uses bundled `com.google.mlkit:text-recognition:16.0.1`, not Play-services. Ship attachment only. No OCR dependency added. APK delta has not been measured.
- Photos: stored as relative paths under journal_photos/. Existing WebDAV sync and ZIP backup enumerate folders and exclude this folder. Lead must add journal_photos to sync, backup, restore and storage migration (outside assigned files).
- Hardware profile, TalkBack, eInk and visual screenshot QA have not been run.
