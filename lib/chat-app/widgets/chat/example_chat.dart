import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/widgets/chat/message_bubble.dart';
import 'package:get/get.dart';

class ExampleChat extends StatelessWidget {
  ExampleChat({super.key});

  final assistant = Get.find<CharacterController>().characters[0].id;
  int get user => 0;

  Widget _buildMessageBubble(
      ChatModel chat, MessageModel message, MessageModel? lastMessage,
      {int index = 0, bool isNarration = false}) {
    return MessageBubble(
        chat: chat,
        message: message,
        isSelected: false,
        onTap: () {},
        index: message.id,
        onLongPress: () {},
        buildBottomButtons: (p1, p2) => SizedBox.shrink(),
        onUpdateChat: () {});
  }

  @override
  Widget build(BuildContext context) {
    final exampleChat = ChatModel(
        id: 0,
        name: 'Example',
        avatar: '',
        lastMessage: 'lastMessage',
        time: 'enn',
        messages: [
          MessageModel(
              id: 1,
              content: '你在何处？',
              senderId: user,
              time: DateTime.now(),
              alternativeContent: [null]),
          MessageModel(
              id: 2,
              content:
                  '*一个纤弱的影子，在朦胧的月光中，轻盈地飘过古老的石板路。*"我在时间的长河里，在回忆的岸边。你呢，是哪阵风，将你吹到了这无人问津的角落？"',
              senderId: assistant,
              time: DateTime.now(),
              alternativeContent: [null]),
          MessageModel(
              id: 3,
              content: '我在寻你。',
              senderId: user,
              time: DateTime.now(),
              alternativeContent: [null]),
          MessageModel(
              id: 4,
              content:
                  '"世间万物皆有其时，为何独独寻我？ "*影子停下了脚步，转过身来，那双如同深海般的眼眸，凝视着你。*"我不过是一缕被遗忘的思绪，一朵早已凋零的花。"',
              senderId: assistant,
              time: DateTime.now(),
              alternativeContent: [null]),
          MessageModel(
              id: 5,
              content: '因为你是诗。',
              senderId: user,
              time: DateTime.now(),
              alternativeContent: [null]),
        ]);

    return Column(
      children: [
        ...exampleChat.messages.map((msg) {
          return _buildMessageBubble(exampleChat, msg, null);
        })
      ],
    );
  }
}
