import 'dart:convert';
import 'dart:io';

class FolderSettingModel {
  String id;
  String path;
  int? defaultAssistantId;
  List<int> characterIds;
  int? chatOptionId;
  Map<String, dynamic> metaData;

  FolderSettingModel({
    required this.id,
    required this.path,
    this.defaultAssistantId,
    this.characterIds = const [],
    this.chatOptionId,
    this.metaData = const {},
  });

  // --- JSON 序列化 ---

  factory FolderSettingModel.fromJson(Map<String, dynamic> json) {
    return FolderSettingModel(
      id: json['id'] as String,
      path: json['path'] as String,
      defaultAssistantId: json['defaultAssistantId'] as int?,
      // 确保从 JSON 解析 List 时处理类型转换
      characterIds: json['characterIds'] != null 
          ? List<int>.from(json['characterIds']) 
          : [],
      chatOptionId: json['chatOptionId'] as int?,
      // 确保从 JSON 解析 Map
      metaData: json['metaData'] != null 
          ? Map<String, dynamic>.from(json['metaData']) 
          : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'defaultAssistantId': defaultAssistantId,
      'characterIds': characterIds,
      'chatOptionId': chatOptionId,
      'metaData': metaData,
    };
  }

  // --- CopyWith 方法 ---

  FolderSettingModel copyWith({
    String? id,
    String? path,
    int? defaultAssistantId,
    List<int>? characterIds,
    int? chatOptionId,
    Map<String, dynamic>? metaData,
  }) {
    return FolderSettingModel(
      id: id ?? this.id,
      path: path ?? this.path,
      // 注意：如果需要将可空字段显式设为 null，
      // 通常需要更复杂的实现，这里采用基础覆盖逻辑
      defaultAssistantId: defaultAssistantId ?? this.defaultAssistantId,
      characterIds: characterIds ?? this.characterIds,
      chatOptionId: chatOptionId ?? this.chatOptionId,
      metaData: metaData ?? this.metaData,
    );
  }
}