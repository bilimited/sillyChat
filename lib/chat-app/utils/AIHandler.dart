import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandlerFactory.dart';
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
      onGenerateStateChange('生成已停止');
      if (dio.CancelToken.isCancel(e)) {
      } else {
        Get.snackbar("发生错误", "$e", colorText: Colors.red);
        LogController.log("发生错误:$e", LogLevel.error);
      }
    } catch (e) {
      Get.snackbar("发生错误", "$e", colorText: Colors.red);
      LogController.log("发生错误:$e", LogLevel.error);
    }
    isBusy = false;
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
}
