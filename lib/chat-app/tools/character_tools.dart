import 'dart:convert';

import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/utils/tool_registry.dart';
import 'package:get/get.dart';

/// 注册所有角色 (Character) 相关工具。
///
/// 在 [CharacterController] 就绪后调用。
void registerCharacterTools() {
  _registerSearchCharacters();
  _registerListCharacters();
  _registerCreateCharacter();
  _registerUpdateCharacter();
  _registerDeleteCharacter();
}

/// 注销所有角色工具。
void unregisterCharacterTools() {
  for (final name in _toolNames) {
    ToolRegistry.instance.unregister(name);
  }
}

const _toolNames = [
  'search_characters',
  'list_characters',
  'create_character',
  'update_character',
  'delete_character',
];

CharacterController get _ctrl => Get.find<CharacterController>();

// ═══════════════════════════════════════════════════════════════════════════
// 角色工具
// ═══════════════════════════════════════════════════════════════════════════

void _registerSearchCharacters() {
  ToolRegistry.instance.register(
    name: 'search_characters',
    description: '按关键词查找角色。同时匹配角色名称（roleName）和备注（remark）。',
    parameters: {
      'type': 'object',
      'properties': {
        'keyword': {
          'type': 'string',
          'description': '搜索关键词，同时匹配角色名称和备注',
        },
      },
      'required': ['keyword'],
    },
    executor: (ctx) async {
      final keyword = (ctx['keyword'] as String).toLowerCase();

      final matched = _ctrl.characters.where((c) {
        return c.roleName.toLowerCase().contains(keyword) ||
            c.remark.toLowerCase().contains(keyword);
      }).toList();

      if (matched.isEmpty) {
        return '未找到匹配 "$keyword" 的角色。';
      }

      final result = matched.map((c) => {
            'id': c.id,
            'role_name': c.roleName,
            'remark': c.remark,
            'brief': c.brief,
            'category': c.category,
          }).toList();

      return jsonEncode({
        'keyword': keyword,
        'total': matched.length,
        'characters': result,
      });
    },
  );
}

void _registerListCharacters() {
  ToolRegistry.instance.register(
    name: 'list_characters',
    description: '列出所有角色（不含临时角色）。返回角色的基本信息。',
    parameters: {
      'type': 'object',
      'properties': {},
    },
    executor: (ctx) async {
      // 排除临时角色（绑定到故事的角色）
      final list = _ctrl.characters.where((c) => c.bindStoryId == null).toList();

      if (list.isEmpty) {
        return '还没有任何角色。';
      }

      final result = list.map((c) => {
            'id': c.id,
            'role_name': c.roleName,
            'remark': c.remark,
            'brief': c.brief,
            'category': c.category,
          }).toList();

      return jsonEncode({
        'total': list.length,
        'characters': result,
      });
    },
  );
}

void _registerCreateCharacter() {
  ToolRegistry.instance.register(
    name: 'create_character',
    description: '创建一个新角色。'
        'roleName 是角色名称，brief 是简略信息（关键信息摘要），archive 是完整人设信息。',
    parameters: {
      'type': 'object',
      'properties': {
        'role_name': {
          'type': 'string',
          'description': '角色名称（唯一标识）',
        },
        'brief': {
          'type': 'string',
          'description': '简略信息，包含角色的关键特征摘要',
        },
        'archive': {
          'type': 'string',
          'description': '完整人设信息，包含角色的详细背景、性格、经历等',
        },
        'category': {
          'type': 'string',
          'description': '角色分组名称。默认空字符串（不分组）。',
        },
      },
      'required': ['role_name'],
    },
    executor: (ctx) async {
      final roleName = ctx['role_name'] as String;
      final brief = ctx['brief'] as String?;
      final archive = ctx['archive'] as String?;
      final category = ctx['category'] as String? ?? '';

      final character = CharacterModel(
        id: DateTime.now().microsecondsSinceEpoch,
        remark: roleName,
        roleName: roleName,
        avatar: '',
        category: category,
      )
        ..brief = brief
        ..archive = archive ?? '';

      await _ctrl.addCharacter(character);
      return '已创建角色 "$roleName"（id: ${character.id}）。';
    },
  );
}

void _registerUpdateCharacter() {
  ToolRegistry.instance.register(
    name: 'update_character',
    description: '修改指定角色的信息。只需传要修改的字段。'
        'roleName 是角色名称，brief 是简略信息，archive 是完整人设信息。',
    parameters: {
      'type': 'object', 
      'properties': {
        'id': {
          'type': 'integer',
          'description': '要修改的角色 ID',
        },
        'role_name': {
          'type': 'string',
          'description': '新的角色名称（不传则保持不变）',
        },
        'brief': { 
          'type': 'string',
          'description': '新的简略信息（不传则保持不变）',
        },
        'archive': {
          'type': 'string',
          'description': '新的完整人设信息（不传则保持不变）',
        },
      },
      'required': ['id'],
    },
    executor: (ctx) async {
      final id = ctx['id'] as int;
      final character = _ctrl.getCharacterById(id);

      // getCharacterById 对不存在的 id 会返回 defaultCharacter (id=-1)
      if (character.id != id || character.id == -1 && id != -1) {
        return '未找到 id 为 $id 的角色。';
      }

      final newRoleName = ctx['role_name'] as String?;
      String? newRemark;
      if (newRoleName != null) {
        // 当 roleName 变化时同步更新 remark
        newRemark = newRoleName;
      }

      final updated = character.copyWith(
        roleName: newRoleName,
        remark: newRemark,
        brief: ctx['brief'] as String?,
        archive: ctx['archive'] as String?,
      );

      await _ctrl.updateCharacter(updated);

      final changes = <String>[];
      if (newRoleName != null) changes.add('角色名 → "$newRoleName"');
      if (ctx['brief'] != null) changes.add('简略信息已更新');
      if (ctx['archive'] != null) changes.add('完整人设已更新');
      return '已更新角色 "${updated.roleName}"（${changes.join("，")}）。';
    },
  );
}

void _registerDeleteCharacter() {
  ToolRegistry.instance.register(
    name: 'delete_character',
    description: '删除指定角色。此操作不可撤销。无法删除内置角色（id 为 -1 或 0 或 -2）。',
    parameters: {
      'type': 'object',
      'properties': {
        'id': {
          'type': 'integer',
          'description': '要删除的角色 ID',
        },
      },
      'required': ['id'],
    },
    executor: (ctx) async {
      final id = ctx['id'] as int;

      // 保护内置角色
      if (id == -1 || id == 0 || id == -2) {
        return '无法删除内置角色（id: $id）。';
      }

      final character = _ctrl.getCharacterById(id);
      if (character.id != id) {
        return '未找到 id 为 $id 的角色，无需删除。';
      }

      final name = character.roleName;
      await _ctrl.deleteCharacter(id);
      return '已删除角色 "$name"（id: $id）。';
    },
  );
}
