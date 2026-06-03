import 'dart:convert';

/// 函数定义 — 描述一个可供模型调用的函数
class FunctionDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters; // JSON Schema

  const FunctionDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'parameters': parameters,
      };

  factory FunctionDefinition.fromJson(Map<String, dynamic> json) =>
      FunctionDefinition(
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      );

  FunctionDefinition copyWith({
    String? name,
    String? description,
    Map<String, dynamic>? parameters,
  }) =>
      FunctionDefinition(
        name: name ?? this.name,
        description: description ?? this.description,
        parameters: parameters ?? this.parameters,
      );
}

/// 工具定义 — 发送给 API 的 tools 数组中的一项
class ToolDefinition {
  final String type; // 目前固定为 "function"
  final FunctionDefinition function;

  const ToolDefinition({
    this.type = 'function',
    required this.function,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'function': function.toJson(),
      };

  factory ToolDefinition.fromJson(Map<String, dynamic> json) => ToolDefinition(
        type: json['type'] ?? 'function',
        function: FunctionDefinition.fromJson(json['function'] ?? {}),
      );
}

/// 模型返回的工具调用
class ToolCall {
  final String id;
  final String type; // "function"
  final String functionName;
  final String arguments; // JSON 字符串，使用 jsonDecode 解析

  const ToolCall({
    required this.id,
    this.type = 'function',
    required this.functionName,
    required this.arguments,
  });

  /// 解析 arguments 为 Map
  Map<String, dynamic> get parsedArguments {
    try {
      return jsonDecode(arguments) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'function': {
          'name': functionName,
          'arguments': arguments,
        },
      };

  factory ToolCall.fromJson(Map<String, dynamic> json) => ToolCall(
        id: json['id'] ?? '',
        type: json['type'] ?? 'function',
        functionName: json['function']?['name'] ?? '',
        arguments: json['function']?['arguments'] ?? '',
      );

  @override
  String toString() =>
      'ToolCall(id: $id, function: $functionName, arguments: $arguments)';
}

/// LLM 流式/非流式响应的统一块类型
///
/// 替代原来的纯文本 String 流。每个 chunk 可以是：
/// - 文本增量（普通内容或思维链内容）
/// - 一个完整的工具调用
/// - 思维链开始/结束标记
class LLMResponseChunk {
  /// 文本内容增量（普通 text 或 reasoning_content）
  final String? content;

  /// 一个完整的工具调用（仅在流式累积完成或非流式解析后设置）
  final ToolCall? toolCall;

  /// 是否为思维链开始标记
  final bool isThinkingStart;

  /// 是否为思维链结束标记
  final bool isThinkingEnd;

  /// finish_reason，仅在非流式或流式最后一个 chunk 时有值
  final String? finishReason;

  const LLMResponseChunk({
    this.content,
    this.toolCall,
    this.isThinkingStart = false,
    this.isThinkingEnd = false,
    this.finishReason,
  });

  /// 纯文本 chunk
  factory LLMResponseChunk.text(String content) => LLMResponseChunk(
        content: content,
      );

  /// 思维链文本 chunk
  factory LLMResponseChunk.thinking(String content) => LLMResponseChunk(
        content: content,
      );

  /// 工具调用 chunk
  factory LLMResponseChunk.tool(ToolCall toolCall,
          {String? finishReason}) =>
      LLMResponseChunk(
        toolCall: toolCall,
        finishReason: finishReason,
      );

  bool get isText => content != null && toolCall == null;
  bool get isToolCall => toolCall != null;

  @override
  String toString() {
    if (isToolCall) {
      return 'LLMResponseChunk(toolCall: $toolCall)';
    } else if (isThinkingStart) {
      return 'LLMResponseChunk(thinking: start)';
    } else if (isThinkingEnd) {
      return 'LLMResponseChunk(thinking: end)';
    } else {
      return 'LLMResponseChunk(content: "$content")';
    }
  }
}
