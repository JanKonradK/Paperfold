import 'package:paperfold/models/opds_catalog.dart';

/// Verified against each publisher's own site on 2026-10-06.
/// These suggestions are not saved rows, so they never replace user catalogs.
enum OnlineBookSource {
  gutenberg('Project Gutenberg', 'https://www.gutenberg.org/ebooks.opds/', -1),
  ebooksGratuits('Ebooks libres et gratuits',
      'https://www.ebooksgratuits.com/opds/index.php', -2),
  standardEbooks('Standard Ebooks', 'https://standardebooks.org/ebooks'),
  globalGrey('Global Grey', 'https://www.globalgreyebooks.com/'),
  openLibrary('Open Library', 'https://openlibrary.org/'),
  libby('Libby', 'https://www.overdrive.com/apps/libby');

  const OnlineBookSource(this.name, this.address, [this.catalogId]);

  final String name;
  final String address;
  final int? catalogId;

  Uri get url => Uri.parse(address);
  bool get isCatalog => catalogId != null;

  OpdsCatalog get catalog => OpdsCatalog(id: catalogId!, name: name, url: url);

  bool matchesCatalog(OpdsCatalog catalog) {
    final saved = catalog.url;
    final host =
        saved.host == 'm.gutenberg.org' ? 'www.gutenberg.org' : saved.host;
    return isCatalog &&
        host == url.host &&
        saved.path.replaceAll(RegExp(r'/+$'), '') ==
            url.path.replaceAll(RegExp(r'/+$'), '') &&
        saved.query == url.query;
  }
}
