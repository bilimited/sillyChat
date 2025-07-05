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

enum MessageRole { user, assistant, system }

extension MessageRoleExtension on MessageRole {
  static MessageRole fromString(String name) {
    return MessageRole.values.firstWhere(
      (e) => e.toString() == 'MessageRole.$name',
      orElse: () => MessageRole.user,
    );
  }
}

class MessageModel {
  final int id;
  String content;

  MessageRole role;

  // 备选文本列表。该列表中一定会有一个Null，代表已选择文本在备选文本中的位置。
  final List<String?> alternativeContent;
  int sender;
  final DateTime time;
  MessageType type;
  bool get isAssistant => role == MessageRole.assistant;

  final int? token;

  // 若type为image或其他文件格式，则为文件路径
  final List<String> resPath;
  // 是否常驻（不会被移出消息列表）
  bool isPinned = false;
  String? bookmark;

  MessageModel({
    required this.id,
    required this.content,
    required this.sender,
    required this.time,
    this.type = MessageType.text,
    this.role = MessageRole.user,
    // this.isAssistant = false,
    this.token = 0,
    this.resPath = const [],
    this.isPinned = false,
    this.bookmark,
    required this.alternativeContent,
  });

  MessageModel.fromJson(Map<String, dynamic> json)
      : content = json['content'],
        id = json['id'],
        sender = json['sender'] ?? -1,
        role = json['isRead'] != null
            ? ((json['isRead'] as bool) // 迁移旧版本数据
                ? MessageRole.assistant
                : MessageRole.user)
            : MessageRole.values.firstWhere(
                (e) => e.toString() == 'MessageRole.${json['role']}',
                orElse: () => MessageRole.user,
              ),
        time = DateTime.parse(json['time']),
        type = MessageTypeExtension.fromJson(json['type']),
        // isAssistant = json['isRead'],
        token = (json['token'] ?? 0) as int,
        resPath = json['resPath'] is String
            ? [if ((json['resPath'] as String).isNotEmpty) json['resPath']]
            : (json['resPath'] is List
                ? List<String>.from(json['resPath'])
                : []),
        isPinned = json['isPinned'] ?? false,
        bookmark = json['bookmark'] is bool ? null : json['bookmark'] ?? null,
        alternativeContent = (json['alternativeContent'] as List<dynamic>?)
                ?.map((e) => e as String?)
                .toList() ??
            [null];

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'sender': sender,
        'time': time.toIso8601String(),
        'type': type.toJson(),
        'role': role.toString().split('.').last,
        // 'isRead': isAssistant,
        'token': token,
        'isPinned': isPinned,
        'bookmark': bookmark,
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
      role: MessageRole.values.firstWhere(
        (e) => e.toString() == 'MessageRole.${map['role']}',
        orElse: () => MessageRole.user,
      ),
      token: map['token'],
      resPath: map['resPath'],
      isPinned: map['isPinned'] ?? false,
      bookmark: map['bookmark'] ?? null,
      alternativeContent: (map['alternativeContent'] as List<dynamic>?)
              ?.map((e) => e as String?)
              .toList() ??
          [null],
    );
  }

  MessageModel copyWith({
    int? id,
    String? content,
    int? sender,
    DateTime? time,
    MessageType? type,
    MessageRole? role,
    bool? isAssistant,
    int? token,
    List<String>? resPath,
    bool? isPinned,
    String? bookmark,
    List<String?>? alternativeContent,
  }) {
    return MessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      sender: sender ?? this.sender,
      time: time ?? this.time,
      type: type ?? this.type,
      role: role ?? this.role,
      // isAssistant: isAssistant ?? this.isAssistant,
      token: token ?? this.token,
      resPath: resPath ?? this.resPath,
      isPinned: isPinned ?? this.isPinned,
      bookmark: bookmark ?? this.bookmark,
      alternativeContent: alternativeContent ?? this.alternativeContent,
    );
  }
}
