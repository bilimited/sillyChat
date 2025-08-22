import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';

class Chatfilesuffixmanager {
  static String fromChatMode(ChatMode mode) {
    switch (mode) {
      case ChatMode.auto:
        return 'chata';
      case ChatMode.group:
        return 'chatg';
      case ChatMode.manual:
        return 'chatm';
      default:
        return 'chata';
    }
  }

  static ChatMode toChatMode(String name) {
    if (name.endsWith('chata')) {
      return ChatMode.auto;
    } else if (name.endsWith('chatg')) {
      return ChatMode.group;
    } else if (name.endsWith('chatm')) {
      return ChatMode.manual;
    }
    return ChatMode.auto; // 默认返回
  }
}
