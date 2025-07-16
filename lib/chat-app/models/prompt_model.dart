
class PromptModel {
  int id;
  String content;
  String role;
  DateTime createDate;
  DateTime updateDate;
  String name;

  bool isDefault = false;

  bool isEnable = true;

  int? priority; // prompt排序，0代表最新消息之后，1代表最新消息之前

  bool isMessageList; // 占位符，在提示词列表中代表整个消息列表

  PromptModel({
    required this.id,
    required this.content,
    required this.role,
    required this.name,
    DateTime? createDate,
    DateTime? updateDate,
    bool this.isDefault = false,
    bool this.isMessageList = false,
  })  : this.createDate = createDate ?? DateTime.now(),
        this.updateDate = updateDate ?? DateTime.now();


  PromptModel.messageListPlaceholder()
      : id = 0,
        content = '<messageList>',
        role = '',
        name = '消息列表',
        isEnable = true,
        createDate = DateTime.now(),
        updateDate = DateTime.now(),
        isMessageList = true;

  PromptModel.userMessagePlaceholder()
      : id = -1,
        content = '<lastUserMessage>',
        role = 'user',
        name = '用户消息',
        isEnable = true,
        createDate = DateTime.now(),
        updateDate = DateTime.now(),
        isMessageList = false;

  PromptModel.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        content = json['content'],
        role = json['role'],
        name = json['name'],
        createDate = DateTime.parse(json['createDate']),
        updateDate = DateTime.parse(json['updateDate']),
        isEnable = json['isEnable'] ?? true,
        priority = json['priority'] ?? null,
        isMessageList = json['isMessageList'] ?? false;

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'role': role,
        'name': name,
        'createDate': createDate.toIso8601String(),
        'updateDate': updateDate.toIso8601String(),
        'isEnable': isEnable,
        'priority': priority,
        'isMessageList' : isMessageList
      };

  PromptModel copy() {
    return PromptModel(
      id: id,
      content: content,
      role: role,
      name: name,
      createDate: createDate,
      updateDate: updateDate,
      isDefault: isDefault,
      isMessageList: isMessageList
    )
      ..isEnable = isEnable
      ..priority = priority;
  }

  PromptModel copyWith({
    int? id,
    String? content,
    String? role,
    String? name,
    DateTime? createDate,
    DateTime? updateDate,
    bool? isDefault,
    bool? isEnable,
    int? priority,
  }) {
    return PromptModel(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      name: name ?? this.name,
      createDate: createDate ?? this.createDate,
      updateDate: updateDate ?? this.updateDate,
      isDefault: isDefault ?? this.isDefault,
      isMessageList: this.isMessageList, // 保持isMessageList不变
    )
      ..isEnable = isEnable ?? this.isEnable
      ..priority = priority ?? this.priority;
  }
}
