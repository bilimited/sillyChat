// 不同服务商API的模型名称和链接

import 'package:flutter_example/chat-app/models/api_model.dart';

class ApiData {
  final List<String> urls;

  final List<String> modelNames;

  const ApiData({
    required this.urls,
    required this.modelNames,
  });

  static List<String> getUrlsByService(ServiceProvider service) {
    return (datas[service])?.urls ?? [];
  }

  static List<String> getModelsByService(ServiceProvider service) {
    return (datas[service])?.modelNames ?? [];
  }

  static const datas = {
    ServiceProvider.deepseek: const ApiData(
      urls: [
        "https://api.deepseek.com/v1/chat/completions",
      ],
      modelNames: [
        "deepseek-chat-3.5",
        "deepseek-chat-4",
      ],
    ),
    ServiceProvider.google: const ApiData(
      urls: [
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash",
      ],
      modelNames: [
        "gemini-1.5-flash",
        "gemini-1.5-pro",
      ],
    ),
    // 以下api由AI生成，不保证能用...
    ServiceProvider.openai: const ApiData(
      urls: [
        "https://api.openai.com/v1/chat/completions",
        "https://api.openai.com/v1/completions",
      ],
      modelNames: [
        "gpt-3.5-turbo",
        "gpt-4",
        "gpt-4o",
      ],
    ),
  };
}
