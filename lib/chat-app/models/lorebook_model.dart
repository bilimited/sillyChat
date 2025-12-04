import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';

enum LorebookType {
  world, // 全局世界书
  character, // 角色书
  memory, // 记忆书
}

class LorebookModel {
  final int id;
  final String name;
  final List<LorebookItemModel> items;
  final int scanDepth;
  final int maxToken;

  final LorebookType type;
  final Map<String, dynamic> metaData = {};

  LorebookModel({
    required this.id,
    required this.name,
    required this.items,
    required this.scanDepth,
    required this.maxToken,
    this.type = LorebookType.world,
  });

  // fromJson
  factory LorebookModel.fromJson(Map<String, dynamic> json) {
    return LorebookModel(
      id: json['id'] as int,
      name: json['name'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => LorebookItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      scanDepth: json['scanDepth'] as int,
      maxToken: json['maxToken'] as int,
      type: LorebookType.values.firstWhere(
          (e) => e.toString().split('.').last == json['type'],
          orElse: () => LorebookType.world),
    )..metaData.addAll(json['metaData'] ?? {});
  }

  factory LorebookModel.emptyWorldBook() {
    return LorebookModel(
        id: DateTime.now().microsecondsSinceEpoch,
        name: '空白世界书',
        items: [],
        scanDepth: 4,
        maxToken: 8000,
        type: LorebookType.world);
  }

  factory LorebookModel.emptyCharacterBook() {
    return LorebookModel(
        id: DateTime.now().microsecondsSinceEpoch,
        name: '空白角色书',
        items: [],
        scanDepth: 4,
        maxToken: 8000,
        type: LorebookType.character);
  }

  factory LorebookModel.emptyMemoryBook() {
    return LorebookModel(
        id: DateTime.now().microsecondsSinceEpoch,
        name: '空白记忆书',
        items: [],
        scanDepth: 4,
        maxToken: 8000,
        type: LorebookType.memory);
  }

  // toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((e) => e.toJson()).toList(),
      'scanDepth': scanDepth,
      'maxToken': maxToken,
      'metaData': metaData,
      'type': type.toString().split('.').last,
    };
  }

  // copy method
  LorebookModel copyWith({
    int? id,
    String? name,
    List<LorebookItemModel>? items,
    int? scanDepth,
    int? maxToken,
    Map<String, dynamic>? metaData,
    LorebookType? type,
  }) {
    return LorebookModel(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? List<LorebookItemModel>.from(this.items),
      scanDepth: scanDepth ?? this.scanDepth,
      maxToken: maxToken ?? this.maxToken,
      type: type ?? this.type,
    )..metaData.addAll(metaData ?? this.metaData);
  }
}
