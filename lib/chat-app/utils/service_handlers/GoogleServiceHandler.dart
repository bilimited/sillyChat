import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandler.dart';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';

class Googleservicehandler extends Servicehandler {
  const Googleservicehandler(
      {required super.baseUrl,
      required super.name,
      required super.defaultModelList});

  @override
  Future<List<String>> fetchModelList(apiKey) async {
    // 将 API 密钥作为查询参数添加到 URL 中
    const String baseUrl =
        'https://generativelanguage.googleapis.com/v1beta/models';
    final Uri uri =
        Uri.parse(baseUrl).replace(queryParameters: {'key': apiKey});

    try {
      final Dio _dio = Dio();
      // 1. 发送 GET 请求
      final response = await _dio.getUri(uri);

      // 2. 检查响应状态码并解析数据
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = response.data;

        // 安全地获取 'models' 列表
        final List<dynamic>? modelsList = responseData['models'] as List?;

        if (modelsList == null) {
          // 如果响应中没有 'models' 字段，返回空列表
          Get.snackbar(
              '获取模型列表时出错', "Response JSON does not contain a 'models' key.");
          return [];
        }
        final List<String> baseModelIds = modelsList
            .where((model) =>
                model is Map &&
                model.containsKey('name') &&
                model['name'] != null)
            .map((model) => model['name'].toString().replaceAll('models/', ''))
            .toList();

        return baseModelIds;
      } else {
        Get.snackbar('获取模型列表时出错',
            'Failed to load model list. Status code: ${response.statusCode}');
        LogController.log(json.encode(response.data), LogLevel.error,
            title: '获取模型列表出错', type: LogType.json);
        return [];
      }
    } on DioException catch (e) {
      Get.snackbar(
          '获取模型列表时出错', 'Failed to load model list. Status code: ${e.message}');
      if (e.response != null) {
        LogController.log(json.encode(e.response?.data), LogLevel.error,
            title: '获取模型列表出错', type: LogType.json);
      }
      return [];
    } catch (e) {
      // 处理其他任何意外错误
      Get.snackbar('获取模型列表时出错', 'An unexpected error occurred: $e');
      return [];
    }
  }

  @override
  parseMessage(LLMMessage message) async {
    final effectiveRole = (message.role == 'assistant') ? 'model' : 'user';
    return {
      "role": effectiveRole,
      "parts": toGeminiParts(message),
    };
  }

  List<Map<String, dynamic>> toGeminiParts(LLMMessage message) {
    final List<Map<String, dynamic>> parts = [];

    final content = message.content;
    final fileDirs = message.fileDirs;

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

  @override
  getRequestBody(LLMRequestOptions options) async {
    final List<dynamic> messages =
        await Future.wait(options.messages.map((msg) => parseMessage(msg)));

    return {
      "contents": messages,
      "generationConfig": {
        "temperature": options.temperature,
        "maxOutputTokens": options.maxTokens,
        "topP": options.topP,
        //"thinkingConfig": {}, // 暂时只有两档,
      },
      "safetySettings": [
        {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
        {
          "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
          "threshold": "BLOCK_NONE"
        },
        {
          "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
          "threshold": "BLOCK_NONE"
        },
      ],
    };
  }

  @override
  Stream<String> request(
      Aihandler aihandler, LLMRequestOptions options, ApiModel api) async* {
    final streamingUrl =
        "https://generativelanguage.googleapis.com/v1beta/models/${api.modelName}:streamGenerateContent?key=${api.apiKey}&alt=sse";
    final notStreamingUrl =
        "https://generativelanguage.googleapis.com/v1beta/models/${api.modelName}:generateContent?key=${api.apiKey}";

    final dioInstance = aihandler.dioInstance;
    final requestBody = await getRequestBody(options);
    LogController.log(json.encode(requestBody), LogLevel.info,
        type: LogType.json, title: 'Gemini请求');
    if (options.isStreaming) {
      aihandler.onGenerateStateChange('正在建立连接...');
    } else {
      aihandler.onGenerateStateChange('正在等待回应...');
    }
    final response = await dioInstance!.post(
      cancelToken: aihandler.cancelToken,
      options.isStreaming ? streamingUrl : notStreamingUrl,
      options: dio.Options(
        responseType: options.isStreaming
            ? dio.ResponseType.stream
            : dio.ResponseType.json,
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 180),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
      ),
      data: jsonEncode(requestBody), // Encode the body to a JSON string
    );

    bool isThinkStart = false;
    aihandler.onGenerateStateChange('正在生成...');

    if (options.isStreaming) {
      await for (final chunk in aihandler.parseSseStream(response, (json) {
        // 处理 Google Gemini SSE 响应，支持 <think> 标签
        final candidates = json['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) return '【空回复】';

        final finish_reason = candidates[0]?['finishReason'] ?? null;
        if (finish_reason != null && finish_reason != 'STOP') {
          // TODO；重做错误处理机制
          return '【回答终止，原因：${finish_reason}】';
        }
        final content = candidates[0]?['content'];
        final parts = content?['parts'] as List?;
        if (parts == null || parts.isEmpty) return '';

        final part = parts[0] as Map<String, dynamic>? ?? {};
        final text = part['text'] as String? ?? '';
        final thought = part['thought'] as bool? ?? false;

        String result = '';

        // 处理思考模式标签
        if (thought && !isThinkStart) {
          isThinkStart = true;
          result += '<think>';
        }
        if (!thought && isThinkStart) {
          isThinkStart = false;
          result += '</think>';
        }
        result += text;
        return result;
      })) {
        yield chunk;
      }
    } else {
      Map<String, dynamic> responseData = response.data as Map<String, dynamic>;
      LogController.log(json.encode(responseData), LogLevel.info,
          type: LogType.json, title: "Gemini响应");
      if (responseData['candidates'][0]['finishReason'] != 'STOP') {
        yield '回答被掐断了,原因：${responseData['candidates'][0]['finishReason']}';
        return;
      }

      final parts =
          responseData['candidates'][0]['content']['parts'] as List<dynamic>;
      for (final item in parts) {
        yield item['text'] ?? '';
      }
    }
  }

  @override
  Future<bool> testConnectivity() {
    // TODO: implement testConnectivity
    throw UnimplementedError();
  }
}
