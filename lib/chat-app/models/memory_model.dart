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
  final List<MemoryEntryModel> entries;

  MemoryModel({
    List<MemoryEntryModel>? entries,
  }) : entries = entries ?? [];

  List<Map<String, dynamic>> toJson() =>
      entries.map((e) => e.toJson()).toList();

  factory MemoryModel.fromJson(List<dynamic>? json) {
    if (json == null) return MemoryModel();
    return MemoryModel(
      entries: json
          .map((e) => MemoryEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  MemoryModel copyWith({
    List<MemoryEntryModel>? entries,
  }) {
    return MemoryModel(
      entries: entries ?? List<MemoryEntryModel>.from(this.entries),
    );
  }
}
