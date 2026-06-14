import 'character_model.dart';

/// 内置角色定义 — 只读、硬编码，不可被用户编辑或删除。
///
/// 新增内置角色只需在此文件中添加一个 [BuiltInCharacters.all] 条目即可。
class BuiltInCharacters {
  BuiltInCharacters._();

  // ── ID 常量 ──────────────────────────────────────────────
  /// 默认助手（AI 助手）ID
  static const int defaultAssistantId = -1;

  /// 总结姬 ID
  static const int summaryCharacterId = -2;

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

  // ── 聚合列表 ─────────────────────────────────────────────

  /// 所有内置角色列表
  static final List<CharacterModel> all = [
    defaultAssistant,
    summaryCharacter,
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
