import 'dart:convert';
import 'dart:math';

import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/tool_call_context.dart';
import 'package:flutter_example/chat-app/utils/tool_registry.dart';
import 'package:get/get.dart';

/// 注册所有聊天变量 (chatVars) 相关工具。
void registerChatVarsTools() {
  _registerGetAllChatVars();
  _registerGetChatVar();
  _registerSetChatVar();
  _registerSetChatVarRandom();
}

/// 注销所有聊天变量工具。
void unregisterChatVarsTools() {
  for (final name in _toolNames) {
    ToolRegistry.instance.unregister(name);
  }
}

const _toolNames = [
  'get_all_chat_vars',
  'get_chat_var',
  'set_chat_var',
  'set_chat_var_random',
];

Future<void> _saveChat(ToolCallContext ctx) async {
  final session = Get.find<ChatController>().currentChat.value;
  if (session != null) {
    await session.saveChat();
  } else if (ctx.chat.file != null) {
    await ctx.chat.file!.writeAsString(json.encode(ctx.chat.toJson()));
  }
}

void _registerGetAllChatVars() {
  ToolRegistry.instance.register(
    name: 'get_all_chat_vars',
    description: '读取当前聊天的所有变量（chatVars）。返回一个键值对映射。'
        '聊天变量是当前对话的持久化键值数据，可用于存储对话中的状态、计数、偏好等信息。',
    parameters: {
      'type': 'object',
      'properties': {},
    },
    executor: (ctx) async {
      final vars = ctx.chat.chatVars;
      if (vars.isEmpty) {
        return '当前聊天还没有任何变量。';
      }

      return jsonEncode({
        'count': vars.length,
        'variables': vars,
      });
    },
  );
}

void _registerGetChatVar() {
  ToolRegistry.instance.register(
    name: 'get_chat_var',
    description: '读取当前聊天中指定名称的变量值。如果变量不存在则返回提示。',
    parameters: {
      'type': 'object',
      'properties': {
        'key': {
          'type': 'string',
          'description': '变量名',
        },
      },
      'required': ['key'],
    },
    executor: (ctx) async {
      final key = ctx['key'] as String;
      final vars = ctx.chat.chatVars;

      if (!vars.containsKey(key)) {
        return '变量 "$key" 不存在。';
      }

      return jsonEncode({
        'key': key,
        'value': vars[key],
      });
    },
  );
}

void _registerSetChatVar() {
  ToolRegistry.instance.register(
    name: 'set_chat_var',
    description: '设置当前聊天中的一个变量。如果变量已存在则更新，否则添加新变量。'
        '变量值统一存储为字符串。',
    parameters: {
      'type': 'object',
      'properties': {
        'key': {
          'type': 'string',
          'description': '变量名',
        },
        'value': {
          'type': 'string',
          'description': '变量值（统一为字符串）',
        },
      },
      'required': ['key', 'value'],
    },
    executor: (ctx) async {
      final key = ctx['key'] as String;
      final value = ctx['value'] as String;
      final vars = ctx.chat.chatVars;

      final existed = vars.containsKey(key);
      vars[key] = value;
      await _saveChat(ctx);

      return existed
          ? '已更新变量 "$key" = "$value"。'
          : '已添加变量 "$key" = "$value"。';
    },
  );
}

void _registerSetChatVarRandom() {
  ToolRegistry.instance.register(
    name: 'set_chat_var_random',
    description: '将当前聊天中的某个变量设置为一个随机整数。'
        '可指定最小值（min，默认 1）和最大值（max，默认 100），闭区间。'
        '如果变量不存在则添加。',
    parameters: {
      'type': 'object',
      'properties': {
        'key': {
          'type': 'string',
          'description': '变量名',
        },
        'min': {
          'type': 'integer',
          'description': '随机数最小值（闭区间），默认 1',
        },
        'max': {
          'type': 'integer',
          'description': '随机数最大值（闭区间），默认 100',
        },
      },
      'required': ['key'],
    },
    executor: (ctx) async {
      final key = ctx['key'] as String;
      final min = (ctx['min'] as int?) ?? 1;
      final max = (ctx['max'] as int?) ?? 100;

      if (min > max) {
        return '最小值 ($min) 不能大于最大值 ($max)。';
      }

      final random = Random();
      final value = min + random.nextInt(max - min + 1);
      final strValue = value.toString();

      final vars = ctx.chat.chatVars;
      final existed = vars.containsKey(key);
      vars[key] = strValue;
      await _saveChat(ctx);

      return existed
          ? '已将变量 "$key" 随机设置为 $strValue（范围：$min ~ $max）。'
          : '已添加变量 "$key"，随机值：$strValue（范围：$min ~ $max）。';
    },
  );
}
