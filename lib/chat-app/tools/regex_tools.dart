import 'dart:convert';

import 'package:flutter_example/chat-app/models/regex_model.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/tool_registry.dart';
import 'package:get/get.dart';

/// 注册所有全局正则表达式 (Regex) 相关工具。
///
/// 全局正则存储在 [VaultSettingController.regexes] 中，
/// 在 [VaultSettingController] 就绪后调用。
void registerRegexTools() {
  _registerListRegexes();
  _registerGetRegex();
  _registerCreateRegex();
  _registerUpdateRegex();
  _registerTestRegex();
}

/// 注销所有正则工具。
void unregisterRegexTools() {
  for (final name in _toolNames) {
    ToolRegistry.instance.unregister(name);
  }
}

const _toolNames = [
  'list_regexes',
  'get_regex',
  'create_regex',
  'update_regex',
  'test_regex',
];

VaultSettingController get _ctrl => Get.find<VaultSettingController>();

/// 将 [RegexModel] 转换为简短摘要 map（不含 pattern / replacement 详情）。
Map<String, dynamic> _regexSummary(RegexModel r) {
  final scopes = <String>[];
  if (r.scopeUser) scopes.add('user');
  if (r.scopeAssistant) scopes.add('assistant');

  final stages = <String>[];
  if (r.onRender) stages.add('render');
  if (r.onRequest) stages.add('request');
  if (r.onAddMessage) stages.add('add_message');

  return {
    'id': r.id,
    'name': r.name,
    'enabled': r.enabled,
    'scope': scopes,
    'apply_stage': stages,
    'depth_min': r.depthMin,
    'depth_max': r.depthMax,
  };
}

