import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';

class MiscSettingModel {
  final bool autoTitle_enabled;
  final int autoTitle_level; // 生成标题的楼层(默认读取所有楼层)
  final ChatOptionModel autotitleOption; // 生成标题使用的预设

  final ChatOptionModel summaryOption;
  final ChatOptionModel genMemOption;

  final ChatOptionModel simulateUserOption;

  MiscSettingModel(
      {required this.autoTitle_enabled,
      required this.autoTitle_level,
      required this.autotitleOption,
      required this.summaryOption,
      required this.simulateUserOption,
      required this.genMemOption});

  toJson() {
    return {
      'autoTitle_enabled': autoTitle_enabled,
      'autoTitle_level': autoTitle_level,
      'autoTitleOption': autotitleOption.toJson(),
      'summaryOption': summaryOption.toJson(),
      'simulateUserOption': simulateUserOption.toJson(),
      'genMemOption': genMemOption.toJson()
    };
  }

  factory MiscSettingModel.fromJson(Map<String, dynamic> json) {
    return MiscSettingModel(
      autoTitle_enabled: json['autoTitle_enabled'] ?? false,
      autoTitle_level: json['autoTitle_level'] ?? 1,
      autotitleOption: json['autoTitleOption'] != null
          ? ChatOptionModel.fromJson(json['autoTitleOption'])
          : defaultAutoTitleOption,
      summaryOption: json['summaryOption'] != null
          ? ChatOptionModel.fromJson(json['summaryOption'])
          : defaultSummaryOption,
      simulateUserOption: json['simulateUserOption'] != null
          ? ChatOptionModel.fromJson(json['simulateUserOption'])
          : defaultSimulateUserOption,
      genMemOption: json['genMemOption'] != null
          ? ChatOptionModel.fromJson(json['genMemOption'])
          : defaultGenMemOption,
    );
  }

  MiscSettingModel copyWith({
    bool? enabled,
    int? level,
    ChatOptionModel? autotitleOption,
    ChatOptionModel? summaryOption,
    ChatOptionModel? simulateUserOption,
    ChatOptionModel? genMemOption,
  }) {
    return MiscSettingModel(
        autoTitle_enabled: enabled ?? this.autoTitle_enabled,
        autoTitle_level: level ?? this.autoTitle_level,
        autotitleOption: autotitleOption ?? this.autotitleOption,
        summaryOption: summaryOption ?? this.summaryOption,
        simulateUserOption: simulateUserOption ?? this.simulateUserOption,
        genMemOption: genMemOption ?? this.genMemOption);
  }

  static ChatOptionModel get defaultAutoTitleOption {
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

  static ChatOptionModel get defaultSummaryOption {
    return ChatOptionModel(
        id: 0,
        name: '总结',
        requestOptions: LLMRequestOptions(messages: []),
        prompts: [
          PromptModel.chatHistoryPlaceholder(),
          PromptModel(
              id: DateTime.now().microsecondsSinceEpoch,
              content:
                  '''Request:请将之前发生的事进行总结，按时间或逻辑顺序保留关键信息，省略冗余描述。请直接输出总结内容。''',
              role: 'user',
              name: '总结指令')
        ],
        regex: []);
  }

  static ChatOptionModel get defaultSimulateUserOption {
    return ChatOptionModel(
        id: 0,
        name: 'AI帮答',
        requestOptions: LLMRequestOptions(messages: []),
        prompts: [
          PromptModel.chatHistoryPlaceholder(),
          PromptModel(
              id: 2,
              content: '''请结合历史聊天记录，根据上下文以及{{user}}的对话风格，帮{{user}}生成3条不同的预选消息。
你应该直接输出所有的预选消息，消息之间用换行分隔，每一行只包含消息的内容。
                  ''',
              role: 'user',
              name: '指令')
        ],
        regex: []);
  }

  static ChatOptionModel get defaultGenMemOption {
    return ChatOptionModel(
        id: 0,
        name: '生成记忆',
        requestOptions: LLMRequestOptions(messages: []),
        prompts: [
          PromptModel.chatHistoryPlaceholder(),
          PromptModel(
              id: 2,
              content:
                  '''Request:请将之前发生的事进行总结，按时间或逻辑顺序保留关键信息，省略冗余描述。输出格式为：第一行是"{{time}}"，第二行是总结内容，第三行是空行。
现在直接输出总结。''',
              role: 'user',
              name: '指令')
        ],
        regex: []);
  }
}
