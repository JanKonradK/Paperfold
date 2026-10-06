/// An OPDS feed parser, ported from `assets/foliate-js/src/opds.js`.
///
/// The fork ships that parser and never calls it: a search of the tree returns
/// the file itself and nothing else. plan.md Section 9.2 says to port it to
/// Dart rather than run it in a hidden WebView, because a WebView bridge for a
/// list screen is not worth the complexity.
///
/// Both catalog generations are handled. OPDS 1.2 is Atom XML. OPDS 2.0 is
/// JSON. A server may serve either, so callers pass what the server said.
library;

import 'dart:convert';

import 'package:xml/xml.dart';

/// An OPDS feed parser, ported from `assets/foliate-js/src/opds.js`.
///
/// The fork ships that parser and never calls it: a search of the tree returns
/// the file itself and nothing else. plan.md Section 9.2 says to port it to
/// Dart rather than run it in a hidden WebView, because a WebView bridge for a
/// list screen is not worth the complexity.
///
/// Both catalog generations are handled. OPDS 1.2 is Atom XML. OPDS 2.0 is
/// JSON. A server may serve either, so callers pass what the server said.
abstract final class OpdsMime {
  static const String atom = 'application/atom+xml';
  static const String opds2 = 'application/opds+json';
}

abstract final class OpdsRel {
  static const String acquisition = 'http://opds-spec.org/acquisition';
  static const String facet = 'http://opds-spec.org/facet';
  static const String group = 'http://opds-spec.org/group';
  static const List<String> cover = <String>[
    'http://opds-spec.org/image',
    'http://opds-spec.org/cover',
  ];
  static const List<String> thumbnail = <String>[
    'http://opds-spec.org/image/thumbnail',
    'http://opds-spec.org/thumbnail',
  ];
}

abstract final class _Ns {
  static const String atom = 'http://www.w3.org/2005/Atom';
  static const String opds = 'http://opds-spec.org/2010/catalog';
  static const String thread = 'http://purl.org/syndication/thread/1.0';
  static const String dcTerms = 'http://purl.org/dc/terms/';
  static const String dc = 'http://purl.org/dc/elements/1.1/';
}

/// A media type split from its parameters.
///
/// `application/atom+xml;profile=opds-catalog;kind=acquisition` is one string
/// carrying three facts, and the profile is what says a feed is a catalog.
class OpdsMediaType {
  const OpdsMediaType(this.mediaType, this.parameters);

  factory OpdsMediaType.parse(String value) {
    final List<String> parts = value.split(';');
    final Map<String, String> parameters = <String, String>{};
    for (final String part in parts.skip(1)) {
      final int equals = part.indexOf('=');
      if (equals < 0) {
        continue;
      }
      parameters[part.substring(0, equals).trim().toLowerCase()] =
          _unquote(part.substring(equals + 1).trim());
    }
    return OpdsMediaType(parts.first.trim().toLowerCase(), parameters);
  }

  static String _unquote(String value) {
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  final String mediaType;
  final Map<String, String> parameters;
}

/// True when [value] is a media type that names an OPDS catalog.
bool isOpdsCatalog(String? value) {
  if (value == null || value.isEmpty) {
    return false;
  }
  final OpdsMediaType parsed = OpdsMediaType.parse(value);
  if (parsed.mediaType == OpdsMime.opds2) {
    return true;
  }
  return parsed.mediaType == OpdsMime.atom &&
      parsed.parameters['profile']?.toLowerCase() == 'opds-catalog';
}

class OpdsPrice {
  const OpdsPrice({required this.currency, required this.value});

  final String? currency;
  final String? value;
}

class OpdsLink {
  const OpdsLink({
    required this.rels,
    required this.href,
    this.type,
    this.title,
    this.facetGroup,
    this.price,
    this.numberOfItems,
  });

  /// `rel` is a space-separated list in Atom, so it is always a list here.
  final List<String> rels;

  /// Resolved against the feed's own address, so a caller never has to.
  final Uri href;

  final String? type;
  final String? title;
  final String? facetGroup;
  final OpdsPrice? price;
  final int? numberOfItems;

  bool get isCatalog => isOpdsCatalog(type);

  /// A link that hands over a file. These are the download links.
  bool get isAcquisition =>
      rels.any((String rel) => rel.startsWith(OpdsRel.acquisition));

  /// A facet the server says is the one currently applied.
  bool get isActiveFacet => rels.contains('self');

