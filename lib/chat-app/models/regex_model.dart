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

  int depthMin = 0;
  int depthMax = -1; // 作用范围，-1代表无限

  List<int>? scopeCharacter = [];

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
    return replaceJsRegex(pattern, input, replacement);
    // final regex = RegExp(pattern);
    // return input.replaceAllMapped(regex, (match) {
    //   String result = replacement;
    //   for (int i = 1; i < match.groupCount + 1; i++) {
    //     result = result.replaceAll('\$$i', match.group(i) ?? '');
    //   }
    //   return result;
    // });
  }

  /// [disableDepthCalc] :无视楼层，适用于新消息
  bool isAvailable(
    ChatModel chat,
    MessageModel message, {
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
      }
      int position = chat.messages.length - index - 1;
      if (position < depthMin) {
        return false;
      } else if (depthMax != -1 && position > depthMax) {
        return false;
      }
    }

    return true;
  }

  /// 将 JavaScript 风格的正则表达式应用于输入字符串进行替换。
  ///
  /// 该方法会解析 JS 正则表达式字符串中的修饰符 (flags)，
  /// 并将其转换为 Dart 的 RegExp 识别的形式。
  /// 然后，它使用解析后的正则表达式对 [input] 字符串进行查找和替换。
  /// 替换字符串 [replacement] 可以包含 $1, $2 等捕获组引用。
  ///
  /// 参数:
  /// - [jsRegexString]: JavaScript 风格的正则表达式字符串，例如 "/pattern/gi" 或 "pattern"。
  /// - [input]: 要进行正则替换的原始字符串。
  /// - [replacement]: 替换字符串，可以使用 $1, $2 等引用捕获组。
  ///
  /// 返回:
  /// 替换后的字符串。
  String replaceJsRegex(
    String jsRegexString,
    String input,
    String replacement,
  ) {
    try {
      String pattern;
      bool caseSensitive = true; // 默认 Dart RegExp 是区分大小写的
      bool multiLine = false; // 默认 Dart RegExp 不支持多行模式
      bool dotAll = false; // 默认 Dart RegExp 的 '.' 不匹配换行符
      bool isGlobal = false; // 判断 JS 正则是否有 'g' flag

      // 1. 解析 JavaScript 正则表达式字符串和 flags
      if (jsRegexString.startsWith('/') && jsRegexString.lastIndexOf('/') > 0) {
        int lastSlashIndex = jsRegexString.lastIndexOf('/');
        String regexBody = jsRegexString.substring(1, lastSlashIndex);
        String flags = jsRegexString.substring(lastSlashIndex + 1);

        pattern = regexBody;

        if (flags.contains('i')) {
          caseSensitive = false;
        }
        if (flags.contains('m')) {
          multiLine = true;
        }
        if (flags.contains('s')) {
          dotAll = true;
        }
        if (flags.contains('g')) {
          isGlobal = true; // 标记有 'g' flag，表示需要全局替换
        }
      } else {
        // 如果不是 /pattern/flags 形式，则整个字符串就是 pattern，所有 flags 为默认值
        pattern = jsRegexString;
      }

      // 2. 创建 Dart RegExp 对象
      final RegExp regex = RegExp(
        pattern,
        caseSensitive: caseSensitive,
        multiLine: multiLine,
        dotAll: dotAll,
      );

      // 3. 执行替换逻辑
      if (isGlobal) {
        // 如果有 'g' flag，使用 replaceAllMapped 模拟全局替换并处理捕获组
        return input.replaceAllMapped(regex, (match) {
          String result = replacement;
          // 遍历所有捕获组，替换 $1, $2 等
          for (int i = 1; i <= match.groupCount; i++) {
            // match.group(i) 可能为 null (如果捕获组没有匹配到)
            result = result.replaceAll('\$$i', match.group(i) ?? '');
          }
          return result;
        });
      } else {
        // 如果没有 'g' flag，只替换第一个匹配项
        final match = regex.firstMatch(input);
        if (match == null) {
          return input; // 没有匹配项，返回原字符串
        }

        String result = replacement;
        // 遍历所有捕获组，替换 $1, $2 等
        for (int i = 1; i <= match.groupCount; i++) {
          result = result.replaceAll('\$$i', match.group(i) ?? '');
        }

        // 找到第一个匹配项的起始和结束索引，然后构建新字符串
        return input.replaceRange(match.start, match.end, result);
      }
    } catch (e) {
      // 如果正则出问题则直接返回原始字符串
      return input;
    }
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
