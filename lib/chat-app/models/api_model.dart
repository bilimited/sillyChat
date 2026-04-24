import 'package:flutter_example/chat-app/utils/service_handlers/ServiceHandlerFactory.dart';

enum ServiceType {
  custom_openai_compatible,
  openai,
  deepseek,
  siliconflow,
  kimi,
  google; // 若有多个google的API，会优先使用第一个的key。

  String toJson() => name;
  static ServiceType fromJson(String json) => values.byName(json);

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
  final ServiceType provider;
  final String? requestBody;

  final List<String> models;

  ApiModel({
    required this.id,
    required this.apiKey,
    required this.displayName,
    required this.modelName,
    required this.url,
    required this.provider,
    this.remarks,
    this.requestBody,
    this.models = const [],
  });

  factory ApiModel.fromJson(Map<String, dynamic> json) {
    return ApiModel(
        id: json['id'] as int,
        apiKey: json['apiKey'] as String,
        displayName: json['displayName'] as String? ?? '',
        modelName: json['modelName'] as String,
        url: json['url'] as String,
        provider: ServiceType.fromJson(json['provider'] ?? 'openai'),
        remarks: json['remarks'] as String?,
        requestBody: json['requestBody'] as String?,
        models: (json['models'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            []);
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
      'models': models,
    };
  }

  ApiModel copyWith({
    int? id,
    String? apiKey,
    String? modelName,
    String? url,
    ServiceType? provider,
    String? remarks,
    String? modelName_think,
    String? displayName, // displayName is not nullable, so we keep it as is
    String? requestBody,
    List<String>? models,
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
      models: models ?? this.models,
    );
  }

  @override
  String toString() {
    return 'ApiModel(apiKey: $apiKey, modelName: $modelName, url: $url, provider: ${provider.name}, remarks: $remarks)';
  }
}