  bool hasAnyRel(List<String> candidates) => rels.any(candidates.contains);
}

/// One publication, with its links kept whole.
class OpdsEntry {
  const OpdsEntry({
    required this.title,
    required this.links,
    this.authors = const <String>[],
    this.summary,
    this.identifier,
    this.language,
    this.publisher,
    this.published,
    this.subjects = const <String>[],
  });

  final String title;
  final List<OpdsLink> links;
  final List<String> authors;
  final String? summary;
  final String? identifier;
  final String? language;
  final String? publisher;
  final String? published;
  final List<String> subjects;

  List<OpdsLink> get acquisitionLinks => links
      .where((OpdsLink link) => link.isAcquisition)
      .toList(growable: false);

  Uri? get coverHref => _first(OpdsRel.cover);
  Uri? get thumbnailHref => _first(OpdsRel.thumbnail);

  Uri? _first(List<String> rels) {
    for (final OpdsLink link in links) {
      if (link.hasAnyRel(rels)) {
        return link.href;
      }
    }
    return null;
  }
}

/// A group of facet links the server offers together, such as "Sort by".
class OpdsFacetGroup {
  const OpdsFacetGroup({required this.title, required this.links});

  final String title;
  final List<OpdsLink> links;
}

class OpdsFeed {
  const OpdsFeed({
    required this.title,
    required this.publications,
    required this.navigation,
    required this.facetGroups,
    this.searchLink,
    this.nextHref,
    this.previousHref,
  });

  final String title;

  /// Entries that carry an acquisition link. These are books.
  final List<OpdsEntry> publications;

  /// Entries and links that lead to another feed. These are shelves.
  final List<OpdsLink> navigation;

  final List<OpdsFacetGroup> facetGroups;

  /// The OpenSearch description, or a search link. Fetch it to learn the
  /// query template. plan.md Section 9.2 makes search optional.
  final OpdsLink? searchLink;

  /// Feeds page. Section 9.2 lists pagination as part of the browse screen.
  final Uri? nextHref;
  final Uri? previousHref;

