import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:dio/dio.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandler.dart';
import 'package:get/get.dart';

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
      Get.snackbar('获取模型列表失败', ' ${e.message}');
      return [];
    } catch (e) {
      Get.snackbar('获取模型列表失败', '$e');
      return [];
    }
  }

  @override
  parseMessage(LLMMessage message) {
    return {
      "role": message.role,
      "content": message.content,
    };
  }

  @override
  Map<String, dynamic> getRequestBody(LLMRequestOptions options) {
    return {
      'messages': options.messages.map((msg) => parseMessage(msg)).toList(),
      'max_tokens': options.maxTokens,
      'temperature': options.temperature,
      'top_p': options.topP,
      'presence_penalty': options.presencePenalty,
      'frequency_penalty': options.frequencyPenalty,
    };
  }

  @override
  Stream<String> request(
      Aihandler aihandler, LLMRequestOptions options, ApiModel api) async* {
    if (options.isStreaming) {
      aihandler.onGenerateStateChange('正在建立连接...');
    } else {
      aihandler.onGenerateStateChange('正在等待回应...');
    }
    LogController.log(
      json.encode(getRequestBody(options)),
      LogLevel.info,
      title: 'OpenAI请求',
      type: LogType.json,
    );

    String key = api.apiKey;
    String model = api.modelName;
    String url = api.url + '/chat/completions';
    final dioInstance = aihandler.dioInstance;

    // 构建请求数据
    Map<String, dynamic> requestData = {
      'model': model,
      ...getRequestBody(options),
      'stream': options.isStreaming,
    };

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
        },
        contentType: 'application/json; charset=utf-8',
      ),
      cancelToken: aihandler.cancelToken,
      data: requestData,
    );

    bool cot = false;
    aihandler.onGenerateStateChange('正在生成...');
    if (options.isStreaming) {
      await for (var chunk in aihandler.parseSseStream(rs, (json) {
        final delta = json['choices'][0]['delta'] as Map<String, dynamic>?;
        if (delta == null) return '';

        // 优先返回 reasoning_content（思维链），如果没有则返回 content
        final reasoningContent = delta['reasoning_content'] as String? ?? '';
        final content = delta['content'] as String? ?? '';

        String result = '';
        if (reasoningContent != '' && !cot) {
          result += '<think>';
          cot = true;
        }
        if (reasoningContent != '') {
          result += reasoningContent;
        }
        if (reasoningContent == '' && cot) {
          result += r'</think>';
          cot = false;
        }
        if (reasoningContent == '' && !cot) {
          result += content;
        }

        return result;
      })) {
        yield chunk;
      }
    } else {
      Map<String, dynamic> responseData = rs.data as Map<String, dynamic>;
      LogController.log(json.encode(responseData), LogLevel.info,
          type: LogType.json, title: "OpenAI响应");

      final message =
          responseData['choices'][0]['message'] as Map<String, dynamic>?;
      if (message == null) {
        yield '未发现可用消息';
        return;
      }

      // 优先返回 reasoning_content（思维链），如果没有则返回 content
      final reasoningContent = message['reasoning_content'] as String?;
      final content = message['content'] as String?;

      yield reasoningContent ?? content ?? '未发现可用消息';
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
