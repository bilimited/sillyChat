import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/entitys/ChatAIState.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/promptBuilder.dart';
import 'package:get/get.dart';
import '../models/chat_model.dart';

class ChatController extends GetxController {
  final RxList<ChatModel> chats = <ChatModel>[].obs;

  final String fileName = 'chats.json';

  final RxMap<int, ChatAIState> states = <int, ChatAIState>{}.obs;

  ChatAIState getAIState(int chatId) {
    if (!states.containsKey(chatId)) {
      {
        states[chatId] = ChatAIState(
            aihandler: Aihandler()
              ..onGenerateStateChange = (str) {
                states[chatId] = states[chatId]!.copyWith(GenerateState: str);
              });
      }
    }
    return states[chatId]!;
  }

  void setAIState(int chatId, ChatAIState state) {
    states[chatId] = state;
  }

  // 当前打开的聊天Id。只支持桌面端
  final RxInt currentChat = (-1).obs;

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

  // 默认聊天为：应用启动（PC端）、找不到聊天、创建群聊时使用的聊天对象
  Rx<ChatModel> defaultChat = ChatModel(
          id: -1,
          name: "新聊天",
          avatar: "",
          lastMessage: "聊天已创建",
          time: DateTime.now().toString(),
          messages: [],
          mode: ChatMode.auto
          // userId: Get.find<CharacterController>().myId
          )
      .obs;

  final CharacterController characterController = Get.find();

  static const int MAX_CHATS_PER_FILE = 15;
  final RxInt currentFileId = 1.obs;

  String getFileName(int fileId) {
    return 'chats_$fileId.json';
  }

  // 会在每次进入新聊天界面时调用。
  void resetDefaultChat() {
    defaultChat = ChatModel(
            id: -1,
            name: "新聊天",
            avatar: "",
            lastMessage: "聊天已创建",
            time: DateTime.now().toString(),
            messages: [],
            userId: null,
            // characterIds: [],
            mode: ChatMode.auto)
        .obs;
  }

  void updateDefaultChat({int? assistantId}) {
    if (assistantId != null) {
      defaultChat.value.assistantId = assistantId;
    }
    defaultChat.refresh();
  }

  // 保存临时聊天，返回聊天id
  ChatModel saveDefaultChat() {
    final newChat = defaultChat.value;
    newChat.id = DateTime.now().microsecond;
    newChat.time = DateTime.now().toString();
    newChat.characterIds = [
      if (newChat.userId != null)
        newChat.userId!
      else if (characterController.myId != null)
        characterController.myId!,
      if (newChat.assistantId != null) newChat.assistantId!,
    ];
    if (newChat.assistantId != null &&
        newChat.assistant.firstMessage != null &&
        newChat.assistant.firstMessage!.isNotEmpty) {
      newChat.messages = [
        MessageModel(
          id: DateTime.now().microsecondsSinceEpoch,
          content: newChat.assistant.firstMessage!,
          sender: newChat.assistantId!,
          time: DateTime.now(),
          alternativeContent: [null],
          role: MessageRole.assistant,
        )
      ];
    }

    addChat(newChat);
    resetDefaultChat();
    return newChat;
  }

  @override
  void onInit() {
    super.onInit();
    loadChats();
  }

  // 从本地加载聊天数据
  Future<void> loadChats() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final firstFile = File('${directory}/${getFileName(1)}');

      // 如果第一个分片文件不存在，尝试迁移旧数据
      if (!await firstFile.exists()) {
        await migrateOldData();
      }

      int maxFileId = 1;
      int totalChats = 0;

      while (true) {
        final file = File('${directory}/${getFileName(maxFileId)}');
        if (!await file.exists()) break;

        final String contents = await file.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        final List<ChatModel> fileChats = jsonList.map((json) {
          final chat = ChatModel.fromJson(json);
          chat.fileId = maxFileId; // 设置fileId
          return chat;
        }).toList();

        chats.addAll(fileChats);
        totalChats += fileChats.length;
        maxFileId++;
      }

      currentFileId.value = maxFileId - 1;

      chats.sort((chat1,chat2){
        return chat1.sortIndex - chat2.sortIndex;
      });

