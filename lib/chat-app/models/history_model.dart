class HistoryModel {
  final List<String> messageHistory;
  final List<String> commandHistory;

  final List<int> characterHistory; // 最近选择角色的历史

  // 最近打开聊天
  final List<String> chatHistory;

  HistoryModel({
    List<String>? messageHistory,
    List<String>? commandHistory,
    List<String>? chatHistory,
    List<int>? characterHistory,
  })  : messageHistory = messageHistory ?? [],
        commandHistory = commandHistory ?? [],
        chatHistory = chatHistory ?? [],
        characterHistory = characterHistory ?? [];

  factory HistoryModel.fromJson(Map<String, dynamic> json) {
    return HistoryModel(
      messageHistory: json['messageHistory'] != null
          ? List<String>.from(json['messageHistory'])
          : [],
      commandHistory: json['commandHistory'] != null
          ? List<String>.from(json['commandHistory'])
          : [],
      chatHistory: json['chatHistory'] != null
          ? List<String>.from(json['chatHistory'])
          : [],
      characterHistory: json['characterHistory'] != null
          ? List<int>.from(json['characterHistory'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageHistory': List<String>.from(messageHistory),
      'commandHistory': List<String>.from(commandHistory),
      'chatHistory': List<String>.from(chatHistory),
      'characterHistory': List<int>.from(characterHistory),
    };
  }

  HistoryModel copyWith({
    List<String>? messageHistory,
    List<String>? commandHistory,
    List<String>? chatHistory,
    List<int>? characterHistory,
  }) {
    return HistoryModel(
      messageHistory: messageHistory ?? this.messageHistory,
      commandHistory: commandHistory ?? this.commandHistory,
      chatHistory: chatHistory ?? this.chatHistory,
      characterHistory: characterHistory ?? this.characterHistory,
    );
  }
}
