class MemoryEntryModel {
  final int id;

  /// 记忆正文内容
  final String content;

  /// 创建时间
  final DateTime createdAt;

  /// 是否启用
  bool isActive;

  MemoryEntryModel({
    required this.id,
    required this.content,
    DateTime? createdAt,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'isActive': isActive,
      };

  factory MemoryEntryModel.fromJson(Map<String, dynamic> json) {
    return MemoryEntryModel(
      id: (json['id'] is String) ? int.parse(json['id']) : json['id'],
      content: json['content'] as String,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  MemoryEntryModel copyWith({
    int? id,
    String? content,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return MemoryEntryModel(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class MemoryModel {
  /// 长期/辅助记忆条目
  final List<MemoryEntryModel> entries;

  /// 短期/默认记忆 — 一段长文本，始终注入到 prompt 中。 
  String defaultMemory;

  MemoryModel({
    List<MemoryEntryModel>? entries,
    this.defaultMemory = '',
  }) : entries = entries ?? [];

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
        'defaultMemory': defaultMemory,
      }; 

  factory MemoryModel.fromJson(dynamic json) {
    if (json == null) return MemoryModel();
    // 兼容旧格式：纯数组
    if (json is List) {
      return MemoryModel(
        entries: json
            .map((e) => MemoryEntryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }
    // 新格式：{entries: [...], defaultMemory: '...'}
    if (json is Map<String, dynamic>) {
      return MemoryModel(
        entries: (json['entries'] as List<dynamic>?)
                ?.map((e) =>
                    MemoryEntryModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        defaultMemory: json['defaultMemory'] as String? ?? '',
      );
    }
    return MemoryModel();
  }

  MemoryModel copyWith({
    List<MemoryEntryModel>? entries,
    String? defaultMemory,
  }) {
    return MemoryModel(
      entries: entries ?? List<MemoryEntryModel>.from(this.entries),
      defaultMemory: defaultMemory ?? this.defaultMemory,
    );
  }
}
