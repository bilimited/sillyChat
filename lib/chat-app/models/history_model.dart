class HistoryModel {
  final List<String> messageHistory;
  final List<String> commandHistory;

  // 最近打开聊天
  final List<String> chatHistory;

  HistoryModel({
    List<String>? messageHistory,
    List<String>? commandHistory,
    List<String>? chatHistory,
  })  : messageHistory = messageHistory ?? [],
        commandHistory = commandHistory ?? [],
        chatHistory = chatHistory ?? [];

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
    );
  }

  void addToChatHistory(String chatId) {
    chatHistory.remove(chatId); // 去重
    chatHistory.insert(0, chatId); // 插入到最前面
    // 保留最多 50 条记录
    if (chatHistory.length > 50) {
      chatHistory.removeRange(50, chatHistory.length);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'messageHistory': List<String>.from(messageHistory),
      'commandHistory': List<String>.from(commandHistory),
      'chatHistory': List<String>.from(chatHistory),
    };
  }

  HistoryModel copyWith({
    List<String>? messageHistory,
    List<String>? commandHistory,
    List<String>? chatHistory,
  }) {
    return HistoryModel(
      messageHistory: messageHistory ?? this.messageHistory,
      commandHistory: commandHistory ?? this.commandHistory,
      chatHistory: chatHistory ?? this.chatHistory,
    );
  }
}
