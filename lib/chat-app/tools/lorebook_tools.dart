import 'dart:convert';

import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/models/story_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/providers/story_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/tool_call_context.dart';
import 'package:flutter_example/chat-app/utils/tool_registry.dart';
import 'package:get/get.dart';

/// 注册所有 LoreBook 相关工具。
///
/// 在 [LoreBookController] 就绪后调用。所有 executor 闭包内通过
/// Get.find 延迟获取 controller，确保调用时 controller 已可用。
void registerLoreBookTools() {
  _registerListLorebooks();
  _registerCreateLorebook();
  _registerUpdateLorebook();
  _registerDeleteLorebook();
  _registerListLorebookItems();
  _registerSearchLorebookItems();
  _registerCreateLorebookItem();
  _registerUpdateLorebookItem();
  _registerDeleteLorebookItem();
  _registerListLorebooksInScope();
  _registerBindLorebook();
  _registerUnbindLorebook();
}

/// 注销所有 LoreBook 工具。
void unregisterLoreBookTools() {
  for (final name in _toolNames) {
    ToolRegistry.instance.unregister(name);
  }
}

const _toolNames = [
  'list_lorebooks',
  'create_lorebook',
  'update_lorebook',
  'delete_lorebook',
  'list_lorebook_items',
  'search_lorebook_items',
  'create_lorebook_item',
  'update_lorebook_item',
  'delete_lorebook_item',
  'list_lorebooks_in_scope',
  'bind_lorebook',
  'unbind_lorebook',
];

LoreBookController get _ctrl => Get.find<LoreBookController>();
CharacterController get _charCtrl => Get.find<CharacterController>();
StoryController get _storyCtrl => Get.find<StoryController>();

// ═══════════════════════════════════════════════════════════════════════════
// 世界书 (LoreBook) 级别工具
// ═══════════════════════════════════════════════════════════════════════════

void _registerListLorebooks() {
  ToolRegistry.instance.register(
    name: 'list_lorebooks',
    description: '列出所有世界书。可选按类型过滤（world / character）。',
    parameters: {
      'type': 'object',
      'properties': {
        'type': {
          'type': 'string',
          'description': '可选的世界书类型过滤：world、character。不传则返回全部。',
          'enum': ['world', 'character'],
        },
      },
    },
    executor: (ctx) async {
      var list = _ctrl.lorebooks.toList();
      final typeFilter = ctx['type'] as String?;
      if (typeFilter != null) {
        final t = LorebookType.values.firstWhere(
          (e) => e.name == typeFilter,
          orElse: () => LorebookType.world,
        );
        list = list.where((lb) => lb.type == t).toList();
      }

      if (list.isEmpty) {
        return typeFilter != null ? '没有类型为 "$typeFilter" 的世界书。' : '还没有任何世界书。';
      }

      final result = list
          .map((lb) => {
                'id': lb.id,
                'name': lb.name,
                'type': lb.type.name,
                'item_count': lb.items.length,
              })
          .toList();

      return jsonEncode(result);
    },
  );
}

void _registerCreateLorebook() {
  ToolRegistry.instance.register(
    name: 'create_lorebook',
    description: '创建一本新的世界书。',
    parameters: {
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string',
          'description': '世界书名称',
        },
        'type': {
          'type': 'string',
          'description': '世界书类型：world（全局）、character（角色）。默认 world。',
          'enum': ['world', 'character'],
        },
      },
      'required': ['name'],
    },
    executor: (ctx) async {
      final name = ctx['name'] as String;
      final typeStr = ctx['type'] as String? ?? 'world';
      final type = LorebookType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => LorebookType.world,
      );

      final lorebook = LorebookModel(
        id: DateTime.now().microsecondsSinceEpoch,
        name: name,
        items: [],
        scanDepth: 4,
        maxToken: 8000,
        type: type,
      );

      await _ctrl.addLorebook(lorebook);
      return '已创建世界书 "${name}"（id: ${lorebook.id}，类型: ${type.name}）。';
    },
  );
}