  bool get isEmpty => publications.isEmpty && navigation.isEmpty;
}

/// Parses a feed body.
///
/// [contentType] decides the generation. When a server sends nothing useful,
/// the body itself is sniffed: a JSON object is OPDS 2.0, anything else is
/// tried as Atom.
OpdsFeed parseOpdsFeed(
  String body, {
  required Uri baseUri,
  String? contentType,
}) {
  final String mediaType =
      contentType == null ? '' : OpdsMediaType.parse(contentType).mediaType;

  if (mediaType == OpdsMime.opds2 ||
      (body.trimLeft().startsWith('{') && mediaType != OpdsMime.atom)) {
    return _parseOpds2(body, baseUri);
  }
  return _parseAtom(body, baseUri);
}

// ---------------------------------------------------------------------------
// OPDS 1.2 — Atom XML
// ---------------------------------------------------------------------------

OpdsFeed _parseAtom(String body, Uri baseUri) {
  final XmlDocument document = XmlDocument.parse(body);
  final XmlElement root = document.rootElement;
  if (!_isAtom(root, 'feed')) {
    throw const FormatException('Expected an Atom feed');
  }

  final List<OpdsLink> feedLinks = root.childElements
      .where((XmlElement element) => _isAtom(element, 'link'))
      .map((XmlElement element) => _atomLink(element, baseUri))
      .whereType<OpdsLink>()
      .toList(growable: false);

  final List<OpdsEntry> publications = <OpdsEntry>[];
  final List<OpdsLink> navigation = <OpdsLink>[];

  for (final XmlElement entry in root.childElements
      .where((XmlElement element) => _isAtom(element, 'entry'))) {
    final List<OpdsLink> links = entry.childElements
        .where((XmlElement element) => _isAtom(element, 'link'))
        .map((XmlElement element) => _atomLink(element, baseUri))
        .whereType<OpdsLink>()
        .toList(growable: false);

    final String title = _text(entry, 'title') ?? '';
    final bool isPublication = links.any((OpdsLink link) => link.isAcquisition);

    if (isPublication) {
      publications.add(
        OpdsEntry(
          title: title,
          links: links,
          authors: entry.childElements
              .where((XmlElement element) => _isAtom(element, 'author'))
              .map((XmlElement author) => _text(author, 'name'))
              .whereType<String>()
              .toList(growable: false),
          summary: _text(entry, 'summary') ?? _text(entry, 'content'),
          identifier: _text(entry, 'id'),
          language: _nsText(entry, _Ns.dcTerms, 'language') ??
              _nsText(entry, _Ns.dc, 'language'),
          publisher: _nsText(entry, _Ns.dcTerms, 'publisher') ??
              _nsText(entry, _Ns.dc, 'publisher'),
          published: _text(entry, 'published') ?? _text(entry, 'updated'),
          subjects: entry.childElements
              .where((XmlElement element) => _isAtom(element, 'category'))
              .map((XmlElement category) =>
                  category.getAttribute('label') ??
                  category.getAttribute('term'))
              .whereType<String>()
              .toList(growable: false),
        ),
      );
      continue;
    }

    // A navigation entry points at another feed. Prefer a link that says it is
    // a catalog, and fall back to the first link the entry offers.
    final OpdsLink? target =
        links.where((OpdsLink link) => link.isCatalog).firstOrNull ??
            links.firstOrNull;
    if (target != null) {
      navigation.add(
        OpdsLink(
          rels: target.rels,
          href: target.href,
          type: target.type,
          // The entry's own title beats the link's, which is usually absent.
          title: title.isEmpty ? target.title : title,
          numberOfItems: target.numberOfItems,
        ),
      );
    }
  }

  return OpdsFeed(
    title: _text(root, 'title') ?? '',
    publications: publications,
    navigation: navigation,
    facetGroups: _facetGroups(feedLinks),
    searchLink: feedLinks
        .where((OpdsLink link) => link.rels.contains('search'))
        .firstOrNull,
    nextHref: _relHref(feedLinks, 'next'),
    previousHref:
        _relHref(feedLinks, 'previous') ?? _relHref(feedLinks, 'prev'),
  );
}

bool _isAtom(XmlElement element, String name) {
  // A feed may declare no namespace at all. Matching on the local name keeps
  // those readable, which is what the JavaScript does.
  final String? uri = element.name.namespaceUri;
  return element.name.local == name && (uri == null || uri == _Ns.atom);
}

OpdsLink? _atomLink(XmlElement element, Uri baseUri) {
  final String? href = element.getAttribute('href');
  if (href == null || href.isEmpty) {
    return null;
  }

  final List<String> rels = (element.getAttribute('rel') ?? '')
      .split(RegExp(r' +'))
      .where((String rel) => rel.isNotEmpty)
      .toList();

  // An active facet is marked by an attribute rather than by a rel, so it is
  // folded into the rels the way the JavaScript folds it.
  if (element.getAttribute('activeFacet', namespace: _Ns.opds) == 'true') {
    rels.add('self');
  }

  final XmlElement? price = element.childElements
      .where((XmlElement child) =>
          child.name.local == 'price' && child.name.namespaceUri == _Ns.opds)
      .firstOrNull;

  return OpdsLink(
    rels: rels,
    href: baseUri.resolve(href),
    type: element.getAttribute('type'),
    title: element.getAttribute('title'),
    facetGroup: element.getAttribute('facetGroup', namespace: _Ns.opds),
    price: price == null
        ? null
        : OpdsPrice(
            currency: price.getAttribute('currencycode'),
            value: price.innerText.trim(),
          ),
    numberOfItems: int.tryParse(
      element.getAttribute('count', namespace: _Ns.thread) ?? '',
    ),
  );
}

String? _text(XmlElement parent, String name) {
  final XmlElement? element = parent.childElements
      .where((XmlElement child) => _isAtom(child, name))
      .firstOrNull;
  final String? value = element?.innerText.trim();
  return (value == null || value.isEmpty) ? null : value;
}

String? _nsText(XmlElement parent, String namespace, String name) {
  final XmlElement? element = parent.childElements
      .where((XmlElement child) =>
          child.name.local == name && child.name.namespaceUri == namespace)
      .firstOrNull;
  final String? value = element?.innerText.trim();
  return (value == null || value.isEmpty) ? null : value;
}

// ---------------------------------------------------------------------------
// OPDS 2.0 — JSON
// ---------------------------------------------------------------------------

OpdsFeed _parseOpds2(String body, Uri baseUri) {
  final Object? decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('an OPDS 2.0 feed must be a JSON object');
  }
  if (decoded['metadata'] is! Map<String, dynamic> ||
      !['publications', 'navigation', 'groups'].any(decoded.containsKey)) {
    throw const FormatException('Expected an OPDS catalog');
  }

