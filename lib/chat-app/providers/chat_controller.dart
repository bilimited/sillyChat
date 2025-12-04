// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/events.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/FileUtils.dart';
import 'package:flutter_example/chat-app/utils/promptFormatter.dart';
import 'package:get/get.dart';
import '../models/chat_model.dart';

import 'package:path/path.dart' as p;

// 聊天索引和聊天文件综合管理器
// TODO:把关于聊天的文件操作都塞到这里。
class ChatController extends GetxController {
  final RxList<ChatModel> chats = <ChatModel>[].obs;

  final String fileName = 'chats.json';

  // 当前打开的聊天
  // TODO: 当前打开聊天被删除时，清除当前聊天
  final Rx<ChatSessionController?> currentChat = Rx(null);
  final PageController pageController = PageController(initialPage: 0);

  // 当前打开的聊天数据路径，若为空则视为聊天根目录
  final RxString currentPath = ''.obs;

  final Rx<FileDeletedEvent?> fileDeleteEvent = Rx(null);
  final Rx<FileCreatedEvent?> fileCreateEvent = Rx(null);

  final RxList<MessageModel> messageClipboard = <MessageModel>[].obs;

  final RxBool isMultiSelecting = false.obs;

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

  // 新增：聊天元数据索引
  final RxMap<String, ChatMetaModel> chatIndex = <String, ChatMetaModel>{}.obs;
  final String chatIndexFileName = 'chat_index.json';

  // 已打开的聊天
  final RxMap<String, ChatSessionController?> openedChat =
      <String, ChatSessionController>{}.obs;

  bool get atFirstPage => pageController.page == 0;
  bool get atSecondPage => pageController.page == 1;

  void fireDeleteEvent(String path) {
    fileDeleteEvent.value = FileDeletedEvent(path);
    fileDeleteEvent.refresh();
  }

  @override
  void onInit() async {
    super.onInit();

    loadChatIndex();
  }

  /// ----迁移用
  @Deprecated('仅迁移用')
  String getFileName(int fileId) {
    return 'chats_$fileId.json';
  }

  @Deprecated('仅迁移用')
  final RxInt currentFileId = 1.obs;

