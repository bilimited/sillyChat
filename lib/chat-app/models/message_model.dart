
import 'package:flutter_example/chat-app/models/character_model.dart';

enum MessageType { text, image, narration, divider }

extension MessageTypeExtension on MessageType {
  String toJson() => toString().split('.').last;
  
  static MessageType fromJson(String json) {
    return MessageType.values.firstWhere(
      (type) => type.toString().split('.').last == json,
      orElse: () => MessageType.text,
    );
  }

  static MessageType fromMessageStyle(MessageStyle style) {
    switch (style) {
      case MessageStyle.common:
        return MessageType.text;
      case MessageStyle.narration:
        return MessageType.narration;
      default:
        return MessageType.text;
    }
  }
}

class MessageModel {
  final int id;
  String content;


  // 备选文本列表。该列表中一定会有一个Null，代表已选择文本在备选文本中的位置。
  final List<String?> alternativeContent;
  final int sender;
  final DateTime time;
  final MessageType type;
  bool isAssistant;

  final int? token;

  // 若type为image或其他文件格式，则为文件路径
  final String? resPath;


  MessageModel({
    required this.id,
    required this.content,
    required this.sender,
    required this.time,
    this.type = MessageType.text,
    this.isAssistant = false,
    this.token = 0,
    this.resPath = "",
    required this.alternativeContent,
  });

  MessageModel.fromJson(Map<String, dynamic> json)
      : content = json['content'],
        id = json['id'],
        sender = json['sender'] ?? -1,
        time = DateTime.parse(json['time']),
        type = MessageTypeExtension.fromJson(json['type']),
        isAssistant = json['isRead'],
        token = (json['token'] ?? 0) as int,
        resPath = json['resPath'] ?? "",
        alternativeContent = (json['alternativeContent'] as List<dynamic>?)
            ?.map((e) => e as String?)
            .toList() ?? [null];



  Map<String, dynamic> toJson() => {
        'id' : id,
        'content': content,
        'sender': sender,
        'time': time.toIso8601String(),
        'type': type.toJson(),
        'isRead': isAssistant,
        'token': token,
        'resPath': resPath,
        'alternativeContent': alternativeContent,
      };

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],
      content: map['content'],
      sender: map['sender'] ?? -1,
      time: DateTime.parse(map['time']),
      type: MessageTypeExtension.fromJson(map['type']),
      isAssistant: map['isRead'] ?? false,
      token: map['token'],
      resPath: map['resPath'],
      alternativeContent: (map['alternativeContent'] as List<dynamic>?)
          ?.map((e) => e as String?)
          .toList() ?? [null],
    );
  }
}