/// 将 [RegexModel] 转换为详细 JSON map（包含所有字段）。
Map<String, dynamic> _regexDetail(RegexModel r) {
  return {
    'id': r.id,
    'name': r.name,
    'pattern': r.pattern,
    'replacement': r.replacement,
    'trim': r.trim,
    'enabled': r.enabled,
    'on_render': r.onRender,
    'on_request': r.onRequest,
    'on_add_message': r.onAddMessage,
    'scope_user': r.scopeUser,
    'scope_assistant': r.scopeAssistant,
    'depth_min': r.depthMin,
    'depth_max': r.depthMax,
    'scope_character': r.scopeCharacter,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// 工具实现
// ═══════════════════════════════════════════════════════════════════════════

void _registerListRegexes() {
  ToolRegistry.instance.register(
    name: 'list_regexes',
    description: '列出所有全局正则表达式。返回每个正则的 id、名称、启用状态、作用域和应用阶段。',
    parameters: {
      'type': 'object',
      'properties': {},
    },
    executor: (ctx) async { 
      final list = _ctrl.regexes.toList();

      if (list.isEmpty) {
        return '还没有任何全局正则表达式。';
      }

      final result = list.map(_regexSummary).toList();

      return jsonEncode({
        'total': list.length,
        'regexes': result,
      });
    },
  );
}

void _registerGetRegex() {
  ToolRegistry.instance.register(
    name: 'get_regex',
    description: '查看指定全局正则表达式的完整详情，包括正则模式、替换文本、作用域等所有字段。',
    parameters: {
      'type': 'object',
      'properties': {
        'id': {
          'type': 'integer',
          'description': '正则表达式 ID',
        },
      },
      'required': ['id'],
    },
    executor: (ctx) async {
      final id = ctx['id'] as int;
      final regex = _ctrl.regexes.firstWhereOrNull((r) => r.id == id);

      if (regex == null) {
        return '未找到 id 为 $id 的全局正则表达式。';
      }

      return jsonEncode(_regexDetail(regex));
    },
  );
}

void _registerCreateRegex() {
  ToolRegistry.instance.register(
    name: 'create_regex',
    description: '创建一个新的全局正则表达式。'
        'name 是正则名称，pattern 是正则表达式（支持 JS 风格 /pattern/flags），'
        'replacement 是替换文本（支持 \$1、\$2 等捕获组引用）。'
        '其他可选字段使用默认值。',
    parameters: {
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string',
          'description': '正则名称',
        },
        'pattern': {
          'type': 'string',
          'description': '正则表达式。支持 JS 风格：/pattern/flags（如 /hello/gi），也支持纯 pattern 字符串',
        },
        'replacement': {
          'type': 'string',
          'description': '替换文本，支持 \$1、\$2 等捕获组引用。默认空字符串（即删除匹配内容）。',
        },
        'enabled': {
          'type': 'boolean',
          'description': '是否启用。默认 true。',
        },
        'trim': {
          'type': 'string',
          'description': '预处理修减文本，每行一个。在正则替换前先去除这些文本。',
        },
        'on_render': {
          'type': 'boolean',
          'description': '是否在渲染时应用。默认 false。',
        },
        'on_request': {
          'type': 'boolean',
          'description': '是否在向 AI 发送请求时应用。默认 false。',
        },
        'on_add_message': {
          'type': 'boolean',
          'description': '是否在添加消息时应用（会影响消息记录）。默认 false。',
        },
        'scope_user': {
          'type': 'boolean',
          'description': '是否作用于用户消息。默认 false。',
        },
        'scope_assistant': {
          'type': 'boolean',
          'description': '是否作用于 AI 消息。默认 false。',
        },
        'depth_min': {
          'type': 'integer',
          'description': '作用深度最小值（0 为最新消息）。默认 -1（不限制）。',
        },
        'depth_max': {
          'type': 'integer',
          'description': '作用深度最大值。默认 -1（无限）。',
        },
      },
      'required': ['name', 'pattern'],
    },
    executor: (ctx) async {
      final name = ctx['name'] as String;
      final pattern = ctx['pattern'] as String;
      final replacement = ctx['replacement'] as String? ?? '';
      final enabled = ctx['enabled'] as bool? ?? true;
      final trim = ctx['trim'] as String?;
      final onRender = ctx['on_render'] as bool? ?? false;
      final onRequest = ctx['on_request'] as bool? ?? false;
      final onAddMessage = ctx['on_add_message'] as bool? ?? false;
      final scopeUser = ctx['scope_user'] as bool? ?? false;
      final scopeAssistant = ctx['scope_assistant'] as bool? ?? false;
      final depthMin = ctx['depth_min'] as int? ?? -1;
      final depthMax = ctx['depth_max'] as int? ?? -1;

      final regex = RegexModel(
        id: DateTime.now().microsecondsSinceEpoch,
        name: name,
        pattern: pattern,
        replacement: replacement,
        trim: trim,
        enabled: enabled,
        onRender: onRender,
        onRequest: onRequest,
        onAddMessage: onAddMessage,
        scopeUser: scopeUser,
        scopeAssistant: scopeAssistant,
        depthMin: depthMin,
        depthMax: depthMax,
      );

      _ctrl.regexes.add(regex);
      await _ctrl.saveSettings();

      // 列出实际生效的字段
      final activeStages = <String>[];
      if (onRender) activeStages.add('render');
      if (onRequest) activeStages.add('request');
      if (onAddMessage) activeStages.add('add_message');
      final activeScopes = <String>[];
      if (scopeUser) activeScopes.add('user');
      if (scopeAssistant) activeScopes.add('assistant');

      return '已创建全局正则 "$name"（id: ${regex.id}）\n'
          '模式: $pattern\n'
          '替换: "${replacement}"\n'
          '应用阶段: ${activeStages.isNotEmpty ? activeStages.join(", ") : "未设置"}\n'
          '作用域: ${activeScopes.isNotEmpty ? activeScopes.join(", ") : "未设置"}\n'
          '深度范围: [$depthMin, ${depthMax == -1 ? "∞" : "$depthMax"}]';
    },
  );
}

