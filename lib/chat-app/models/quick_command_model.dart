class QuickCommandModel {
  final String name;
  final String? description;

  final String content; // 快捷指令发送的内容
  final int? optionId; // 发送时使用的预设(会被角色绑定预设覆盖)
  final int characterId; // 快捷指令发给的角色（只在关闭isreplaceLastMessage时有用，默认为-1，即默认AI助手）

  final bool isInsertIntoChat; // 发送的快捷指令是否插入聊天
  final bool isReplaceLastMessage; // （重写模式）快捷指令的响应是否会替换最新的消息（只替换内容）

  QuickCommandModel({
    required this.name,
    this.description,
    required this.content,
    this.optionId,
    this.characterId = -1,
    this.isInsertIntoChat = true,
    this.isReplaceLastMessage = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'content': content,
      'optionId': optionId,
      'characterId': characterId,
      'isInsertIntoChat': isInsertIntoChat,
      'isReplaceLastMessage': isReplaceLastMessage,
    };
  }

  QuickCommandModel.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        description = json['description'],
        content = json['content'],
        optionId = json['optionId'],
        characterId = json['characterId'] ?? -1,
        isInsertIntoChat = json['isInsertIntoChat'] ?? true,
        isReplaceLastMessage = json['isReplaceLastMessage'] ?? false;

  copyWith({
    String? name,
    String? description,
    String? content,
    int? optionId,
    int? characterId,
    bool? isInsertIntoChat,
    bool? isReplaceLastMessage,
  }) {
    return QuickCommandModel(
      name: name ?? this.name,
      description: description ?? this.description,
      content: content ?? this.content,
      optionId: optionId ?? this.optionId,
      characterId: characterId ?? this.characterId,
      isInsertIntoChat: isInsertIntoChat ?? this.isInsertIntoChat,
      isReplaceLastMessage: isReplaceLastMessage ?? this.isReplaceLastMessage,
    );
  }
}
