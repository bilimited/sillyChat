import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:dio/io.dart' show IOHttpClientAdapter;
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/error_handler.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandlerFactory.dart';
import 'package:get/get.dart';

/**
 * 用于维护一个同API之间的连接
 */
class Aihandler {
  static const bool enableSSE = true;
  static int _activeTaskCount = 0;

  void Function(String newState) onGenerateStateChange = (newStat) {};

  bool isInterrupt = false;
  bool isBusy = false;
  bool isError = false; // 用于测试上次生成中是否出错

  dio.Dio? dioInstance;
  //int token_used = 0;
  dio.CancelToken cancelToken = dio.CancelToken(); // 用于中断请求

  void interrupt() {
    isInterrupt = true;
    isBusy = false;

    cancelToken.cancel();
    onGenerateStateChange('生成已停止');
  }

  Future<void> onTaskStart() async {
    isBusy = true;
    _activeTaskCount++;

    if (_activeTaskCount == 1) {
      if (Platform.isAndroid) {
        if (await FlutterBackground.hasPermissions) {
          print("前台启动..");
          await FlutterBackground.enableBackgroundExecution();
        }
      }
    }
  }

  Future<void> onTaskEnd() async {
    isBusy = false;
    _activeTaskCount--;
    if (_activeTaskCount < 0) _activeTaskCount = 0;

    if (_activeTaskCount == 0) {
      if (Platform.isAndroid) {
        print("前台关闭..");
        await FlutterBackground.disableBackgroundExecution();
      }
    }
  }

  void initDio() {
    if (dioInstance == null) {
      print("正在创建新的Dio实例");
      //  一个连接最长保持4分钟，以加快Gemini响应速度
      // 注意：如果空闲时间过长某个中间网关可能会静默丢弃这个连接，导致一次连接超时
      dioInstance = dio.Dio();
      dioInstance!.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          // 默认就是 true，这里写出来只是为了演示
          client.idleTimeout = Duration(minutes: 4); // 可以在这里设置空闲保持时间
          return client;
        },
      );
    }
  }

  Future<void> request(
      void Function(String) callback, LLMRequestOptions options) async {
    await for (String token in requestTokenStream(options)) {
      callback(token);
    }
  }

  Stream<String> requestTest(String apiKey, String modelName, String url,
      ServiceProvider provider) async* {
    try {
      isInterrupt = false;
      isError = false;
      cancelToken = dio.CancelToken();

      if (isBusy) {
        return;
      } else {
        isBusy = true;
      }

      initDio();
      final handler = Servicehandlerfactory.getHandler(provider);

      await for (final token in handler.request(
          this,
          LLMRequestOptions(messages: [
            LLMMessage(
                content: '你好!收到这条信息后，请只回复一个"好"字，不要有任何多余的内容。', role: 'user')
          ], isStreaming: false),
          ApiModel(
              id: -1,
              apiKey: apiKey,
              displayName: '',
              modelName: modelName,
              url: url,
              provider: provider))) {
        yield token;
      }
    } on dio.DioException catch (e) {
      isError = true;
      onGenerateStateChange('生成已停止');
      if (dio.CancelToken.isCancel(e)) {
      } else {
        ErrorHandler.handleDioExpection(e, null);
      }
    } catch (e) {
      isError = true;
      Get.snackbar("发生错误", "$e", colorText: Colors.red);
      LogController.log("发生错误:$e", LogLevel.error);
    }
    isBusy = false;
  }

  Stream<String> requestTokenStream(LLMRequestOptions options) async* {
    try {
      isInterrupt = false;
      isError = false;
      cancelToken = dio.CancelToken();

      if (isBusy) {
        return;
      } else {
        //isBusy = true;
        await onTaskStart();
      }

      final VaultSettingController settingController = Get.find();
      final ApiModel? api = settingController.getApiById(options.apiId);
      if (api == null) {
        Get.snackbar("无可用API!", "请检查你是否已经配置了API");
        onGenerateStateChange('未选择API');
        isBusy = false;
        return;
      }
      initDio();
      final handler = Servicehandlerfactory.getHandler(api.provider);

      await for (final token in handler.request(this, options, api)) {
        yield token;
      }
    } on dio.DioException catch (e) {
      isError = true;
      onGenerateStateChange('生成已停止');
      if (dio.CancelToken.isCancel(e)) {
      } else {
        ErrorHandler.handleDioExpection(e, null, requestOptions: options);
      }
    } catch (e) {
      isError = true;
      Get.snackbar("发生错误", "$e", colorText: Colors.red);
      LogController.log("发生错误:$e", LogLevel.error);
    } finally {
      onTaskEnd();
    }
    //isBusy = false;
  }

  /***
   * 解析流式响应
   * 写的乱七八糟但是可以运行
   */
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
            throw Exception("SSE JSON解析错误: $line\n错误信息: $e");
            // LogController.log(
            //     "SSE JSON解析错误: $line\n错误信息: $e", LogLevel.warning);
            //continue;
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
          throw Exception("Google JSON解析错误: $currentBuffer\n错误信息: $e");
          // LogController.log(
          //     "Google JSON解析错误: $currentBuffer\n错误信息: $e", LogLevel.warning);
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
