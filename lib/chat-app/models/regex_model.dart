import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';

class RegexModel {
  int id;
  String name;
  String pattern; // 正则表达式
  String replacement; // 替换文本
  String? trim; // 修减掉，不知道有啥用
  bool enabled;

  bool onRender = false; // 在渲染时应用正则
  bool onRequest = false; // 在向AI发送请求时应用正则（对应ST仅格式提示词）
  bool onAddMessage = false; // 在添加消息时应用正则，会影响消息记录

  bool scopeUser = false;
  bool scopeAssistant = false; // 作用域：应用于AI消息还是用户消息

  int depthMin = -1;
  int depthMax = -1; // 作用范围，-1代表无限

  RegexModel({
    required this.id,
    required this.name,
    required this.pattern,
    required this.replacement,
    this.trim,
    this.enabled = true,
    this.onRender = false,
    this.onRequest = false,
    this.onAddMessage = false,
    this.scopeUser = false,
    this.scopeAssistant = false,
    this.depthMin = -1,
    this.depthMax = -1,
  });

  // 对传入字符串进行正则替换
  // replacement字符串中，$1、$2会被替换为匹配到的分组内容
  String process(String input) {
    if (!enabled || pattern.isEmpty) return input;

    final trims = this.trim?.split('\n') ?? [];
    trims.forEach((t) {
      if (t.isNotEmpty) {
        input = input.replaceAll(t, '');
      }
    });

    final regex = RegExp(pattern);
    return input.replaceAllMapped(regex, (match) {
      String result = replacement;
      for (int i = 1; i < match.groupCount + 1; i++) {
        result = result.replaceAll('\$$i', match.group(i) ?? '');
      }
      return result;
    });
  }


  /// [disableDepthCalc] :无视楼层，适用于新消息
  bool isAvailable(ChatModel chat, MessageModel message, {
    bool disableDepthCalc = false,
  }) {
    if (!enabled) {
      return false;
    }
    if (!scopeUser && !message.isAssistant) {
      return false;
    }
    if (!scopeAssistant && message.isAssistant) {
      return false;
    }

    if (!disableDepthCalc) {
      int index = chat.messages.indexOf(message);
      if (index < 0) {
        return false;
      } else {
        int position = chat.messages.length - index - 1;
        if (position < depthMin || position > depthMax) {
          return false;
        }
      }
    }

    return true;
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pattern': pattern,
      'replacement': replacement,
      'trim': trim,
      'enabled': enabled,
      'onRender': onRender,
      'onRequest': onRequest,
      'onResponse': onAddMessage,
      'scopeUser': scopeUser,
      'scopeAssistant': scopeAssistant,
      'depthMin': depthMin,
      'depthMax': depthMax,
    };
  }

  // JSON deserialization
  factory RegexModel.fromJson(Map<String, dynamic> json) {
    return RegexModel(
      id: json['id'] as int,
      name: json['name'] as String,
      pattern: json['pattern'] as String,
      replacement: json['replacement'] as String,
      trim: json['trim'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      onRender: json['onRender'] as bool? ?? false,
      onRequest: json['onRequest'] as bool? ?? false,
      onAddMessage: json['onResponse'] as bool? ?? false,
      scopeUser: json['scopeUser'] as bool? ?? false,
      scopeAssistant: json['scopeAssistant'] as bool? ?? false,
      depthMin: json['depthMin'] as int? ?? -1,
      depthMax: json['depthMax'] as int? ?? -1,
    );
  }

  // copyWith method
  RegexModel copyWith({
    int? id,
    String? name,
    String? pattern,
    String? replacement,
    String? trim,
    bool? enabled,
    bool? onRender,
    bool? onRequest,
    bool? onResponse,
    bool? scopeUser,
    bool? scopeAssistant,
    int? depthMin,
    int? depthMax,
  }) {
    return RegexModel(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      trim: trim ?? this.trim,
      enabled: enabled ?? this.enabled,
      onRender: onRender ?? this.onRender,
      onRequest: onRequest ?? this.onRequest,
      onAddMessage: onResponse ?? this.onAddMessage,
      scopeUser: scopeUser ?? this.scopeUser,
      scopeAssistant: scopeAssistant ?? this.scopeAssistant,
      depthMin: depthMin ?? this.depthMin,
      depthMax: depthMax ?? this.depthMax,
    );
  }
}
