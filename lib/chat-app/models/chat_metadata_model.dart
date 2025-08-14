import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:get/get.dart';

class ChatMetaModel {
  late final int id;
  late final String name;
  late final String avatar;
  late final String lastMessage;
  late final String time;
  late final int messageCount;
  late final List<int> characterIds;

  ChatMetaModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.time,
    required this.messageCount,
    required this.characterIds,
  });

  factory ChatMetaModel.fromChatModel(ChatModel chatModel) {
    return ChatMetaModel(
      id: chatModel.id,
      name: chatModel.name,
      avatar: chatModel.avatar,
      lastMessage: chatModel.lastMessage,
      time: chatModel.time,
      messageCount: chatModel.messages.length,
      characterIds: chatModel.characterIds,
    );
  }

  factory ChatMetaModel.fromJson(Map<String, dynamic> json) {
    return ChatMetaModel(
      id: json['id'],
      name: json['name'],
      avatar: json['avatar'],
      lastMessage: json['lastMessage'],
      time: json['time'],
      messageCount: json['messageCount'],
      characterIds: (json['characterIds'] as List?)?.cast<int>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'lastMessage': lastMessage,
      'time': time,
      'messageCount': messageCount,
      'characterIds': characterIds,
    };
  }

  List<CharacterModel> get characters {
    CharacterController controller = Get.find();
    return characterIds
        .map((id) => controller.getCharacterById(id))
        .nonNulls
        .toList();
  }

  ChatMetaModel copyWith({
    int? id,
    String? name,
    String? avatar,
    String? backgroundImage,
    String? lastMessage,
    String? time,
    int? messageCount,
    List<int>? characterIds,
  }) {
    return ChatMetaModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      messageCount: messageCount ?? this.messageCount,
      characterIds: characterIds ?? this.characterIds,
    );
  }
}
