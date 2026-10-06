import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:paperfold/models/opds_catalog.dart';
import 'package:paperfold/service/opds/opds.dart';
import 'package:paperfold/service/opds/opds_credentials.dart';

/// Why a feed could not be read.
///
/// The browse screen has to tell these apart: a wrong password is the reader's
/// to fix, a server that is down is not, and a body that is not a feed usually
/// means the address points at a web page instead of a catalog.
enum OpdsFailure { network, unauthorized, notFound, server, notAFeed }

class OpdsException implements Exception {
  const OpdsException(this.failure, {this.statusCode, this.detail});

  final OpdsFailure failure;
  final int? statusCode;
  final String? detail;

  @override
  String toString() =>
      'OpdsException(${failure.name}, status: $statusCode, $detail)';
}

/// Fetches and parses OPDS feeds.
///
/// The parser in `opds.dart` takes a string. This is the part that has to talk
/// to a real server, so it is the part that carries authentication, redirects
/// and the failure cases.
class OpdsClient {
  OpdsClient({Dio? dio, OpdsCredentials? credentials})
      : _dio = dio ?? Dio(),
        _credentials = credentials ?? const KeystoreOpdsCredentials();

  final Dio _dio;
  final OpdsCredentials _credentials;

  /// What a client sends to say it would like a catalog, in either
  /// generation, and would rather not be handed a web page.
  static const String acceptHeader =
      'application/atom+xml;profile=opds-catalog, '
      'application/opds+json, application/atom+xml;q=0.9, */*;q=0.1';

  /// Reads the feed at [url] for [catalog].
  ///
  /// [url] defaults to the catalog's own address, so paging and navigation
  /// pass the link they followed.
  Future<OpdsFeed> fetchFeed(OpdsCatalog catalog, {Uri? url}) async {
    final Uri target = url ?? catalog.url;
    final Response<dynamic> response;

    try {
      response = await _request(catalog, target);
    } on DioException catch (error) {
      throw OpdsException(OpdsFailure.network, detail: error.message);
    }

    final int status = response.statusCode ?? 0;
    if (status == 401 || status == 403) {
      throw OpdsException(OpdsFailure.unauthorized, statusCode: status);
    }
    if (status == 404 || status == 410) {
      throw OpdsException(OpdsFailure.notFound, statusCode: status);
    }
    if (status < 200 || status >= 300) {
      throw OpdsException(OpdsFailure.server, statusCode: status);
    }

    final String body = response.data ?? '';
    try {
      return parseOpdsFeed(
        body,
        // The address the body actually came from, so a redirect does not
        // leave every relative link pointing at the old host.
        baseUri: response.realUri,
        contentType: response.headers.value('content-type'),
      );
    } catch (error) {
      throw OpdsException(OpdsFailure.notAFeed, detail: error.toString());
    }
  }

  /// Downloads [url] to [savePath] and returns the file.
  ///
  /// The caller hands the result to the existing import path, which already
  /// knows how to read a book file. plan.md Section 9.2: the import path
  /// exists, so point it at a downloaded file.
  Future<void> download(
    OpdsCatalog catalog,
    Uri url,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final Response<dynamic> response = await _request(
        catalog,
        url,
        savePath: savePath,
        onProgress: onProgress,
      );

      final int status = response.statusCode ?? 0;
      if (status == 401 || status == 403) {
        throw OpdsException(OpdsFailure.unauthorized, statusCode: status);
      }
      if (status == 404 || status == 410) {
        throw OpdsException(OpdsFailure.notFound, statusCode: status);
      }
      if (status < 200 || status >= 300) {
        throw OpdsException(OpdsFailure.server, statusCode: status);
      }
    } on DioException catch (error) {
      throw OpdsException(OpdsFailure.network, detail: error.message);
    }
  }

  /// The Authorization header for [catalog], or nothing.
  ///
  /// A catalog set to Basic with no stored password sends no header. The
  /// server answers 401, and the browse screen asks. That is better than
  /// sending an empty password and calling the result a server error.
  Future<Response<dynamic>> _request(
    OpdsCatalog catalog,
    Uri target, {
    String? savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    for (var redirects = 0; redirects <= 5; redirects++) {
      if ((target.scheme != 'https' && target.scheme != 'http') ||
          target.host.isEmpty) {
        throw const OpdsException(OpdsFailure.network,
            detail: 'Invalid catalog link');
      }
      final options = Options(
        headers: {
          if (savePath == null) 'Accept': acceptHeader,
          ...await _authorization(catalog, target),
        },
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (_) => true,
      );
      final response = savePath == null
          ? await _dio.getUri<String>(target, options: options)
          : await _dio.downloadUri(target, savePath,
              options: options, onReceiveProgress: onProgress);
      final location = response.headers.value('location');
      if (!const [301, 302, 303, 307, 308].contains(response.statusCode) ||
          location == null) {
        return response;
      }
      target = target.resolve(location);
    }
    throw const OpdsException(OpdsFailure.network,
        detail: 'Too many redirects');
  }

  Future<Map<String, String>> _authorization(
      OpdsCatalog catalog, Uri target) async {
    if (catalog.authType != OpdsAuthType.basic ||
        catalog.url.scheme != target.scheme ||
        catalog.url.host != target.host ||
        catalog.url.port != target.port) {
      return const <String, String>{};
    }
    final String? password = await _credentials.read(catalog.id);
    final String username = catalog.username ?? '';
    if (password == null || (username.isEmpty && password.isEmpty)) {
      return const <String, String>{};
    }
    final String token = base64Encode(utf8.encode('$username:$password'));
    return <String, String>{'Authorization': 'Basic $token'};
  }
}
