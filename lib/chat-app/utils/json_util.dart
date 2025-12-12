import 'dart:convert';

class JsonUtil {
  static String? encode(dynamic data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return null;
    }
  }

  static String format(String json) {
    if (json.trim().isEmpty) return json;
    try {
      final dynamic data = jsonDecode(json);
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return json;
    }
  }

  static String formatMap(dynamic data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data;
    }
  }
}
