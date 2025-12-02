class PromptModel {
  int id;
  String content;
  String role;
  DateTime createDate;
  DateTime updateDate;
  String name;

  bool isInChat = false;

  bool isEnable = true;

  int priority;
  int depth; // prompt排序，0代表最新消息之后，1代表最新消息之前

  bool isChatHistory; // 占位符，在提示词列表中代表整个消息列表

  PromptModel({
    required this.id,
    required this.content,
    required this.role,
    required this.name,
    DateTime? createDate,
    DateTime? updateDate,
    bool this.isInChat = false,
    bool this.isChatHistory = false,
    this.priority = 100,
    this.depth = 4,
  })  : this.createDate = createDate ?? DateTime.now(),
        this.updateDate = updateDate ?? DateTime.now();

  PromptModel.chatHistoryPlaceholder()
      : id = 0,
        content = 'messageList',
        role = '',
        name = '消息列表',
        isEnable = true,
        createDate = DateTime.now(),
        updateDate = DateTime.now(),
        isChatHistory = true,
        priority = 100,
        depth = 4;

  PromptModel.userMessagePlaceholder()
      : id = -1,
        content = '{{lastuserMessage}}',
        role = 'user',
        name = '用户消息',
        isEnable = true,
        createDate = DateTime.now(),
        updateDate = DateTime.now(),
        isChatHistory = false,
        priority = 100,
        depth = 4;

  PromptModel.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        content = json['content'],
        role = json['role'],
        name = json['name'],
        createDate = DateTime.parse(json['createDate']),
        updateDate = DateTime.parse(json['updateDate']),
        isEnable = json['isEnable'] ?? true,
        priority = json['priority'] ?? 100,
        depth = json['depth'] ?? 4,
        isInChat = json['isInChat'] ?? false,
        isChatHistory = json['isMessageList'] ?? false;

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'role': role,
        'name': name,
        'createDate': createDate.toIso8601String(),
        'updateDate': updateDate.toIso8601String(),
        'isEnable': isEnable,
        'priority': priority,
        'depth': depth,
        'isInChat': isInChat,
        'isMessageList': isChatHistory
      };

  PromptModel copy() {
    return PromptModel(
      id: id,
      content: content,
      role: role,
      name: name,
      createDate: createDate,
      updateDate: updateDate,
      isInChat: isInChat,
      isChatHistory: isChatHistory,
      depth: depth,
      priority: priority,
    )..isEnable = isEnable;
  }

  PromptModel copyWith({
    int? id,
    String? content,
    String? role,
    String? name,
    DateTime? createDate,
    DateTime? updateDate,
    bool? isInChat,
    bool? isEnable,
    int? priority,
    int? depth,
  }) {
    return PromptModel(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      name: name ?? this.name,
      createDate: createDate ?? this.createDate,
      updateDate: updateDate ?? this.updateDate,
      isInChat: isInChat ?? this.isInChat,
      isChatHistory: this.isChatHistory, // 保持isMessageList不变
    )
      ..isEnable = isEnable ?? this.isEnable
      ..priority = priority ?? this.priority
      ..depth = depth ?? this.depth;
  }
}
