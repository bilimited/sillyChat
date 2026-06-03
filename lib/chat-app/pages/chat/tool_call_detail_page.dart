import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/utils/entitys/tool_call.dart';

/// 工具调用详情页
///
/// 可显示两类内容：
/// - 传入 [toolCalls]：展示 assistant 消息中的工具调用列表
/// - 传入 [toolResult]：展示 tool 角色的消息结果
class ToolCallDetailPage extends StatelessWidget {
  final List<ToolCall>? toolCalls;
  final MessageModel? toolResult;

  const ToolCallDetailPage({
    super.key,
    this.toolCalls,
    this.toolResult,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(toolCalls != null ? '工具调用' : '工具结果'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: toolCalls != null
            ? _buildToolCallsView(colors)
            : _buildToolResultView(colors),
      ),
    );
  }

  Widget _buildToolCallsView(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.build, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              '${toolCalls!.length} 个工具调用',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...toolCalls!.map((tc) => _buildToolCallItem(colors, tc)),
      ],
    );
  }

  Widget _buildToolCallItem(ColorScheme colors, ToolCall tc) {
    final parsedArgs = tc.parsedArguments;
    final prettyArgs = const JsonEncoder.withIndent('  ').convert(parsedArgs);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 函数名
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tc.functionName,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ID
          _buildFieldRow(colors, 'ID', tc.id),

          const SizedBox(height: 12),

          // 参数标题
          Text(
            'Arguments',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.outline,
            ),
          ),
          const SizedBox(height: 6),

          // 参数内容（格式化 JSON）
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectionArea(
              child: Text(
                prettyArgs,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolResultView(ColorScheme colors) {
    final result = toolResult!;
    final toolCallId = result.toolCallId;

    // 尝试格式化 JSON 内容
    String displayContent;
    bool isJson = false;
    try {
      final parsed = jsonDecode(result.content);
      displayContent = const JsonEncoder.withIndent('  ').convert(parsed);
      isJson = true;
    } catch (_) {
      displayContent = result.content;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.handyman_outlined, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              '工具结果',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tool Call ID
        if (toolCallId != null) ...[
          _buildFieldRow(colors, 'Tool Call ID', toolCallId),
          const SizedBox(height: 16),
        ],

        // 内容类型
        Row(
          children: [
            Text(
              'Content',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.outline,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isJson
                    ? colors.tertiaryContainer
                    : colors.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isJson ? 'JSON' : 'TEXT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color:
                      isJson ? colors.onTertiaryContainer : colors.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${result.content.length} 字符',
              style: TextStyle(
                fontSize: 11,
                color: colors.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 内容
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant.withOpacity(0.2)),
          ),
          child: SelectionArea(
            child: Text(
              displayContent,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldRow(ColorScheme colors, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.outline,
            ),
          ),
        ),
        Expanded(
          child: SelectionArea(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
