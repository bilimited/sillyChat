import 'package:flutter_example/chat-app/constants.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'character_model.dart';

/// 内置角色定义 — 只读、硬编码，不可被用户编辑或删除。
///
/// 新增内置角色只需在此文件中添加一个 [BuiltInCharacters.all] 条目即可。
class BuiltInCharacters {
  BuiltInCharacters._();

  // ── ID 常量 ──────────────────────────────────────────────
  /// 默认助手（AI 助手）ID — 当查找的角色不存在时作为兜底
  static const int defaultAssistantId = -1;

  /// 总结姬 ID — 用于生成聊天摘要
  static const int summaryCharacterId = -2;

  /// 内置默认助手 ID — 硬编码的 SillyChat 功能助手
  static const int defaultAgentId = -3;

  // ── 角色实例 ─────────────────────────────────────────────

  /// 默认 AI 助手 — 当查找的角色不存在时作为兜底
  static final CharacterModel defaultAssistant = CharacterModel(
    id: defaultAssistantId,
    remark: '内置角色',
    roleName: 'AI助手',
    avatar: '',
    category: '',
    messageStyle: MessageStyle.common,
  );

  /// 总结姬 — 用于生成聊天摘要
  static final CharacterModel summaryCharacter = CharacterModel(
    id: summaryCharacterId,
    remark: '总结姬',
    roleName: '总结姬',
    avatar: '',
    category: '',
    messageStyle: MessageStyle.summary,
  );

  /// 内置默认助手 — SillyChat 功能助手，帮助用户快速了解和使用应用
  static final CharacterModel defaultAgent = CharacterModel(
    id: defaultAgentId,
    remark: '内置Agent',
    roleName: '默认Agent',
    avatar: '',
    category: '内置',
    brief: 'SillyChat 内置功能助手，帮你快速了解和使用应用',
    firstMessage: '你好，我是 SillyChat 内置 Agent 👋\n'
        '我可以通过调用工具帮你管理角色、聊天记录、世界书、记忆和正则规则。\n'
        '你可以直接告诉我你想做什么，比如：\n'
        '• "帮我创建一个新角色"\n'
        '• "列出所有世界书"\n'
        '• "搜索最近的聊天记录"\n'
        '• "给角色添加一条记忆"\n'
        '试试看吧！',
  )
    ..type = CharacterType.agent
    ..archive = Constants.DEFAULT_AGENT_PROMPT
    ..bindOption = ChatOptionModel.agent(name: '默认Agent预设');

  // ── 聚合列表 ─────────────────────────────────────────────

  /// 所有内置角色列表
  static final List<CharacterModel> all = [
    defaultAssistant,
    summaryCharacter,
    defaultAgent,
  ];

  // ── 工具方法 ─────────────────────────────────────────────

  /// 根据 ID 查询内置角色，找不到返回 `null`
  static CharacterModel? getById(int id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 判断指定 ID 是否为内置角色
  static bool isBuiltIn(int id) => getById(id) != null;
}
