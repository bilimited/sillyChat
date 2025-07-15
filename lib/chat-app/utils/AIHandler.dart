import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/RequestOptions.dart';
import 'package:get/get.dart';

class RequestOptions {}

class Aihandler {
  // 默认API已禁用
  static const String API_URL = "";
  static const String API_KEY = "";
  static const String MODEL_NAME = "";
  static const bool enableSSE = true;

  void Function(String newState) onGenerateStateChange = (newStat) {};

  bool isInterrupt = false;
  bool isBusy = false;
  dio.Dio? dioInstance;
  int token_used = 0;

  void interrupt() {
    isInterrupt = true;
    isBusy = false;
    if (dioInstance != null) {
      
      dioInstance!.close(force: true);

      
    }
  }

  Future<void> request(
      void Function(String) callback, LLMRequestOptions options) async {
    await for (String token in requestTokenStream(options)) {
      callback(token);
    }
  }

  // 不好使
  static Future<void> testConnectivity(String url,void Function(bool isSuccess,String message) callback) async {
    final d = dio.Dio();
    try {
      // 尝试发送一个HEAD请求，通常比GET请求更轻量，且不返回响应体
      // 或者发送一个GET请求到API的健康检查端点（如果有的话）
      final response = await d.head(url,
          options: dio.Options(receiveTimeout: const Duration(seconds: 5)));
      callback(response.statusCode == 200, 'URL可正常连接'); // 检查HTTP状态码
    } on dio.DioException catch (e) {
      if (e.type == dio.DioExceptionType.connectionTimeout ||
          e.type == dio.DioExceptionType.receiveTimeout ||
          e.type == dio.DioExceptionType.sendTimeout ||
          e.type == dio.DioExceptionType.unknown) {
        print('网络连接超时或无网络: ${e.message}');
        callback(false, '网络连接超时或无网络: ${e.message}');
      }
      print('API连通性测试失败: ${e.message}');
      callback(false, 'API连通性测试失败: ${e.message}');
    } catch (e) {
      print('发生未知错误: $e');
      callback(false, '发生未知错误: $e');
    }
  }

  Stream<String> requestTokenStream(LLMRequestOptions options) async* {
    try {
      isInterrupt = false;

      if (isBusy) {
        return;
      } else {
        isBusy = true;
      }

      token_used = 0;
      final VaultSettingController settingController = Get.find();
      final ApiModel? api = settingController.getApiById(options.apiId);
      if (api == null) {
        Get.snackbar("未选择API", "请先选择一个API");
        return;
      }
      if (api.provider.isOpenAICompatiable) {
        await for (final token in requestOpenAI(options, api)) {
          print("Token:$token");
          yield token;
        }
        // yield* requestOpenAI(options, api); yield* 会导致异常无法正常被catch
      } else if (api.provider.isGoogleCompatiable) {
        // 谷歌接口
        await for (final token in requestGoogle(options, api)) {
          yield token;
        }
      }
    } catch (e) {
      onGenerateStateChange('生成已停止');
      Get.snackbar("发生错误", "$e", colorText: Colors.red);
      LogController.log("发生错误:$e", LogLevel.error);
    }
    isBusy = false;
    if (dioInstance != null) {
      dioInstance!.close();
      dioInstance = null;
    }
  }

