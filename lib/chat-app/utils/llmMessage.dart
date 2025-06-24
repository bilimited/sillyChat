import 'dart:convert';
import 'dart:io';

import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

class LLMMessage {
  final String content;
  final String role; // 如 "user"、"assistant"、"system"
  final List<String> fileDirs; // 上传文件目录列表

  LLMMessage({
    required this.content,
    required this.role,
    this.fileDirs = const [],
  });

  /// 从 MessageModel 创建
  factory LLMMessage.fromMessageModel(MessageModel msg) {
    return LLMMessage(
      content: msg.content,
      role: msg.role.toString().split('.').last,
      fileDirs: msg.resPath
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
      // if (fileDirs.isNotEmpty) "files": fileDirs,
    };
  }

  /// 转为 Gemini 消息格式
  Map<String, dynamic> toGeminiJson() {
    return {
      "parts": [
        {"text": content},
        if (fileDirs.isNotEmpty)
          ...fileDirs.map((dir) => {"file_data": {"file_uri": dir}})
      ],
      "role": role,
    };
  }

  Content toGeminiContent() {
    return Content(
      parts: [
        Part.text(content),
        if (fileDirs.isNotEmpty)
          ...fileDirs.map((dir){
            final bytes = File(dir).readAsBytesSync();
            return Part.inline(InlineData(
            mimeType: 'image/jpeg',
            data: base64Encode(bytes)
          ));
          })
      ],
      role: role == 'assistant' ? 'model' : 'user'
    );
  }
}