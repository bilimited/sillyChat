import 'dart:convert';
import 'dart:io';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/ChatFileSuffixManager.dart';
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

  // 新增：聊天元数据索引
  final RxMap<String, ChatMetaModel> chatIndex = <String, ChatMetaModel>{}.obs;
  final String chatIndexFileName = 'chat_index.json';

  @override
  void onInit() async {
    super.onInit();
    await debug_moveAllChats();
    loadChatIndex();
  }

  Future<void> debug_moveAllChats() async {
    final directory = await Get.find<SettingController>().getVaultPath();
    final folder = File('${directory}/chats');
    if (!await folder.exists()) {
      chats.value.forEach((chat) async {
        final fext =
            Chatfilesuffixmanager.fromChatMode(chat.mode ?? ChatMode.auto);

        final f = File('${directory}/chats/chat_${chat.id}.$fext');
        await f.create(recursive: true);
        await f.writeAsString(json.encode(chat.toJson()));
      });

      Get.snackbar('迁移成功!', 'message');
    }
  }

  // 新增：重新生成聊天索引的方法
  Future<Map<String, ChatModel>> rebuildChatIndex() async {
    final path = await SettingController.of.getChatPath();
    final Map<String, ChatModel> newChatIndex = {};
    final Directory directory = Directory(path);

    if (!await directory.exists()) {
      print('路径不存在: $path');
      return {};
    }

    // 递归遍历目录下的所有文件
    final List<FileSystemEntity> files = directory.listSync(recursive: true);

    for (var entity in files) {
      // 检查是否是文件
      if (entity is File) {
        // 筛选符合条件的文件
        // TODO: 在这里添加文件筛选条件，例如：
        // - 文件名以 'chat_' 开头
        // - 文件名以 '.json' 结尾
        final rightPath = entity.path.replaceAll('/', '\\');
        final String fileName = rightPath.split('\\').last;
        if (fileName.startsWith('chat_') && fileName.endsWith('.json')) {
          try {
            final String contents = await entity.readAsString();
            final Map<String, dynamic> jsonMap = json.decode(contents);
            final ChatModel chatModel = ChatModel.fromJson(jsonMap)
              ..file = entity;
            newChatIndex[entity.path] = chatModel;
          } catch (e) {
            print('解析文件失败: ${entity.path}, 错误: $e');
          }
        }
      }
    }

    // 更新chatIndex
    chatIndex.value =
        newChatIndex.map((k, v) => MapEntry(k, ChatMetaModel.fromChatModel(v)));
    await saveChatIndex();

    return newChatIndex;
  }

  // 新增：加载聊天索引
  Future<void> loadChatIndex() async {
    await rebuildChatIndex(); // 测试中 每次启动都重新构建

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

  // 新增：保存聊天索引
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

  // 新增：添加聊天元数据
  Future<void> updateChatMeta(String path, ChatMetaModel chatMeta) async {
    //chatIndex[path] = (chatMeta);
    chatIndex.assign(path, chatMeta);
    await saveChatIndex();
  }

  // 新增：删除聊天元数据
  Future<void> deleteChatMetaByPath(String path) async {
    chatIndex.remove(path);
    await saveChatIndex();
  }

  /// [path] 要创建聊天的绝对路径。不包含文件名。
  Future<void> createChat(ChatModel chat, String path) async {
    final fullPath = '$path/chat_${chat.id}.json';
    final file = File(fullPath);
    file.create(recursive: true);
    final String contents = json.encode(chat.toJson());
    chat.file = file;
    await file.writeAsString(contents);

    // 新增：创建聊天后，同步更新聊天元数据索引
    final chatMeta = ChatMetaModel.fromChatModel(chat);
    await updateChatMeta(fullPath, chatMeta);
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

  static ChatController get of => Get.find<ChatController>();
}
