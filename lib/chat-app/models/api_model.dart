import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandlerFactory.dart';

enum ServiceProvider {
  custom_openai_compatible,
  openai,
  deepseek,
  siliconflow,
  kimi,
  google; // 若有多个google的API，会优先使用第一个的key。

  String toJson() => name;
  static ServiceProvider fromJson(String json) => values.byName(json);

  @Deprecated('使用ServiceHandlerFactory')
  static const Map<ServiceProvider, Map<String, dynamic>> providerData = {
    ServiceProvider.custom_openai_compatible: {
      "localString": "自定义",
      "defaultUrl": "",
      "modelList": [],
    },
    ServiceProvider.openai: {
      "localString": "openai",
      "defaultUrl": "https://api.openai.com/v1/chat/completions",
      "modelListUrl": 'https://api.openai.com/v1/models',
      "modelList": [
        "gpt-3.5-turbo",
        "gpt-4",
        "gpt-4o",
      ],
    },
    ServiceProvider.deepseek: {
      "localString": "deepseek",
      "defaultUrl": "https://api.deepseek.com/chat/completions",
      "modelListUrl": "https://api.deepseek.com/models",
      "modelList": [
        'deepseek-chat',
        'deepseek-reasoner',
        'DeepSeek-V3-0324',
        'DeepSeek-R1-0528',
        'DeepSeek-V3',
        'DeepSeek-R1'
      ],
    },
    ServiceProvider.siliconflow: {
      "localString": "硅基流动",
      "defaultUrl": "https://api.siliconflow.cn/v1/chat/completions",
      "modelListUrl": "https://api.siliconflow.cn/v1/models",
      "modelList": [
        'deepseek-ai/DeepSeek-V3',
        'deepseek-ai/DeepSeek-R1',
        'Pro/deepseek-ai/DeepSeek-R1',
        'Pro/deepseek-ai/DeepSeek-V3',
        'Qwen/Qwen3-32B',
        'Qwen/Qwen3-30B-A3B',
        'Qwen/Qwen3-8B'
      ],
    },
    ServiceProvider.google: {
      "localString": "google",
      "modelListUrl": "https://api.siliconflow.cn/v1/models",
      "defaultUrl": "这个不需要填",
      "modelList": [
        "gemini-2.5-pro",
        "gemini-2.5-pro-preview-06-05",
        "gemini-2.5-pro-preview-05-06",
        "gemini-2.5-pro-preview-03-25",
        "gemini-2.5-pro-exp-03-25",
        "gemini-2.5-flash",
        "gemini-2.5-flash-preview-05-20",
        "gemini-2.5-flash-preview-04-17",
        "gemini-2.5-lite-preview-06-17",
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite",
        "gemini-1.5-flash",
        "gemini-1.5-flash-8b",
        "gemini-1.5-pro",
        "gemini-1.0-pro"
      ],
    },
  };

  @Deprecated('使用ServiceHandlerFactory')
  static findProviderByModelName(String modelName) {
    return providerData.entries
        .firstWhere(
          (entry) => entry.value["modelList"].contains(modelName),
          orElse: () => MapEntry(ServiceProvider.custom_openai_compatible, {}),
        )
        .key;
  }

  String toLocalString() => Servicehandlerfactory.getHandler(this).name;

  String get defaultUrl => Servicehandlerfactory.getHandler(this).baseUrl;

  List<String> get modelList => List<String>.from(
      Servicehandlerfactory.getHandler(this).defaultModelList);
}

class ApiModel {
  final int id;
  final String apiKey;
  final String displayName;
  final String modelName;
  final String url;
  final String? remarks;
  final ServiceProvider provider;
  final String? requestBody;

  ApiModel({
    required this.id,
    required this.apiKey,
    required this.displayName,
    required this.modelName,
    required this.url,
    required this.provider,
    this.remarks,
    this.requestBody,
  });

  factory ApiModel.fromJson(Map<String, dynamic> json) {
    return ApiModel(
      id: json['id'] as int,
      apiKey: json['apiKey'] as String,
      displayName: json['displayName'] as String? ?? '',
      modelName: json['modelName'] as String,
      url: json['url'] as String,
      provider: ServiceProvider.fromJson(json['provider'] ?? 'openai'),
      remarks: json['remarks'] as String?,
      requestBody: json['requestBody'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apiKey': apiKey,
      'displayName': displayName,
      'modelName': modelName,
      'url': url,
      'provider': provider.toJson(),
      'remarks': remarks,
      'requestBody': requestBody,
    };
  }

  ApiModel copyWith({
    int? id,
    String? apiKey,
    String? modelName,
    String? url,
    ServiceProvider? provider,
    String? remarks,
    String? modelName_think,
    String? displayName, // displayName is not nullable, so we keep it as is
    String? requestBody,
  }) {
    return ApiModel(
      id: id ?? this.id,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      url: url ?? this.url,
      provider: provider ?? this.provider,
      remarks: remarks ?? this.remarks,
      displayName: displayName ?? this.displayName,
      requestBody: requestBody ?? this.requestBody,
    );
  }

  @override
  String toString() {
    return 'ApiModel(apiKey: $apiKey, modelName: $modelName, url: $url, provider: ${provider.name}, remarks: $remarks)';
  }
}
