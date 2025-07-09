import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/handleSevereError.dart';
import 'package:flutter_example/chat-app/utils/llmMessage.dart';
import 'package:get/get.dart';
import '../models/chat_model.dart';

class ChatController extends GetxController {
  final RxList<ChatModel> chats = <ChatModel>[].obs;

  final String fileName = 'chats.json';

  // 与AI有关的状态变量
  final RxString LLMMessageBuffer = "".obs;
  final RxBool isLLMGenerating = false.obs;
  final RxInt currentAssistant = 0.obs;

  // 仅桌面端：当前打开的聊天Id。
  final RxInt desktop_currentChat = (-1).obs;

  final chatAIHandler = Aihandler();

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
            userId: characterController.myId,
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
      if (newChat.userId != null) newChat.userId!,
      if (newChat.assistantId != null) newChat.assistantId!,
    ]; // TODO:处理群聊初始化的情况
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
      handleSevereError('Save Failed!', e);
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

  String propressMessage(String content, LLMRequestOptions options,
      {bool isGroupMode = false}) {
    // 处理消息内容，删除thinking标记
    if (options.isDeleteThinking) {
      content =
          content.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
    }
    return content;
  }

  // sender!=null ,则为群聊模式
  List<LLMMessage> getLLMMessageList(ChatModel chat, {CharacterModel? sender}) {
    var sysPrompts = chat.prompts
        .where((prompt) => prompt.isEnable)
        .map((prompt) => LLMMessage(
              content: prompt.getContent(chat, sender: sender),
              role: prompt.role,
              priority: prompt.priority ?? 99999,
              isPrompt: true,
            ))
        .toList();

    int maxMsgs = chat.requestOptions.maxHistoryLength;
    final int total = chat.messages.length;
    final int start = total > maxMsgs ? total - maxMsgs : 0;
    final pinnedIndexes = <int>{};
    final hiddenIndexs = <int>{};
    for (int i = 0; i < chat.messages.length; i++) {
      if (chat.messages[i].isPinned == true) {
        pinnedIndexes.add(i);
      } else if (chat.messages[i].isHidden == true) {
        hiddenIndexs.add(i);
      }
    }

    // 需要保留的消息索引：末尾maxMsgs条+所有pinned-所有hidden
    final keepIndexes = <int>{
      ...List.generate(total - start, (i) => start + i),
      ...pinnedIndexes
    }..removeAll(hiddenIndexs);

    // 计算priority，使最后一条消息priority为0，倒数第二条为1，依此类推
    final msgIndexes = List.generate(chat.messages.length, (i) => i)
        .where((i) => keepIndexes.contains(i))
        .toList();
    final msglst = [
      ...sysPrompts,
      ...msgIndexes.map((i) {
        final msg = chat.messages[i];
        final content = propressMessage(msg.content, chat.requestOptions);
        int priority = msgIndexes.length - 1 - msgIndexes.indexOf(i); // 最后一条为0
        if (sender == null) {
          return LLMMessage(
            content: content,
            role: msg.isAssistant ? "assistant" : "user",
            fileDirs: msg.resPath,
            priority: priority,
          );
        } else {
          return LLMMessage(
              content: msg.sender == sender.id
                  ? content
                  : "${characterController.getCharacterById(msg.sender).roleName}:\n${content}",
              role: msg.sender == sender.id ? "assistant" : "user",
              fileDirs: msg.resPath,
              priority: priority);
        }
      })
    ];

    // 按priority升序排序，priority相同则sysPrompts更靠后（稳定排序）
    msglst.sort((b, a) {
      if (a.priority != b.priority) {
        return a.priority.compareTo(b.priority);
      }
      if (a.isPrompt == b.isPrompt) return 0;
      return a.isPrompt ? -1 : 1; // sysPrompts更靠后
    });

    // 修正最后一条消息内容
    // if (msglst.isNotEmpty) {
    //   final last = msglst.last;
    //   final fixedContent =
    //       chat.messageTemplate.replaceAll('{{msg}}', last.content);
    //   if (sender != null) {
    //     // 强制修正发言者；防止人名重复出现
    //     msglst[msglst.length - 1] = LLMMessage(
    //       content: "$fixedContent\n${sender.roleName}:",
    //       role: last.role,
    //       fileDirs: last.fileDirs,
    //     );
    //   } else {
    //     msglst[msglst.length - 1] = LLMMessage(
    //       content: fixedContent,
    //       role: last.role,
    //       fileDirs: last.fileDirs,
    //     );
    //   }
    // }
    // if (sender == null && msglst.isNotEmpty && msglst.last.role != 'user') {
    //   msglst.add(LLMMessage(
    //     content: '请接着刚才的话题继续。',
    //     role: 'user',
    //   ));
    // }
    return msglst;
  }

  // 按行分割功能:已弃用
  // 处理消息功能，默认为单聊
  Stream<String> handleLLMMessage(ChatModel chat,
      {bool think = false, CharacterModel? sender = null}) async* {
    LLMMessageBuffer.value = "";
    isLLMGenerating.value = true;
    late LLMRequestOptions options;
    late List<LLMMessage> messages;

    currentAssistant.value =
        sender == null ? (chat.assistantId ?? 0) : sender.id;
    messages = getLLMMessageList(chat, sender: sender);
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
