/// ToolCallResult 标签的序列化、反序列化和展开工具类。
///
/// 标签格式：
/// ```xml
/// <ToolCallResult id="call_123" name="get_weather" args='{"city":"NY"}'>结果</ToolCallResult>
/// ```
///
/// - `args` 使用单引号包裹以避免与 JSON 双引号冲突
/// - 标签 body 做 XML 转义（& < >）
///
/// 使用方式：
/// ```dart
/// // 持久化
/// final tag = ToolCallTag.buildTag(toolCall, result);
/// fullResponse.write(tag);
///
/// // 重建 LLM 消息
/// final expanded = ToolCallTag.expandToolCallResults(assistantMessage);
///
/// // UI 剥离
/// final clean = ToolCallTag.stripTags(message.content);
/// ```

import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/entitys/tool_call.dart';
class ToolCallTag {
  ToolCallTag._();

  // ---- 编码 ----

  /// 对 args JSON 字符串编码，使其安全放入单引号属性值
  static String _encodeArgsAttr(String args) {
    return args.replaceAll("'", "&apos;");
  }

  /// 对标签 body 文本做 XML 转义
  static String _encodeXmlContent(String text) {
    return text
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;");
  }

  /// 将一次工具调用和结果序列化为标签字符串
  static String buildTag(ToolCall tc, String result) {
    final safeArgs = _encodeArgsAttr(tc.arguments);
    final safeResult = _encodeXmlContent(result);
    return '<ToolCallResult id="${tc.id}" name="${tc.functionName}"'
        " args='$safeArgs'>$safeResult</ToolCallResult>";
  }

  // ---- 解码 ----

  static String _decodeArgsAttr(String encoded) {
    return encoded.replaceAll("&apos;", "'");
  }

  static String _decodeXmlContent(String encoded) {
    return encoded
        .replaceAll("&gt;", ">")
        .replaceAll("&lt;", "<")
        .replaceAll("&amp;", "&");
  }

  /// 匹配单个完整的 ToolCallResult 标签
  /// Group 1: id, Group 2: name, Group 3: args, Group 4: result content
  static final RegExp _tagRegex = RegExp(
    r'''<ToolCallResult\s+id="([^"]*)"\s+name="([^"]*)"\s+args='([^']*)'>(.*?)</ToolCallResult>''',
    dotAll: true,
  );

  // ---- 公共方法 ----

  /// 从文本中移除所有 ToolCallResult 标签（用于 UI 显示）
  static String stripTags(String text) {
    return text.replaceAll(_tagRegex, '');
  }

  /// 解析 assistant 消息中的 ToolCallResult 标签，展开为标准 LLM 消息序列。
  ///
  /// 输入的 message 应为 `role: "assistant"` 的消息。
  /// 返回展开后的 [LLMMessage] 列表：
  /// ```text
  /// [assistant(textBeforeTC1, toolCalls: [tc1, tc2]),
  ///  tool(result1, toolCallId: tc1.id),
  ///  tool(result2, toolCallId: tc2.id),
  ///  assistant(textAfterLastTC),
  ///  ...]
  /// ```
  ///
  /// 如果消息不含 ToolCallResult 标签，返回 `[message]` 原样。
  static List<LLMMessage> expandToolCallResults(LLMMessage message) {
    if (message.role != 'assistant' ||
        !message.content.contains('<ToolCallResult')) {
      return [message];
    }

    final matches = _tagRegex.allMatches(message.content).toList(); 
    if (matches.isEmpty) return [message];

    final result = <LLMMessage>[];
    int lastEnd = 0;

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];

      // 该 tag 之前的文本
      final textBefore = message.content.substring(lastEnd, match.start);

      // 收集连续的 ToolCallResult 标签（同一轮可能多次工具调用）
      final toolCalls = <ToolCall>[];
      final toolResults = <String>[];

      int currentEnd = match.start;
      for (int j = i; j < matches.length; j++) { 
        final m = matches[j];
        if (m.start == currentEnd) {
          final tcId = m.group(1)!;
          final tcName = m.group(2)!; 
          final tcArgs = _decodeArgsAttr(m.group(3)!);
          toolCalls.add(ToolCall(
            id: tcId,
            functionName: tcName,
            arguments: tcArgs,
          ));
          toolResults.add(_decodeXmlContent(m.group(4)!));
          currentEnd = m.end;
          i = j; // 推进外层循环
        } else {
          break;
        }
      }
      lastEnd = currentEnd;

      // 含有 tool_calls 的 assistant 消息
      result.add(LLMMessage(
        content: textBefore,
        role: 'assistant',
        toolCalls: toolCalls,
      ));

      // 逐个 tool 结果消息
      for (int k = 0; k < toolResults.length; k++) {
        result.add(LLMMessage(
          content: toolResults[k],
          role: 'tool',
          toolCallId: toolCalls[k].id,
        ));
      }
    }

    // 最后一个标签之后的剩余文本 → 最终 assistant 消息
    if (lastEnd < message.content.length) {
      final textAfter = message.content.substring(lastEnd);
      if (textAfter.isNotEmpty) {
        result.add(LLMMessage(
          content: textAfter,
          role: 'assistant',
        ));
      }
    }

    return result.isEmpty ? [message] : result;
  }
}
