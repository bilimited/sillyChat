import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/RequestOptions.dart';
import 'package:get/get.dart';
import '../models/chat_model.dart';

class ChatController extends GetxController {
  final RxList<ChatModel> chats = <ChatModel>[].obs;
  final RxString LLMMessageBuffer = "".obs;
  final RxString LLMThinkBuffer = "".obs;
  final String fileName = 'chats.json';

  final RxBool isLLMGenerating = false.obs;
  final RxInt currentAssistant = 0.obs;

  final chatAIHandler = Aihandler();

  final ChatModel defaultChat = ChatModel(
    id: -1,
    name: "ERROR!",
    avatar: "",
    lastMessage: "ERROR!!!",
    time: "Error!!",
    messages: [],
  );

  final CharacterController characterController = Get.find();

  static const int MAX_CHATS_PER_FILE = 15;
  final RxInt currentFileId = 1.obs;

  String getFileName(int fileId) {
    return 'chats_$fileId.json';
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

  // 保存聊天数据到本地
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
    return chats.firstWhereOrNull((chat) => chat.name == name) ?? defaultChat;
  }

  ChatModel getChatById(int id) {
    return chats.firstWhereOrNull((chat) => chat.id == id) ?? defaultChat;
  }

  // 复制聊天（除messages和id外）
  ChatModel cloneChat(ChatModel original) {
    return ChatModel(
      id: DateTime.now().millisecondsSinceEpoch,
      name: original.name,
      avatar: original.avatar,
      lastMessage: "群聊已拷贝",
      time: DateTime.now().toString(),
      messages: [],
      characterIds: List.from(original.characterIds),
      prompts: List.from(original.prompts.map((prompt) => prompt.copy())),
      requestOptions: original.requestOptions.copyWith(),
      assistantId: original.assistantId,
      userId: original.userId,
      backgroundImage: original.backgroundImage,
      description: original.description,
      mode: original.mode,
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
      await saveChats();
      print("AddMessage: ${message.content}");
      chats.refresh();
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
      await saveChats();
      chats.refresh();
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
      await saveChats();
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
      await saveChats();
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
        await saveChats();
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

  List<Map<String, String>> getLLMMessageList(ChatModel chat) {
    var sysPrompts = chat.prompts.map((prompt) => {
          "role": prompt.role,
          "content": prompt.getContent(chat),
        });
    int maxMsgs = chat.requestOptions.maxHistoryLength;
    bool isDeleteThinking = chat.requestOptions.isDeleteThinking;
    final msglst = [
      ...sysPrompts,
      ...chat.messages
          .skip(chat.messages.length > maxMsgs
              ? chat.messages.length - maxMsgs
              : 0)
          .map((msg) {
        
        return {
          "role": msg.isAssistant ? "assistant" : "user",
          "content": isDeleteThinking
              ? msg.content
                  .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
              : msg.content
        };
      })
    ];
    print(msglst);
    if (msglst.length > 0) {
      msglst.last['content'] =
          chat.messageTemplate.replaceAll('{{msg}}', msglst.last['content']!);
    }

    return msglst;
  }

  List<Map<String, String>> getGroupMessageList(
      ChatModel chat, CharacterModel sender) {
    var sysPrompts = chat.prompts.map((prompt) => {
          "role": prompt.role,
          "content": prompt.getContent(chat, sender: sender),
        });
    int maxMsgs = chat.requestOptions.maxHistoryLength;
    bool isDeleteThinking = chat.requestOptions.isDeleteThinking;
    final msglst = [
      ...sysPrompts,
      ...chat.messages
          .skip(chat.messages.length > maxMsgs
              ? chat.messages.length - maxMsgs
              : 0)
          .map((msg) {
        final content = isDeleteThinking
            ? msg.content
                .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
            : msg.content;
        return {
          "role": msg.sender == sender.id ? "assistant" : "user",
          "content": msg.sender == sender.id
              ? content
              : "${characterController.getCharacterById(msg.sender).name}:\n${content}"
        };
      })
    ];
    if (msglst.length > 0) {
      msglst.last['content'] =
          chat.messageTemplate.replaceAll('{{msg}}', msglst.last['content']!);
      // 强制修正发言者；防止人名重复出现
      msglst.last['content'] = "${msglst.last['content']}\n${sender.name}:";
    }
    return msglst;
  }

  // 按行分割功能:已弃用
  // 处理消息功能，默认为单聊
  Stream<String> handleLLMMessage(ChatModel chat,
      {bool think = false, CharacterModel? sender = null}) async* {
    LLMMessageBuffer.value = "";
    isLLMGenerating.value = true;
    late LLMRequestOptions options;
    late List<Map<String, String>> messages;
    if (sender == null) {
      currentAssistant.value = chat.assistantId ?? 0;
      sender = (Get.find<CharacterController>())
          .getCharacterById(currentAssistant.value);
      messages = getLLMMessageList(chat);
      // options = chat.requestOptions.copyWith(messages: );
    } else {
      currentAssistant.value = sender.id;
      messages = getGroupMessageList(chat, sender);
      // options = chat.requestOptions
      //     .copyWith(messages: getGroupMessageList(chat, sender));
    }
    options = chat.requestOptions.copyWith(messages: messages);

    await for (String token in chatAIHandler.requestTokenStream(options)) {
      LLMMessageBuffer.value += token;
      LLMMessageBuffer.refresh();
    }
    isLLMGenerating.value = false;
    yield fixMessage(LLMMessageBuffer.value);
  }

  // 消除行首空格
  String fixMessage(String content) {
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

  void interrupt() {
    // chatAIHandler.isInterrupt = true;
    // if(chatAIHandler.dio!=null){
    //   chatAIHandler.dio!.close(force: true);
    // }
    chatAIHandler.interrupt();

    isLLMGenerating.value = false;
  }
}
