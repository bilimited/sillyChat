/// 内置工具注册中心
///
/// 在应用启动时调用 [BuiltInTools.registerAll] 注册所有默认工具。
/// 需要确保 [ToolRegistry] 已初始化。
///
/// 使用方式：
/// ```dart
/// BuiltInTools.registerAll();
/// ```

import 'package:flutter_example/chat-app/tools/character_tools.dart';
import 'package:flutter_example/chat-app/tools/chat_context_tool.dart';
import 'package:flutter_example/chat-app/tools/chat_tool.dart';
import 'package:flutter_example/chat-app/tools/chat_vars_tools.dart';
import 'package:flutter_example/chat-app/tools/lorebook_tools.dart';
import 'package:flutter_example/chat-app/tools/memory_tools.dart';
import 'package:flutter_example/chat-app/tools/regex_tools.dart';
import 'package:flutter_example/chat-app/utils/tool_registry.dart';

class BuiltInTools {
  static bool _registered = false;

  /// 注册所有内置工具。
  /// 多次调用安全——仅在首次调用时实际注册。
  static void registerAll() {
    if (_registered) return;
    _registered = true;

    _registerTestTool();
    registerLoreBookTools();
    registerCharacterTools();
    registerMemoryTools();
    registerChatContextTool();
    registerChatTools();
    registerRegexTools();
    registerChatVarsTools();
  }

  /// 测试工具：模型每次调用后返回调用次数，用于验证 Tool Call 端到端流程。
  static void _registerTestTool() {
    int callCount = 0;

    ToolRegistry.instance.register(
      name: 'test_tool',
      description: '一个测试工具。调用后将返回调用次数。可以用于验证工具调用功能是否正常。',
      parameters: {
        'type': 'object',
        'properties': {
          'message': {
            'type': 'string',
            'description': '任意消息内容',
          },
        },
      }, 
      executor: (ctx) async {
        callCount++;
        final msg = ctx['message'] as String?;
        final extra = msg != null && msg.isNotEmpty ? '，收到的消息: "$msg"' : '';
        return '你成功调用工具$callCount次$extra';
      },
    );
  }

  /// 注销所有内置工具。
  /// 在仓库切换或应用重置时调用。
  static void unregisterAll() {
    if (!_registered) return;
    _registered = false;
    unregisterCharacterTools();
    unregisterLoreBookTools();
    unregisterMemoryTools();
    unregisterChatContextTool();
    unregisterChatTools();
    unregisterRegexTools();
    unregisterChatVarsTools();
    ToolRegistry.instance.unregister('test_tool');
  }
}
