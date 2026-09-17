import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:paperfold/models/book.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

/// File metadata, independent of reader font size and screen pagination.
typedef SpineMetadata = ({
  String? series,
  String? volume,
  int? pages,
  bool estimated
});
const _empty = (series: null, volume: null, pages: null, estimated: false);
final _cache =
    <String, ({int modified, int size, Future<SpineMetadata> data})>{};
final _volume = RegExp(r'(?:vol(?:ume)?\.?|book)\s*(\d+(?:\.\d+)?)\s*$',
    caseSensitive: false);

Future<void> loadBookSpineMetadata(List<Book> books) async {
  // Read one file at a time so a large library cannot exhaust device memory.
  for (final book in books) {
    String? filePath;
    try {
      filePath = book.fileFullPath;
      if (path.extension(filePath).toLowerCase() != '.epub') continue;
      final stat = await File(filePath).stat();
      if (stat.type != FileSystemEntityType.file) continue;
      var cached = _cache[filePath];
      if (cached == null ||
          cached.modified != stat.modified.microsecondsSinceEpoch ||
          cached.size != stat.size) {
        cached = (
          modified: stat.modified.microsecondsSinceEpoch,
          size: stat.size,
          data: compute(_readFile, filePath)
        );
        _cache[filePath] = cached;
      }
      final metadata = await cached.data;
      book.series = metadata.series;
      book.volume = metadata.volume;
      book.pageCount = metadata.pages;
      book.pageCountEstimated = metadata.estimated;
    } catch (_) {
      // A missing file or failed isolate must not hide the library.
      _cache.remove(filePath);
    }
  }
  matchKnownBookSeries(books);
}

/// Older volumes can omit series metadata. Match only a known series title,
/// the same primary author, and an explicit volume number.
void matchKnownBookSeries(List<Book> books) {
  String author(Book book) => book.author
      .toLowerCase()
      .split(RegExp(r',|\s+and\s+|\s*&\s*'))
      .first
      .trim();
  for (final book in books) {
    book.volume =
        _tidyVolume(book.volume ?? _volume.firstMatch(book.title)?.group(1));
    if (book.series != null || book.volume == null) continue;
    final matches = books.where((other) =>
        other.series?.isNotEmpty == true &&
        author(other) == author(book) &&
        book.title.toLowerCase().startsWith('${other.series!.toLowerCase()} '));
    if (matches.isNotEmpty) book.series = matches.first.series;
  }
  // Numbered titles such as "Earthsea, Book 2" also identify their own series.
  for (final book in books) {
    if (book.series != null) continue;
    final match = _volume.firstMatch(book.title);
    if (match == null) continue;
    final title = book.title
        .substring(0, match.start)
        .replaceFirst(RegExp(r'[,\s:–—-]+$'), '')
        .trim();
    if (title.isNotEmpty) book.series = title;
  }
}

String? _tidyVolume(String? value) => value == null || value.trim().isEmpty
    ? null
    : (num.tryParse(value)?.toString() ?? value)
        .replaceFirst(RegExp(r'\.0$'), '');

SpineMetadata _readFile(String filePath) {
  try {
    return readEpubSpineMetadata(File(filePath).readAsBytesSync());
  } catch (_) {
    // Metadata is optional. A damaged or protected book must not hide a shelf.
    return _empty;
  }
}

