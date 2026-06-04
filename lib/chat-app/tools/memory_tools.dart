import 'dart:convert';

import 'package:flutter_example/chat-app/models/memory_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/story_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/tool_call_context.dart';
import 'package:flutter_example/chat-app/utils/tool_registry.dart';
import 'package:get/get.dart';

/// 注册所有记忆 (Memory) 相关工具。
void registerMemoryTools() {
  // ── 默认记忆（短期记忆，长文本）──
  _registerReadDefaultMemory();
  _registerWriteDefaultMemory();
  _registerEditDefaultMemory();
  // ── 辅助记忆（长期记忆，条目式）──
  // _registerListAuxiliaryMemories();
  // _registerCreateAuxiliaryMemory();
  // _registerUpdateAuxiliaryMemory(); 
  // _registerDeleteAuxiliaryMemory();
}

/// 注销所有记忆工具。
void unregisterMemoryTools() {
  for (final name in _toolNames) {
    ToolRegistry.instance.unregister(name);
  }
}

const _toolNames = [
  'read_memory',
  'write_memory',
  'edit_memory',
  // 'list_auxiliary_memories',
  // 'create_auxiliary_memory',
  // 'update_auxiliary_memory',
  // 'delete_auxiliary_memory',
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

String _targetLabel(_MemoryAccess a) =>
    a.targetType == 'story' ? '故事' : '角色';

// ═══════════════════════════════════════════════════════════════════════════
// 默认记忆（短期记忆，长文本）— 默认注入 prompt
// ═══════════════════════════════════════════════════════════════════════════

void _registerReadDefaultMemory() {
  ToolRegistry.instance.register(
    name: 'read_memory',
    description: '读取当前的记忆。这是一段会自动注入到 prompt 中的长文本，'
        '用于记录当前会话的关键上下文、角色状态或近期事件。'
        '如需更结构化的持久记忆，请使用辅助记忆工具（list/create/update/delete_auxiliary_memory）。',
    parameters: {
      'type': 'object',
      'properties': {},
    },
    executor: (ctx) async {
      final a = _resolveFromContext(ctx);
      if (a == null) return '当前聊天未绑定角色或故事，无法访问记忆。';

      if (a.memory.defaultMemory.isEmpty) {
        return '${_targetLabel(a)}"${a.targetName}"还没有默认记忆。'
            '可以使用 write_memory 创建。';
      }

      return jsonEncode({
        'target_type': a.targetType,
        'target_name': a.targetName,
        'content': a.memory.defaultMemory,
        'length': a.memory.defaultMemory.length,
      });
    },
  );
}

void _registerWriteDefaultMemory() {
  ToolRegistry.instance.register(
    name: 'write_memory',
    description: '写入记忆。支持覆盖或追加模式。'
        '默认记忆是一段会自动注入到 prompt 中的长文本，适合记录当前会话的关键上下文。'
        '此操作会整体设置默认记忆内容。如需局部修改，请使用 edit_memory。',
    parameters: {
      'type': 'object',
      'properties': {
        'content': {
          'type': 'string',
          'description': '要写入的记忆内容',
        },
        'mode': {
          'type': 'string',
          'enum': ['overwrite', 'append'],
          'description': '写入模式：overwrite（覆盖，默认）或 append（追加到末尾）',
        },
      },
      'required': ['content'],
    },
    executor: (ctx) async {
      final a = _resolveFromContext(ctx);
      if (a == null) return '当前聊天未绑定角色或故事，无法访问记忆。';

      final content = ctx['content'] as String;
      final mode = ctx['mode'] as String? ?? 'overwrite';

      switch (mode) {
        case 'append':
          a.memory.defaultMemory += '\n$content';
          break;
        case 'overwrite':
        default:
          a.memory.defaultMemory = content;
          break;
      }

      a.save();
      final action = mode == 'append' ? '追加' : '写入';
      return '已${action}${_targetLabel(a)}"${a.targetName}"的默认记忆'
          '（当前长度: ${a.memory.defaultMemory.length} 字符）。';
    },
  );
}

void _registerEditDefaultMemory() {
  ToolRegistry.instance.register(
    name: 'edit_memory',
    description: '局部修改记忆。在记忆文本中查找 old_text 并替换为 new_text。'
        '类似文本编辑器的查找替换功能，适合进行小范围修改而无需重写整个记忆。'
        'old_text 必须在记忆文本中唯一匹配一次，否则编辑会失败。',
    parameters: {
      'type': 'object',
      'properties': {
        'old_text': {
          'type': 'string',
          'description': '要被替换的原文。必须在记忆文本中精确匹配且仅匹配一次。',
        },
        'new_text': {
          'type': 'string',
          'description': '替换后的新文本。传空字符串即删除 old_text。',
        },
      },
      'required': ['old_text', 'new_text'],
    },
    executor: (ctx) async {
      final a = _resolveFromContext(ctx);
      if (a == null) return '当前聊天未绑定角色或故事，无法访问记忆。';

      final oldText = ctx['old_text'] as String;
      final newText = ctx['new_text'] as String;
      final current = a.memory.defaultMemory;

      if (current.isEmpty) {
        return '记忆为空，无法编辑。请先使用 write_memory 写入内容。';
      }

      if (oldText.isEmpty) {
        return 'old_text 不能为空。';
      }

      final matches = oldText.allMatches(current).toList();
      if (matches.isEmpty) {
        return '未在记忆中找到 old_text 指定的内容。请确认原文是否正确。';
      }
      if (matches.length > 1) {
        return 'old_text 在记忆中匹配了 ${matches.length} 次，但必须唯一匹配。'
            '请提供更多上下文使 old_text 唯一。';
      }

      a.memory.defaultMemory =
          current.replaceFirst(oldText, newText);
      a.save();

      return '已编辑${_targetLabel(a)}"${a.targetName}"的记忆'
          '（替换 1 处，当前长度: ${a.memory.defaultMemory.length} 字符）。';
    },
  );
}