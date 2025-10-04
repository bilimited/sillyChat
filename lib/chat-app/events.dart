import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';

abstract class AppEvent {}

class FileDeletedEvent extends AppEvent {
  final String filePath;

  FileDeletedEvent(this.filePath);
}

class NewMessageEvent extends AppEvent {
  final MessageModel message;
  final ChatModel chat;

  NewMessageEvent(this.message, this.chat);
}
