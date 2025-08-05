import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STLorebookImporter.dart';
import 'package:flutter_example/chat-app/widgets/alert_card.dart';
import 'package:get/get.dart';

abstract class STCharacterImporter {
  static Future<CharacterModel?> fromJson(
      Map<String, dynamic> json, String fileName, String filePath) async {
    try {
      Map<String, dynamic> data = json['data'];
      CharacterModel char = CharacterModel(
          id: DateTime.now().microsecondsSinceEpoch,
          remark: '',
          roleName: data['name'],
          avatar: filePath,
          category: '从ST导入');

      char.brief = data['personality']; // 这个其实是角色设定摘要
      char.firstMessage = data['first_mes'];
      char.moreFirstMessage =
          (data['alternate_greetings'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();

      char.archive =
          "${data['description']}\n${data['personality']}\n${data['scenario']}\n\n[Example Chat]\n${data['mes_example']}";

      if (data['extensions']?['regex_scripts'] != null) {
        bool? result = await Get.dialog(
          AlertDialog(
            title: Text('警告'),
            content: ModernAlertCard(
              child: Text('检测到包含正则脚本。SillyChat目前不支持角色内联正则和状态栏美化，因此正则脚本不会被导入。'),
              type: ModernAlertCardType.warning,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back(result: false);
                  throw Exception('用户取消导入');
                },
                child: Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Get.back(result: true);
                },
                child: Text('继续导入'),
              ),
            ],
          ),
          barrierDismissible: false,
        );

        if(result == false){
          return null;
        }
      }

      /// 未兼容的字段：
      /// 兼容内联正则（在支持WebView渲染前不需要加）
      /// data['depth_prompt'] （按深度插入，应该放世界书比较好）
      /// data['system_prompt'] data['post_history_instructions']  不知道有什么用
      ///
      /// 可能的问题：
      /// mes_example应该放在archive里还是CharacterModel的单独字段里？

      final characterBook = data['character_book'];

      try {
        LorebookModel? lorebookModel =
            STLorebookImporter.fromJson(characterBook);
        if (lorebookModel != null) {
          Get.find<LoreBookController>().addLorebook(lorebookModel);
          char.lorebookIds.add(lorebookModel.id);
        }
      } catch (e) {
        Get.snackbar('Lorebook未能导入', '$e');
      }

      return char;
    } catch (e) {
      rethrow;
    }
  }
}