@visibleForTesting
SpineMetadata readEpubSpineMetadata(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  XmlDocument? document(String name) {
    final entry = archive.findFile(name);
    if (entry == null || entry.size > 16 * 1024 * 1024) return null;
    try {
      return XmlDocument.parse(
          utf8.decode(entry.content as List<int>, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  Iterable<XmlElement> elements(XmlNode node, String name) => node.descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == name);
  final container = document('META-INF/container.xml');
  final opfPath = container == null
      ? null
      : elements(container, 'rootfile').firstOrNull?.getAttribute('full-path');
  final opf = opfPath == null ? null : document(opfPath);
  if (opf == null) return _empty;
  final metadata = elements(opf, 'metadata').firstOrNull;
  final meta =
      metadata == null ? <XmlElement>[] : elements(metadata, 'meta').toList();
  String? series;
  String? volume;
  int? pages;
  String value(XmlElement e) =>
      (e.getAttribute('content') ?? e.innerText).trim();
  for (final e in meta) {
    if (e.getAttribute('name') == 'calibre:series') series = value(e);
    if (e.getAttribute('name') == 'calibre:series_index') volume = value(e);
    if (e.getAttribute('property') == 'belongs-to-collection') {
      final id = e.getAttribute('id');
      final refinements =
          meta.where((r) => id != null && r.getAttribute('refines') == '#$id');
      final collectionType = refinements
          .where((r) => r.getAttribute('property') == 'collection-type')
          .map(value)
          .firstOrNull;
      if (collectionType == null || collectionType == 'series') {
        series = value(e);
        volume = refinements
            .where((r) => r.getAttribute('property') == 'group-position')
            .map(value)
            .firstOrNull;
      }
    }
    if (['schema:numberOfPages', 'page-count']
        .contains(e.getAttribute('property') ?? e.getAttribute('name'))) {
      pages = int.tryParse(value(e));
    }
  }
  final manifest = {
    for (final e in elements(opf, 'item')) e.getAttribute('id'): e
  };
  String resolve(String href) => path.posix.normalize(path.posix.join(
      path.posix.dirname(opfPath!),
      Uri.decodeComponent(href.split('#').first)));
  void countPages(Iterable<String> labels) {
    final values = labels.toList();
    if (values.isEmpty) return;
    final numeric = values.map(int.tryParse).whereType<int>();
    final count = numeric.isEmpty ? values.length : numeric.reduce(math.max);
    if (count > 0) pages = math.max(pages ?? 0, count);
  }

  for (final item in manifest.values) {
    final href = item.getAttribute('href');
    if (href == null) continue;
    if ((item.getAttribute('properties') ?? '').split(' ').contains('nav')) {
      final nav = document(resolve(href));
      if (nav == null) continue;
      for (final e in elements(nav, 'nav')) {
        if (e.attributes.any((a) =>
            a.name.local == 'type' &&
            a.value.split(' ').contains('page-list'))) {
          countPages(elements(e, 'a').map((a) => a.innerText.trim()));
        }
      }
    } else if (item.getAttribute('media-type') == 'application/x-dtbncx+xml') {
      final ncx = document(resolve(href));
      if (ncx != null) {
        countPages(elements(ncx, 'pageTarget')
            .map((e) => e.getAttribute('value') ?? e.innerText.trim()));
      }
    }
  }
  final printedPages = pages != null && pages! > 0;
  if (!printedPages) {
    var words = 0;
    var illustratedPages = 0;
    final seen = <String>{};
    for (final ref in elements(opf, 'itemref')) {
      if (ref.getAttribute('linear') == 'no') continue;
      final href = manifest[ref.getAttribute('idref')]?.getAttribute('href');
      if (href == null || !seen.add(href)) continue;
      final chapter = document(resolve(href));
      if (chapter == null) continue;
      final body = elements(chapter, 'body').firstOrNull;
      if (body == null) continue;
      final text =
          body.descendants.whereType<XmlText>().map((t) => t.value).join(' ');
      words += RegExp(r'\S+').allMatches(text).length;
      // Fixed-layout illustrated books can have almost no text.
      if (elements(body, 'img').isNotEmpty ||
          elements(body, 'image').isNotEmpty) {
        illustratedPages++;
      }
    }
    pages = math.max((words / 250).ceil(), illustratedPages);
  }
  return (
    series: series?.isEmpty == true ? null : series,
    volume: _tidyVolume(volume),
    pages: pages != null && pages! > 0 ? pages : null,
    estimated: !printedPages && pages != null && pages! > 0
  );
}
