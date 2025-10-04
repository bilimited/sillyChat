import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';

class AutoTitleSettingModel {
  final bool enabled;
  final int level; // 生成标题的楼层(默认读取所有楼层)
  final ChatOptionModel option; // 生成标题使用的预设

  AutoTitleSettingModel({
    required this.enabled,
    required this.level,
    required this.option,
  });

  toJson() {
    return {
      'enabled': enabled,
      'level': level,
      'option': option.toJson(),
    };
  }

  factory AutoTitleSettingModel.fromJson(Map<String, dynamic> json) {
    return AutoTitleSettingModel(
      enabled: json['enabled'] ?? false,
      level: json['level'] ?? 1,
      option: json['option'] != null
          ? ChatOptionModel.fromJson(json['option'])
          : defaultOption,
    );
  }

  AutoTitleSettingModel copyWith({
    bool? enabled,
    int? level,
    ChatOptionModel? option,
  }) {
    return AutoTitleSettingModel(
      enabled: enabled ?? this.enabled,
      level: level ?? this.level,
      option: option ?? this.option,
    );
  }

  static ChatOptionModel get defaultOption {
    int id = DateTime.now().microsecondsSinceEpoch;
    return ChatOptionModel(
        id: 0,
        name: '自动标题',
        requestOptions: const LLMRequestOptions(messages: []),
        prompts: [
          PromptModel(
              id: id,
              content: '<messageList>',
              role: 'user',
              name: '消息列表',
              isChatHistory: true),
          PromptModel(
            id: id + 1,
            content: '''请根据以上聊天记录生成一个简洁的标题，不超过10个字。
**你的输出应该只包含标题，不要包含其他任何语句**
你生成的标题是：''',
            role: 'user',
            name: '指令',
          ),
        ],
        regex: []);
  }
}
