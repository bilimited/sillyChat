import 'dart:convert';
import 'dart:io';

import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';

class LLMMessage {
  final String content;
  final String role; // 如 "user"、"assistant"、"system"
  final List<String> fileDirs; // 上传文件目录列表
  final bool isPrompt; // prompt消息比常规消息优先级更高

  final int? senderId; // 这个没啥用

  LLMMessage({
    required this.content,
    required this.role,
    this.fileDirs = const [],
    this.isPrompt = false,
    this.senderId,
  });

  /// 从 MessageModel 创建
  factory LLMMessage.fromMessageModel(MessageModel msg) {
    return LLMMessage(
        content: msg.content,
        role: msg.role.toString().split('.').last,
        fileDirs: msg.resPath,
        senderId: msg.sender
        );
  }

  /// 从 PromptModel 创建
  factory LLMMessage.fromPromptModel(PromptModel prompt) {
    return LLMMessage(
      content: prompt.content,
      role: prompt.role,
      fileDirs: [],
    );
  }

  /// 转为 OpenAI 消息格式
  Map<String, String> toOpenAIJson() {
    return {
      "role": role,
      "content": content,
    };
  }

  List<Map<String, dynamic>> toGeminiParts() {
    final List<Map<String, dynamic>> parts = [];

    // Add the text part if content is not empty.
    if (content.isNotEmpty) {
      parts.add({"text": content});
    }

    // Add file parts if any files are present.
    if (fileDirs.isNotEmpty) {
      for (var dir in fileDirs) {
        try {
          final file = File(dir);
          final bytes = file.readAsBytesSync();
          // A simple way to guess the mime type. For a robust solution,
          // you might use a library like 'mime'.
          final mimeType = dir.endsWith('.png')
              ? 'image/png'
              : 'image/jpeg'; // Default to jpeg

          parts.add({
            "inline_data": {"mime_type": mimeType, "data": base64Encode(bytes)}
          });
        } catch (e) {
          // Handle file reading errors, e.g., log them.
          print('Error reading file $dir: $e');
        }
      }
    }
    return parts;
  }

  /// 转为 Gemini 消息格式
  /// Converts to Gemini REST API message format.
  /// This new method replaces toGeminiJson and toGeminiContent.
  Map<String, dynamic> toGeminiRestJson() {
    final effectiveRole = (role == 'assistant') ? 'model' : 'user';
    return {
      "role": effectiveRole,
      "parts": toGeminiParts(),
    };
  }

  static Map<String, dynamic> toGeminiSystemPrompt(
      List<LLMMessage> messages) {
    if (messages.isEmpty) {
      return {};
    }
    // 取第一个消息的角色
    final role = messages.first.role;
    // 合并内容
    final mergedContent = messages.map((m) => m.content).join('\n');
    // 合并文件
    final mergedFileDirs = messages.expand((m) => m.fileDirs).toList();

    final mergedMessage = LLMMessage(
      content: mergedContent,
      role: role,
      fileDirs: mergedFileDirs,
    );
    return {
      "parts": mergedMessage.toGeminiParts()
    };
  }

  LLMMessage copyWith({
    String? content,
    String? role,
    List<String>? fileDirs,
    bool? isPrompt,
    int? senderId,
  }) {
    return LLMMessage(
      content: content ?? this.content,
      role: role ?? this.role,
      fileDirs: fileDirs ?? this.fileDirs,
      isPrompt: isPrompt ?? this.isPrompt,
      senderId: senderId ?? this.senderId,
    );
  }
}
