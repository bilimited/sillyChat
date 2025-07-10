import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/providers/prompt_controller.dart';
import 'package:flutter_example/chat-app/utils/RequestOptions.dart';
import 'package:get/get.dart';

class ChatOptionModel {
  int id = 0; // 新增：用于唯一标识每个ChatOptionModel
  String name;
  String messageTemplate = "{{msg}}";
  LLMRequestOptions requestOptions;
  List<PromptModel> prompts = []; // 新增：存储实际的PromptModel对象
  // List<int> promptId = [];

  static List<PromptModel> getPromptsbyId(List<int> promptId) {
    final PromptController controller = Get.find();
    return promptId
        .map((p) {
          return controller.getPromptById(p) ?? null;
        })
        .nonNulls
        .toList();
  }

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
      prompts: json['prompts'] != null
          ? (json['prompts'] as List<dynamic>)
              .map((p) => PromptModel.fromJson(p as Map<String, dynamic>))
              .toList()
          : getPromptsbyId((json['promptId'] as List<dynamic>?)
                  ?.map((e) => e as int)
                  .toList() ??
              []), // 版本迁移用
    );
  }

  factory ChatOptionModel.empty() {
    return ChatOptionModel(
        id: 0,
        name: '空预设',
        requestOptions: LLMRequestOptions(messages: []),
        prompts: []);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'messageTemplate': messageTemplate,
        'requestOptions': requestOptions.toJson()
          ..addAll({'max_history_length': requestOptions.maxHistoryLength}),
        'prompts': prompts.map((p) => p.toJson()).toList(),
      };

  ChatOptionModel copyWith(
    bool isDeep, {
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
      requestOptions: requestOptions ??
          (isDeep ? this.requestOptions.copyWith() : this.requestOptions),
      prompts: prompts ??
          (isDeep ? this.prompts.map((p) => p.copy()).toList() : this.prompts),
      //promptId: prompts?.map((p) => p.id).toList() ?? this.promptId,
    );
  }
}
