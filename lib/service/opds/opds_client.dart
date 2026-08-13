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
    final Response<String> response;

    try {
      response = await _dio.getUri<String>(
        target,
        options: Options(
          headers: <String, String>{
            'Accept': acceptHeader,
            ...await _authorization(catalog),
          },
          responseType: ResponseType.plain,
          // Every status is handled here rather than thrown as a DioException,
          // so a 401 can be told from a broken connection.
          validateStatus: (int? status) => true,
        ),
      );
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
    } on Exception catch (error) {
      throw OpdsException(OpdsFailure.notAFeed, detail: error.toString());
    }
  }

  /// The Authorization header for [catalog], or nothing.
  ///
  /// A catalog set to Basic with no stored password sends no header. The
  /// server answers 401, and the browse screen asks. That is better than
  /// sending an empty password and calling the result a server error.
  Future<Map<String, String>> _authorization(OpdsCatalog catalog) async {
    if (catalog.authType != OpdsAuthType.basic) {
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
