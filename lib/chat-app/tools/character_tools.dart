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
  _registerEditCharacterField();
  _registerListCharacterRelations();
  _registerAddCharacterRelation();
  _registerUpdateCharacterRelation();
  _registerRemoveCharacterRelation();
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
  'edit_character_field',
  'list_character_relations',
  'add_character_relation',
  'update_character_relation',
  'remove_character_relation',
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

      final matched = _ctrl.getAllCharacters().where((c) {
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
            'archive': c.archive,
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
      final list = _ctrl.getAllCharacters();

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
        id: DateTime.now().millisecondsSinceEpoch,
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
        id: character.id,
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

void _registerEditCharacterField() {
  ToolRegistry.instance.register(
    name: 'edit_character_field',
    description: '对指定角色的 brief 或 archive 字段进行局部字符串替换编辑。'
        '仅修改匹配到的部分文本，无需传递全量内容。'
        '适用于小范围调整角色设定、修改特定段落等场景。',
    parameters: {
      'type': 'object',
      'properties': {
        'character_id': {
          'type': 'integer',
          'description': '要编辑的角色 ID',
        },
        'field': {
          'type': 'string',
          'enum': ['brief', 'archive'],
          'description': '要编辑的字段：brief（简略信息）或 archive（完整人设）',
        },
        'old_text': {
          'type': 'string',
          'description': '要查找并替换的文本（普通字符串匹配）',
        },
        'new_text': {
          'type': 'string',
          'description': '替换后的新文本。默认为空字符串（即删除匹配到的文本）。',
        },
      },
      'required': ['character_id', 'field', 'old_text'],
    },
    executor: (ctx) async {
      final characterId = ctx['character_id'] as int;
      final field = ctx['field'] as String;
      final oldText = ctx['old_text'] as String;
      final newText = ctx['new_text'] as String? ?? '';

      if (oldText.isEmpty) {
        return 'old_text 不能为空。';
      }

      final character = _ctrl.getCharacterById(characterId);
      if (character.id != characterId || (character.id == -1 && characterId != -1)) {
        return '未找到 id 为 $characterId 的角色。';
      }

      // 读取原始字段内容
      String original;
      switch (field) {
        case 'brief':
          original = character.brief ?? '';
          break;
        case 'archive':
          original = character.archive;
          break;
        default:
          return '不支持的字段: "$field"，仅支持 brief 和 archive。';
      }

      if (!original.contains(oldText)) {
        return '在角色"${character.roleName}"的 $field 字段中未找到匹配的文本。'
            '请先使用 get_character 工具查看该字段的完整内容，确认 old_text 是否正确。';
      }

      // 执行字符串替换（仅替换第一个匹配，避免误改）
      final modified = original.replaceFirst(oldText, newText);

      // 构建更新后的角色
      final updated = character.copyWith(id: character.id)
        ..brief = (field == 'brief' ? modified : character.brief)
        ..archive = (field == 'archive' ? modified : character.archive);

      await _ctrl.updateCharacter(updated);

      final oldLen = original.length;
      final newLen = modified.length;
      final delta = newLen - oldLen;

      return '已更新角色"${character.roleName}"的 $field 字段。\n'
          '匹配位置: 找到并替换了第一处匹配\n'
          '字段长度变化: $oldLen → $newLen (${delta >= 0 ? '+' : ''}$delta)';
    },
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 角色关系工具
// ═══════════════════════════════════════════════════════════════════════════

/// 根据 target_id 解析目标角色名，查找失败则返回 null。
String? _resolveTargetName(int targetId) {
  final char = _ctrl.getCharacterById(targetId);
  return char.id == targetId ? char.roleName : null;
}

void _registerListCharacterRelations() {
  ToolRegistry.instance.register(
    name: 'list_character_relations',
    description: '列出指定角色的所有人物关系。返回每个关系的目标角色名称、关系类型和关系简述。',
    parameters: {
      'type': 'object',
      'properties': {
        'character_id': {
          'type': 'integer',
          'description': '要查询关系的角色 ID',
        },
      },
      'required': ['character_id'],
    },
    executor: (ctx) async {
      final characterId = ctx['character_id'] as int;
      final character = _ctrl.getCharacterById(characterId);
      if (character.id != characterId || (character.id == -1 && characterId != -1)) {
        return '未找到 id 为 $characterId 的角色。';
      }

      if (character.relations.isEmpty) {
        return '角色"${character.roleName}"还没有任何人物关系。';
      }

      final result = character.relations.entries.map((entry) {
        final rel = entry.value;
        return {
          'target_id': rel.targetId,
          'target_name': _resolveTargetName(rel.targetId) ?? '未知角色',
          'type': rel.type,
          'brief': rel.brief,
        };
      }).toList();

      return jsonEncode({
        'character_id': character.id,
        'character_name': character.roleName,
        'total': result.length,
        'relations': result,
      });
    },
  );
}

void _registerAddCharacterRelation() {
  ToolRegistry.instance.register(
    name: 'add_character_relation',
    description: '为指定角色添加一条人物关系。关系的 key 使用 target_id。'
        '如果该 target_id 的关系已存在，则会覆盖。',
    parameters: {
      'type': 'object',
      'properties': {
        'character_id': {
          'type': 'integer',
          'description': '要添加关系的角色 ID',
        },
        'target_id': {
          'type': 'integer',
          'description': '关系目标角色 ID',
        },
        'type': {
          'type': 'string',
          'description': '关系类型，如"朋友"、"恋人"、"敌人"、"家人"、"同事"等。默认"朋友"。',
        },
        'brief': {
          'type': 'string',
          'description': '关系的简要描述，如"从小一起长大的青梅竹马"',
        },
      },
      'required': ['character_id', 'target_id'],
    },
    executor: (ctx) async {
      final characterId = ctx['character_id'] as int;
      final targetId = ctx['target_id'] as int;
      final relationType = ctx['type'] as String? ?? '朋友';
      final relationBrief = ctx['brief'] as String?;

      if (characterId == targetId) {
        return '不能为角色添加与自身的关系。';
      }

      final character = _ctrl.getCharacterById(characterId);
      if (character.id != characterId || (character.id == -1 && characterId != -1)) {
        return '未找到 id 为 $characterId 的角色。';
      }

      // 验证目标角色存在
      final targetName = _resolveTargetName(targetId);
      if (targetName == null) {
        return '未找到目标角色（id: $targetId）。请先创建该角色再添加关系。';
      }

      final isUpdate = character.relations.containsKey(targetId);

      final relation = Relation(targetId: targetId)
        ..type = relationType
        ..brief = relationBrief;

      final newRelations = Map<int, Relation>.from(character.relations);
      newRelations[targetId] = relation;

      final updated = character.copyWith(id: character.id, relations: newRelations);
      await _ctrl.updateCharacter(updated);

      final action = isUpdate ? '已更新（原关系已覆盖）' : '已添加';
      return '$action角色"${character.roleName}"与"$targetName"的关系。\n'
          '类型: $relationType${relationBrief != null ? '\n简述: $relationBrief' : ''}';
    },
  );
}

void _registerUpdateCharacterRelation() {
  ToolRegistry.instance.register(
    name: 'update_character_relation',
    description: '修改指定角色的某条已有人物关系。只传需要修改的字段。',
    parameters: {
      'type': 'object',
      'properties': {
        'character_id': {
          'type': 'integer',
          'description': '角色 ID',
        },
        'target_id': {
          'type': 'integer',
          'description': '要修改的关系目标角色 ID',
        },
        'type': {
          'type': 'string',
          'description': '新的关系类型（不传则保持不变）',
        },
        'brief': {
          'type': 'string',
          'description': '新的关系简述（不传则保持不变）',
        },
      },
      'required': ['character_id', 'target_id'],
    },
    executor: (ctx) async {
      final characterId = ctx['character_id'] as int;
      final targetId = ctx['target_id'] as int;
      final newType = ctx['type'] as String?;
      final newBrief = ctx['brief'] as String?;

      if (newType == null && newBrief == null) {
        return '请至少提供 type 或 brief 中的一个字段进行修改。';
      }

      final character = _ctrl.getCharacterById(characterId);
      if (character.id != characterId || (character.id == -1 && characterId != -1)) {
        return '未找到 id 为 $characterId 的角色。';
      }

      final existing = character.relations[targetId];
      if (existing == null) {
        final targetName = _resolveTargetName(targetId) ?? '未知角色';
        return '角色"${character.roleName}"与"$targetName"（id: $targetId）之间不存在关系。'
            '请先使用 add_character_relation 添加关系。';
      }

      final updated = existing.copy()
        ..type = newType ?? existing.type
        ..brief = newBrief ?? existing.brief;

      final newRelations = Map<int, Relation>.from(character.relations);
      newRelations[targetId] = updated;

      final updatedChar = character.copyWith(id: character.id, relations: newRelations);
      await _ctrl.updateCharacter(updatedChar);

      final targetName = _resolveTargetName(targetId) ?? '未知角色';
      final changes = <String>[];
      if (newType != null) changes.add('类型 → "$newType"');
      if (newBrief != null) changes.add('简述已更新');

      return '已更新角色"${character.roleName}"与"$targetName"的关系（${changes.join("，")}）。';
    },
  );
}

void _registerRemoveCharacterRelation() {
  ToolRegistry.instance.register(
    name: 'remove_character_relation',
    description: '移除指定角色的一条人物关系。此操作不可撤销。',
    parameters: {
      'type': 'object',
      'properties': {
        'character_id': {
          'type': 'integer',
          'description': '角色 ID',
        },
        'target_id': {
          'type': 'integer',
          'description': '要移除的关系目标角色 ID',
        },
      },
      'required': ['character_id', 'target_id'],
    },
    executor: (ctx) async {
      final characterId = ctx['character_id'] as int;
      final targetId = ctx['target_id'] as int;

      final character = _ctrl.getCharacterById(characterId);
      if (character.id != characterId || (character.id == -1 && characterId != -1)) {
        return '未找到 id 为 $characterId 的角色。';
      }

      final existing = character.relations[targetId];
      if (existing == null) {
        final targetName = _resolveTargetName(targetId) ?? '未知角色';
        return '角色"${character.roleName}"与"$targetName"（id: $targetId）之间不存在关系，无需删除。';
      }

      final newRelations = Map<int, Relation>.from(character.relations);
      newRelations.remove(targetId);

      final updated = character.copyWith(id: character.id, relations: newRelations);
      await _ctrl.updateCharacter(updated);

      final targetName = _resolveTargetName(targetId) ?? '未知角色';
      final oldType = existing.type ?? '未设置类型';
      return '已移除角色"${character.roleName}"与"$targetName"的关系（原类型: $oldType）。';
    },
  );
}
