import 'dart:convert';

import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
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
];

LoreBookController get _ctrl => Get.find<LoreBookController>();

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
    description: '修改指定世界书的名称或类型。',
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