void _registerUpdateLorebook() {
  ToolRegistry.instance.register(
    name: 'update_lorebook',
    description: '修改指定世界书的名称、类型或全局激活状态。',
    parameters: {
      'type': 'object',
      'properties': {
        'id': {
          'type': 'integer',
          'description': '要修改的世界书 ID',
        },
        'name': {
          'type': 'string',
          'description': '新的名称（不传则保持不变）',
        },
        'type': {
          'type': 'string',
          'description': '新的类型：world、character（不传则保持不变）',
          'enum': ['world', 'character'],
        },
        'global_activated': {
          'type': 'boolean',
          'description': '是否全局激活。设为 true 则加入全局激活列表，设为 false 则从全局激活列表中移除。不传则保持不变。',
        },
      },
      'required': ['id'],
    },
    executor: (ctx) async {
      final id = ctx['id'] as int;
      final lorebook = _ctrl.getLorebookById(id);
      if (lorebook == null) {
        return '未找到 id 为 $id 的世界书。';
      }

      final newName = ctx['name'] as String?;
      final typeStr = ctx['type'] as String?;
      LorebookType? newType;
      if (typeStr != null) {
        newType = LorebookType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => LorebookType.world,
        );
      }

      final updated = lorebook.copyWith(
        name: newName,
        type: newType,
      );
      await _ctrl.updateLorebook(updated);

      final changes = <String>[];
      if (newName != null) changes.add('名称 → "$newName"');
      if (newType != null) changes.add('类型 → ${newType.name}');

      // 处理全局激活状态
      final globalActivated = ctx['global_activated'] as bool?;
      if (globalActivated != null) {
        if (globalActivated) {
          if (!_ctrl.globalActivitedLoreBookIds.contains(id)) {
            _ctrl.globalActivitedLoreBookIds.add(id);
            changes.add('已加入全局激活');
          } else {
            changes.add('已在全局激活列表中，无需操作');
          }
        } else {
          if (_ctrl.globalActivitedLoreBookIds.contains(id)) {
            _ctrl.globalActivitedLoreBookIds.remove(id);
            changes.add('已从全局激活中移除');
          } else {
            changes.add('本就不在全局激活列表中，无需操作');
          }
        }
        await _ctrl.saveActivationState();
      }

      return '已更新世界书 "${updated.name}"（${changes.join("，")}）。';
    },
  );
}

