import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';

abstract class AppEvent {}

class FileDeletedEvent extends AppEvent {
  final String filePath;

  FileDeletedEvent(this.filePath);
}

class FileCreatedEvent extends AppEvent {
  final String filePath;
  FileCreatedEvent(this.filePath);
}

enum MessageEventType {
  add,
  update,
  delete
}

class MessageEvent extends AppEvent {
  final MessageEventType type;
  final MessageModel message;
  final ChatModel chat;

  MessageEvent(this.message, this.chat, {this.type=MessageEventType.add});
}
