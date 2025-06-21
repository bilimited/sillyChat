import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/RequestOptions.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:get/get.dart';

class RequestOptions {}

class Aihandler {
  // 默认API已禁用
  static const String API_URL = "";
  static const String API_KEY = "";
  static const String MODEL_NAME = "";

  bool isInterrupt = false;
  bool isBusy = false;
  Dio? dio;
  int token_used = 0;

  void interrupt() {
    isInterrupt = true;
    isBusy = false;
    if (dio != null) {
      dio!.close(force: true);
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
      if (api.provider == ServiceProvider.openai) {
        await for (final token in requestOpenAI(options, api)) {
          print("Token:$token");
          yield token;
        }
        // yield* requestOpenAI(options, api); yield* 会导致异常无法正常被catch
      } else if (api.provider == ServiceProvider.google) {
        // 谷歌接口
        await for (final token in requestGoogle(options, api)) {
          yield token;
        }
      } else if (api.provider == ServiceProvider.deepseek) {
        // DeepSeek接口（主要区别：可切换思考模式）
        String? overriteModelName = api.modelName;
        if (options.isThinkMode && api.modelName_think.isNotEmpty) {
          overriteModelName = api.modelName_think;
        }
        await for (final token in requestOpenAI(options, api, overriteModelName: overriteModelName)) {
          yield token;
        }
      }
    } catch (e) {
      Get.snackbar("发生错误", "$e", colorText: Colors.red);
      LogController.log("发生错误:$e", LogLevel.error);
    }
    isBusy = false;
    if (dio != null) {
      dio!.close();
      dio = null;
    }
  }

  Stream<String> requestOpenAI(LLMRequestOptions options, ApiModel api,
      {String? overriteModelName}) async* {
    try {
      String key = api.apiKey;
      String model = overriteModelName ?? api.modelName;
      String url = api.url;

      dio = Dio();
      final rs = await dio!.post(
        url,
        options: Options(
          responseType: ResponseType.stream,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 180),
          headers: {
            'Authorization': 'Bearer ' + key,
          },
          contentType: 'application/json; charset=utf-8',
        ),
        data: {
          'model': model,
          ...options.toJson(),
          'stream': true,
        },
      );

      String buffer = ''; // 用于存储未完成的JSON数据
      await for (var data in rs.data.stream) {
        final bytes = data as List<int>;
        final decodedData = utf8.decode(bytes);

        // 将新数据添加到缓冲区
        buffer += decodedData;

        // 处理所有完整的数据行
        while (buffer.contains('\n')) {
          var index = buffer.indexOf('\n');
          var line = buffer.substring(0, index).trim();
          buffer = buffer.substring(index + 1);

          if (line.startsWith('data: ')) {
            line = line.substring(6);

            if (line == '[DONE]') break;
            if (line.isEmpty) continue;

            try {
              final json = jsonDecode(line);
              final content =
                  json['choices'][0]['delta']['content'] as String? ?? '';
              final finishReason = json['choices'][0]['finish_reason'] ?? '';

              if (json['usage']?['completion_tokens'] != null) {
                token_used = json['usage']['completion_tokens'] as int;
              }

              if (content.isNotEmpty) {
                yield content;
              }

              if (finishReason == 'stop') {
                break;
              }
            } catch (e) {
              LogController.log("JSON解析错误: $line\n错误信息: $e", LogLevel.warning);
              continue;
            }
          }
        }

        if (isInterrupt) break;
      }
    } catch (e) {
      throw e;
    }
  }

  Stream<String> requestGoogle(LLMRequestOptions options, ApiModel api) async* {
    Gemini.reInitialize(apiKey: api.apiKey);

    List<Content> chats = [];
    for (final msg in options.messages) {
      chats.add(Content(
        parts: [Part.text(msg['content'] ?? '')],
        role:
            msg['role'] == 'assistant' ? 'model' : 'user', // gemini只有user和model
      ));
    }
    await for (final token in Gemini.instance
        .streamChat(chats,
            generationConfig: GenerationConfig(
                maxOutputTokens: options.maxTokens,
                temperature: options.temperature,
                topP: options.topP),
            modelName: (api.modelName.isBlank == null || api.modelName.isBlank!)
                ? null
                : api.modelName)
        .asyncMap((val) => val.output ?? '')) {
      yield token;
    }
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
