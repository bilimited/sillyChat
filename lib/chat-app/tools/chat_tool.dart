import 'dart:convert';
import 'dart:io';

import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/tool_call_context.dart';
import 'package:flutter_example/chat-app/utils/tool_registry.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

/// 注册所有聊天 (Chat) 相关工具。
///
/// 在 [ChatController] 就绪后调用。
void registerChatTools() {
  _registerListChats();
  _registerSearchMessages();
  _registerReadChatMessages();
}

/// 注销所有聊天工具。
void unregisterChatTools() {
  for (final name in _toolNames) {
    ToolRegistry.instance.unregister(name);
  }
}

const _toolNames = [
  'list_chats',
  'search_messages',
  'read_chat_messages',
];

SettingController get _settingCtrl => Get.find<SettingController>();
ChatController get _chatCtrl => Get.find<ChatController>();

/// 从当前聊天上下文解析目标目录。
///
/// 优先故事（ctx.chat.bindStory），其次角色（ctx.chat.bindCharacter）。
/// 返回 (directoryPath, targetType, targetName)，null 表示未绑定。
(String, String, String)? _resolveChatDir(ToolCallContext ctx) {
  final chat = ctx.chat;
  final basePath = _settingCtrl.getChatPathSync();

  // 1) 故事聊天
  final story = chat.bindStory;
  if (story != null) {
    final dir = p.join(basePath, 'stories', story.id.toString());
    return (dir, 'story', story.name);
  }

  // 2) 角色聊天
  final char = chat.bindCharacter;
  if (char != null) {
    final dir = p.join(basePath, 'roles', char.id.toString());
    return (dir, 'character', char.roleName);
  }

  return null;
}

/// 读取一个聊天文件的 [ChatModel]，失败返回 null。 
Future<ChatModel?> _readChatFile(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return ChatModel.fromJson(json.decode(content));
  } catch (e) {
    return null;
  }
}

String _targetLabel(String type) =>
    type == 'story' ? '故事' : '角色';

// ═══════════════════════════════════════════════════════════════════════════
// 工具实现
// ═══════════════════════════════════════════════════════════════════════════

void _registerListChats() {
  ToolRegistry.instance.register(
    name: 'list_chats',
    description: '列出当前角色或故事的所有聊天文件。'
        '返回聊天标题、文件名、消息数量和最后消息时间。最多返回 100 条，按修改时间倒序排列。',
    parameters: {
      'type': 'object',
      'properties': {},
    },
    executor: (ctx) async {
      final resolved = _resolveChatDir(ctx);
      if (resolved == null) {
        return '当前聊天未绑定角色或故事，无法列出聊天。';
      }

      final (dir, targetType, targetName) = resolved;
      final directory = Directory(dir);
      if (!await directory.exists()) {
        return '${_targetLabel(targetType)}"$targetName"还没有任何聊天记录。';
      }

      final files = directory
          .listSync()
          .whereType<File>()
          .where((f) => p.extension(f.path) == '.chat')
          .toList();

      if (files.isEmpty) {
        return '${_targetLabel(targetType)}"$targetName"还没有任何聊天记录。';
      }

      // 按修改时间倒序
      files.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      final results = <Map<String, dynamic>>[];
      for (final file in files.take(100)) {
        final canonicalPath = p.canonicalize(file.path);

        // 优先从聊天索引获取元数据
        final indexMeta = _chatCtrl.getIndex(canonicalPath);
        if (indexMeta != null) {
          results.add({
            'filename': p.basename(canonicalPath),
            'title': indexMeta.name,
            'message_count': indexMeta.messageCount,
            //'last_message': indexMeta.lastMessage,
            'time': indexMeta.time,
          });
        } else {
          // 回退：直接读取文件获取基本信息
          final chat = await _readChatFile(canonicalPath);
          if (chat != null) {
            results.add({
              'filename': p.basename(canonicalPath),
              'title': chat.name,
              'message_count': chat.messages.length,
              //'last_message': chat.lastMessage,
              'time': chat.time,
            });
          }
        }
      }

      return jsonEncode({
        'target_type': targetType,
        'target_name': targetName,
        'total': results.length,
        'chats': results,
      });
    },
  );
}

