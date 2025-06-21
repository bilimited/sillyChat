enum ServiceProvider {
  openai,
  deepseek,
  google; // 若有多个google的API，会优先使用第一个的key。

  String toJson() => name;
  static ServiceProvider fromJson(String json) => values.byName(json);
}

class ApiModel {
  final int id;
  final String apiKey;
  final String displayName;
  final String modelName;
  final String modelName_think;
  final String url;
  final String? remarks;
  final ServiceProvider provider;

  ApiModel({
    required this.id,
    required this.apiKey,
    required this.displayName,
    required this.modelName,
    required this.url,
    required this.provider,
    this.remarks,
    this.modelName_think = '',
  });

  factory ApiModel.fromJson(Map<String, dynamic> json) {
    return ApiModel(
      id: json['id'] as int,
      apiKey: json['apiKey'] as String,
      displayName: json['displayName'] as String? ?? '',
      modelName: json['modelName'] as String,
      url: json['url'] as String,
      provider: ServiceProvider.fromJson(json['provider']??'openai' as String),
      remarks: json['remarks'] as String?,
      modelName_think: json['modelName_think'] as String? ?? '',
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
      'modelName_think': modelName_think,
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
  }) {
    return ApiModel(
      id: id ?? this.id,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      url: url ?? this.url,
      provider: provider ?? this.provider,
      remarks: remarks ?? this.remarks,
      modelName_think: modelName_think ?? this.modelName_think,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  String toString() {
    return 'ApiModel(apiKey: $apiKey, modelName: $modelName, url: $url, provider: ${provider.name}, remarks: $remarks)';
  }
}
