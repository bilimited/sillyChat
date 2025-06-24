import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/utils/RequestOptions.dart';

class ChatOptionModel {
  int id = 0; // 新增：用于唯一标识每个ChatOptionModel
  String name;
  String messageTemplate = "{{msg}}";
  LLMRequestOptions requestOptions;
  List<PromptModel> prompts = []; // 新增：存储实际的PromptModel对象

  ChatOptionModel({
    required this.id, 
    required this.name,
    this.messageTemplate = "{{msg}}",
    required this.requestOptions,
    required this.prompts,
  });

  factory ChatOptionModel.fromJson(Map<String, dynamic> json) {
    return ChatOptionModel(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        messageTemplate: json['messageTemplate'] ?? "{{msg}}",
        requestOptions: json['requestOptions'] != null
            ? LLMRequestOptions.fromJson(json['requestOptions'])
            : const LLMRequestOptions(messages: []),
        prompts: ((json['prompts'] as List?)
                ?.map((e) => PromptModel.fromJson(e))
                .toList()) ??
            []);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'messageTemplate': messageTemplate,
        'requestOptions': requestOptions.toJson()
          ..addAll({'max_history_length': requestOptions.maxHistoryLength}),
        'prompts': prompts.map((p) => p.toJson()).toList(),
      };

  ChatOptionModel copyWith({
    int? id,
    String? name,
    String? messageTemplate,
    LLMRequestOptions? requestOptions,
    List<PromptModel>? prompts,
  }) {
    return ChatOptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      messageTemplate: messageTemplate ?? this.messageTemplate,
      requestOptions: requestOptions ?? this.requestOptions,
      prompts: prompts ?? this.prompts,
    );
  }
}