void _registerSearchMessages() {
  ToolRegistry.instance.register(
    name: 'search_messages',
    description: '在当前角色或故事的所有聊天记录中搜索匹配的消息正文。'
        '支持正则表达式模式匹配。最多返回 10 条匹配结果，优先搜索最近的聊天。',
    parameters: {
      'type': 'object',
      'properties': {
        'pattern': {
          'type': 'string',
          'description': '用于匹配消息正文的正则表达式模式（不区分大小写）',
        },
      },
      'required': ['pattern'],
    },
    executor: (ctx) async {
      final resolved = _resolveChatDir(ctx);
      if (resolved == null) {
        return '当前聊天未绑定角色或故事，无法搜索聊天记录。';
      }

      final (dir, targetType, targetName) = resolved;
      final directory = Directory(dir);
      if (!await directory.exists()) {
        return '${_targetLabel(targetType)}"$targetName"还没有任何聊天记录。';
      }

      final patternStr = ctx['pattern'] as String;
      final regex = RegExp(patternStr, caseSensitive: false);

      final files = directory
          .listSync()
          .whereType<File>()
          .where((f) => p.extension(f.path) == '.chat')
          .toList();

      // 按修改时间倒序，优先搜索最近的聊天
      files.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      final matches = <Map<String, dynamic>>[];
      for (final file in files) {
        if (matches.length >= 10) break;

        final chat = await _readChatFile(file.path);
        if (chat == null) continue;

        for (final msg in chat.messages) {
          if (matches.length >= 10) break;
          if (regex.hasMatch(msg.content)) {
            // 截断过长的消息内容
            final displayContent = msg.content.length > 500
                ? '${msg.content.substring(0, 500)}...'
                : msg.content;
            matches.add({
              'chat_title': chat.name,
              'chat_filename': p.basename(file.path),
              'message_id': msg.id,
              'role': msg.role.toString().split('.').last,
              'content': displayContent,
              'time': msg.time.toIso8601String(),
            });
          }
        }
      }

      if (matches.isEmpty) {
        return '在${_targetLabel(targetType)}"$targetName"的聊天记录中'
            '未找到匹配 "$patternStr" 的消息。';
      }

      return jsonEncode({
        'target_type': targetType,
        'target_name': targetName,
        'pattern': patternStr,
        'total_matches': matches.length,
        'matches': matches,
      });
    },
  );
}

void _registerReadChatMessages() {
  ToolRegistry.instance.register(
    name: 'read_chat_messages',
    description: '读取指定聊天文件的消息记录。'
        '可通过 limit 参数获取最新 N 条消息，也可通过 pattern 参数进行正则匹配过滤。'
        '两者同时提供时，在最新 N 条消息中进行模式匹配。',
    parameters: {
      'type': 'object',
      'properties': {
        'chat_filename': {
          'type': 'string',
          'description': '聊天文件名（如 "新对话-123456.chat"），来自 list_chats 的返回结果',
        },
        'limit': {
          'type': 'integer',
          'description': '返回最新 N 条消息。默认 20，最大 200。',
        },
        'pattern': {
          'type': 'string',
          'description': '正则表达式模式，用于过滤消息正文（不区分大小写）。不传则返回全部（受 limit 限制）。',
        },
      },
      'required': ['chat_filename'],
    },
    executor: (ctx) async {
      final resolved = _resolveChatDir(ctx);
      if (resolved == null) {
        return '当前聊天未绑定角色或故事，无法读取聊天记录。';
      }

      final (dir, targetType, targetName) = resolved;
      final chatFilename = ctx['chat_filename'] as String;
      final limit = ctx['limit'] as int? ?? 20;
      final patternStr = ctx['pattern'] as String?;

      if (limit < 1 || limit > 200) {
        return 'limit 参数必须在 1 到 200 之间。';
      }

      // 解析文件路径：支持绝对路径或相对于上下文目录的文件名
      final filePath = p.isAbsolute(chatFilename)
          ? chatFilename
          : p.join(dir, chatFilename);

      final chat = await _readChatFile(filePath);
      if (chat == null) {
        return '未找到聊天文件 "$chatFilename"。'
            '请使用 list_chats 查看可用的聊天文件列表。';
      }

      final totalCount = chat.messages.length;

      // 取最新的 limit 条消息
      var messages = totalCount > limit
          ? chat.messages.sublist(totalCount - limit)
          : chat.messages.toList();

      // 如果指定了 pattern，进行正则过滤
      if (patternStr != null && patternStr.isNotEmpty) {
        final regex = RegExp(patternStr, caseSensitive: false);
        messages = messages.where((m) => regex.hasMatch(m.content)).toList();
      }

      if (messages.isEmpty) {
        final patternInfo =
            patternStr != null && patternStr.isNotEmpty ? '匹配 "$patternStr" 的' : '';
        return '在聊天"${chat.name}"中未找到${patternInfo}消息'
            '（共 $totalCount 条消息，搜索范围: 最新 $limit 条）。';
      }

      final result = messages.map((m) => {
            'id': m.id,
            'role': m.role.toString().split('.').last,
            'content': m.content,
            'time': m.time.toIso8601String(),
            'sender_id': m.senderId,
          }).toList();

      return jsonEncode({
        'chat_title': chat.name,
        'chat_filename': p.basename(filePath),
        'target_type': targetType,
        'target_name': targetName,
        'total_messages': totalCount,
        'returned': result.length,
        'limit': limit,
        'pattern': patternStr,
        'messages': result,
      });
    },
  );
}
