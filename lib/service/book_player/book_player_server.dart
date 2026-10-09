import 'dart:io';
import 'dart:typed_data';

import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

class Server {
  static final Server _singleton = Server._internal();

  factory Server() {
    return _singleton;
  }

  Server._internal();

  HttpServer? _server;

  Future start() async {
    if (_server != null) {
      AnxLog.info(
        'Server: Existing instance detected on port ${_server?.port}, restarting',
      );
      await stop();
    }

    var handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(handleRequest);

    int port = Prefs().lastServerPort;

    try {
      _server = await io.serve(handler, '127.0.0.1', port);
    } catch (e, s) {
      AnxLog.warning(
        'Server: Failed to bind to port $port, trying random port $e',
        s,
      );
      _server = await io.serve(handler, '127.0.0.1', 0);
    }

    Prefs().lastServerPort = _server!.port;
    AnxLog.info(
      'Server: Serving at http://${_server?.address.host}:${_server?.port}',
    );
  }

  int get port {
    return _server!.port;
  }

  Future stop() async {
    if (_server == null) {
      return;
    }
    final stoppedPort = _server!.port;
    await _server?.close(force: true);
    _server = null;
    AnxLog.info('Server: Server stopped (port $stoppedPort)');
  }

  Future<String> _loadAsset(String path) async {
    return await rootBundle.loadString(path);
  }

  File? _tempFile;
  String? _tempFileName;

  String setTempFile(File file) {
    _tempFile = file;
    _tempFileName =
        '${DateTime.now().millisecondsSinceEpoch}.${file.path.split('.').last}';
    return _tempFileName!;
  }

  void clearTempFile() {
    _tempFile = null;
    _tempFileName = null;
  }

