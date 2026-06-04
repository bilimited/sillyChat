/// Agent 配置模型
///
/// 控制 AI Agent 的工具调用行为，包括工具白名单和最大调用轮数。
///
/// - [toolWhitelist]: 允许使用的工具名称列表。`null` 表示所有已注册工具均可用。
/// - [maxCallRounds]: 最大工具调用轮数，防止无限循环。默认 5。
///
/// 工具名称与 [ToolRegistry] 中注册的名称一致，内置工具有：
/// - `test_tool` — 测试工具
/// - LoreBook 系列：`list_lorebooks`, `create_lorebook`, `update_lorebook`,
///   `delete_lorebook`, `list_lorebook_items`, `search_lorebook_items`,
///   `create_lorebook_item`, `update_lorebook_item`, `delete_lorebook_item`
/// - Character 系列：`search_characters`, `list_characters`, `create_character`,
///   `update_character`, `delete_character`
class AgentConfig {
  /// 是否启用 Agent 模式。
  final bool enabled;

  /// 工具白名单。`null` 或空列表表示允许所有已注册工具。
  final List<String>? toolWhitelist;

  /// 最大工具调用轮数。默认 5。
  final int maxCallRounds;

  const AgentConfig({
    this.enabled = false,
    this.toolWhitelist,
    this.maxCallRounds = 5,
  }); 

  /// 是否允许某个工具名称被调用。
  /// [toolWhitelist] 为 `null` 时允许所有工具。
  bool isToolAllowed(String toolName) {
    if (toolWhitelist == null || toolWhitelist!.isEmpty) return true;
    return toolWhitelist!.contains(toolName);
  }

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    return AgentConfig(
      enabled: json['enabled'] as bool? ?? false,
      toolWhitelist: (json['toolWhitelist'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      maxCallRounds: json['maxCallRounds'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'toolWhitelist': toolWhitelist,
        'maxCallRounds': maxCallRounds,
      };

  AgentConfig copyWith({
    bool? enabled,
    List<String>? toolWhitelist,
    int? maxCallRounds,
  }) {
    return AgentConfig(
      enabled: enabled ?? this.enabled,
      toolWhitelist: toolWhitelist ?? this.toolWhitelist,
      maxCallRounds: maxCallRounds ?? this.maxCallRounds,
    );
  }
}
