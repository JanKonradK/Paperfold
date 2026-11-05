# Paperfold 2.1

## Changes

Appearance settings offer Cream, Burgundy, Dark, and System.
Cream uses warm surfaces from the supplied reference palette.
Burgundy is the middle theme between Cream and Dark.
The dark theme retains the true-black option.
The eInk option retains its separate display settings.
The reader keeps its saved page colors.

Spines use all five supplied reference colors and five additional binding colors.
Text retains at least 4.5:1 contrast against each binding.
Series bindings retain their shared colors.
Spines remain the default view. Covers remain available.

The book screen shows a compact cover, the full title, the author, and reading progress.
Journal, Details, Shelves, and Customise use labeled buttons.
The Read button stays below the details while the details scroll.
Wishlist books open Books to buy without false reading progress.
Large text and wide screens use layouts with sufficient space for the controls.

Each of the 16 locale files contains all 851 messages.
The locale checks compare message keys and ICU placeholders.
These checks do not replace a native speaker's review of each translation.

## Development tools

The release uses Flutter 3.47.6 and Dart 3.13.5.
The app uses the official Material and Cupertino packages.
A compatibility bridge supplies themes and translations to older package widgets.

Android uses Kotlin 2.3.21, Gradle 8.14.6, and Android Gradle Plugin 8.13.2.
The WebView fork still uses a ProGuard file that Android Gradle Plugin 9 rejects.
The release uses the latest compatible stable versions in the previous tool series.
The Java compilation target remains 17.

The reader build uses Node 24, Babel 8, and Webpack 5.
PDF.js 6.4.299 loads when the reader opens a PDF.
PDF support files are available offline in the app assets.
Prism 1.30.0 supplies code highlighting.

Secure storage remains on version 10.3.4.
Version 10 migrates the older Android ciphers before version 11 can replace them.
The migration keeps a backup and does not delete credentials after an error.

Some package updates require incompatible versions of other packages.
The release retains the compatible versions in this table.

| Package | Version | Reason |
| --- | --- | --- |
| connectivity_plus | 7.3.1 | Desktop packages still require dbus 0.7. |
| wakelock_plus | 1.8.0 | The newer version requires dbus 0.8. |
| screen_retriever | 0.2.2 | window_manager requires version 0.2.2. |
| xml | 6.6.1 | The WebDAV fork requires XML 6. |
| flutter_secure_storage | 10.3.4 | Direct upgrades need the older cipher migration. |
| permission_handler | 12.0.3 | Newer Android releases need API 37 and Android Gradle Plugin 9. |
| permission_handler_android | 13.0.1 | An exact constraint keeps the supported API 36 implementation. |

PDF checks use Chromium 152.
PDF.js lists Chrome 125 and Safari 18 as the minimum versions for its legacy build.
Older WebViews and iOS 15.2 need device checks.
The CSS fallback does not establish full support for those older browsers.

## Checks

All 456 local tests passed.
The analyzer reported no errors. It retains advisory findings from the framework migration and inherited code.
The final capture check completed 26 app states across phone, wide, large-text, and Arabic layouts.
The independent visual review found no material interface defects in those captures.
The final review disposition is `ship`. The design document and its sidecar match the built app.
The PDF browser harness completed 21 checks in Chromium 152.
The reader build completed with no warnings, and the npm audit reported no vulnerabilities.

The signed Android release is version 2.1.0, code 210.
Installation on the connected Galaxy S23 Ultra completed without an uninstall or a data reset.
Device checks confirmed the three app themes, real book art, book actions, Journal, Statistics, and Android Back.
The reader opened at its saved position with its separate page colors.

## Sources

Source checks date: 2026-10-08.

- [Flutter SDK archive](https://docs.flutter.dev/install/archive).
- [Official Material package and migration guide](https://pub.dev/packages/material_ui).
- [Android Gradle Plugin 8.13 compatibility](https://developer.android.com/build/releases/agp-8-13-0-release-notes).
- [Gradle releases](https://gradle.org/releases/).
- [Secure storage migration changes](https://pub.dev/packages/flutter_secure_storage/changelog).
- [Android permission package changes](https://pub.dev/packages/permission_handler_android/changelog).
- [PDF.js](https://github.com/mozilla/pdf.js).
- [Prism](https://github.com/PrismJS/prism).
- [PDF.js browser support](https://github.com/mozilla/pdf.js/wiki/Frequently-Asked-Questions#faq-support).
