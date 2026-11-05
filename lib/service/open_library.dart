import 'package:dio/dio.dart';

/// Book details from Open Library, the catalog the plan names for metadata
/// lookup. It needs no account or key.
typedef OpenLibraryMatch = ({
  String key,
  String title,
  String author,
  int? year,
  int? coverId,
});

// Open Library asks callers to identify themselves.
final _dio = Dio(
  BaseOptions(
    baseUrl: 'https://openlibrary.org',
    headers: {'User-Agent': 'Paperfold (github.com/JanKonradK/Paperfold)'},
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ),
);

Future<List<OpenLibraryMatch>> searchOpenLibrary(String query) async {
  final response = await _dio.get<Map<String, dynamic>>(
    '/search.json',
    queryParameters: {
      'q': query,
      'fields': 'key,title,author_name,first_publish_year,cover_i',
      'limit': 20,
    },
  );
  return parseOpenLibrarySearch(response.data ?? const {});
}

List<OpenLibraryMatch> parseOpenLibrarySearch(Map<String, dynamic> json) => [
  for (final doc in (json['docs'] as List? ?? const []).cast<Map>())
    if (doc['key'] is String && doc['title'] is String)
      (
        key: doc['key'] as String,
        title: doc['title'] as String,
        author: (doc['author_name'] as List? ?? const []).join(', '),
        year: doc['first_publish_year'] as int?,
        coverId: doc['cover_i'] as int?,
      ),
];

/// The work's description. Open Library stores it as a string or as a
/// `{type, value}` object.
Future<String?> openLibraryDescription(String key) async {
  final response = await _dio.get<Map<String, dynamic>>('$key.json');
  return parseOpenLibraryDescription(response.data?['description']);
}

/// Contributors often append a rule and a list of source links, which do not
/// belong on a book's jacket.
String? parseOpenLibraryDescription(Object? description) {
  final text = switch (description) {
    String text => text,
    {'value': String text} => text,
    _ => null,
  };
  final kept = text?.split(RegExp(r'\r?\n-{3,}')).first.trim();
  return kept == null || kept.isEmpty ? null : kept;
}

Uri openLibraryCover(int id, {String size = 'L'}) =>
    Uri.parse('https://covers.openlibrary.org/b/id/$id-$size.jpg');

Future<void> downloadOpenLibraryCover(int id, String savePath) =>
    _dio.download(openLibraryCover(id).toString(), savePath);
