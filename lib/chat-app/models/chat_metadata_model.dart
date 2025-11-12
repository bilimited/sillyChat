import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:get/get.dart';

class ChatMetaModel {
  late final int id;
  late final String name;
  //late final String avatar;
  late final String lastMessage;
  late final String time;
  late final int messageCount;
  late final List<int> characterIds;
  late final int assistantId;
  late final ChatMode mode;

  // JSON Ignore
  late final String path;

  ChatMetaModel({
    required this.id,
    required this.name,
    //required this.avatar,
    required this.lastMessage,
    required this.time,
    required this.messageCount,
    required this.characterIds,
    required this.assistantId,
    required this.mode,
  });

  CharacterModel get assistant {
    CharacterController controller = Get.find();
    return controller.getCharacterById(assistantId);
  }

  List<String> getAllAvatars() {
    final controller = CharacterController.of;
    return characterIds
        .map((id) => controller.getCharacterById(id))
        .map((char) => char.avatar)
        .toList();
  }

  factory ChatMetaModel.fromChatModel(ChatModel chatModel) {
    return ChatMetaModel(
        id: chatModel.id,
        name: chatModel.name,
        //avatar: chatModel.assistant.avatar,
        lastMessage: chatModel.lastMessage,
        time: chatModel.time,
        messageCount: chatModel.messages.length,
        characterIds: chatModel.characterIds,
        mode: chatModel.mode ?? ChatMode.auto,
        assistantId: chatModel.assistantId ?? -1);
  }

  factory ChatMetaModel.fromJson(Map<String, dynamic> json) {
    return ChatMetaModel(
        id: json['id'],
        name: json['name'],
        //avatar: json['avatar'],
        lastMessage: json['lastMessage'],
        time: json['time'],
        messageCount: json['messageCount'],
        characterIds: (json['characterIds'] as List?)?.cast<int>() ?? [],
        assistantId: json['assistant'],
        mode: json['mode'] != null
            ? ChatMode.values.firstWhere(
                (e) => e.toString() == 'ChatMode.${json['mode']}',
                orElse: () => ChatMode.auto)
            : ChatMode.auto);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      //'avatar': avatar,
      'lastMessage': lastMessage,
      'time': time,
      'messageCount': messageCount,
      'characterIds': characterIds,
      'assistant': assistantId,
      'mode': mode.toString().split('.').last,
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
    String? backgroundImage,
    String? lastMessage,
    String? time,
    int? messageCount,
    List<int>? characterIds,
    int? assistant,
    ChatMode? mode,
    String? path,
  }) {
    return ChatMetaModel(
      id: id ?? this.id,
      name: name ?? this.name,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      messageCount: messageCount ?? this.messageCount,
      characterIds: characterIds ?? this.characterIds,
      mode: mode ?? this.mode,
      assistantId: assistant ?? this.assistantId,
    )..path = path ?? this.path;
  }
}