  final List<OpdsLink> feedLinks = _jsonLinks(decoded['links'], baseUri);

  final List<OpdsEntry> publications =
      (decoded['publications'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> publication) {
    final Map<String, dynamic> metadata =
        publication['metadata'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final List<OpdsLink> links = <OpdsLink>[
      ..._jsonLinks(publication['links'], baseUri),
      // Images are a separate array in OPDS 2.0. Tagging them with the 1.2
      // rel keeps one cover lookup for both generations.
      ..._jsonLinks(publication['images'], baseUri, addRel: OpdsRel.cover[0]),
    ];

    return OpdsEntry(
      title: metadata['title']?.toString() ?? '',
      links: links,
      authors: _people(metadata['author']),
      summary: metadata['description']?.toString(),
      identifier: metadata['identifier']?.toString(),
      language: metadata['language'] is List
          ? (metadata['language'] as List<dynamic>).firstOrNull?.toString()
          : metadata['language']?.toString(),
      publisher: _people(metadata['publisher']).firstOrNull,
      published: metadata['published']?.toString(),
      subjects: _people(metadata['subject']),
    );
  }).toList(growable: false);

  final List<OpdsLink> navigation = _jsonLinks(decoded['navigation'], baseUri);

  // OPDS 2.0 groups carry sub-feeds. Their links join the navigation, so a
  // browse screen shows one list rather than a special case per generation.
  for (final Map<String, dynamic> group
      in (decoded['groups'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()) {
    navigation.addAll(_jsonLinks(group['navigation'], baseUri));
  }

  final Map<String, dynamic> metadata =
      decoded['metadata'] as Map<String, dynamic>? ?? <String, dynamic>{};

  return OpdsFeed(
    title: metadata['title']?.toString() ?? '',
    publications: publications,
    navigation: navigation,
    facetGroups: _facetGroups(feedLinks),
    searchLink: feedLinks
        .where((OpdsLink link) => link.rels.contains('search'))
        .firstOrNull,
    nextHref: _relHref(feedLinks, 'next'),
    previousHref:
        _relHref(feedLinks, 'previous') ?? _relHref(feedLinks, 'prev'),
  );
}

List<OpdsLink> _jsonLinks(Object? value, Uri baseUri, {String? addRel}) {
  if (value is! List) {
    return <OpdsLink>[];
  }
  return value
      .whereType<Map<String, dynamic>>()
      .map((Map<String, dynamic> link) {
        final String? href = link['href']?.toString();
        if (href == null || href.isEmpty) {
          return null;
        }
        final Object? rel = link['rel'];
        return OpdsLink(
          rels: <String>[
            if (rel is String) rel,
            if (rel is List) ...rel.map((Object? each) => each.toString()),
            if (addRel != null) addRel,
          ],
          href: baseUri.resolve(href),
          type: link['type']?.toString(),
          title: link['title']?.toString(),
          numberOfItems: link['properties'] is Map<String, dynamic>
              ? int.tryParse(
                  (link['properties'] as Map<String, dynamic>)['numberOfItems']
                          ?.toString() ??
                      '',
                )
              : null,
        );
      })
      .whereType<OpdsLink>()
      .toList();
}

List<String> _people(Object? value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is String) {
    return <String>[value];
  }
  if (value is Map<String, dynamic>) {
    final String? name = value['name']?.toString();
    return name == null ? const <String>[] : <String>[name];
  }
  if (value is List) {
    return value.expand(_people).toList(growable: false);
  }
  return const <String>[];
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

List<OpdsFacetGroup> _facetGroups(List<OpdsLink> links) {
  final Map<String, List<OpdsLink>> groups = <String, List<OpdsLink>>{};
  for (final OpdsLink link in links) {
    if (!link.rels.contains(OpdsRel.facet)) {
      continue;
    }
    // A facet with no group of its own still belongs somewhere, or it is lost.
    final String group = link.facetGroup ?? link.title ?? '';
    groups.putIfAbsent(group, () => <OpdsLink>[]).add(link);
  }
  return groups.entries
      .map((MapEntry<String, List<OpdsLink>> entry) =>
          OpdsFacetGroup(title: entry.key, links: entry.value))
      .toList(growable: false);
}

Uri? _relHref(List<OpdsLink> links, String rel) {
  for (final OpdsLink link in links) {
    if (link.rels.contains(rel)) {
      return link.href;
    }
  }
  return null;
}
