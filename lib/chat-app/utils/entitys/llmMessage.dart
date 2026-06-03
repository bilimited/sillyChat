import 'dart:convert';
import 'dart:io';

import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/utils/entitys/tool_call.dart';

class LLMMessage {
  final String content;
  final String role; // 如 "user"、"assistant"、"system"、"tool"
  final List<String> fileDirs; // 上传文件目录列表
  final bool isPrompt; // prompt消息比常规消息优先级更高

  final int? senderId; // 这个没啥用

  /// 工具调用列表（仅 role=="assistant" 且模型调用了工具时有值）
  final List<ToolCall>? toolCalls;

  /// 工具调用 ID（仅 role=="tool" 时有值，对应回 ToolCall.id）
  final String? toolCallId;

  LLMMessage({
    required this.content,
    required this.role,
    this.fileDirs = const [],
    this.isPrompt = false,
    this.senderId,
    this.toolCalls,
    this.toolCallId,
  });

  LLMMessage.fromJson(Map<String, dynamic> json)
      : content = json['content'] ?? '',
        role = json['role'] ?? 'user',
        fileDirs = (json['fileDirs'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        isPrompt = json['isPrompt'] ?? false,
        senderId = json['senderId'],
        toolCalls = (json['toolCalls'] as List<dynamic>?)
            ?.map((e) => ToolCall.fromJson(e as Map<String, dynamic>))
            .toList(),
        toolCallId = json['toolCallId'];

  /// 从 MessageModel 创建
  factory LLMMessage.fromMessageModel(MessageModel msg) {
    return LLMMessage(
        content: msg.content,
        role: msg.role.toString().split('.').last,
        fileDirs: msg.resPath,
        senderId: msg.senderId);
  }

  /// 从 PromptModel 创建
  factory LLMMessage.fromPromptModel(PromptModel prompt) {
    return LLMMessage(
      content: prompt.content,
      role: prompt.role,
      fileDirs: [],
    );
  }

  LLMMessage copyWith({
    String? content,
    String? role,
    List<String>? fileDirs,
    bool? isPrompt,
    int? senderId,
    List<ToolCall>? toolCalls,
    String? toolCallId,
  }) {
    return LLMMessage(
      content: content ?? this.content,
      role: role ?? this.role,
      fileDirs: fileDirs ?? this.fileDirs,
      isPrompt: isPrompt ?? this.isPrompt,
      senderId: senderId ?? this.senderId,
      toolCalls: toolCalls ?? this.toolCalls,
      toolCallId: toolCallId ?? this.toolCallId,
    );
  }
}
