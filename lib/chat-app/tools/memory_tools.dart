import 'dart:convert';

import 'package:flutter_example/chat-app/models/memory_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/story_controller.dart';
import 'package:flutter_example/chat-app/utils/tool_registry.dart';
import 'package:get/get.dart';

/// 注册所有记忆 (Memory) 相关工具。
void registerMemoryTools() {
  _registerListMemoryEntries();
  _registerCreateMemoryEntry();
  _registerUpdateMemoryEntry();
  _registerDeleteMemoryEntry();
}

/// 注销所有记忆工具。
void unregisterMemoryTools() {
  for (final name in _toolNames) {
    ToolRegistry.instance.unregister(name);
  }
}

const _toolNames = [
  'list_memory_entries',
  'create_memory_entry',
  'update_memory_entry',
  'delete_memory_entry',
];

CharacterController get _charCtrl => Get.find<CharacterController>();
StoryController get _storyCtrl => Get.find<StoryController>();

/// 根据 target_type 和 target_id 获取 MemoryModel 并返回保存函数。
/// 返回 (memory, saveFn, ownerName)。
(Map<String, dynamic>, String Function())? _resolveMemory(
    String targetType, dynamic targetId) {
  if (targetType == 'character') {
    final id = targetId is int ? targetId : int.tryParse(targetId.toString());
    if (id == null) return null;
    final char = _charCtrl.getCharacterById(id);
    if (char.id != id) return null;
    final memory = char.memory ?? MemoryModel();
    char.memory = memory;
    return (
      {'memory': memory, 'id': id, 'type': 'character'},
      () {
        _charCtrl.updateCharacter(char);
        return char.roleName;
      },
    );
  } else if (targetType == 'story') {
    final story = _storyCtrl.getStoryById(targetId.toString());
    if (story == null) return null;
    final memory = story.memory ?? MemoryModel();
    story.memory = memory;
    return (
      {'memory': memory, 'id': targetId, 'type': 'story'},
      () {
        _storyCtrl.updateStory(story);
        return story.name;
      },
    );
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════════════════
// 记忆条目工具
// ═══════════════════════════════════════════════════════════════════════════

void _registerListMemoryEntries() {
  ToolRegistry.instance.register(
    name: 'list_memory_entries',
    description: '列出指定角色或故事的记忆条目。',
    parameters: {
      'type': 'object',
      'properties': {
        'target_type': {
          'type': 'string',
          'description': '目标类型：character（角色）或 story（故事）',
          'enum': ['character', 'story'],
        },
        'target_id': {
          'description':
              '目标 ID。角色 ID 为整数，故事 ID 为字符串。',
        },
      },
      'required': ['target_type', 'target_id'],
    },
    executor: (args) async {
      final targetType = args['target_type'] as String;
      final targetId = args['target_id'];

      final resolved = _resolveMemory(targetType, targetId);
      if (resolved == null) {
        return '未找到 $targetType（id: $targetId）。';
      }

      final memory = resolved.$1['memory'] as MemoryModel;
      if (memory.entries.isEmpty) {
        return '该 $targetType 还没有任何记忆条目。';
      }

      final result = memory.entries.map((e) => {
            'id': e.id,
            'content': e.content,
            'created_at': e.createdAt.toIso8601String(),
            'is_active': e.isActive,
          }).toList();

      return jsonEncode({
        'target_type': targetType,
        'target_id': targetId.toString(),
        'total': memory.entries.length,
        'entries': result,
      });
    },
  );
}

void _registerCreateMemoryEntry() {
  ToolRegistry.instance.register(
    name: 'create_memory_entry',
    description: '为指定角色或故事创建一条记忆条目。',
    parameters: {
      'type': 'object',
      'properties': {
        'target_type': {
          'type': 'string',
          'description': '目标类型：character 或 story',
          'enum': ['character', 'story'],
        },
        'target_id': {
          'description': '目标 ID。',
        },
        'content': {
          'type': 'string',
          'description': '记忆正文内容',
        },
        'is_active': {
          'type': 'boolean',
          'description': '是否启用。默认 true。',
        },
      },
      'required': ['target_type', 'target_id', 'content'],
    },
    executor: (args) async {
      final targetType = args['target_type'] as String;
      final targetId = args['target_id'];
      final content = args['content'] as String;
      final isActive = args['is_active'] as bool? ?? true;

      final resolved = _resolveMemory(targetType, targetId);
      if (resolved == null) {
        return '未找到 $targetType（id: $targetId）。';
      }

      final memory = resolved.$1['memory'] as MemoryModel;
      final entry = MemoryEntryModel(
        id: DateTime.now().microsecondsSinceEpoch,
        content: content,
        isActive: isActive,
      );

      memory.entries.add(entry);
      final ownerName = resolved.$2();
      return '已为 $targetType "$ownerName" 创建记忆条目（id: ${entry.id}）。';
    },
  );
}

void _registerUpdateMemoryEntry() {
  ToolRegistry.instance.register(
    name: 'update_memory_entry',
    description: '修改指定角色或故事的一条记忆条目。只需传要修改的字段。',
    parameters: {
      'type': 'object',
      'properties': {
        'target_type': {
          'type': 'string',
          'description': '目标类型：character 或 story',
          'enum': ['character', 'story'],
        },
        'target_id': {
          'description': '目标 ID。',
        },
        'entry_id': {
          'type': 'integer',
          'description': '记忆条目 ID',
        },
        'content': {
          'type': 'string',
          'description': '新的记忆正文（不传则保持不变）',
        },
        'is_active': {
          'type': 'boolean',
          'description': '是否启用（不传则保持不变）',
        },
      },
      'required': ['target_type', 'target_id', 'entry_id'],
    },
    executor: (args) async {
      final targetType = args['target_type'] as String;
      final targetId = args['target_id'];
      final entryId = args['entry_id'] as int;

      final resolved = _resolveMemory(targetType, targetId);
      if (resolved == null) {
        return '未找到 $targetType（id: $targetId）。';
      }

      final memory = resolved.$1['memory'] as MemoryModel;
      final index = memory.entries.indexWhere((e) => e.id == entryId);
      if (index == -1) {
        return '未找到 id 为 $entryId 的记忆条目。';
      }

      final oldEntry = memory.entries[index];
      final newEntry = oldEntry.copyWith(
        content: args['content'] as String?,
        isActive: args['is_active'] as bool?,
      );

      memory.entries[index] = newEntry;
      final ownerName = resolved.$2();

      final changes = <String>[];
      if (args['content'] != null) changes.add('正文已更新');
      if (args['is_active'] != null) {
        changes.add('激活状态 → ${newEntry.isActive}');
      }
      return '已更新 $targetType "$ownerName" 的记忆条目（${changes.join("，")}）。';
    },
  );
}

void _registerDeleteMemoryEntry() {
  ToolRegistry.instance.register(
    name: 'delete_memory_entry',
    description: '删除指定角色或故事的一条记忆条目。此操作不可撤销。',
    parameters: {
      'type': 'object',
      'properties': {
        'target_type': {
          'type': 'string',
          'description': '目标类型：character 或 story',
          'enum': ['character', 'story'],
        },
        'target_id': {
          'description': '目标 ID。',
        },
        'entry_id': {
          'type': 'integer',
          'description': '要删除的记忆条目 ID',
        },
      },
      'required': ['target_type', 'target_id', 'entry_id'],
    },
    executor: (args) async {
      final targetType = args['target_type'] as String;
      final targetId = args['target_id'];
      final entryId = args['entry_id'] as int;

      final resolved = _resolveMemory(targetType, targetId);
      if (resolved == null) {
        return '未找到 $targetType（id: $targetId）。';
      }

      final memory = resolved.$1['memory'] as MemoryModel;
      final entry = memory.entries.firstWhereOrNull((e) => e.id == entryId);
      if (entry == null) {
        return '未找到 id 为 $entryId 的记忆条目，无需删除。';
      }

      memory.entries.removeWhere((e) => e.id == entryId);
      final ownerName = resolved.$2();
      return '已从 $targetType "$ownerName" 中删除记忆条目（id: $entryId）。';
    },
  );
}