  @visibleForTesting
  Future<shelf.Response> handleRequest(shelf.Request request) async {
    final uriPath = request.requestedUri.path;
    AnxLog.info('Server: Request for $uriPath');

    if (_tempFileName != null && uriPath == "/${_tempFileName!}") {
      if (_tempFile == null || !await _tempFile!.exists()) {
        return shelf.Response.notFound('Book not found');
      }
      return shelf.Response.ok(
        _tempFile?.openRead(),
        headers: {
          'Content-Type': 'application/epub+zip',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    if (uriPath.startsWith('/book/')) {
      return _handleBookRequest(request);
    } else if (uriPath.startsWith('/js/')) {
      String content = await _loadAsset('assets/js/${path.basename(uriPath)}');
      return shelf.Response.ok(
        content,
        headers: {'Content-Type': 'application/javascript'},
      );
    } else if (uriPath.startsWith('/bundled-fonts/')) {
      // The faces that ship with the application. They live in the asset
      // bundle, not in the font directory that /fonts/ serves, and only the
      // names this map lists are reachable, so a path cannot walk out of it.
      const bundled = <String, String>{
        'Philosopher-Regular.ttf': 'assets/fonts/Philosopher-Regular.ttf',
        'Philosopher-Italic.ttf': 'assets/fonts/Philosopher-Italic.ttf',
        'Philosopher-Bold.ttf': 'assets/fonts/Philosopher-Bold.ttf',
        'Philosopher-BoldItalic.ttf': 'assets/fonts/Philosopher-BoldItalic.ttf',
        'SourceSans3-Regular.ttf': 'assets/fonts/SourceSans3-Regular.ttf',
        'SourceSans3-Italic.ttf': 'assets/fonts/SourceSans3-Italic.ttf',
        'SourceSans3-SemiBold.ttf': 'assets/fonts/SourceSans3-SemiBold.ttf',
        'SourceSans3-Bold.ttf': 'assets/fonts/SourceSans3-Bold.ttf',
        'SourceHanSerifSC-Regular.otf':
            'assets/fonts/SourceHanSerifSC-Regular.otf',
        'SourceHanSerifSC-Bold.otf': 'assets/fonts/SourceHanSerifSC-Bold.otf',
      };
      final assetPath = bundled[path.basename(Uri.decodeComponent(uriPath))];
      if (assetPath == null) {
        return shelf.Response.notFound('Font not found');
      }
      final data = await rootBundle.load(assetPath);
      return shelf.Response.ok(
        data.buffer.asUint8List(),
        headers: {
          'Content-Type': assetPath.endsWith('.otf') ? 'font/otf' : 'font/ttf',
          'Access-Control-Allow-Origin': '*',
          'cache-control': 'public, max-age=31536000',
        },
      );
    } else if (uriPath.startsWith('/fonts/')) {
      Directory fontDir = getFontDir();
      final file = File(
        '${fontDir.path}/${path.basename(Uri.decodeComponent(uriPath))}',
      );
      if (!_isInside(fontDir, file)) {
        return shelf.Response.notFound('Font not found');
      }
      return shelf.Response.ok(
        file.openRead(),
        headers: {
          'Content-Type': 'font/opentype',
          'Access-Control-Allow-Origin': '*',
          'cache-control': 'public, max-age=31536000',
        },
      );
    } else if (uriPath.startsWith('/foliate-js/')) {
      final relativePath = Uri.decodeComponent(uriPath.substring(12));
      if (relativePath.startsWith('/') ||
          relativePath.contains('\\') ||
          relativePath.contains('\u0000') ||
          relativePath.split('/').any((part) => part == '.' || part == '..')) {
        return shelf.Response.notFound('Reader asset not found');
      }
      const contentTypes = {
        '.html': 'text/html',
        '.css': 'text/css',
        '.js': 'application/javascript',
        '.mjs': 'application/javascript',
        '.json': 'application/json',
        '.epub': 'application/epub+zip',
        '.wasm': 'application/wasm',
        '.svg': 'image/svg+xml',
        '.ttf': 'font/ttf',
        '.otf': 'font/otf',
      };
      try {
        final data = await rootBundle.load('assets/foliate-js/$relativePath');
        return shelf.Response.ok(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          headers: {
            'Content-Type':
                contentTypes[path.extension(relativePath)] ??
                'application/octet-stream',
            'Access-Control-Allow-Origin': '*',
          },
        );
      } on FlutterError {
        return shelf.Response.notFound('Reader asset not found');
      }
    } else if (uriPath.startsWith('/bgimg/')) {
      return await _handleBgimgRequest(request);
    } else {
      return shelf.Response.ok(
        'Request for "${request.url}"',
        headers: {'Access-Control-Allow-Origin': '*'},
      );
    }
  }

  shelf.Response _handleBookRequest(shelf.Request request) {
    final bookPath = Uri.decodeComponent(request.url.path.substring(5));
    final file = File(bookPath);
    AnxLog.info('Server: Request for book: $bookPath');
    if (!_isInside(getFileDir(), file)) {
      return shelf.Response.notFound('Book not found');
    }
    final headers = {
      'Content-Type': 'application/epub+zip',
      'Access-Control-Allow-Origin': '*',
    };
    return shelf.Response.ok(file.openRead(), headers: headers);
  }

  Future<shelf.Response> _handleBgimgRequest(shelf.Request request) async {
    final bgimgPath = Uri.decodeComponent(request.url.path.substring(6));
    ByteBuffer? file;
    if (bgimgPath.startsWith('assets/')) {
      file = (await rootBundle.load(bgimgPath.substring(7))).buffer;
    } else if (bgimgPath.startsWith('local/')) {
      final path =
          getBgimgDir().path + Platform.pathSeparator + bgimgPath.substring(6);
      final image = File(path);
      if (!_isInside(getBgimgDir(), image)) {
        return shelf.Response.notFound('Bgimg not found');
      }
      file = (await image.readAsBytes()).buffer;
    } else {
      return shelf.Response.notFound('Bgimg not found');
    }
    final headers = {
      'Content-Type': 'image/png',
      'Access-Control-Allow-Origin': '*',
    };
    return shelf.Response.ok(file.asUint8List(), headers: headers);
  }

  bool _isInside(Directory directory, File file) {
    try {
      return file.existsSync() &&
          path.isWithin(
            directory.resolveSymbolicLinksSync(),
            file.resolveSymbolicLinksSync(),
          );
    } on FileSystemException {
      return false;
    }
  }
}
