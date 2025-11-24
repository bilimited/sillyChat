// 各种预设提示词/对话
class PromptSettingModel {
  // 用于让AI连续输出
  String continuePrompt = "继续";

  // 在连续Assistant消息之间添加的用户消息分隔符
  String interAssistantUserSeparator = "继续";

  // 群聊中添加在每条消息开头
  String groupFormatter = "<char>:<message>";

  // 是否格式化正文
  bool isFormatMainContent = false;

  PromptSettingModel();

  // JSON序列化
  Map<String, dynamic> toJson() {
    return {
      'continuePrompt': continuePrompt,
      'interAssistantUserSeparator': interAssistantUserSeparator,
      'groupFormatter': groupFormatter,
      'isFormatMainContent': isFormatMainContent,
    };
  }

  // 从JSON反序列化
  factory PromptSettingModel.fromJson(Map<String, dynamic> json) {
    return PromptSettingModel()
      ..continuePrompt = json['continuePrompt'] ?? "继续"
      ..interAssistantUserSeparator =
          json['interAssistantUserSeparator'] ?? "继续"
      ..isFormatMainContent = json['isFormatMainContent'] ?? false
      ..groupFormatter = json['groupFormatter'] ?? "<char>:<message>";
  }

  copyWith({
    String? continuePrompt,
    String? interAssistantUserSeparator,
    String? groupFormatter,
    bool? isFormatMainContent,
  }) {
    return PromptSettingModel()
      ..continuePrompt = continuePrompt ?? this.continuePrompt
      ..interAssistantUserSeparator =
          interAssistantUserSeparator ?? this.interAssistantUserSeparator
      ..groupFormatter = groupFormatter ?? this.groupFormatter
      ..isFormatMainContent = isFormatMainContent ?? this.isFormatMainContent;
  }
}
