class LorebookItemModel {
  /// 唯一标识符，用于在数据库或列表中查找和管理条目
  final int id;

  /// 条目名称，供用户识别和管理
  final String name;

  /// 实际的世界信息内容，这是会注入到LLM上下文中的文本
  final String content;

  /// 关键词列表，用于传统匹配（如果启用）
  final String keywords;

  final MatchingLogic logic;

  /// 激活条件：可以设置为 Always（总是激活），Keywords（关键词激活），或 Manual（手动激活，用于RAG等）
  final ActivationType activationType;

  /// 是否激活
  bool isActive;

  /// 是否收藏
  final bool isFavorite;

  /// 激活深度：对于关键词匹配，指示回溯多少条消息；对于RAG，指示检索多少个chunk。0代表使用全局（世界书）设置。
  final int activationDepth;

  /// 优先级：当上下文窗口有限时，优先级高的条目优先注入
  final int priority;

  /// 插入位置。可能的取值：
  /// before_char、after_char
  /// before_em、after_em
  /// @Duser、@Dassistant、@Dsystem则插入到positionId层。 纯属为了兼容ST
  final String position;

  /// 插入位置的ID：用于指定条目在上下文中的插入位置
  final int positionId;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime updatedAt;

  LorebookItemModel(
      {required this.id,
      required this.name,
      required this.content,
      this.keywords = '',
      this.activationType = ActivationType.keywords,
      this.activationDepth = 0, // 默认回溯0条消息
      this.priority = 0, // 默认优先级
      this.logic = MatchingLogic.or,
      this.isActive = true, // 默认激活状态
      DateTime? createdAt,
      DateTime? updatedAt,
      this.positionId = 0, // 默认插入位置ID为0
      this.position = 'before_char', // 默认插入位置
      this.isFavorite = false})
      : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
  // JSON 序列化和反序列化方法
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'content': content,
        'keywords': keywords,
        'activationType': activationType.toString().split('.').last, // 枚举转字符串
        'activationDepth': activationDepth,
        'priority': priority,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isActive': isActive,
        'logic': logic.toString().split('.').last, // 枚举转字符串
        'position': position.toString().split('.').last, // 枚举转字符串
        'positionId': positionId,
        'isFavorite': isFavorite,
      };

  factory LorebookItemModel.fromJson(Map<String, dynamic> json) {
    return LorebookItemModel(
      id: (json['id'] is String) ? int.parse(json['id']) : json['id'],
      name: json['name'],
      content: json['content'],
      keywords: json['keywords'],
      activationType: ActivationType.values.firstWhere(
          (e) => e.toString().split('.').last == json['activationType'],
          orElse: () => ActivationType.keywords),
      activationDepth: json['activationDepth'] ?? 0,
      priority: json['priority'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      logic: MatchingLogic.values.firstWhere(
          (e) => e.toString().split('.').last == json['logic'],
          orElse: () => MatchingLogic.or),
      position: json['position'] ?? 'before_char',
      positionId: json['positionId'] ?? 0,
      isActive: json['isActive'] ?? true, // 默认激活状态为true
      isFavorite: json['isFavorite'] ?? false, // 默认非收藏
    );
  }

  LorebookItemModel copyWith({
    int? id,
    String? name,
    String? content,
    String? keywords,
    MatchingLogic? logic,
    ActivationType? activationType,
    bool? isActive,
    int? activationDepth,
    int? priority,
    int? positionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? position,
    bool? isFavorite,
  }) {
    return LorebookItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      keywords: keywords ?? this.keywords,
      logic: logic ?? this.logic,
      activationType: activationType ?? this.activationType,
      isActive: isActive ?? this.isActive,
      activationDepth: activationDepth ?? this.activationDepth,
      priority: priority ?? this.priority,
      position: position ?? this.position,
      positionId: positionId ?? this.positionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// 验证这个条目是否被激活
  /// content为根据激活深度裁剪并拼接得到的消息记录
  bool verify(String content) {
    if (activationType == ActivationType.keywords) {
      switch (logic) {
        case MatchingLogic.and:
          return keywords
              .split(',')
              .every((keyword) => content.contains(keyword.trim()));
        case MatchingLogic.or:
          return keywords
              .split(',')
              .any((keyword) => content.contains(keyword.trim()));
        case MatchingLogic.regex:
          final regex = RegExp(keywords);
          return regex.hasMatch(content);
      }
    }
    return false;
  }
}

enum ActivationType {
  always, // 总是激活，不推荐用于大量信息
  keywords, // 通过关键词匹配激活
  rag, // 通过语义相似性（RAG）激活
  manual, // 手动激活/停用（可能用于特殊场景或调试）
}

enum MatchingLogic { and, or, regex }
