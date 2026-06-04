import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/models/memory_model.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';

class StoryModel {
  String id;
  String name;
  String remark;
  String story_prompt;
  String category;
  int? chatOptionId;
  List<int> characterIds;
  List<int> lorebookIds;
  Map<String, dynamic> metaData;

  MemoryModel? memory; // 内联记忆

  ChatOptionModel? get chatOption =>
      ChatOptionController.of().getChatOptionById(chatOptionId ?? -1);

  List<LorebookModel> get loreBooks => lorebookIds
      .map((id) => LoreBookController.of.getLorebookById(id))
      .nonNulls
      .toList();

  StoryModel({
    required this.id,
    required this.name,
    required this.remark,
    required this.story_prompt,
    this.category = '',
    this.chatOptionId,
    this.characterIds = const [],
    this.lorebookIds = const [],
    this.metaData = const {},
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      remark: json['remark'] as String,
      story_prompt: json['story_prompt'] as String,
      category: json['category'] as String? ?? '',
      chatOptionId: json['chatOptionId'] as int?,
      characterIds: (json['characterIds'] as List<dynamic>?)?.cast<int>() ?? [],
      lorebookIds: (json['lorebookIds'] as List<dynamic>?)?.cast<int>() ?? [],
      metaData: json['metaData'] as Map<String, dynamic>? ?? {},
    )..memory = json['memory'] != null
        ? MemoryModel.fromJson(json['memory'] as List<dynamic>?)
        : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'remark': remark,
      'story_prompt': story_prompt,
      'category': category,
      if (chatOptionId != null) 'chatOptionId': chatOptionId,
      'characterIds': characterIds,
      'lorebookIds': lorebookIds,
      'metaData': metaData,
      'memory': memory?.toJson(),
    };
  }

  StoryModel copyWith({
    String? id,
    String? name,
    String? remark,
    String? story_prompt,
    String? category,
    int? chatOptionId,
    List<int>? characterIds,
    List<int>? lorebookIds,
    Map<String, dynamic>? metaData,
    MemoryModel? memory,
  }) {
    return StoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      remark: remark ?? this.remark,
      story_prompt: story_prompt ?? this.story_prompt,
      category: category ?? this.category,
      chatOptionId: chatOptionId ?? this.chatOptionId,
      characterIds: characterIds ?? this.characterIds,
      lorebookIds: lorebookIds ?? this.lorebookIds,
      metaData: metaData ?? this.metaData,
    )..memory = memory ?? this.memory;
  }
}