void _registerUpdateRegex() {
  ToolRegistry.instance.register(
    name: 'update_regex',
    description: '修改指定全局正则表达式。只需传要修改的字段。',
    parameters: {
      'type': 'object',
      'properties': {
        'id': {
          'type': 'integer',
          'description': '要修改的正则表达式 ID',
        },
        'name': {
          'type': 'string',
          'description': '新的名称（不传则保持不变）',
        },
        'pattern': {
          'type': 'string',
          'description': '新的正则表达式（不传则保持不变）',
        },
        'replacement': {
          'type': 'string',
          'description': '新的替换文本（不传则保持不变）',
        },
        'enabled': {
          'type': 'boolean',
          'description': '是否启用（不传则保持不变）',
        },
        'trim': {
          'type': 'string',
          'description': '新的预处理修减文本（不传则保持不变）',
        },
        'on_render': {
          'type': 'boolean',
          'description': '是否在渲染时应用（不传则保持不变）',
        },
        'on_request': {
          'type': 'boolean',
          'description': '是否在向 AI 发送请求时应用（不传则保持不变）',
        },
        'on_add_message': {
          'type': 'boolean',
          'description': '是否在添加消息时应用（不传则保持不变）',
        },
        'scope_user': {
          'type': 'boolean',
          'description': '是否作用于用户消息（不传则保持不变）',
        },
        'scope_assistant': {
          'type': 'boolean',
          'description': '是否作用于 AI 消息（不传则保持不变）',
        },
        'depth_min': {
          'type': 'integer',
          'description': '作用深度最小值（不传则保持不变）',
        },
        'depth_max': {
          'type': 'integer',
          'description': '作用深度最大值（不传则保持不变）',
        },
      },
      'required': ['id'],
    },
    executor: (ctx) async {
      final id = ctx['id'] as int;
      final index = _ctrl.regexes.indexWhere((r) => r.id == id);

      if (index == -1) {
        return '未找到 id 为 $id 的全局正则表达式。';
      }

      final old = _ctrl.regexes[index];
      final updated = old.copyWith(
        name: ctx['name'] as String?,
        pattern: ctx['pattern'] as String?,
        replacement: ctx['replacement'] as String?,
        enabled: ctx['enabled'] as bool?,
        trim: ctx['trim'] as String?,
        onRender: ctx['on_render'] as bool?,
        onRequest: ctx['on_request'] as bool?,
        onResponse: ctx['on_add_message'] as bool?,
        scopeUser: ctx['scope_user'] as bool?,
        scopeAssistant: ctx['scope_assistant'] as bool?,
        depthMin: ctx['depth_min'] as int?,
        depthMax: ctx['depth_max'] as int?,
      );

      _ctrl.regexes[index] = updated;
      await _ctrl.saveSettings();

      final changes = <String>[];
      if (ctx['name'] != null) changes.add('名称 → "${updated.name}"');
      if (ctx['pattern'] != null) changes.add('模式已更新');
      if (ctx['replacement'] != null) changes.add('替换文本已更新');
      if (ctx['enabled'] != null) changes.add('启用 → ${updated.enabled}');
      if (ctx['trim'] != null) changes.add('修减文本已更新');
      if (ctx['on_render'] != null) changes.add('渲染时应用 → ${updated.onRender}');
      if (ctx['on_request'] != null) changes.add('请求时应用 → ${updated.onRequest}');
      if (ctx['on_add_message'] != null) changes.add('添加消息时应用 → ${updated.onAddMessage}');
      if (ctx['scope_user'] != null) changes.add('作用用户 → ${updated.scopeUser}');
      if (ctx['scope_assistant'] != null) changes.add('作用AI → ${updated.scopeAssistant}');
      if (ctx['depth_min'] != null) changes.add('depthMin → ${updated.depthMin}');
      if (ctx['depth_max'] != null) changes.add('depthMax → ${updated.depthMax}');

      return '已更新正则 "${updated.name}"（${changes.join("，")}）。';
    },
  );
}

void _registerTestRegex() {
  ToolRegistry.instance.register(
    name: 'test_regex',
    description: '测试指定全局正则表达式对输入文本的应用效果。'
        '会先应用 trim 预处理（如果有），再应用正则替换，返回处理后的文本。'
        '如果正则未启用，仍会执行测试。',
    parameters: {
      'type': 'object',
      'properties': {
        'id': {
          'type': 'integer',
          'description': '要测试的正则表达式 ID',
        },
        'text': {
          'type': 'string',
          'description': '要测试的输入文本',
        },
      },
      'required': ['id', 'text'],
    },
    executor: (ctx) async {
      final id = ctx['id'] as int;
      final text = ctx['text'] as String;

      final regex = _ctrl.regexes.firstWhereOrNull((r) => r.id == id);
      if (regex == null) {
        return '未找到 id 为 $id 的全局正则表达式。';
      }

      // 测试时无视 enabled 状态，强制启用处理
      final testRegex = regex.copyWith(enabled: true);
      final result = testRegex.process(text);

      final changed = result != text;

      return jsonEncode({
        'regex_id': id,
        'regex_name': regex.name,
        'pattern': regex.pattern,
        'replacement': regex.replacement,
        'trim': regex.trim,
        'input_length': text.length,
        'output_length': result.length,
        'changed': changed,
        'input_preview': text.length > 500 ? '${text.substring(0, 500)}...' : text,
        'output_preview': result.length > 500 ? '${result.substring(0, 500)}...' : result,
      });
    },
  );
}
