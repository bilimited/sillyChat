import 'package:flutter_example/chat-app/utils/AIHandler.dart';

class ChatAIState{
  
  final String LLMBuffer;
  final String GenerateState;
  final bool isGenerating;
  final int currentAssistant;
  final Aihandler aihandler;

  ChatAIState({
    this.LLMBuffer = "",
    this.GenerateState = "",
    this.isGenerating = false,
    this.currentAssistant = -1,
    required this.aihandler,
  });

  ChatAIState copyWith({
    String? LLMBuffer,
    String? GenerateState,
    bool? isGenerating,
    int? currentAssistant,
  }) {
    return ChatAIState(
      LLMBuffer: LLMBuffer ?? this.LLMBuffer,
      GenerateState: GenerateState ?? this.GenerateState,
      isGenerating: isGenerating ?? this.isGenerating,
      currentAssistant: currentAssistant ?? this.currentAssistant,
      aihandler: this.aihandler,
    );
  }

}