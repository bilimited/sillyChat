import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/widgets/other/compressed_message.dart';

class LLMRequestOptions {
  final List<LLMMessage> messages; // 消息记录
  final int maxTokens; // token上限
  final double temperature; // 温度参数
  final double topP; // 核采样参数
  final double presencePenalty; // 话题新鲜度惩罚
  final double frequencyPenalty; // 词频惩罚
  final int maxHistoryLength; // 历史消息长度上限
  final int apiId;
  final int seed;

  final bool isDeleteThinking; // 是否删除思考消息
  final bool isThinkMode; // 是否思考模式
  final bool isStreaming; // 是否流式响应

  final bool isMergeMessageList;
  final ChatCompressionSettings chatCompressionSettings;

  ApiModel? get api => VaultSettingController.of().getApiById(apiId);

  const LLMRequestOptions({
    required this.messages,
    this.maxTokens = 8000,
    this.temperature = 0.95,
    this.topP = 1.0,
    this.presencePenalty = 0.0,
    this.frequencyPenalty = 0.0,
    this.maxHistoryLength = 64,
    this.apiId = -1,
    this.isThinkMode = false,
    this.isDeleteThinking = true,
    this.seed = -1,
    this.isMergeMessageList = false,
    this.isStreaming = true,
    ChatCompressionSettings? chatCompressionSettings,
  }) : chatCompressionSettings = chatCompressionSettings ?? const ChatCompressionSettings();

  factory LLMRequestOptions.fromJson(Map<String, dynamic> json) {
    return LLMRequestOptions(
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((e) => LLMMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      maxTokens: json['max_tokens'] ?? 4000,
      temperature: json['temperature']?.toDouble() ?? 0.7,
      topP: json['top_p']?.toDouble() ?? 1.0,
      presencePenalty: json['presence_penalty']?.toDouble() ?? 0.0,
      frequencyPenalty: json['frequency_penalty']?.toDouble() ?? 0.0,
      maxHistoryLength: json['max_history_length'] ?? 10,
      apiId: json['api_id'] ?? 0,
      isDeleteThinking: json['is_delete_thinking'] ?? true,
      isThinkMode: json['is_think_mode'] ?? false,
      seed: json['seed'] ?? -1,
      isMergeMessageList: json['is_merge_message_list'] ?? false,
      isStreaming: json['is_streaming'] ?? true,
      chatCompressionSettings: json.containsKey('chat_compression_settings')
          ? ChatCompressionSettings.fromJson(json['chat_compression_settings'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'max_tokens': maxTokens,
      'temperature': temperature,
      'top_p': topP,
      'presence_penalty': presencePenalty,
      'frequency_penalty': frequencyPenalty,
      'max_history_length': maxHistoryLength,
      'api_id': apiId,
      'is_delete_thinking': isDeleteThinking,
      'is_think_mode': isThinkMode,
      'seed': seed,
      'is_merge_message_list': isMergeMessageList,
      'is_streaming': isStreaming,
      'chat_compression_settings': chatCompressionSettings.toJson(),
    };
  }

  LLMRequestOptions copyWith({
    List<LLMMessage>? messages,
    int? maxTokens,
    double? temperature,
    double? topP,
    double? presencePenalty,
    double? frequencyPenalty,
    int? maxHistoryLength,
    int? apiId,
    bool? isDeleteThinking,
    bool? isThinkMode,
    int? seed,
    bool? isMergeMessageList,
    bool? isStreaming,
    ChatCompressionSettings? chatCompressionSettings,
  }) {
    return LLMRequestOptions(
      messages: messages ?? this.messages,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      presencePenalty: presencePenalty ?? this.presencePenalty,
      frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
      maxHistoryLength: maxHistoryLength ?? this.maxHistoryLength,
      apiId: apiId ?? this.apiId,
      isDeleteThinking: isDeleteThinking ?? this.isDeleteThinking,
      isThinkMode: isThinkMode ?? this.isThinkMode,
      seed: seed ?? this.seed,
      isMergeMessageList: isMergeMessageList ?? this.isMergeMessageList,
      isStreaming: isStreaming ?? this.isStreaming,
      chatCompressionSettings: chatCompressionSettings ?? this.chatCompressionSettings,
    );
  }
}