  @Deprecated('仅迁移用')
  Future<void> loadChats() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final firstFile = File('${directory}/${getFileName(1)}');

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
    } catch (e) {
      print('加载聊天数据失败: $e');
      throw e;
    }
  }

  Future<void> debug_moveAllChats() async {
    final directory = await Get.find<SettingController>().getVaultPath();
    if (chats.isEmpty) {
      Get.snackbar('迁移失败', '没有旧版本数据');
      return;
    }

    for (final chat in chats) {
      final f = await createUniqueFile(
          originalPath: '${directory}/chats/${chat.name}.chat',
          recursive: true);
      await f.writeAsString(json.encode(chat.toJson()));
    }

    Get.snackbar('迁移成功!', 'message');
  }

  // 加载聊天索引
  Future<void> loadChatIndex() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$chatIndexFileName');
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final Map<String, dynamic> jsonList = json.decode(contents);
        jsonList.forEach((key, json) {
          chatIndex[key] = ChatMetaModel.fromJson(json);
        });
      } else {}
    } catch (e) {
      print('加载聊天索引失败: $e');
    }
  }

  // 保存聊天索引
  Future<void> saveChatIndex() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$chatIndexFileName');
      final Map<String, dynamic> jsonList = {};
      chatIndex.forEach((key, chatMeta) {
        jsonList[key] = chatMeta.toJson();
      });
      final String jsonString = json.encode(jsonList);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('保存聊天索引失败: $e');
    }
  }

  // 更新一条聊天索引，用于在保存聊天的同时调用
  Future<void> updateChatMeta(String path, ChatMetaModel chatMeta) async {
    chatIndex[p.normalize(path)] = chatMeta;
    //chatIndex.assign(path, chatMeta);
    await saveChatIndex();
  }

  Future<List<ChatMetaModel>> getAllChatTemplate() async {
    final directory = await Get.find<SettingController>().getVaultPath();
    final path = p.join(directory, 'chats', 'templates');
    List<ChatMetaModel> metas = [];

    try {
      final dir = Directory(path);
      if (!await dir.exists()) return [];

      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && Fileutils.isChatFile(entity.path)) {
          final filePath = entity.path;

          if (getIndex(entity.path) == null) {
            final meta = await buildIndex(entity.path);
            if (meta != null) {
              metas.add(meta);
            }
          } else {
            metas.add(getIndex(entity.path)!);
          }
        }
      }
    } catch (e) {
      print('扫描模板目录失败: $e');
    }
    return metas;
  }

  ChatMetaModel? getIndex(String _path) {
    final meta = chatIndex[p.normalize(_path)];
    return meta?.copyWith(path: p.normalize(_path));
  }

  // 构建一条聊天索引，用于在初次加载一个聊天时使用
  Future<ChatMetaModel?> buildIndex(String _path) async {
    final path = p.normalize(_path);
    try {
      final file = File(path);
      final content = await file.readAsString();
      final chat = ChatModel.fromJson(json.decode(content));

      chatIndex[path] = ChatMetaModel.fromChatModel(chat);

      saveChatIndex();
      return chatIndex[path];
    } catch (e) {
      rethrow;
      return null;
    }
  }

  // 新增：删除聊天元数据
  Future<void> deleteChatMetaByPath(String _path) async {
    final path = p.normalize(_path);
    chatIndex.remove(path);
    await saveChatIndex();
  }

  /// [path] 要创建聊天的绝对路径。不包含文件名。
  /// TODO:添加事件监听实现自动更新聊天列表
  Future<String> createChat(ChatModel chat, String path) async {
    final fullPath =
        p.join(path, '${chat.name}-${DateTime.now().hashCode}.chat');
    //'$path\\${chat.name}-${DateTime.now().hashCode}.chat';

    final file =
        await createUniqueFile(originalPath: fullPath, recursive: true);

    chat.needAutoTitle =
        VaultSettingController.of().miscSetting.value.autoTitle_enabled;
    final String contents = json.encode(chat.toJson());
    chat.file = file;

    await file.writeAsString(contents);

    // 启用自动标题

    // 新增：创建聊天后，同步更新聊天元数据索引
    final chatMeta = ChatMetaModel.fromChatModel(chat);
    await updateChatMeta(fullPath, chatMeta);
    fileCreateEvent.value = FileCreatedEvent(fullPath);
    return fullPath;
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
          senderId: char.id,
          time: DateTime.now(),
          alternativeContent: [
            null,
            ...char.moreFirstMessage.map((msg) => formatMessage(msg))
          ]));
    await createChat(chatModel, path);

    return chatModel;
  }

  Future<ChatModel> createQuickChat(String path) async {
    final id = DateTime.now().microsecond;
    ChatModel chatModel = ChatModel(
        id: id,
        name: '快速聊天',
        avatar: '',
        lastMessage: '聊天已创建',
        time: DateTime.now().toString(),
        assistantId: -1,
        messages: [],
        chatOptionId: Get.find<ChatOptionController>()
            .chatOptions
            .elementAtOrNull(0)
            ?.id);

    await createChat(chatModel, path);

    return chatModel;
  }

  static ChatController get of => Get.find<ChatController>();

  Future<File> createUniqueFile({
    required String originalPath,
    bool recursive = true,
  }) async {
    // 从原始路径创建一个文件对象
    File file = File(originalPath);

    // 检查文件是否已存在
    if (!await file.exists()) {
      // 如果文件不存在，直接创建并返回
      return file.create(recursive: recursive);
    }

    // 获取文件所在的目录、文件名和扩展名
    final directory = p.dirname(originalPath);
    final baseName = p.basenameWithoutExtension(originalPath);
    final extension = p.extension(originalPath);

    // 准备计数器，从 2 开始
    int counter = 2;
    late File newFile;

    // 进入循环，直到找到一个不重复的文件名
    do {
      // 构建新的文件名，例如 "filename(2).txt"
      final newFileName = '$baseName($counter)$extension';
      // 构建新的完整路径
      final newPath = p.join(directory, newFileName);

      // 创建一个新的文件对象
      newFile = File(newPath);

      // 检查这个新文件是否存在
      if (!await newFile.exists()) {
        // 如果不存在，跳出循环
        break;
      }

      // 如果存在，计数器加一，继续下一次尝试
      counter++;
    } while (true);

    // 创建并返回找到的唯一文件
    return newFile.create(recursive: recursive);
  }

  void putMessageToClipboard(
      List<MessageModel> originalMessages, List<MessageModel> messageToCopy) {
    final messageMap = {for (var msg in messageToCopy) msg.id: msg};

    final orderedMessagesToCopy = originalMessages
        .where((msgToCopy) => messageMap.containsKey(msgToCopy.id))
        .toList() // Convert the iterable to a list
        .cast<MessageModel>(); // Explicitly cast to MessageModel

    messageClipboard.assignAll(orderedMessagesToCopy.reversed);
  }
}
