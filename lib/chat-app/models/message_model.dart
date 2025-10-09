import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';

// enum MessageType { common, narration }

// extension MessageTypeExtension on MessageType {
//   String toJson() => toString().split('.').last;

//   static MessageType fromJson(String json) {
//     return MessageType.values.firstWhere(
//       (type) => type.toString().split('.').last == json,
//       orElse: () => MessageType.common,
//     );
//   }

//   static MessageType fromMessageStyle(MessageStyle style) {
//     switch (style) {
//       case MessageStyle.common:
//         return MessageType.common;
//       case MessageStyle.narration:
//         return MessageType.narration;
//       default:
//         return MessageType.common;
//     }
//   }
// }

enum MessageRole { user, assistant, system }

extension MessageRoleExtension on MessageRole {
  static MessageRole fromString(String name) {
    return MessageRole.values.firstWhere(
      (e) => e.toString() == 'MessageRole.$name',
      orElse: () => MessageRole.user,
    );
  }
}

enum MessageVisbility { common, pinned, hidden }

class MessageModel {
  final int id;
  String content;

  MessageRole role;

  // 备选文本列表。该列表中一定会有一个Null，代表已选择文本在备选文本中的位置。
  final List<String?> alternativeContent;
  int senderId;
  final DateTime time;
  MessageStyle style;
  bool get isAssistant => role == MessageRole.assistant;

  final int? token;

  // 若type为image或其他文件格式，则为文件路径
  // 目前里面只能装图片。而且默认为图片
  // TODO:通过前缀区分文件类型。如 图片： image://xxx.jpg
  final List<String> resPath;

  MessageVisbility visbility;

  bool get isPinned => visbility == MessageVisbility.pinned;
  bool get isHidden => visbility == MessageVisbility.hidden;
  String? bookmark;

  CharacterModel get sender =>
      CharacterController.of.getCharacterById(senderId);

  MessageModel({
    required this.id,
    required this.content,
    required this.senderId,
    required this.time,
    this.style = MessageStyle.common,
    this.role = MessageRole.user,
    this.token = 0,
    this.resPath = const [],
    this.visbility = MessageVisbility.common,
    this.bookmark,
    required this.alternativeContent,
  });

  MessageModel.fromJson(Map<String, dynamic> json)
      : content = json['content'],
        id = json['id'],
        senderId = json['sender'] ?? -1,
        role = json['isRead'] != null
            ? ((json['isRead'] as bool) // 迁移旧版本数据
                ? MessageRole.assistant
                : MessageRole.user)
            : MessageRole.values.firstWhere(
                (e) => e.toString() == 'MessageRole.${json['role']}',
                orElse: () => MessageRole.user,
              ),
        time = DateTime.parse(json['time']),
        style = MessageStyle.fromJson(json['type']),
        token = (json['token'] ?? 0) as int,
        resPath = json['resPath'] is String
            ? [if ((json['resPath'] as String).isNotEmpty) json['resPath']]
            : (json['resPath'] is List
                ? List<String>.from(json['resPath'])
                : []),
        visbility = MessageVisbility.values.firstWhere(
          (e) => e.toString() == 'MessageVisbility.${json['visbility']}',
          orElse: () => MessageVisbility.common,
        ),
        bookmark = json['bookmark'] is bool ? null : json['bookmark'] ?? null,
        alternativeContent = (json['alternativeContent'] as List<dynamic>?)
                ?.map((e) => e as String?)
                .toList() ??
            [null];

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'sender': senderId,
        'time': time.toIso8601String(),
        'type': style.toJson(),
        'role': role.toString().split('.').last,
        // 'isRead': isAssistant,
        'token': token,
        // 'isPinned': isPinned,
        'visbility': visbility.toString().split('.').last,
        'bookmark': bookmark,
        'resPath': resPath,
        'alternativeContent': alternativeContent,
      };

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],
      content: map['content'],
      senderId: map['sender'] ?? -1,
      time: DateTime.parse(map['time']),
      style: MessageStyle.fromJson(map['type']),
      role: MessageRole.values.firstWhere(
        (e) => e.toString() == 'MessageRole.${map['role']}',
        orElse: () => MessageRole.user,
      ),
      token: map['token'],
      resPath: map['resPath'],
      visbility: MessageVisbility.values.firstWhere(
        (e) => e.toString() == 'MessageVisbility.${map['visbility']}',
        orElse: () => MessageVisbility.common,
      ),
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
    MessageStyle? type,
    MessageRole? role,
    bool? isAssistant,
    int? token,
    List<String>? resPath,
    bool? isPinned,
    String? bookmark,
    MessageVisbility? visbility,
    List<String?>? alternativeContent,
  }) {
    return MessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      senderId: sender ?? this.senderId,
      time: time ?? this.time,
      style: type ?? this.style,
      role: role ?? this.role,
      // isAssistant: isAssistant ?? this.isAssistant,
      token: token ?? this.token,
      resPath: resPath ?? this.resPath,
      visbility: visbility ?? this.visbility,
      bookmark: bookmark ?? this.bookmark,
      alternativeContent: alternativeContent ?? this.alternativeContent,
    );
  }
}
