import 'package:flutter_example/chat-app/models/regex_model.dart';

abstract class STRegexImporter {
  static RegexModel? fromJson(Map<String, dynamic> json, String fileName,
      {int? id}) {
    try {
      RegexModel regexModel = RegexModel(
          id: id ?? DateTime.now().microsecondsSinceEpoch,
          name: json['scriptName'] ?? fileName,
          pattern: json['findRegex'],
          replacement: json['replaceString']);

      regexModel.enabled = !(json['disabled'] ?? true);

      if (json['promptOnly'] == true) {
        regexModel.onRequest = true;
      } else {
        regexModel.onAddMessage = true;
      }

      regexModel.depthMin = json['minDepth'] ?? 0;
      regexModel.depthMax = json['maxDepth'] ?? -1;

      List<dynamic> placement = json['placement'];
      if (placement.contains(1)) {
        regexModel.scopeUser = true;
      }
      if (placement.contains(2)) {
        regexModel.scopeAssistant = true;
      }

      List<dynamic> trim = json['trimStrings'];
      regexModel.trim = trim.join('\n');

      return regexModel;
    } catch (e) {
      rethrow;
    }
  }
}
