import 'dart:convert';

import 'package:paperfold/enums/convert_chinese_mode.dart';

class ReadingRules {
  late ConvertChineseMode convertChineseMode;

  ReadingRules({required this.convertChineseMode});

  ReadingRules.fromJson(String json) {
    Map<String, dynamic> data = jsonDecode(json);
    convertChineseMode = getConvertChineseMode(data['convertChineseMode']);
  }

  String toJson() {
    return '''
    {
      "convertChineseMode": "${convertChineseMode.name}"
    }
    ''';
  }

  ReadingRules copyWith({ConvertChineseMode? convertChineseMode}) {
    return ReadingRules(
      convertChineseMode: convertChineseMode ?? this.convertChineseMode,
    );
  }
}
