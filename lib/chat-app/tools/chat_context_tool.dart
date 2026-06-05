import 'dart:convert';

import 'package:flutter_example/chat-app/utils/entitys/tool_call_context.dart';
import 'package:flutter_example/chat-app/utils/tool_registry.dart';
import 'package:path/path.dart' as p;

/// 注册聊天上下文工具。
void registerChatContextTool() {
  _registerGetChatContext();
}

/// 注销聊天上下文工具。
void unregisterChatContextTool() {
  for (final name in _toolNames) {
    ToolRegistry.instance.unregister(name);
  }
}

const _toolNames = ['get_chat_context'];

void _registerGetChatContext() {
  ToolRegistry.instance.register(
    name: 'get_chat_context',
    description: '获取当前聊天的上下文信息，包括：聊天文件路径和文件名、消息条数、'
        '绑定的故事 ID、绑定的角色 ID、涉及的所有角色列表等。'
        '无需参数，直接返回当前对话的完整上下文概览。',
    parameters: {
      'type': 'object',
      'properties': {},
    },
    executor: (ctx) async {
      final chat = ctx.chat;
      final fileName = p.basename(chat.filePath);

      final result = <String, dynamic>{
        'filename': fileName,
        'file_path': chat.filePath,
        'chat_title': chat.name,
        'message_count': chat.messages.length,
        'last_message_time': chat.time,
      };

      // 绑定的故事
      final story = chat.bindStory;
      if (story != null) {
        result['bind_story'] = {
          'id': story.id,
          'name': story.name,
        };
      } else {
        result['bind_story'] = null;
      }

      // 绑定的角色（作为 AI 助手）
      final assistant = chat.bindCharacter;
      if (assistant != null) {
        result['bind_character'] = {
          'id': assistant.id,
          'name': assistant.roleName,
        };
      } else {
        result['bind_character'] = null;
      }

      // 涉及的角色（含用户人设）
      result['characters'] = chat.characters
          .map((c) => {
                'id': c.id,
                'name': c.roleName,
                'is_user': c.id == chat.user.id,
              })
          .toList();

      return jsonEncode(result);
    },
  );
}
