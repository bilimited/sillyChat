import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/character_model.dart';
import '../models/prompt_model.dart';

class BackupData {
  final List<CharacterModel> characters;
  final List<PromptModel> prompts;

  BackupData({required this.characters, required this.prompts});

  Map<String, dynamic> toJson() => {
        'characters': characters.map((c) => c.toJson()).toList(),
        'prompts': prompts.where((p) => !p.isDefault).map((p) => p.toJson()).toList(),
      };

  static BackupData fromJson(Map<String, dynamic> json) {
    return BackupData(
      characters: (json['characters'] as List)
          .map((c) => CharacterModel.fromJson(c))
          .toList(),
      prompts: (json['prompts'] as List)
          .map((p) => PromptModel.fromJson(p))
          .toList(),
    );
  }
}

class BackupHelper {
  static Future<void> exportData(List<CharacterModel> characters, List<PromptModel> prompts) async {
    try {
      final data = BackupData(characters: characters, prompts: prompts);
      final jsonStr = jsonEncode(data.toJson());
      
      final directory = await getDownloadsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory!.path}/backup_$timestamp.json');
      await file.writeAsString(jsonStr);
    } catch (e) {
      throw Exception('导出失败: $e');
    }
  }

  static Future<BackupData?> importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();
        final json = jsonDecode(jsonStr);
        return BackupData.fromJson(json);
      }
      return null;
    } catch (e) {
      throw Exception('导入失败: $e');
    }
  }
}
