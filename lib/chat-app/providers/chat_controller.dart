// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/events.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/models/story_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_page.dart';
import 'package:flutter_example/chat-app/providers/base_controller.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:get/get.dart';
import '../models/chat_model.dart';

import 'package:path/path.dart' as p;

// 聊天索引和聊天文件综合管理器
// TODO:把关于聊天的文件操作都塞到这里。
class ChatController extends BaseController {
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

  final RxBool isMultiSelecting = false.obs;

  final CharacterController characterController = Get.find();

  // 新增：聊天元数据索引
  final RxMap<String, ChatMetaModel> chatIndex = <String, ChatMetaModel>{}.obs;
  final String chatIndexFileName = 'chat_index.json';
  final String recentChatFileName = "recent_chat.json";

  // 最近聊天列表：按时间从新到旧。每个父目录（角色/故事）只保留一条最新条目。
  static const int recentChatLimit = 50;
  final RxList<ChatMetaModel> recentChats = <ChatMetaModel>[].obs;

  // 已打开的聊天
  final RxMap<String, ChatSessionController?> openedChat =
      <String, ChatSessionController>{}.obs;

  void fireDeleteEvent(String path) {
    fileDeleteEvent.value = FileDeletedEvent(path);
    fileDeleteEvent.refresh();
  }

