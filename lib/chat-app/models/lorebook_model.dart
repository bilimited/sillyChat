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
  LorebookModel copyWith({
    int? id,
    String? name,
    List<LorebookItemModel>? items,
    int? scanDepth,
    int? maxToken,
  }) {
    return LorebookModel(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? List<LorebookItemModel>.from(this.items),
      scanDepth: scanDepth ?? this.scanDepth,
      maxToken: maxToken ?? this.maxToken,
    );
  }



}