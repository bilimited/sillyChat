// 预设导入器
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:get/get.dart';

abstract class SillytavernConfigImporter {
  /// 提示词机制：
  /// 相邻同role会合并成一条
  /// "聊天中"独立于其他提示词，按照Assistant,User,System的顺序排序。我草神经病吧
  static void fromJson(Map<String, dynamic> json, String fileName) {
    String ErrMsg = '导入未开始';
    try {
      ErrMsg = '转换请求参数';
      LLMRequestOptions llmRequestOptions = LLMRequestOptions(
        messages: [],
        maxTokens: json['openai_max_tokens'] as int,
        temperature: (json['temperature'] as num).toDouble(),
        frequencyPenalty: (json['frequency_penalty'] as num).toDouble(),
        presencePenalty: (json['presence_penalty'] as num).toDouble(),
        topP: (json['top_p'] as num).toDouble(),
        isStreaming: json['stream_openai']
      );
      List<PromptModel> prompts = [];

      ErrMsg = '导入Prompt';
      final List<dynamic> jsonPrompts = json['prompts'] as List<dynamic>;
      final Map<String, dynamic> allPrompts = {};
      jsonPrompts.forEach((json) {
        allPrompts[json['identifier']] = json;
      });

      ErrMsg = '导入PromptOrder';
      final List<dynamic> promptOrders = json['prompt_order'] as List<dynamic>;
      final List<dynamic> promptOrder = promptOrders
          .where((po) => po['character_id'] == 100001)
          .toList()[0]['order'];

      ErrMsg = '转换Prompt';
      int initialId = DateTime.now().microsecondsSinceEpoch;
      promptOrder.forEach((po) {
        final Map<String, dynamic> prompt = allPrompts[po['identifier']];

        if (prompt['marker'] == true) {
          String content = '';
          bool isPass = false;
          switch (prompt['identifier']) {
            case 'dialogueExamples':
              {
                content = "<lore id=2>\n<dialogueExamples>\n<lore id=3>";
                break;
              }
            case 'chatHistory':
              {
                content = "<messageList>";
                break;
              }
            case 'worldInfoAfter':
              {
                content = "<lore id=1>";
                break;
              }
            case 'worldInfoBefore':
              {
                content = "<lore id=0>";
                break;
              }
            case 'charDescription':
              {
                content = """
名称:<char>
<archive>

## 人物关系
<relations> 
""";
                break;
              }
            case 'charPersonality':
              {
                isPass = true;
                break;
              }
            case 'scenario':
              {
                content = ((json['scenario_format']??'<description>') as String).replaceAll('{{scenario}}', '<description>');
                break;
              }
            case 'personaDescription': // 用户角色描述
              {
                content = ((json['personality_format']??'<user>:<userbrief>') as String).replaceAll('{{char}}', '<user>')
                .replaceAll('{{personality}}', '<userbrief>');
                break;
              }
          }
          if (!isPass) {
            prompts.add(
              PromptModel(
                  id: initialId,
                  content: content,
                  role: prompt['system_prompt'] == true
                      ? 'system'
                      : prompt['role'] ?? 'user',
                  name: prompt['name'],
                  isInChat: prompt['injection_position'] == 1,
                  depth: prompt['injection_depth'] ?? 4,
                  priority: 100, // 未实现，不知道对应字段是啥
                  isChatHistory: prompt['identifier'] == 'chatHistory')
                ..isEnable = po['enabled'],
            );
          }
        } else {
          prompts.add(PromptModel(
              id: initialId,
              content: prompt['content'] ?? '',
              role: prompt['system_prompt'] == true
                  ? 'system'
                  : prompt['role'] ?? 'user',
              isInChat: prompt['injection_position'] == 1,
              depth: prompt['injection_depth'] ?? 4,
              priority: 100, // 未实现，不知道对应字段是啥
              name: prompt['name'])
            ..isEnable = po['enabled']);
        }
        initialId++;
      });

      ChatOptionModel chatOptionModel = ChatOptionModel(
          id: DateTime.now().microsecondsSinceEpoch,
          name: fileName,
          requestOptions: llmRequestOptions,
          prompts: prompts,
          regex: []);

      ChatOptionController controller = Get.find();
      controller.addChatOption(chatOptionModel);
      Get.snackbar('导入成功', '导入成功');
    } catch (e) {
      Get.snackbar('导入失败', '${ErrMsg};$e');
      rethrow;
    }
  }
}