      if (totalChats > 0) {
        Get.snackbar('Chat Data Loaded',
            'Loaded $totalChats chats from ${maxFileId - 1} files',
            duration: Duration(seconds: 2), icon: Icon(Icons.done));
      }
    } catch (e) {
      print('加载聊天数据失败: $e');
      throw e;
    }
  }

  Future<void> migrateOldData() async {
    final directory = await Get.find<SettingController>().getVaultPath();
    final oldFile = File('${directory}/$fileName');

    if (await oldFile.exists()) {
      try {
        final String contents = await oldFile.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        final List<ChatModel> oldChats =
            jsonList.map((json) => ChatModel.fromJson(json)).toList();

        // 按MAX_CHATS_PER_FILE分组存储
        for (int i = 0; i < oldChats.length; i += MAX_CHATS_PER_FILE) {
          final fileId = (i ~/ MAX_CHATS_PER_FILE) + 1;
          final chatsForFile =
              oldChats.skip(i).take(MAX_CHATS_PER_FILE).toList();

          // 设置fileId
          for (var chat in chatsForFile) {
            chat.fileId = fileId;
          }

          // 保存到新文件
          final newFile = File('${directory}/${getFileName(fileId)}');
          final String jsonString = json.encode(
            chatsForFile.map((chat) => chat.toJson()).toList(),
          );
          await newFile.writeAsString(jsonString);
        }

        // 备份旧文件
        await oldFile.rename('${directory}/$fileName.bak');

        Get.snackbar('数据迁移完成', '旧数据已迁移到新的存储格式',
            duration: Duration(seconds: 2),
            icon: Icon(
              Icons.done_all,
            ));
      } catch (e) {
        print('数据迁移失败: $e');
      }
    }
  }

  /// 保存聊天数据到本地
  /// 
  /// [fileId] 要保存聊天的文件Id。所有FileId相同的聊天会保存在同一个文件里。
  Future<void> saveChats([int? fileId]) async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();

      if (fileId != null) {
        // 保存特定文件
        final targetChats =
            chats.where((chat) => chat.fileId == fileId).toList();
        final file = File('${directory}/${getFileName(fileId)}');
        final String jsonString = json.encode(
          targetChats.map((chat) => chat.toJson()).toList(),
        );
        await file.writeAsString(jsonString);
      } else {
        // 保存所有文件
        for (int i = 1; i <= currentFileId.value; i++) {
          final targetChats = chats.where((chat) => chat.fileId == i).toList();
          if (targetChats.isEmpty) continue;

          final file = File('${directory}/${getFileName(i)}');
          final String jsonString = json.encode(
            targetChats.map((chat) => chat.toJson()).toList(),
          );
          await file.writeAsString(jsonString);
        }
      }
    } catch (e) {
      print('保存聊天数据失败: $e');
      Get.snackbar('聊天数据保存失败', '$e');
      rethrow;
    }
  }

  Future<void> refleshAll() async {
    chats.refresh();
  }

  // 添加新聊天
  Future<void> addChat(ChatModel chat) async {
    // 检查当前文件是否已满
    int currentFileChatsCount =
        chats.where((c) => c.fileId == currentFileId.value).length;
    if (currentFileChatsCount >= MAX_CHATS_PER_FILE || currentFileId == 0) {
      currentFileId.value++;
    }

    chat.fileId = currentFileId.value;
    chats.add(chat);
    await saveChats(currentFileId.value);
  }

  // 更新聊天（只有一处引用:只能在updatedChat的fileId未初始化时使用）
  Future<void> updateChat(int id, ChatModel updatedChat) async {
    final index = chats.indexWhere((chat) => chat.id == id);
    if (index != -1) {
      int fileId = chats[index].fileId;

      updatedChat.fileId = fileId;
      chats[index] = updatedChat;
      await saveChats(fileId);
    }
  }

  // 删除聊天
  Future<void> deleteChat(int id) async {
    final chat = chats.firstWhere((chat) => chat.id == id);
    int fileId = chat.fileId;
    chats.removeWhere((chat) => chat.id == id);
    await saveChats(fileId);
  }

  // 根据名称获取聊天
  ChatModel getChatByName(String name) {
    return chats.firstWhereOrNull((chat) => chat.name == name) ??
        defaultChat.value;
  }

  ChatModel getChatById(int id) {
    return chats.firstWhereOrNull((chat) => chat.id == id) ?? defaultChat.value;
  }

  // 复制聊天（除messages和id外）
  ChatModel cloneChat(ChatModel original) {
    return original.deepCopyWith(
      id: DateTime.now().millisecondsSinceEpoch,
      lastMessage: "群聊已拷贝",
      time: DateTime.now().toString(),
      messages: [],
    );
  }

  // 在指定聊天中添加消息
  Future<void> addMessage(
      {required int chatId,
      required MessageModel message,
      String? lastMessage = null}) async {
    var chat = getChatById(chatId);
    if (chat != defaultChat) {
      chat.messages.add(message);
      chat.lastMessage = lastMessage != null ? lastMessage : message.content;
      chat.time = message.time.toString();
      chats.refresh();
      await saveChats(chat.fileId);
      print("AddMessage: ${message.content}");
    } else {
      print("Unknown chat!");
    }
  }

  // 在指定聊天中删除消息
  Future<void> removeMessage(int chatId, DateTime messageTime) async {
    final chat = getChatById(chatId);
    if (chat != defaultChat) {
      chat.messages.removeWhere((msg) => msg.time == messageTime);
      if (chat.messages.isNotEmpty) {
        final lastMsg = chat.messages.last;
        chat.lastMessage = lastMsg.content;
        chat.time = lastMsg.time.toString();
      }
      chats.refresh();
      await saveChats(chat.fileId);
    }
  }

  Future<void> addMessages(int chatId, List<MessageModel> messages) async {
    final chat = getChatById(chatId);
    if (chat != defaultChat) {
      chat.messages.addAll(messages);
      if (messages.isNotEmpty) {
        chat.lastMessage = messages.last.content;
        chat.time = messages.last.time.toString();
      }
      await saveChats(chat.fileId);
      chats.refresh();
    } else {
      print("Unknown chat!");
    }
  }

  Future<void> removeMessages(int chatId, List<MessageModel> messages) async {
    final chat = getChatById(chatId);
    if (chat != defaultChat) {
      chat.messages.removeWhere((msg) => messages.contains(msg));
      if (chat.messages.isNotEmpty) {
        final lastMsg = chat.messages.last;
        chat.lastMessage = lastMsg.content;
        chat.time = lastMsg.time.toString();
      }
      await saveChats(chat.fileId);
      chats.refresh();
    }
  }

  // 在指定聊天中更新消息
  Future<void> updateMessage(
      int chatId, DateTime messageTime, MessageModel updatedMessage) async {
    final chat = getChatById(chatId);
    if (chat != defaultChat) {
      final index = chat.messages.indexWhere((msg) => msg.time == messageTime);
      if (index != -1) {
        chat.messages[index] = updatedMessage;
        if (index == chat.messages.length - 1) {
          chat.lastMessage = updatedMessage.content;
          chat.time = updatedMessage.time.toString();
        }
        await saveChats(chat.fileId);
        chats.refresh();
      }
    }
  }

  // 获取角色相关的群聊
  List<ChatModel> getChatsByCharacterId(int characterId) {
    return chats
        .where((chat) => chat.characterIds.contains(characterId))
        .toList();
  }

  /// 发送信息方法
  /// 行为：创建一个新的消息插入该聊天；自动获取当前聊天默认assistant的回复
  Future<void> sendMessageAndGetReply(
      ChatModel chat, String text, List<String> selectedPath) async {
    if (text.isNotEmpty) {
      final message = MessageModel(
          id: DateTime.now().microsecondsSinceEpoch,
          content: text,
          sender: chat.user.id,
          time: DateTime.now(),
          type: MessageTypeExtension.fromMessageStyle(chat.user.messageStyle),
          role: MessageRole.user,
          alternativeContent: [null],
          resPath: selectedPath);

      await addMessage(chatId: chat.id, message: message);

      if (chat.mode == ChatMode.group) {
        return;
      } else if (chat.mode == ChatMode.auto) {
        await for (var content in _handleLLMMessage(chat,
            think: chat.requestOptions.isThinkMode)) {
          _handleAIResult(chat, content, chat.assistantId ?? -1);
        }
      } else {
        return;
      }
    }
  }

  void getGroupReply(ChatModel chat, CharacterModel sender) async {
    await for (var content in _handleLLMMessage(chat,
        sender: sender, think: chat.requestOptions.isThinkMode)) {
      _handleAIResult(chat, content, sender.id);
    }
  }

  // 重新发送ai请求（会自动追加在最新的AI回复后面。若无最新AI回复且为群聊模式，则不可用）（该方法未完成）
  Future<void> retry(ChatModel chat, {int index = 1}) async {
    final msgList = getChatById(chat.id).messages;

    // 获取需要重生成的消息
    int indexToRetry = msgList.length - index;
    if (indexToRetry < 0 ||
        index < 1 ||
        msgList.length == 0 ||
        chat.isChatNotCreated) {
      return;
    }
    MessageModel? message = msgList[indexToRetry];

    // 判断是重新生成，还是直接回复
    if (message.isAssistant) {
      removeMessage(chat.id, message.time);
    } else {
      message = null;
    }

    if (chat.mode == ChatMode.auto) {
      //
      await for (var content
          in _handleLLMMessage(chat, think: chat.requestOptions.isThinkMode)) {
        _handleAIResult(chat, content, chat.assistantId ?? -1,
            existedMessage: message);
      }
    } else if (chat.mode == ChatMode.group && message != null) {
      final CharacterController controller = Get.find();
      await for (var content in _handleLLMMessage(chat,
          sender: controller.getCharacterById(message.sender),
          think: chat.requestOptions.isThinkMode)) {
        _handleAIResult(chat, content, message.sender, existedMessage: message);
      }
    }
  }

  Future<void> _handleAIResult(ChatModel chat, String content, int senderID,
      {MessageModel? existedMessage}) async {
    List<String?> existedContent = [null];
    if (existedMessage != null) {
      int firstNull = existedMessage.alternativeContent.indexOf(null);
      existedMessage.alternativeContent[firstNull] = existedMessage.content;
      existedMessage.alternativeContent.add(null);
      existedContent = existedMessage.alternativeContent;
    }

    final AIMessage = MessageModel(
      id: DateTime.now().microsecondsSinceEpoch,
      content: content,
      sender: senderID,
      time: DateTime.now(),
      role: MessageRole.assistant,
      alternativeContent: existedContent,
    );
    await addMessage(chatId: chat.id, message: AIMessage);
  }

  // 按行分割功能:已弃用
  // 处理消息功能，默认为单聊
  Stream<String> _handleLLMMessage(ChatModel chat,
      {bool think = false, CharacterModel? sender = null}) async* {
    late LLMRequestOptions options;
    late List<LLMMessage> messages;

    messages = Promptbuilder().getLLMMessageList(chat, sender: sender);
    options = chat.requestOptions.copyWith(messages: messages);

    chat.setAIState(chat.aiState.copyWith(
        LLMBuffer: "",
        isGenerating: true,
        GenerateState: "正在激活世界书...",
        currentAssistant:
            sender == null ? (chat.assistantId ?? 0) : sender.id));

    await for (String token
        in chat.aiState.aihandler.requestTokenStream(options)) {
      final oldState = chat.aiState;
      chat.setAIState(oldState.copyWith(LLMBuffer: oldState.LLMBuffer + token));
      //LLMMessageBuffer.refresh();
    }

    chat.setAIState(chat.aiState.copyWith(isGenerating: false));
    yield _fixMessage(chat.aiState.LLMBuffer);
  }

  // 消除行首空格
  String _fixMessage(String content) {
    String result = "";
    for (String line in content.split('\n')) {
      if (line.startsWith('    ')) {
        result += line.replaceFirst(RegExp(r'^    +'), '') + '\n';
      } else {
        result += line + '\n';
      }
    }
    return result.trimRight();
  }

  void interrupt(ChatModel chat) {
    chat.setAIState(chat.aiState.copyWith(isGenerating: false));
    chat.aiState.aihandler.interrupt();
  }
}
