# Paperfold next release

## Paper books

Select **Add books > Paper book** to add a printed book.
Enter the title. The author, the total pages, and the cover are optional.
Select **Choose cover** for a JPG or PNG file, or **Take photo** on Android and iOS.
Share a JPG or PNG photo to Paperfold to start a paper book with that cover.

Paperfold makes a clean copy of each new cover:

- It accepts only JPG and PNG files of 20 MB or less.
- It checks the file signature and the image size before it decodes the image.
- It turns the image upright from the camera orientation.
- It reduces the long edge to 2048 pixels. It does not enlarge a small image.
- It removes EXIF, GPS, and text metadata.

A paper book has no book file. Its `file_path` is empty.
**Read** and **Continue** open **Log progress** instead of the reader.
The current page sets the progress. The first page sets the start date.
The last page sets the finish date, so the reading challenge counts the book.
Paper books use the same shelves, filters, search, journal, review, and export.
File actions, such as **Share file** and **Replace file**, do not show for a paper book.
WebDAV sync sends the database and the cover. It does not look for a book file.

The status menu now also sets the start date and the finish date.

### Database version 11

Version 11 adds two columns to `tb_books`:

| Column | Type | Default |
| --- | --- | --- |
| `total_pages` | INTEGER | NULL |
| `current_page` | INTEGER | 0 |

Existing books keep all values. The upgrade is safe to repeat.
A device with an older Paperfold cannot open a version 11 sync database.
Update Paperfold on every device that syncs.

## Daily reading reminder

Select **Settings > Reading > Daily reading reminder**, then select the time.
The reminder is off by default.
Paperfold asks for notification permission only when you turn on the reminder.
The notification text contains no book titles.
Paperfold does not ask for the exact-alarm permission.
Android can deliver the reminder some minutes late to save battery.
The reminder is available on Android and iOS. Desktop systems do not show it.

The system restores the reminder after a restart.
Paperfold schedules it again at each start, which also follows a change of time zone.

## Library view slider

The library header has a two-position slider: **Spines** and **Covers**.
Tap a side or drag the thumb. The slider keeps the sort, the filters, and the shelf.
Each side is a labeled button with a selected state for screen readers.

## Sharper images

- The book model decodes art at up to 1024 pixels, not 512.
  At 3x screens, 512 pixels looked soft on the book in the hand.
  The cache keeps the 24 most recent covers. Before, it had no limit.
- A new cover keeps up to 2048 pixels on its long edge.
- The cover grid keeps its decode size. A larger decode used more memory
  and gave no visible gain at the grid sizes.

## Book sources and other apps

Wikisource (English) is a built-in catalog with EPUB downloads.
Internet Archive opens as a website. Its book files import through the book browser.

Book finder apps, such as PageDrop, and file managers can share books to Paperfold.
PageDrop has no share or "open with" action. It can save copies to the phone.
Open a saved copy with Paperfold, or share it from a file manager.
Paperfold now accepts these types from other apps: EPUB, PDF, MOBI, AZW3, FB2,
TXT, JPG, PNG, and unnamed binary files.
Paperfold no longer offers itself for every web link.
A link that you share to Paperfold still opens in the book browser.

## Security

| Area | Change |
| --- | --- |
| Shared files | The share plugin used the sender's file name, so `../` could write outside the cache. A patched copy in `third_party/share_handler_android` keeps only the last part of the name. |
| Reader server | The server answered every web origin. It now refuses a Host that is not `127.0.0.1` or `localhost`, and allows only its own origin. |
| Backups | A backup file no longer contains the WebDAV password or translation API keys. A restore keeps the passwords on the device. |
| Updates | The app installs an update only from a Paperfold release on GitHub, and only when the file matches the SHA-256 digest that GitHub lists. |
| Update check | A beta version such as `0.1.0-beta.1` no longer stops the update check. |
| Covers | See the clean copy rules above. |

These items stay the same:

- The network configuration still permits HTTP and user certificates.
  Readers use them for OPDS and WebDAV servers on a home network.
- The WebDAV password stays in app preferences.
  Moving it to the system keystore needs a migration with a recovery path.
  Do that in a separate change.

## Development

New packages:

| Package | Version | Use |
| --- | --- | --- |
| image | ^4.10.1 | Cover validation and clean copies. It was already in the lock file. |
| image_picker | ^1.2.1 | Cover photos from the camera. |
| flutter_local_notifications | ^21.0.0 | The daily reminder. It needs core library desugaring. |
| timezone | ^0.11.0 | Local reminder times. |
| flutter_timezone | ^5.0.1 | The device time zone. |

`android/app/build.gradle` enables core library desugaring with `desugar_jdk_libs` 2.1.4.

## Checks still to do on a device

- Take a cover photo with the camera on Android and iOS.
- Turn on the reminder, then restart the device and change the time zone.
- Share an EPUB from a file manager and a photo from the gallery.
- Open Wikisource and download a book.
- On iOS, set the notification center delegate if the reminder must show while Paperfold is open.
