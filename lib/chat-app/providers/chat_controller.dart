import 'dart:convert';
import 'dart:io';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/entitys/ChatAIState.dart';
import 'package:flutter_example/chat-app/utils/promptFormatter.dart';
import 'package:get/get.dart';
import '../models/chat_model.dart';

// 聊天索引管理器
class ChatController extends GetxController {
  final RxList<ChatModel> chats = <ChatModel>[].obs;

  final String fileName = 'chats.json';

  // 聊天路径到聊天状态的映射表
  final RxMap<String, ChatAIState> states = <String, ChatAIState>{}.obs;

  ChatAIState getAIState(String path) {
    if (!states.containsKey(path)) {
      {
        states[path] = ChatAIState(
            aihandler: Aihandler()
              ..onGenerateStateChange = (str) {
                states[path] = states[path]!.copyWith(GenerateState: str);
              });
      }
    }
    return states[path]!;
  }

  void setAIState(String path, ChatAIState state) {
    states[path] = state;
  }

  // 当前打开的聊天
  final Rx<ChatSessionController?> currentChat = Rx(null);

  final RxList<MessageModel> messageClipboard = <MessageModel>[].obs;

  List<MessageModel> get messageToPaste {
    final now = DateTime.now();
    final messagesToPaste = messageClipboard.reversed
        .toList()
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(
              time: now.add(Duration(microseconds: entry.key + 1)),
              id: now.microsecondsSinceEpoch + entry.key + 1,
            ))
        .toList();
    return messagesToPaste;
  }

  final CharacterController characterController = Get.find();

  static const int MAX_CHATS_PER_FILE = 15;
  final RxInt currentFileId = 1.obs;

  @override
  void onInit() {
    super.onInit();
    //loadChats();
  }

  /// [path] 要创建聊天的绝对路径。不包含文件名。
  Future<void> createChat(ChatModel chat, String path) async {
    final fullPath = '$path/chat_${chat.id}.json';
    final file = File(fullPath);
    file.create(recursive: true);
    final String contents = json.encode(chat.toJson());
    chat.file = file;
    await file.writeAsString(contents);
  }

  Future<ChatModel> createChatFromCharacter(
      CharacterModel char, String path) async {
    final id = DateTime.now().microsecond;
    ChatModel chatModel = ChatModel(
        id: id,
        name: '${char.roleName}',
        avatar: char.avatar,
        lastMessage: '聊天已创建',
        time: DateTime.now().toString(),
        assistantId: char.id,
        messages: [],
        chatOptionId:
            Get.find<ChatOptionController>().chatOptions.elementAtOrNull(0)?.id)
      ..characterIds = [char.id];

    String formatMessage(String message) {
      return Promptformatter.formatPrompt(message, chatModel);
    }

    if (char.firstMessage != null && !char.firstMessage!.isEmpty)
      chatModel.messages.add(MessageModel(
          id: DateTime.now().microsecondsSinceEpoch,
          content: formatMessage(char.firstMessage!),
          sender: char.id,
          time: DateTime.now(),
          alternativeContent: [
            null,
            ...char.moreFirstMessage.map((msg) => formatMessage(msg))
          ]));
    await createChat(chatModel, path);

    return chatModel;
  }
}
