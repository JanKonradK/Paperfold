import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/enums/lang_list.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/service/translate/index.dart';
import 'package:paperfold/utils/log/common.dart';

// The endpoint the Google Translate web page itself calls. It needs no key and
// returns plain JSON, so the popup shows text instead of an embedded web page
// with that site's cookie banner.
// ponytail: unofficial endpoint; if Google closes it, the API-key services
// in Settings remain.
const _url = 'https://translate.googleapis.com/translate_a/t';

class GoogleWebTranslateProvider extends TranslateServiceProvider {
  @override
  TranslateService get service => TranslateService.googleWeb;

  @override
  String getLabel(BuildContext context) => L10n.of(context).translateGoogleWeb;

  @override
  String mapLanguageCode(LangListEnum lang) =>
      lang == LangListEnum.auto ? 'auto' : lang.code;

  @override
  Widget translate(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
  }) {
    return convertStreamToWidget(translateStream(text, from, to));
  }

  @override
  Stream<String> translateStream(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
    bool isFullText = false,
  }) async* {
    yield '...';
    try {
      final response = await Dio().post<String>(
        _url,
        queryParameters: {
          'client': 'gtx',
          'sl': mapLanguageCode(from),
          'tl': mapLanguageCode(to),
          'format': 'text',
        },
        data: {'q': text},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      yield parseGoogleWebResponse(response.data ?? '');
    } catch (e) {
      AnxLog.severe('Translate Google Web Error: error=$e');
      yield* Stream.error(Exception(e));
    }
  }
}

/// `[["text","en"]]` when the source language is detected, `["text"]` when it
/// is given.
String parseGoogleWebResponse(String body) {
  final first = (jsonDecode(body) as List).first;
  final text = first is List ? first.first : first;
  if (text is! String || text.trim().isEmpty) {
    throw FormatException('Unexpected Google response: $body');
  }
  return text;
}
