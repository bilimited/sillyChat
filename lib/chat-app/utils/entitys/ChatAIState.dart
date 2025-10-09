import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';

/** TODO:本类意义不明，回头改一下 */
class ChatAIState {
  final String id;
  final String LLMBuffer;
  final String GenerateState;
  final bool isGenerating;
  final MessageStyle style;
  final int currentAssistant;
  final Aihandler aihandler;

  ChatAIState({
    this.id = "_",
    this.LLMBuffer = "",
    this.GenerateState = "",
    this.style = MessageStyle.common,
    this.isGenerating = false,
    this.currentAssistant = -1,
    required this.aihandler,
  });

  ChatAIState copyWith({
    String? LLMBuffer,
    String? GenerateState,
    bool? isGenerating,
    int? currentAssistant,
    MessageStyle? style,
  }) {
    return ChatAIState(
        LLMBuffer: LLMBuffer ?? this.LLMBuffer,
        GenerateState: GenerateState ?? this.GenerateState,
        isGenerating: isGenerating ?? this.isGenerating,
        currentAssistant: currentAssistant ?? this.currentAssistant,
        aihandler: this.aihandler,
        style: style ?? this.style);
  }
}
