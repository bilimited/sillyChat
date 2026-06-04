import 'dart:convert';

import 'package:flutter_example/chat-app/models/memory_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/story_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/tool_call_context.dart';
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

/// 从当前聊天上下文自动解析到的记忆访问句柄。
class _MemoryAccess {
  final MemoryModel memory;
  final String targetType; // 'character' | 'story'
  final String targetName;
  final void Function() save;

  _MemoryAccess({
    required this.memory,
    required this.targetType,
    required this.targetName,
    required this.save,
  });
}

/// 从当前聊天上下文自动解析 MemoryModel。
///
/// 优先故事（ctx.chat.bindStory），其次角色（ctx.chat.bindCharacter）。
/// 返回 null 表示当前聊天未绑定任何角色或故事。
_MemoryAccess? _resolveFromContext(ToolCallContext ctx) {
  final chat = ctx.chat;

  // 1) 故事聊天
  final story = chat.bindStory;
  if (story != null) {
    final memory = story.memory ?? MemoryModel();
    story.memory = memory;
    return _MemoryAccess(
      memory: memory,
      targetType: 'story',
      targetName: story.name,
      save: () => _storyCtrl.updateStory(story),
    );
  }

  // 2) 角色聊天
  final char = chat.bindCharacter;
  if (char != null) {
    final memory = char.memory ?? MemoryModel();
    char.memory = memory;
    return _MemoryAccess(
      memory: memory,
      targetType: 'character',
      targetName: char.roleName,
      save: () => _charCtrl.updateCharacter(char),
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
    description: '列出当前聊天所属角色或故事的全部记忆条目。',
    parameters: {
      'type': 'object',
      'properties': {},
    },
    executor: (ctx) async {
      final a = _resolveFromContext(ctx);
      if (a == null) return '当前聊天未绑定角色或故事，无法访问记忆。';

      if (a.memory.entries.isEmpty) {
        return '${a.targetType == 'story' ? '故事' : '角色'}"${a.targetName}"还没有任何记忆条目。';
      }

      final result = a.memory.entries.map((e) => {
            'id': e.id,
            'content': e.content,
            'created_at': e.createdAt.toIso8601String(),
            'is_active': e.isActive,
          }).toList();

      return jsonEncode({
        'target_type': a.targetType,
        'target_name': a.targetName,
        'total': a.memory.entries.length,
        'entries': result,
      });
    },
  );
}

void _registerCreateMemoryEntry() {
  ToolRegistry.instance.register(
    name: 'create_memory_entry',
    description: '为当前聊天所属角色或故事创建一条新的记忆条目。',
    parameters: {
      'type': 'object',
      'properties': {
        'content': {
          'type': 'string',
          'description': '记忆正文内容',
        },
        'is_active': {
          'type': 'boolean',
          'description': '是否启用。默认 true。',
        },
      },
      'required': ['content'],
    },
    executor: (ctx) async {
      final a = _resolveFromContext(ctx);
      if (a == null) return '当前聊天未绑定角色或故事，无法创建记忆。';

      final content = ctx['content'] as String;
      final isActive = ctx['is_active'] as bool? ?? true;

      final entry = MemoryEntryModel(
        id: DateTime.now().microsecondsSinceEpoch,
        content: content,
        isActive: isActive,
      );

      a.memory.entries.add(entry);
      a.save();
      return '已为${a.targetType == 'story' ? '故事' : '角色'}"${a.targetName}"创建记忆条目（id: ${entry.id}）。';
    },
  );
}

void _registerUpdateMemoryEntry() {
  ToolRegistry.instance.register(
    name: 'update_memory_entry',
    description: '修改当前聊天所属角色或故事的一条记忆条目。只需传要修改的字段。',
    parameters: {
      'type': 'object',
      'properties': {
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
      'required': ['entry_id'],
    },
    executor: (ctx) async {
      final a = _resolveFromContext(ctx);
      if (a == null) return '当前聊天未绑定角色或故事，无法修改记忆。';

      final entryId = ctx['entry_id'] as int;
      final index = a.memory.entries.indexWhere((e) => e.id == entryId);
      if (index == -1) return '未找到 id 为 $entryId 的记忆条目。';

      final oldEntry = a.memory.entries[index];
      final newEntry = oldEntry.copyWith(
        content: ctx['content'] as String?,
        isActive: ctx['is_active'] as bool?,
      );

      a.memory.entries[index] = newEntry;
      a.save();
 
      final changes = <String>[];
      if (ctx['content'] != null) changes.add('正文已更新');
      if (ctx['is_active'] != null) changes.add('激活状态 → ${newEntry.isActive}');
      return '已更新${a.targetType == 'story' ? '故事' : '角色'}"${a.targetName}"的记忆条目（${changes.join("，")}）。';
    },
  );
}

void _registerDeleteMemoryEntry() {
  ToolRegistry.instance.register(
    name: 'delete_memory_entry',
    description: '删除当前聊天所属角色或故事的一条记忆条目。此操作不可撤销。',
    parameters: {
      'type': 'object',
      'properties': {
        'entry_id': {
          'type': 'integer',
          'description': '要删除的记忆条目 ID',
        },
      },
      'required': ['entry_id'],
    },
    executor: (ctx) async {
      final a = _resolveFromContext(ctx);
      if (a == null) return '当前聊天未绑定角色或故事，无法删除记忆。';

      final entryId = ctx['entry_id'] as int;
      final entry = a.memory.entries.firstWhereOrNull((e) => e.id == entryId);
      if (entry == null) return '未找到 id 为 $entryId 的记忆条目，无需删除。';

      a.memory.entries.removeWhere((e) => e.id == entryId);
      a.save();
      return '已从${a.targetType == 'story' ? '故事' : '角色'}"${a.targetName}"中删除记忆条目（id: $entryId）。';
    },
  );
}
