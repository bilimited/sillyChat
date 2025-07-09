class LorebookModel {
  /// 唯一标识符，用于在数据库或列表中查找和管理条目
  final String id;

  /// 条目名称，供用户识别和管理
  final String name;

  /// 实际的世界信息内容，这是会注入到LLM上下文中的文本
  final String content;

  /// 关键词列表，用于传统匹配（如果启用）
  final String keywords;

  final MatchingLogic logic;

  /// 激活条件：可以设置为 Always（总是激活），Keywords（关键词激活），或 Manual（手动激活，用于RAG等）
  final ActivationType activationType;

  /// 激活深度：对于关键词匹配，指示回溯多少条消息；对于RAG，指示检索多少个chunk
  final int activationDepth;

  /// 优先级：当上下文窗口有限时，优先级高的条目优先注入
  final int priority;

  /// 标签或分类：用于组织和过滤世界信息
  final List<String> tags;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime updatedAt;


  LorebookModel({
    required this.id,
    required this.name,
    required this.content,
    this.keywords = '',
    this.activationType = ActivationType.keywords,
    this.activationDepth = 3, // 默认回溯3条消息
    this.priority = 0, // 默认优先级
    this.tags = const [],
    this.logic = MatchingLogic.or,
    DateTime? createdAt,
    DateTime? updatedAt,

  }) : createdAt = createdAt ?? DateTime.now(),
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
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory LorebookModel.fromJson(Map<String, dynamic> json) {
    return LorebookModel(
      id: json['id'],
      name: json['name'],
      content: json['content'],
      keywords: json['keywords'],
      activationType: ActivationType.values.firstWhere(
          (e) => e.toString().split('.').last == json['activationType'],
          orElse: () => ActivationType.keywords),
      activationDepth: json['activationDepth'] ?? 3,
      priority: json['priority'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

enum ActivationType {
  always, // 总是激活，不推荐用于大量信息
  keywords, // 通过关键词匹配激活
  rag, // 通过语义相似性（RAG）激活
  manual, // 手动激活/停用（可能用于特殊场景或调试）
}

enum MatchingLogic{
  and,
  or,
  regex
}