  Stream<String> requestOpenAI(LLMRequestOptions options, ApiModel api,
      {String? overriteModelName}) async* {
    try {
      String key = api.apiKey;
      String model = overriteModelName ?? api.modelName;
      String url = api.url;

      onGenerateStateChange('正在建立连接...');
      dioInstance = dio.Dio();
      final rs = await dioInstance!.post(
        url,
        options: dio.Options(
          responseType: dio.ResponseType.stream,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 180),
          headers: {
            'Authorization': 'Bearer ' + key,
          },
          contentType: 'application/json; charset=utf-8',
        ),
        data: {
          'model': model,
          ...options.toOpenAIJson(),
          'stream': true,
        },
      );
      onGenerateStateChange('正在生成...');
      await for (var chunk in parseSseStream(rs,
          (json) => json['choices'][0]['delta']['content'] as String? ?? '')) {
        yield chunk;
      }
    } catch (e) {
      throw e;
    }
  }

  Stream<String> requestGoogle(LLMRequestOptions options, ApiModel api) async* {
    try {
      final url =
          "https://generativelanguage.googleapis.com/v1beta/models/${api.modelName}:streamGenerateContent?key=${api.apiKey}&alt=sse";

      final requestBody = {
        // if (options.messages.where((msg) => msg.role == 'system').isNotEmpty)
        //   "system_instruction": LLMMessage.toGeminiSystemPrompt(
        //       options.messages.where((msg) => msg.role == 'system').toList()),
        "contents": options.messages
            //.where((msg) => msg.role != 'system')
            .map((msg) => msg.toGeminiRestJson())
            .toList(),
        "generationConfig": {
          "temperature": options.temperature,
          "maxOutputTokens": options.maxTokens,
          "topP": options.topP,
          "thinkingConfig": {
            // Gemini 2.5 Pro: 我无法停止思考！
            // TODO: 添加ThinkBudget设置和includeThoughts开关
            // "thinkingBudget": options.isThinkMode ? -1 : 0,
            // "includeThoughts": options.isThinkMode ? true : false,
          }, // 暂时只有两档,

          // if (options.seed >= 0) "seed": options.seed,
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
      onGenerateStateChange('正在建立连接...');
      dioInstance = dio.Dio();
      final response = await dioInstance!.post(
        url,
        options: dio.Options(
          responseType: dio.ResponseType.stream,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 180),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
          },
        ),
        data: jsonEncode(requestBody), // Encode the body to a JSON string
      );

      bool isThinkStart = false;
      onGenerateStateChange('正在生成...');
      await for (final chunk in parseSseStream(response, (json) {
        // 处理 Google Gemini SSE 响应，支持 <think> 标签
        final candidates = json['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) return '';

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
    } catch (e) {
      if (e is dio.DioException && e.response?.data != null) {
        final errorData = e.response!.data;
        // Attempt to decode error response for better logging
        try {
          final decoded = utf8.decode(errorData);
          final jsonError = jsonDecode(decoded);
          throw 'Google API Error: ${jsonError['error']?['message'] ?? decoded}';
        } catch (_) {
          print(errorData);
          throw 'Google API Error: ${e.message}';
        }
      }
      print("Error:$e");
      throw e; // Re-throw to be caught by the main handler
    }
  }

  Stream<String> parseSseStream(
      dio.Response response, String Function(dynamic json) parser) async* {
    String buffer = ''; // 用于积累不完整的行

    // 使用 utf8.decoder.bind 来安全地解码字节流
    await for (var decodedData in utf8.decoder.bind(response.data.stream)) {
      buffer += decodedData;

      // 持续处理缓冲区，直到没有更多的换行符
      while (buffer.contains('\n')) {
        var index = buffer.indexOf('\n');
        var line = buffer.substring(0, index).trim();
        buffer = buffer.substring(index + 1);

        if (line.startsWith('data: ')) {
          line = line.substring(5).trim();

          if (line.isEmpty) continue;
          // SSE 中常常有 "event: " 和 "id: " 等行，我们只关心 "data: " 行
          if (line == '[DONE]') {
            print("SSE stream finished with [DONE]");
            break; // 退出循环
          }

          try {
            // 尝试将数据行解析为 JSON
            final json = jsonDecode(line);
            print("JSON (SSE)::: $json");

            final content = parser(json);

            if (content.isNotEmpty) {
              yield content;
            }
          } catch (e) {
            LogController.log(
                "SSE JSON解析错误: $line\n错误信息: $e", LogLevel.warning);
            continue;
          }
        } else {
          print("Non-data SSE line: $line");
        }
      }

      if (isInterrupt) break;
    }
    if (buffer.isNotEmpty) {
      print("Remaining buffer after stream end: $buffer");
    }
  }

  Future<String> parseNotSSEStream(dio.Response response) async {
    StringBuffer accumulatedBuffer =
        StringBuffer(); // Use StringBuffer for efficiency
    await for (var decodedData in utf8.decoder.bind(response.data.stream)) {
      if (isInterrupt) break;

      accumulatedBuffer.write(decodedData); // Append new data
      String currentBuffer =
          accumulatedBuffer.toString(); // Get current string for parsing
      try {
        final json = jsonDecode(currentBuffer);
        print("JSON::: $json"); // This should now print
        if (json is List) {
          for (var jsonItem in json) {
            // 确保每个jsonItem也是一个Map，并且包含'candidates'键
            if (jsonItem is Map<String, dynamic> &&
                jsonItem.containsKey('candidates')) {
              final content = jsonItem['candidates']?[0]?['content']?['parts']
                      ?[0]?['text'] as String? ??
                  '';
              if (content.isNotEmpty) {
                return content;
              }
            }
          }
        } else {
          final content = json['candidates']?[0]?['content']?['parts']?[0]
                  ?['text'] as String? ??
              '';
          if (content.isNotEmpty) {
            return content;
          }
        }
        accumulatedBuffer.clear();
      } catch (e) {
        if (e is! FormatException) {
          LogController.log(
              "Google JSON解析错误: $currentBuffer\n错误信息: $e", LogLevel.warning);
        }
      }
    }
    return "出现了错误！";
  }

  static bool isEndLine(String token) {
    return token.contains('\n');
  }

  static bool isThinkStart(String token) {
    return token == '<think>';
  }

  static bool isThinkEnd(String token) {
    return token == '</think>';
  }
}
