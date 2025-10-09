import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/utils/PackageValue.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';

class SummarySettingModel {
  final ChatOptionModel summaryOption;

  /** 
   * 总结并插入世界书的相关设置 
   */
  final ChatOptionModel lorebookSummaryOption;
  final int? loreBookToInsert; // 要插入的世界书ID
  final String defaultPosition; // 默认的“插入位置”属性
  final int defaultDepth;

  SummarySettingModel(
      {required this.summaryOption,
      required this.lorebookSummaryOption,
      this.loreBookToInsert,
      this.defaultDepth = 0,
      this.defaultPosition = 'after_char'});

  static ChatOptionModel defaultOption() {
    return ChatOptionModel(
        id: 0,
        name: '总结',
        requestOptions: LLMRequestOptions(messages: []),
        prompts: [
          PromptModel.chatHistoryPlaceholder(),
          PromptModel(
              id: DateTime.now().microsecondsSinceEpoch,
              content: '''Request:请将之前发生的事进行总结，按时间或逻辑顺序保留关键信息，省略冗余描述。''',
              role: 'user',
              name: '总结指令')
        ],
        regex: []);
  }

  factory SummarySettingModel.empty() {
    return SummarySettingModel(
      summaryOption: defaultOption(),
      lorebookSummaryOption: defaultOption(),
    );
  }

  toJson() {
    return {
      'summaryOption': summaryOption.toJson(),
      'loreBookToInsert': loreBookToInsert,
      'defaultPosition': defaultPosition,
      'lorebookSummaryOption': lorebookSummaryOption.toJson(),
      'defaultDepth': defaultDepth,
    };
  }

  factory SummarySettingModel.fromJson(Map<String, dynamic> json) {
    return SummarySettingModel(
      summaryOption: json['summaryOption'] != null
          ? ChatOptionModel.fromJson(json['summaryOption'])
          : defaultOption(),
      loreBookToInsert: json['loreBookToInsert'],
      defaultPosition: json['defaultPosition'] ?? 'after_char',
      lorebookSummaryOption: json['lorebookSummaryOption'] != null
          ? ChatOptionModel.fromJson(json['lorebookSummaryOption'])
          : defaultOption(),
      defaultDepth: json['defaultDepth'] ?? 0,
    );
  }

  copyWith({
    ChatOptionModel? option,
    PackageValue<int?>? loreBookToInsert,
    String? defaultPosition,
    ChatOptionModel? lorebookSummaryOption,
    int? defaultDepth,
  }) {
    return SummarySettingModel(
      summaryOption: option ?? this.summaryOption,
      loreBookToInsert: loreBookToInsert?.value ?? this.loreBookToInsert,
      defaultPosition: defaultPosition ?? this.defaultPosition,
      lorebookSummaryOption:
          lorebookSummaryOption ?? this.lorebookSummaryOption,
      defaultDepth: defaultDepth ?? this.defaultDepth,
    );
  }
}