void _registerDeleteLorebook() {
  ToolRegistry.instance.register(
    name: 'delete_lorebook',
    description: '删除指定世界书。此操作不可撤销，会同时删除其下所有条目。',
    parameters: {
      'type': 'object',
      'properties': {
        'id': {
          'type': 'integer',
          'description': '要删除的世界书 ID',
        },
      },
      'required': ['id'],
    },
    executor: (ctx) async {
      final id = ctx['id'] as int;
      final lorebook = _ctrl.getLorebookById(id);
      if (lorebook == null) {
        return '未找到 id 为 $id 的世界书，无需删除。';
      }

      final name = lorebook.name;
      await _ctrl.deleteLorebook(id);
      return '已删除世界书 "$name"（id: $id），包含 ${lorebook.items.length} 个条目。';
    },
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 世界书条目 (LoreBook Item) 级别工具
// ═══════════════════════════════════════════════════════════════════════════

void _registerListLorebookItems() {
  ToolRegistry.instance.register(
    name: 'list_lorebook_items',
    description: '列出指定世界书下的所有条目。',
    parameters: {
      'type': 'object',
      'properties': {
        'lorebook_id': {
          'type': 'integer',
          'description': '世界书 ID',
        },
      },
      'required': ['lorebook_id'],
    },
    executor: (ctx) async {
      final lorebookId = ctx['lorebook_id'] as int;
      final lorebook = _ctrl.getLorebookById(lorebookId);
      if (lorebook == null) {
        return '未找到 id 为 $lorebookId 的世界书。';
      }

      if (lorebook.items.isEmpty) {
        return '世界书 "${lorebook.name}" 下还没有任何条目。';
      }

      final result = lorebook.items.map((item) => {
            'id': item.id,
            'name': item.name,
            'content': item.content,
            'is_active': item.isActive,
          }).toList();

      return jsonEncode({
        'lorebook_name': lorebook.name,
        'total': lorebook.items.length,
        'items': result,
      });
    },
  );
}

void _registerSearchLorebookItems() {
  ToolRegistry.instance.register(
    name: 'search_lorebook_items',
    description: '在指定世界书的条目中搜索。同时匹配条目的名称和正文内容。支持分页。',
    parameters: {
      'type': 'object',
      'properties': {
        'lorebook_id': {
          'type': 'integer',
          'description': '世界书 ID',
        },
        'keyword': {
          'type': 'string',
          'description': '搜索关键词，同时匹配条目名称和正文',
        },
        'page': {
          'type': 'integer',
          'description': '页码，从 1 开始。默认 1。',
        },
        'page_size': {
          'type': 'integer',
          'description': '每页条数。默认 10，最大 50。',
        },
      },
      'required': ['lorebook_id', 'keyword'],
    },
    executor: (ctx) async {
      final lorebookId = ctx['lorebook_id'] as int;
      final keyword = (ctx['keyword'] as String).toLowerCase();
      final page = (ctx['page'] as int?) ?? 1;
      final pageSize = ((ctx['page_size'] as int?) ?? 10).clamp(1, 50);

      final lorebook = _ctrl.getLorebookById(lorebookId);
      if (lorebook == null) {
        return '未找到 id 为 $lorebookId 的世界书。';
      }

      // 同时匹配名称和正文
      final matched = lorebook.items.where((item) {
        return item.name.toLowerCase().contains(keyword) ||
            item.content.toLowerCase().contains(keyword);
      }).toList();

      if (matched.isEmpty) {
        return '在世界书 "${lorebook.name}" 中未找到匹配 "$keyword" 的条目。';
      }

      final total = matched.length;
      final totalPages = (total / pageSize).ceil();
      final safePage = page.clamp(1, totalPages);
      final start = (safePage - 1) * pageSize;
      final end = (start + pageSize).clamp(0, total);
      final pageItems = matched.sublist(start, end);

      return jsonEncode({
        'lorebook_name': lorebook.name,
        'keyword': keyword,
        'total': total,
        'page': safePage,
        'page_size': pageSize,
        'total_pages': totalPages,
        'items': pageItems.map((item) => {
              'id': item.id,
              'name': item.name,
              'content': item.content,
              'is_active': item.isActive,
            }).toList(),
      });
    },
  );
}

void _registerCreateLorebookItem() { 
  ToolRegistry.instance.register(
    name: 'create_lorebook_item',
    description: '在指定世界书下创建一条新条目。其他未暴露字段使用默认值。',
    parameters: {
      'type': 'object',
      'properties': {
        'lorebook_id': {
          'type': 'integer',
          'description': '所属世界书 ID',
        },
        'name': {
          'type': 'string',
          'description': '条目名称',
        },
        'content': {
          'type': 'string',
          'description': '条目正文内容，即注入到 LLM 上下文中的文本',
        },
        'is_active': {
          'type': 'boolean',
          'description': '是否激活。默认 true。',
        },
      },
      'required': ['lorebook_id', 'name', 'content'],
    },
    executor: (ctx) async {
      final lorebookId = ctx['lorebook_id'] as int;
      final name = ctx['name'] as String;
      final content = ctx['content'] as String;
      final isActive = ctx['is_active'] as bool? ?? true;

      final lorebook = _ctrl.getLorebookById(lorebookId);
      if (lorebook == null) {
        return '未找到 id 为 $lorebookId 的世界书。';
      }

      final item = LorebookItemModel(
        id: DateTime.now().microsecondsSinceEpoch,
        name: name,
        content: content,
        isActive: isActive,
        // 以下字段使用默认值
        keywords: '',
        activationType: ActivationType.always,
        activationDepth: 0,
        priority: 0,
        logic: MatchingLogic.or,
        position: 'before_char',
        positionId: 0,
        isFavorite: false,
      );

      final updatedItems = [...lorebook.items, item];
      await _ctrl.updateLorebook(lorebook.copyWith(items: updatedItems));

      return '已在世界书 "${lorebook.name}" 中创建条目 "$name"（id: ${item.id}，激活: $isActive）。';
    },
  );
}

void _registerUpdateLorebookItem() {
  ToolRegistry.instance.register(
    name: 'update_lorebook_item',
    description: '修改指定世界书中的一条条目。只需传要修改的字段。',
    parameters: {
      'type': 'object',
      'properties': {
        'lorebook_id': {
          'type': 'integer',
          'description': '所属世界书 ID',
        },
        'item_id': {
          'type': 'integer',
          'description': '条目 ID',
        },
        'name': {
          'type': 'string',
          'description': '新的条目名称（不传则保持不变）',
        },
        'content': {
          'type': 'string',
          'description': '新的条目正文（不传则保持不变）',
        },
        'is_active': {
          'type': 'boolean',
          'description': '是否激活（不传则保持不变）',
        },
      },
      'required': ['lorebook_id', 'item_id'],
    },
    executor: (ctx) async {
      final lorebookId = ctx['lorebook_id'] as int;
      final itemId = ctx['item_id'] as int;

      final lorebook = _ctrl.getLorebookById(lorebookId);
      if (lorebook == null) {
        return '未找到 id 为 $lorebookId 的世界书。';
      }

      final index = lorebook.items.indexWhere((i) => i.id == itemId);
      if (index == -1) {
        return '未在世界书 "${lorebook.name}" 中找到 id 为 $itemId 的条目。';
      }

      final oldItem = lorebook.items[index];
      final newItem = oldItem.copyWith(
        name: ctx['name'] as String?,
        content: ctx['content'] as String?,
        isActive: ctx['is_active'] as bool?,
      );

      final updatedItems = lorebook.items.toList();
      updatedItems[index] = newItem;
      await _ctrl.updateLorebook(lorebook.copyWith(items: updatedItems));

      final changes = <String>[];
      if (ctx['name'] != null) changes.add('名称 → "${newItem.name}"');
      if (ctx['content'] != null) changes.add('正文已更新');
      if (ctx['is_active'] != null) {
        changes.add('激活状态 → ${newItem.isActive}');
      }
      return '已更新条目 "${newItem.name}"（${changes.join("，")}）。';
    },
  );
}

void _registerDeleteLorebookItem() {
  ToolRegistry.instance.register(
    name: 'delete_lorebook_item',
    description: '删除指定世界书中的一条条目。此操作不可撤销。',
    parameters: {
      'type': 'object',
      'properties': {
        'lorebook_id': {
          'type': 'integer',
          'description': '所属世界书 ID',
        },
        'item_id': {
          'type': 'integer',
          'description': '要删除的条目 ID',
        },
      },
      'required': ['lorebook_id', 'item_id'],
    },
    executor: (ctx) async {
      final lorebookId = ctx['lorebook_id'] as int;
      final itemId = ctx['item_id'] as int;

      final lorebook = _ctrl.getLorebookById(lorebookId);
      if (lorebook == null) {
        return '未找到 id 为 $lorebookId 的世界书。';
      }

      final item = lorebook.items.firstWhereOrNull((i) => i.id == itemId);
      if (item == null) {
        return '未在世界书 "${lorebook.name}" 中找到 id 为 $itemId 的条目，无需删除。';
      }

      final updatedItems =
          lorebook.items.where((i) => i.id != itemId).toList();
      await _ctrl.updateLorebook(lorebook.copyWith(items: updatedItems));

      return '已从世界书 "${lorebook.name}" 中删除条目 "${item.name}"（id: $itemId）。';
    },
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 作用域 & 绑定工具
// ═══════════════════════════════════════════════════════════════════════════

/// 从当前聊天上下文解析作用域信息。
///
/// 返回全局激活的 lorebook ID 列表、当前绑定的角色和故事。
({List<int> globalIds, CharacterModel? character, StoryModel? story})
    _resolveScope(ToolCallContext ctx) {
  final chat = ctx.chat;
  return (
    globalIds: _ctrl.globalActivitedLoreBookIds.toList(),
    character: chat.bindCharacter,
    story: chat.bindStory,
  );
}

/// 将 [LorebookModel] 转换为简短的 JSON map。
Map<String, dynamic> _lorebookSummary(LorebookModel lb, String source) {
  return {
    'id': lb.id,
    'name': lb.name,
    'type': lb.type.name,
    'source': source,
    'item_count': lb.items.length,
  };
}

void _registerListLorebooksInScope() {
  ToolRegistry.instance.register(
    name: 'list_lorebooks_in_scope',
    description: '列出当前作用域下的世界书。'
        '包含三类：全局激活的世界书、当前聊天绑定的角色关联的世界书、当前聊天绑定的故事关联的世界书。'
        '结果按来源分组返回，已自动去重。',
    parameters: {
      'type': 'object',
      'properties': {},
    },
    executor: (ctx) async {
      final (:globalIds, :character, :story) = _resolveScope(ctx);

      // 收集各来源的世界书，同时去重
      final seen = <int>{};
      final globalLorebooks = <Map<String, dynamic>>[];
      final characterLorebooks = <Map<String, dynamic>>[];
      final storyLorebooks = <Map<String, dynamic>>[];

      // 1) 全局激活的世界书
      for (final id in globalIds) {
        final lb = _ctrl.getLorebookById(id);
        if (lb != null && seen.add(lb.id)) {
          globalLorebooks.add(_lorebookSummary(lb, 'global'));
        }
      }

      // 2) 角色绑定的世界书
      if (character != null) {
        for (final lb in character.loreBooks) {
          if (seen.add(lb.id)) {
            characterLorebooks.add(_lorebookSummary(lb, 'character'));
          }
        }
      }

      // 3) 故事绑定的世界书
      if (story != null) {
        for (final lb in story.loreBooks) {
          if (seen.add(lb.id)) {
            storyLorebooks.add(_lorebookSummary(lb, 'story'));
          }
        }
      }

      final total =
          globalLorebooks.length + characterLorebooks.length + storyLorebooks.length;

      if (total == 0) {
        final parts = <String>[];
        parts.add('全局激活的世界书：无');
        if (character != null) {
          parts.add('角色"${character.roleName}"绑定的世界书：无');
        } else {
          parts.add('当前聊天未绑定角色');
        }
        if (story != null) {
          parts.add('故事"${story.name}"绑定的世界书：无');
        } else {
          parts.add('当前聊天未绑定故事');
        }
        return parts.join('；') + '。';
      }

      return jsonEncode({
        'total': total,
        'global_activated': {
          'count': globalLorebooks.length,
          'lorebooks': globalLorebooks,
        },
        if (character != null)
          'character_bound': {
            'character_id': character.id,
            'character_name': character.roleName,
            'count': characterLorebooks.length,
            'lorebooks': characterLorebooks,
          },
        if (story != null)
          'story_bound': {
            'story_id': story.id,
            'story_name': story.name,
            'count': storyLorebooks.length,
            'lorebooks': storyLorebooks,
          },
      });
    },
  );
}

void _registerBindLorebook() {
  ToolRegistry.instance.register(
    name: 'bind_lorebook',
    description: '将指定世界书绑定到角色或故事。绑定后该世界书将在对应角色/故事的聊天中生效。',
    parameters: {
      'type': 'object',
      'properties': {
        'lorebook_id': {
          'type': 'integer',
          'description': '要绑定的世界书 ID',
        },
        'target_type': {
          'type': 'string',
          'enum': ['character', 'story'],
          'description': '绑定目标类型：character（角色）或 story（故事）',
        },
        'target_id': {
          'description': '目标 ID。角色 ID 为整数，故事 ID 为字符串。',
        },
      },
      'required': ['lorebook_id', 'target_type', 'target_id'],
    },
    executor: (ctx) async {
      final lorebookId = ctx['lorebook_id'] as int;
      final targetType = ctx['target_type'] as String;
      final rawTargetId = ctx['target_id'];

      // 验证世界书存在
      final lorebook = _ctrl.getLorebookById(lorebookId);
      if (lorebook == null) {
        return '未找到 id 为 $lorebookId 的世界书。';
      }

      switch (targetType) {
        case 'character':
          final charId = rawTargetId is int ? rawTargetId : int.tryParse(rawTargetId.toString());
          if (charId == null) {
            return '角色 ID 必须为整数，收到: $rawTargetId。';
          }
          final character = _charCtrl.getCharacterById(charId);
          if (character.id != charId) {
            return '未找到 id 为 $charId 的角色。';
          }

          if (character.lorebookIds.contains(lorebookId)) {
            return '角色"${character.roleName}"已经绑定了世界书"${lorebook.name}"（id: $lorebookId），无需重复绑定。';
          }

          final updated = character.copyWith(
            id: character.id,
            lorebookIds: [...character.lorebookIds, lorebookId],
          );
          await _charCtrl.updateCharacter(updated);
          return '已将世界书"${lorebook.name}"（id: $lorebookId）绑定到角色"${character.roleName}"（id: $charId）。';

        case 'story':
          final storyId = rawTargetId.toString();
          final story = _storyCtrl.getStoryById(storyId);
          if (story == null) {
            return '未找到 id 为 "$storyId" 的故事。';
          }

          if (story.lorebookIds.contains(lorebookId)) {
            return '故事"${story.name}"已经绑定了世界书"${lorebook.name}"（id: $lorebookId），无需重复绑定。';
          }

          final updated = story.copyWith(
            lorebookIds: [...story.lorebookIds, lorebookId],
          );
          await _storyCtrl.updateStory(updated);
          return '已将世界书"${lorebook.name}"（id: $lorebookId）绑定到故事"${story.name}"（id: $storyId）。';

        default:
          return '未知的 target_type: "$targetType"，仅支持 character 和 story。';
      }
    },
  );
}

void _registerUnbindLorebook() {
  ToolRegistry.instance.register(
    name: 'unbind_lorebook',
    description: '将指定世界书从角色或故事解除绑定。解除绑定后该世界书将不再在该角色/故事的聊天中生效。',
    parameters: {
      'type': 'object',
      'properties': {
        'lorebook_id': {
          'type': 'integer',
          'description': '要解除绑定的世界书 ID',
        },
        'target_type': {
          'type': 'string',
          'enum': ['character', 'story'],
          'description': '解除绑定目标类型：character（角色）或 story（故事）',
        },
        'target_id': {
          'description': '目标 ID。角色 ID 为整数，故事 ID 为字符串。',
        },
      },
      'required': ['lorebook_id', 'target_type', 'target_id'],
    },
    executor: (ctx) async {
      final lorebookId = ctx['lorebook_id'] as int;
      final targetType = ctx['target_type'] as String;
      final rawTargetId = ctx['target_id'];

      // 验证世界书存在
      final lorebook = _ctrl.getLorebookById(lorebookId);
      if (lorebook == null) {
        return '未找到 id 为 $lorebookId 的世界书。';
      }

      switch (targetType) {
        case 'character':
          final charId = rawTargetId is int ? rawTargetId : int.tryParse(rawTargetId.toString());
          if (charId == null) {
            return '角色 ID 必须为整数，收到: $rawTargetId。';
          }
          final character = _charCtrl.getCharacterById(charId);
          if (character.id != charId) {
            return '未找到 id 为 $charId 的角色。';
          }

          if (!character.lorebookIds.contains(lorebookId)) {
            return '角色"${character.roleName}"未绑定世界书"${lorebook.name}"（id: $lorebookId），无需解绑。';
          }

          final updated = character.copyWith(
            lorebookIds: character.lorebookIds.where((id) => id != lorebookId).toList(),
          );
          await _charCtrl.updateCharacter(updated);
          return '已将世界书"${lorebook.name}"（id: $lorebookId）从角色"${character.roleName}"（id: $charId）解除绑定。';

        case 'story':
          final storyId = rawTargetId.toString();
          final story = _storyCtrl.getStoryById(storyId);
          if (story == null) {
            return '未找到 id 为 "$storyId" 的故事。';
          }

          if (!story.lorebookIds.contains(lorebookId)) {
            return '故事"${story.name}"未绑定世界书"${lorebook.name}"（id: $lorebookId），无需解绑。';
          }

          final updated = story.copyWith(
            lorebookIds: story.lorebookIds.where((id) => id != lorebookId).toList(),
          );
          await _storyCtrl.updateStory(updated);
          return '已将世界书"${lorebook.name}"（id: $lorebookId）从故事"${story.name}"（id: $storyId）解除绑定。';

        default:
          return '未知的 target_type: "$targetType"，仅支持 character 和 story。';
      }
    },
  );
}
