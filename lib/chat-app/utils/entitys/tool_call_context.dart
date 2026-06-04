import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/story_model.dart';

/// 工具调用上下文 — 封装模型传入的 JSON 参数与当前聊天信息。
///
/// 通过 `operator []` 委托到 [args]，现有代码只需将参数名从 `args` 改为 `ctx`
/// 即可编译通过并自动获取聊天上下文。
class ToolCallContext {
  final Map<String, dynamic> args;
  final ChatModel chat;

  const ToolCallContext({required this.args, required this.chat});

  /// 委托 [] 到 args — ctx['keyword'] 等价于 args['keyword']
  dynamic operator [](String key) => args[key];

  /// 委托 []= 到 args
  void operator []=(String key, dynamic value) {
    args[key] = value;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 便捷访问器
  // ═══════════════════════════════════════════════════════════════════════════

  /// 当前对话绑定的角色
  CharacterModel? get assistant => chat.bindCharacter;

  /// 当前对话绑定的故事/群聊
  StoryModel? get story => chat.bindStory;

  /// 当前用户人设
  CharacterModel get user => chat.user;

  /// 对话中涉及的所有角色
  List<CharacterModel> get characters => chat.characters;
}
