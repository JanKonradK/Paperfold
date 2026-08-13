import 'dart:convert';

import 'package:paperfold/service/book_player/book_player_server.dart';

/// Where a reader font comes from.
///
/// A bundled face ships in the application and is served straight out of the
/// asset bundle. An imported face is a file the reader added, which lives in
/// the font directory on disk. Both reach the WebView over the local server,
/// but from different routes, so the source has to survive a round trip
/// through preferences.
enum FontSource {
  builtIn,
  bundled,
  imported,
}

class FontModel {
  final String label;
  final String name;
  final FontSource source;
  String path;

  FontModel({
    required this.label,
    required this.name,
    required this.path,
    this.source = FontSource.imported,
  });

  /// A face that ships with the application.
  ///
  /// [name] is the CSS family the reader stylesheet asks for, so it must match
  /// the family the WebView declares in its `@font-face` rule.
  factory FontModel.bundled({
    required String label,
    required String name,
    required String fileName,
  }) {
    return FontModel(
      label: label,
      name: name,
      path: bundledFontUrl(fileName),
      source: FontSource.bundled,
    );
  }

  /// A choice that names no file: follow the book, or use the system face.
  factory FontModel.builtIn({required String label, required String name}) {
    return FontModel(
      label: label,
      name: name,
      path: name,
      source: FontSource.builtIn,
    );
  }

  static String bundledFontUrl(String fileName) =>
      'http://127.0.0.1:${Server().port}/bundled-fonts/$fileName';

  String toJson() {
    return '''
    {
      "label": "$label",
      "name": "$name",
      "source": "${source.name}",
      "path": "${path.split('/').last}"
    }
    ''';
  }

  String get litePath => path.split('/').last;

  static FontModel fromJson(String fontJson) {
    final Map<String, dynamic> json = jsonDecode(fontJson);
    final source = FontSource.values.firstWhere(
      (value) => value.name == json['source'],
      // Preferences written before bundled faces existed carry no source, and
      // every font they could name was an imported one.
      orElse: () => FontSource.imported,
    );
    final fileName = json['path'];
    return FontModel(
      label: json['label'],
      name: json['name'],
      source: source,
      path: switch (source) {
        FontSource.builtIn => fileName,
        FontSource.bundled => bundledFontUrl(fileName),
        FontSource.imported =>
          'http://127.0.0.1:${Server().port}/fonts/$fileName',
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontModel &&
          runtimeType == other.runtimeType &&
          litePath == other.litePath;

  @override
  int get hashCode => name.hashCode ^ path.hashCode;
}
