import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';

class LorebookModel {

  final int id;
  final String name;
  final List<LorebookItemModel> items;
  final int scanDepth;
  final int maxToken;

  LorebookModel({
    required this.id,
    required this.name,
    required this.items,
    required this.scanDepth,
    required this.maxToken,
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
    );
  }

  // toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((e) => e.toJson()).toList(),
      'scanDepth': scanDepth,
      'maxToken': maxToken,
    };
  }

  // copy method
  LorebookModel copy({bool deep = false}) {
    return LorebookModel(
      id: id,
      name: name,
      items: deep
          ? items.map((item) => item.copyWith()).toList()
          : List<LorebookItemModel>.from(items),
      scanDepth: scanDepth,
      maxToken: maxToken,
    );
  }

}