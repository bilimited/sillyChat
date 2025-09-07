import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:get/get.dart';

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
  //int token_used = 0;
  dio.CancelToken cancelToken = dio.CancelToken(); // 用于中断请求

  void interrupt() {
    isInterrupt = true;
    isBusy = false;

    cancelToken.cancel();
    onGenerateStateChange('生成已停止');
  }

  void initDio() {
    if (dioInstance == null) {
      print("正在创建新的Dio实例");
      //  一个连接最长保持4分钟，以加快Gemini响应速度
      // 注意：如果空闲时间过长某个中间网关可能会静默丢弃这个连接，导致一次连接超时
      dioInstance = dio.Dio()
        ..httpClientAdapter = Http2Adapter(ConnectionManager(
          idleTimeout: Duration(minutes: 4),
          onClientCreate: (uri, p1) {
            print('[${DateTime.now()}] 监控: 正在为 $uri 建立一个新的 HTTP/2 连接...');
          },
        ));
    }
  }

  Future<void> request(
      void Function(String) callback, LLMRequestOptions options) async {
    await for (String token in requestTokenStream(options)) {
      callback(token);
    }
  }

  // 不好使
  static Future<List<String>> fetchModelList(String url, String token,
      void Function(bool isSuccess, String message) callback) async {
    final d = dio.Dio();
    try {
      final rs = await d!.post(
        url,
      );
    } on dio.DioException catch (e) {
      if (e.type == dio.DioExceptionType.connectionTimeout ||
          e.type == dio.DioExceptionType.receiveTimeout ||
          e.type == dio.DioExceptionType.sendTimeout ||
          e.type == dio.DioExceptionType.unknown) {
        print('网络连接超时或无网络: ${e.message}');
        callback(false, '网络连接超时或无网络: ${e.message}');
      }
      print('API连接失败: ${e.message}');
      callback(false, 'API连接失败: ${e.message}');
    } catch (e) {
      print('发生未知错误: $e');
      callback(false, '发生未知错误: $e');
    }

    return [];
  }

  Stream<String> requestTokenStream(LLMRequestOptions options) async* {
    try {
      isInterrupt = false;
      cancelToken = dio.CancelToken();

      if (isBusy) {
        return;
      } else {
        isBusy = true;
      }

      final VaultSettingController settingController = Get.find();
      final ApiModel? api = settingController.getApiById(options.apiId);
      if (api == null) {
        Get.snackbar("未选择API", "请先选择一个API");
        onGenerateStateChange('未选择API');
        isBusy = false;
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
  }

  Stream<String> requestOpenAI(LLMRequestOptions options, ApiModel api,
      {String? overriteModelName}) async* {
    try {
      String key = api.apiKey;
      String model = overriteModelName ?? api.modelName;
      String url = api.url;
      if (options.isStreaming) {
        onGenerateStateChange('正在建立连接...');
      } else {
        onGenerateStateChange('正在等待回应...');
      }

      initDio();

      LogController.log(
        json.encode(options.toOpenAIJson()),
        LogLevel.info,
        title: 'OpenAI请求',
        type: LogType.json,
      );
      final rs = await dioInstance!.post(
        url,
        options: dio.Options(
          responseType: options.isStreaming
              ? dio.ResponseType.stream
              : dio.ResponseType.json,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 180),
          headers: {
            'Authorization': 'Bearer ' + key,
          },
          contentType: 'application/json; charset=utf-8',
        ),
        cancelToken: cancelToken,
        data: {
          'model': model,
          ...options.toOpenAIJson(),
          'stream': options.isStreaming,
        },
      );

      onGenerateStateChange('正在生成...');
      if (options.isStreaming) {
        await for (var chunk in parseSseStream(
            rs,
            (json) =>
                json['choices'][0]['delta']['content'] as String? ?? '')) {
          yield chunk;
        }
      } else {
        Map<String, dynamic> responseData = rs.data as Map<String, dynamic>;
        LogController.log(json.encode(responseData), LogLevel.info,
            type: LogType.json, title: "OpenAI响应");
        yield responseData['choices'][0]['message']['content'] ?? '未发现可用消息';
      }
    } on dio.DioException catch (e) {
      if (dio.CancelToken.isCancel(e)) {
      } else {
        rethrow;
      }
    } catch (e) {
      rethrow;
    }
  }

  Stream<String> requestGoogle(LLMRequestOptions options, ApiModel api) async* {
    try {
      final streamingUrl =
          "https://generativelanguage.googleapis.com/v1beta/models/${api.modelName}:streamGenerateContent?key=${api.apiKey}&alt=sse";
      final notStreamingUrl =
          "https://generativelanguage.googleapis.com/v1beta/models/${api.modelName}:generateContent?key=${api.apiKey}";

      final requestBody = {
        "contents":
            options.messages.map((msg) => msg.toGeminiRestJson()).toList(),
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
      LogController.log(json.encode(requestBody), LogLevel.info,
          type: LogType.json, title: 'Gemini请求');
      if (options.isStreaming) {
        onGenerateStateChange('正在建立连接...');
      } else {
        onGenerateStateChange('正在等待回应...');
      }
      initDio();
      final response = await dioInstance!.post(
        cancelToken: cancelToken,
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
      onGenerateStateChange('正在生成...');

      if (options.isStreaming) {
        await for (final chunk in parseSseStream(response, (json) {
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
        Map<String, dynamic> responseData =
            response.data as Map<String, dynamic>;
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
    } on dio.DioException catch (e) {
      if (dio.CancelToken.isCancel(e)) {
      } else if (e.response?.data != null) {
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
    } catch (e) {
      print("Error:$e");
      rethrow;
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

  // gemini的提示词预处理(合并相邻相同role消息)。兼容酒馆用
  List<Map<String, dynamic>> _geminiMergeAdjacentMessages(
      List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) {
      return [];
    }

    final mergedMessages = <Map<String, dynamic>>[];
    Map<String, dynamic>? currentMergedMessage;
    List<String> currentPartsTexts = []; // 新增：用于收集当前合并块的所有文本

    for (final message in messages) {
      final role = message['role'];
      final partText = message['parts'][0]['text'] as String;

      if (currentMergedMessage == null) {
        currentMergedMessage = {
          'role': role,
        };
        currentPartsTexts.add(partText);
      } else if (currentMergedMessage['role'] == role) {
        currentPartsTexts.add(partText);
      } else {
        currentMergedMessage['parts'] = [
          {'text': currentPartsTexts.join('\n')}
        ];
        mergedMessages.add(currentMergedMessage);

        // 开始新的合并块
        currentMergedMessage = {
          'role': role,
        };
        currentPartsTexts = [partText]; // 重置并添加当前文本
      }
    }

    // 将最后一个合并块添加到结果列表
    if (currentMergedMessage != null) {
      currentMergedMessage['parts'] = [
        {'text': currentPartsTexts.join('\n')}
      ];
      mergedMessages.add(currentMergedMessage);
    }

    return mergedMessages;
  }
}