  @override
  void onInit() async {
    super.onInit();

    await loadChatIndex();
    await loadRecentChats();

    ever(fileDeleteEvent, (ev) {
      if (ev == null) return;
      chatIndex.remove(ev!.filePath);
      removeRecentChatByPath(ev.filePath);
    });

    markReady();
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
          chatIndex[key] = ChatMetaModel.fromJson(json, p.canonicalize(key));
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

  // 加载最近聊天
  Future<void> loadRecentChats() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$recentChatFileName');
      if (!await file.exists()) {
        print('最近聊天文件不存在，跳过加载');
        return;
      }
      final String contents = await file.readAsString();
      final List<dynamic> jsonList = json.decode(contents);
      final List<ChatMetaModel> loaded = [];
      for (final item in jsonList) {
        try {
          final map = item as Map<String, dynamic>;
          final path = p.canonicalize(map['path'] as String);
          loaded.add(ChatMetaModel.fromJson(map, path));
        } catch (e) {
          print('解析单条最近聊天失败: $e');
        }
      }
      recentChats.assignAll(loaded);
      print('加载最近聊天成功，共 ${recentChats.length} 条');
      if (recentChats.isNotEmpty) {
        openChat(recentChats[0].path);
      }
    } catch (e) {
      print('加载最近聊天失败: $e');
    }
  }

  // 保存最近聊天
  Future<void> saveRecentChats() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$recentChatFileName');
      final List<Map<String, dynamic>> data = recentChats.map((meta) {
        final m = meta.toJson();
        m['path'] = meta.path;
        return m;
      }).toList();
      await file.writeAsString(json.encode(data));
      print('保存最近聊天成功，共 ${recentChats.length} 条');
    } catch (e) {
      print('保存最近聊天失败: $e');
    }
  }

  // 将一条聊天置顶到最近聊天。
  // 同一父目录下只保留最新的一条（同目录视为同一角色/故事）。
  Future<void> pushRecentChat(String _path, ChatMetaModel meta) async {
    final path = p.canonicalize(_path);
    final dir = p.dirname(path);

    recentChats.removeWhere((m) {
      final mp = p.canonicalize(m.path);
      return p.equals(mp, path) || p.equals(p.dirname(mp), dir);
    });

    recentChats.insert(0, meta.copyWith(path: path));

    if (recentChats.length > recentChatLimit) {
      recentChats.removeRange(recentChatLimit, recentChats.length);
    }

    print('置顶最近聊天: $path (当前共 ${recentChats.length} 条)');
    await saveRecentChats();
  }

  // 按完整路径移除一条最近聊天
  Future<void> removeRecentChatByPath(String _path) async {
    final path = p.canonicalize(_path);
    final before = recentChats.length;
    recentChats.removeWhere((m) =>
        p.equals(p.canonicalize(m.path), path) ||
        p.isWithin(path, p.canonicalize(m.path)));
    if (recentChats.length != before) {
      print('移除最近聊天: $path (剩余 ${recentChats.length} 条)');
      await saveRecentChats();
    }
  }

  // 更新一条聊天索引，用于在保存聊天的同时调用
  Future<void> updateChatMeta(String path, ChatMetaModel chatMeta) async {
    chatIndex[p.canonicalize(path)] = chatMeta;
    //chatIndex.assign(path, chatMeta);
    await saveChatIndex();
  }

  ChatMetaModel? getIndex(String _path) {
    final meta = chatIndex[p.canonicalize(_path)];
    return meta?.copyWith(path: p.canonicalize(_path));
  }

  // 构建一条聊天索引，用于在初次加载一个聊天时使用
  Future<ChatMetaModel?> buildIndex(String _path) async {
    final path = p.canonicalize(_path);
    try {
      final file = File(path);
      final content = await file.readAsString();
      final chat = ChatModel.fromJson(json.decode(content));

      chatIndex[path] = ChatMetaModel.fromChatModel(chat, path);

      saveChatIndex();
      return chatIndex[path];
    } catch (e) {
      rethrow;
    }
  }

  // 新增：删除聊天元数据
  Future<void> deleteChatMetaByPath(String _path) async {
    final path = p.canonicalize(_path);
    chatIndex.remove(path);
    await saveChatIndex();
  }

  /// [path] 要创建聊天的绝对路径。不包含文件名。
  Future<String> createChat(ChatModel chat, String path) async {
    final fullPath = p.canonicalize(
        p.join(path, '${chat.name}-${DateTime.now().hashCode}.chat'));
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
    final chatMeta = ChatMetaModel.fromChatModel(chat, fullPath);
    await updateChatMeta(fullPath, chatMeta);
    fileCreateEvent.value = FileCreatedEvent(fullPath);
    return fullPath;
  }

  Future<ChatModel> createQuickChat(String path) async {
    final id = DateTime.now().microsecond;
    ChatModel chatModel = ChatModel.empty();

    await createChat(chatModel, path);

    return chatModel;
  }

  Future<(ChatModel, String)> createChatForCharacter(
      CharacterModel character) async {
    String path = p.join(SettingController.of.getChatPathSync(), 'roles',
        character.id.toString());
    final chat =
        ChatModel.empty().copyWith(assistantId: character.id, messages: [
      if (character.firstMessage != null && character.firstMessage!.isNotEmpty)
        MessageModel(
            id: DateTime.now().millisecondsSinceEpoch,
            content: character.firstMessage!,
            senderId: character.id,
            time: DateTime.now(),
            alternativeContent: [null, ...character.moreFirstMessage])
    ]);
    final fp = await createChat(chat, path);
    return (chat, fp);
  }

  Future<(ChatModel, String)> createChatForStory(StoryModel story) async {
    String path = p.join(
        SettingController.of.getChatPathSync(), 'stories', story.id.toString());
    final chat = ChatModel.empty().copyWith(mode: ChatMode.group);
    final fp = await createChat(chat, path);
    return (chat, fp);
  }

  Future<(ChatModel, String)> createChatForChat(ChatModel chat) async {
    if (chat.bindCharacter != null) {
      return await createChatForCharacter(chat.bindCharacter!);
    } else if (chat.bindStory != null) {
      return await createChatForStory(chat.bindStory!);
    } else {
      throw Exception("聊天无法创建！");
    }
  }

  void openChat(String path) {
    currentChat.value = ChatSessionController(path);
  }

  // 打开某角色的最新聊天，不存在则创建
  void openCharacterLatestChat(CharacterModel character) async {
    String path = p.join(SettingController.of.getChatPathSync(), 'roles',
        character.id.toString());
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final files = dir.listSync().whereType<File>().map((file) {
      final modified = file.statSync().modified;
      return MapEntry(file, modified);
    }).toList();

    if (files.isEmpty) {
      final (chat, fp) = await createChatForCharacter(character);
      openChat(fp);
    } else {
      files.sort((a, b) => b.value.compareTo(a.value));
      final file = files.first.key;
      openChat(file.path);
    }
  }

  // 打开某故事的最新聊天，不存在则创建
  void openStoryLatestChat(StoryModel story) async {
    String path = p.join(
        SettingController.of.getChatPathSync(), 'stories', story.id.toString());
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final files = dir.listSync().whereType<File>().map((file) {
      final modified = file.statSync().modified;
      return MapEntry(file, modified);
    }).toList();

    if (files.isEmpty) {
      final (chat, fp) = await createChatForStory(story);
      openChat(fp);
    } else {
      files.sort((a, b) => b.value.compareTo(a.value));
      final file = files.first.key;
      openChat(file.path);
    }
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
}
