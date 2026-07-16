import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/models/settings/chat_displaysetting_model.dart';
import 'package:flutter_example/chat-app/widgets/chat/message_bubble.dart';

class SummaryMessageBubble extends StatefulWidget {
  const SummaryMessageBubble({
    super.key,
    required this.context,
    required this.isLoading,
    required this.message,
    required this.displaySetting,
    required this.widget,
  });

  final BuildContext context;
  final bool isLoading;
  final MessageModel message;
  final ChatDisplaySettingModel displaySetting;
  final MessageBubble widget;

  @override
  State<SummaryMessageBubble> createState() => _SummaryMessageBubbleState();
}

class _SummaryMessageBubbleState extends State<SummaryMessageBubble> {
  /// 从消息内容中提取纯文本 — 跳过 <think> 和 <ToolCallResult> 块
  String _extractPlainText(String content) {
    final tagRegex = RegExp(
      r'<think>(.*?)</think>|'
      r'''<ToolCallResult\s+id="([^"]*)"\s+name="([^"]*)"\s+args='([^']*)'>(.*?)</ToolCallResult>''',
      dotAll: true,
    );

    final buffer = StringBuffer();
    int lastEnd = 0;
    for (final match in tagRegex.allMatches(content)) {
      if (match.start > lastEnd) {
        buffer.write(content.substring(lastEnd, match.start));
      }
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      final remaining = content.substring(lastEnd);
      // 去掉未闭合的 <think> 标签
      final cleaned =
          remaining.replaceFirst(RegExp(r'<think>.*', dotAll: true), '');
      buffer.write(cleaned);
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final plainText = _extractPlainText(widget.message.content);
    final allLines = plainText.trim().split('\n');
    final totalLines = allLines.length;
    final hasMore = totalLines > 3;

    // 内容为空且不在加载中则不显示
    if (plainText.trim().isEmpty && !widget.isLoading) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上分割线 — 左侧显示 "AI SUMMARY"
          Row(
            children: [
              Text(
                'AI SUMMARY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.outline,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(color: colors.outlineVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 摘要文本 — 缩小字体，默认显示最后 3 行
          Text(
            widget.isLoading && plainText.trim().isEmpty
                ? '...'
                : plainText.trim(),
            textScaler:
                TextScaler.linear(widget.displaySetting.ContentFontScale * 0.85),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.outline,
              height: 1.4,
            ),
          ),
          // 如果超过 3 行，显示剩余行数提示
          if (hasMore)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '... +${totalLines - 3} 行',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.outline.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          // 下分割线
          Divider(color: colors.outlineVariant),
          const SizedBox(height: 4),
          widget.widget
              .buildBottomButtons(widget.widget.isSelected, widget.message),
        ],
      ),
    );
  }
}
