/// 消息内容片段的类型
enum ContentSegmentType { text, think, toolCallResult }

/// 消息内容片段 — 将消息内容拆分为不同类型的片段
class ContentSegment {
  final ContentSegmentType type;
  final String content;
  final Map<String, String>? attributes; // toolCallResult: id, name, args
  final bool isThinking; // think: 是否为未闭合的思考块（流式输出中）

  const ContentSegment({
    required this.type,
    required this.content,
    this.attributes,
    this.isThinking = false,
  });
}
