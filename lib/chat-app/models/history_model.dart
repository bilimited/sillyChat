class HistoryModel {
  final List<String> messageHistory;
  final List<String> commandHistory;

  HistoryModel({
    List<String>? messageHistory,
    List<String>? commandHistory,
  })  : messageHistory = List.unmodifiable(messageHistory ?? const []),
        commandHistory = List.unmodifiable(commandHistory ?? const []);

  factory HistoryModel.fromJson(Map<String, dynamic> json) {
    return HistoryModel(
      messageHistory: json['messageHistory'] != null
          ? List<String>.from(json['messageHistory'])
          : const [],
      commandHistory: json['commandHistory'] != null
          ? List<String>.from(json['commandHistory'])
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageHistory': List<String>.from(messageHistory),
      'commandHistory': List<String>.from(commandHistory),
    };
  }

  HistoryModel copyWith({
    List<String>? messageHistory,
    List<String>? commandHistory,
  }) {
    return HistoryModel(
      messageHistory: messageHistory ?? this.messageHistory,
      commandHistory: commandHistory ?? this.commandHistory,
    );
  }
}
