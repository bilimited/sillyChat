import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:dio/dio.dart';
import 'package:flutter_example/chat-app/constants.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/entitys/tool_call.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';

/// 流式传输中累积中工具调用的内部辅助类
class _PendingToolCall {
  String? id;
  String? name;
  final StringBuffer arguments = StringBuffer();

  bool get isComplete => id != null && name != null;
}

class Openaiservicehandler extends Servicehandler {
  const Openaiservicehandler(
      {required super.baseUrl,
      required super.name,
      required super.defaultModelList});

  @override
  Future<List<String>> fetchModelList(String apiKey) async {
    final String url = '$baseUrl/models';

    try {
      final Dio _dio = Dio();

      // 1. 设置请求头
      final options = Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
      );

      // 2. 发送 GET 请求
      final response = await _dio.get(url, options: options);

      // 3. 检查响应状态码并解析数据
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = response.data;

        // 从响应中获取 'data' 字段，它是一个列表
        final List<dynamic> modelsData = responseData['data'] as List;

        // 4. 遍历列表，提取每个模型的 'id'
        final List<String> modelIds =
            modelsData.map((model) => model['id'].toString()).toList();

        return modelIds;
      } else {
        // 如果服务器返回非 200 的状态码，打印错误信息
        Get.snackbar('获取模型列表失败', ' Status code: ${response.statusCode}');
        LogController.log(json.encode(response.data), LogLevel.error,
            type: LogType.json, title: '获取模型列表失败');
        return [];
      }
    } on DioException catch (e) {
      Get.snackbar('获取模型列表失败', ' $e');
      return [];
    } catch (e) {
      Get.snackbar('获取模型列表失败', '$e');
      return [];
    }
  }

  parseImage(String path) async {
    // try {
    //   final bytes = await FlutterImageCompress.compressWithFile(
    //     path,
    //     quality: 85,
    //     format: CompressFormat.jpeg,
    //   );
    //   if (bytes != null) {
    //     imageContents.add({
    //       "type": "image_url",
    //       "image_url": base64Encode(bytes),
    //     });
    //   }
    // } catch (e) {
    //   // 这里可以改为更合适的日志记录
    //   print('Error compressing/reading file $path: $e');
    // }
    final file = File(path);

    final bytes = await file.readAsBytes();
    final ext = path.split('.').last.toLowerCase();
    String mimeType;
    if (ext == 'png') {
      mimeType = 'image/png';
    } else if (ext == 'jpg' || ext == 'jpeg') {
      mimeType = 'image/jpeg';
    } else if (ext == 'gif') {
      mimeType = 'image/gif';
    } else if (ext == 'webp') {
      mimeType = 'image/webp';
    } else if (ext == 'bmp') {
      mimeType = 'image/bmp';
    } else {
      mimeType = 'application/octet-stream';
    }
    final base64Data = base64Encode(bytes);
    return "data:$mimeType;base64,$base64Data";
  }

  @override
  parseMessage(LLMMessage message) async {
    // 工具结果消息：role == "tool"
    if (message.role == 'tool' && message.toolCallId != null) {
      return {
        "role": "tool",
        "tool_call_id": message.toolCallId,
        "content": message.content,
      };
    }

    // 助理消息包含工具调用
    if (message.toolCalls != null && message.toolCalls!.isNotEmpty) {
      return {
        "role": "assistant",
        "content": message.content.isEmpty ? null : message.content,
        "tool_calls": message.toolCalls!.map((tc) => tc.toJson()).toList(),
      };
    }

    // 普通消息（支持图片附件）
    if (message.fileDirs.isNotEmpty) {
      // 先单独计算所有 image_url（压缩并 base64 编码），然后再构建返回内容
      final List<dynamic> imageContents = [];
      for (final path in message.fileDirs) {
        imageContents
            .add({"type": "image_url", "image_url": await parseImage(path)});
      }

      return {
        "role": message.role,
        "content": [
          {
            "type": "text",
            "text": message.content,
          },
          ...imageContents,
        ],
      };
    }
    return {
      "role": message.role,
      "content": message.content,
    };
  }

  @override
  Future<Map<String, dynamic>> getRequestBody(LLMRequestOptions options) async {
    final List<dynamic> messages =
        await Future.wait(options.messages.map((msg) => parseMessage(msg)));

    final body = <String, dynamic>{
      'messages': messages,
      'max_tokens': options.maxTokens,
      'temperature': options.temperature,
      'top_p': options.topP,
      'presence_penalty': options.presencePenalty,
      'frequency_penalty': options.frequencyPenalty,
    };

    // 添加工具定义
    if (options.tools != null && options.tools!.isNotEmpty) {
      body['tools'] = options.tools!.map((t) => t.toJson()).toList();
    }

    // 添加工具选择策略
    if (options.toolChoice != null) {
      body['tool_choice'] = options.toolChoice;
    }

    return body;
  }

  @override
  Stream<LLMResponseChunk> request(
      Aihandler aihandler, LLMRequestOptions options, ApiModel api) async* {
    aihandler.onGenerateStateChange('正在准备...');

    final requestBody = await getRequestBody(options);

    LogController.log(
      json.encode(requestBody),
      LogLevel.info,
      title: 'OpenAI请求',
      type: LogType.json,
    );

    String key = api.apiKey;
    String model = api.modelName;

    String url = api.url.isEmpty
        ? baseUrl + '/chat/completions'
        : api.url + '/chat/completions';
    final dioInstance = aihandler.dioInstance;

    // 构建请求数据
    Map<String, dynamic> requestData = {
      'model': model,
      ...requestBody,
      'stream': options.isStreaming,
    };

    if (options.isStreaming) {
      aihandler.onGenerateStateChange('正在建立连接...');
    } else {
      aihandler.onGenerateStateChange('正在等待回应...');
    }

    // 如果API配置了requestBody，尝试解析并合并到请求数据中
    if (api.requestBody != null && api.requestBody!.isNotEmpty) {
      try {
        final additionalData = _parseRequestBody(api.requestBody!);
        if (additionalData is Map<String, dynamic>) {
          requestData.addAll(additionalData);
        }
      } catch (e) {
        LogController.log(
          '解析requestBody失败: ${e.toString()}',
          LogLevel.warning,
          title: 'requestBody解析错误',
        );
      }
    }
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
          'User-Agent': Constants.USER_AGENT,
        },
        contentType: 'application/json; charset=utf-8',
      ),
      cancelToken: aihandler.cancelToken,
      data: requestData,
    );

    aihandler.onGenerateStateChange('正在生成...');
    if (options.isStreaming) {
      yield* _handleStreamingResponse(rs);
    } else {
      yield* _handleNonStreamingResponse(rs);
    }
  }

  /// 处理流式响应 — 支持文本增量、思维链和工具调用的增量累积
  Stream<LLMResponseChunk> _handleStreamingResponse(dio.Response rs) async* {
    String buffer = '';
    bool cot = false;
    final pendingToolCalls = <int, _PendingToolCall>{};

    await for (var decodedData in utf8.decoder.bind(rs.data.stream)) {
      buffer += decodedData;

      while (buffer.contains('\n')) {
        var index = buffer.indexOf('\n');
        var line = buffer.substring(0, index).trim();
        buffer = buffer.substring(index + 1);

        if (!line.startsWith('data: ')) continue;
        line = line.substring(5).trim();
        if (line.isEmpty) continue;
        if (line == '[DONE]') {
          // 流结束，发送所有未完成的工具调用
          for (final pending in pendingToolCalls.values) {
            if (pending.isComplete) {
              yield LLMResponseChunk.tool(
                ToolCall(
                  id: pending.id!,
                  functionName: pending.name!,
                  arguments: pending.arguments.toString(),
                ),
                finishReason: 'tool_calls',
              );
            }
          }
          pendingToolCalls.clear();
          break;
        }

        final jsonData = jsonDecode(line) as Map<String, dynamic>;

        if ((jsonData['choices'] is List) &&
            (jsonData['choices'] as List).isEmpty) {
          continue;
        }

        final delta =
            jsonData['choices'][0]['delta'] as Map<String, dynamic>?;
        if (delta == null) continue;

        // ----- 处理工具调用增量 -----
        final toolCallsDelta = delta['tool_calls'] as List?;
        if (toolCallsDelta != null) {
          for (final tcDelta in toolCallsDelta) {
            final idx = (tcDelta['index'] as int?) ?? 0;
            final pending = pendingToolCalls.putIfAbsent(
                idx, () => _PendingToolCall());

            if (tcDelta['id'] != null) {
              pending.id = tcDelta['id'] as String;
            }
            final func = tcDelta['function'] as Map<String, dynamic>?;
            if (func != null) {
              if (func['name'] != null) {
                pending.name = func['name'] as String;
              }
              if (func['arguments'] != null) {
                pending.arguments.write(func['arguments'] as String);
              }
            }
          }
        }

        // ----- 检查 finish_reason -----
        final finishReason =
            jsonData['choices'][0]['finish_reason'] as String?;

        if (finishReason == 'tool_calls') {
          // 工具调用完成，发送所有累积的工具调用
          for (final pending in pendingToolCalls.values) {
            if (pending.isComplete) {
              yield LLMResponseChunk.tool(
                ToolCall(
                  id: pending.id!,
                  functionName: pending.name!,
                  arguments: pending.arguments.toString(),
                ),
                finishReason: 'tool_calls',
              );
            }
          }
          pendingToolCalls.clear();
          continue;
        }

        // ----- 处理文本内容（含思维链） -----
        final reasoningContent =
            delta['reasoning_content'] as String? ?? '';
        final content = delta['content'] as String? ?? '';

        if (reasoningContent.isNotEmpty && !cot) {
          yield const LLMResponseChunk(isThinkingStart: true);
          cot = true;
        }
        if (reasoningContent.isNotEmpty) {
          yield LLMResponseChunk.thinking(reasoningContent);
        }
        if (reasoningContent.isEmpty && cot) {
          yield const LLMResponseChunk(isThinkingEnd: true);
          cot = false;
        }
        if (reasoningContent.isEmpty && !cot && content.isNotEmpty) {
          yield LLMResponseChunk.text(content);
        }
      }
    }

    // 流结束后，发送所有未完成的工具调用（兜底）
    for (final pending in pendingToolCalls.values) {
      if (pending.isComplete) {
        yield LLMResponseChunk.tool(
          ToolCall(
            id: pending.id!,
            functionName: pending.name!,
            arguments: pending.arguments.toString(),
          ),
          finishReason: 'tool_calls',
        );
      }
    }
  }

  /// 处理非流式响应 — 支持工具调用和文本内容
  Stream<LLMResponseChunk> _handleNonStreamingResponse(dio.Response rs) async* {
    Map<String, dynamic> responseData = rs.data as Map<String, dynamic>;
    LogController.log(json.encode(responseData), LogLevel.info,
        type: LogType.json, title: "OpenAI响应");

    final message =
        responseData['choices'][0]['message'] as Map<String, dynamic>?;
    if (message == null) {
      yield LLMResponseChunk.text('未发现可用消息');
      return;
    }

    // 处理工具调用
    final toolCallsJson = message['tool_calls'] as List?;
    if (toolCallsJson != null && toolCallsJson.isNotEmpty) {
      for (final tcJson in toolCallsJson) {
        yield LLMResponseChunk.tool(
          ToolCall.fromJson(tcJson as Map<String, dynamic>),
          finishReason: 'tool_calls',
        );
      }
    }

    // 处理文本内容
    final reasoningContent = message['reasoning_content'] as String?;
    final content = message['content'] as String?;

    if (reasoningContent != null && reasoningContent.isNotEmpty) {
      yield const LLMResponseChunk(isThinkingStart: true);
      yield LLMResponseChunk.thinking(reasoningContent);
      yield const LLMResponseChunk(isThinkingEnd: true);
    }

    if (content != null && content.isNotEmpty) {
      yield LLMResponseChunk.text(content);
    } else if ((toolCallsJson == null || toolCallsJson.isEmpty) &&
        (reasoningContent == null || reasoningContent.isEmpty)) {
      yield LLMResponseChunk.text('未发现可用消息');
    }
  }

  // 解析requestBody，支持Python风格语法转换为JSON
  dynamic _parseRequestBody(String requestBody) {
    try {
      // 首先尝试直接解析为JSON
      return json.decode(requestBody);
    } catch (jsonError) {
      try {
        // 如果JSON解析失败，尝试转换Python风格语法
        final convertedJson = _convertPythonToJson(requestBody);
        return json.decode(convertedJson);
      } catch (pythonError) {
        throw Exception(
            '无法解析requestBody。JSON解析错误: $jsonError，Python语法转换错误: $pythonError');
      }
    }
  }

  // 将Python风格语法转换为JSON格式
  String _convertPythonToJson(String pythonStyle) {
    String converted = pythonStyle;

    // 替换 Python风格的 True/False/None
    converted = converted.replaceAll(RegExp(r'\bTrue\b'), 'true');
    converted = converted.replaceAll(RegExp(r'\bFalse\b'), 'false');
    converted = converted.replaceAll(RegExp(r'\bNone\b'), 'null');

    // 处理单引号字符串（Python允许，JSON不允许）
    converted = _convertSingleQuotesToJson(converted);

    return converted;
  }

  // 将单引号字符串转换为双引号字符串
  String _convertSingleQuotesToJson(String input) {
    final buffer = StringBuffer();
    bool inString = false;
    bool inSingleQuote = false;
    bool inDoubleQuote = false;
    bool escapeNext = false;

    for (int i = 0; i < input.length; i++) {
      final char = input[i];

      if (escapeNext) {
        buffer.write(char);
        escapeNext = false;
        continue;
      }

      if (char == '\\') {
        buffer.write(char);
        escapeNext = true;
        continue;
      }

      if (!inString) {
        if (char == '"') {
          inString = true;
          inDoubleQuote = true;
          buffer.write(char);
        } else if (char == "'") {
          inString = true;
          inSingleQuote = true;
          buffer.write('"'); // 将单引号转换为双引号
        } else {
          buffer.write(char);
        }
      } else {
        if (inDoubleQuote && char == '"') {
          inString = false;
          inDoubleQuote = false;
          buffer.write(char);
        } else if (inSingleQuote && char == "'") {
          inString = false;
          inSingleQuote = false;
          buffer.write('"'); // 将结束单引号转换为双引号
        } else {
          buffer.write(char);
        }
      }
    }

    return buffer.toString();
  }

  @override
  Future<bool> testConnectivity() {
    // TODO: implement testConnectivity
    throw UnimplementedError();
  }
}
