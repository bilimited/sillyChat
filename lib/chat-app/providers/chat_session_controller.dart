import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/session_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/entitys/ChatAIState.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/promptBuilder.dart';
import 'package:path/path.dart' as p;
import 'package:get/get.dart';

class ChatSessionController extends SessionController {
  String get sessionId => this.chatPath;
  late TextEditingController inputController;

  RxBool isLoading = false.obs;

  // 当前会话是否处于前台
  bool isViewActive = true;

  bool get isGenerating => aiState.isGenerating;

  final Rx<ChatModel> _chat = ChatModel(
      id: -1,
      name: '未加载的聊天',
      avatar: '',
      lastMessage: '',
      time: '',
      messages: []).obs;

  late Rx<ChatAIState> _aiState;

  ChatAIState get aiState =>
      _aiState.value; //=> Get.find<ChatController>().getAIState(file.path);

  void setAIState(ChatAIState newState) {
    _aiState.value = newState;
    //Get.find<ChatController>().setAIState(file.path, newState);
  }

  ChatModel get chat => _chat.value;
  File get file => _chat.value.file;
  bool get isChatLoading => chat.id == -1;
  bool isChatUninitialized = false;

  final String chatPath;

  /**
   * [chatPath] : 聊天文件的完整路径
   */
  ChatSessionController(this.chatPath) {
    this.inputController = TextEditingController();
  }

  factory ChatSessionController.uninitialized() {
    return ChatSessionController('')..isChatUninitialized = true;
  }

  static ChatSessionController? tryGetSession(String path) {
    if (Get.isRegistered<ChatSessionController>(tag: path)) {
      return Get.find<ChatSessionController>(tag: path);
    } else {
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    ever(ChatController.of.fileDeleteEvent, (fe) {
      if (fe == null) {
        return;
      }
      if (p.equals(fe.filePath, chatPath) ||
          p.isWithin(fe.filePath, chatPath)) {
        // Quit
        close();
      }
    });
    _aiState = ChatAIState(
            aihandler: Aihandler()
              ..onGenerateStateChange = (str) {
                _aiState.value = aiState.copyWith(GenerateState: str);
              })
        .obs;
    // 异步加载，显示进度条
    loadChat();
  }

  @override
  void onClose() {
    super.onClose();
    inputController.dispose();
  }

  void reflesh() {
    _chat.refresh();
  }

  /// 只有该值为True时，退出聊天时SessionController会被销毁
  bool get canDestory {
    return !_aiState.value.isGenerating && inputController.text.isEmpty;
  }

  // 手动关闭此聊天，使其不能再打开。
  void close() {
    _chat.value = ChatModel(
        id: -1,
        name: '未加载的聊天',
        avatar: '',
        lastMessage: '',
        time: '',
        messages: []);
    isChatUninitialized = true;
    inputController.text = '';
  }

  Future<void> loadChat() async {
    if (chatPath.isEmpty) {
      return;
    }
    isLoading.value = true;

    final chatFile = File(chatPath);

    if (await chatFile.exists()) {
      final String contents = await chatFile.readAsString();
      final Map<String, dynamic> data = json.decode(contents);
      _chat.value = ChatModel.fromJson(data);
      //chat.fileId = 0; // fileId字段已弃用
      chat.file = chatFile;
    } else {
      //Get.snackbar('聊天加载失败.', '聊天文件不存在');
    }

    isLoading.value = false;
  }

  Future<void> saveChat() async {
    if (await file.exists()) {
      final String contents = json.encode(chat.toJson());
      await file.writeAsString(contents);

      await ChatController.of
          .updateChatMeta(file.path, ChatMetaModel.fromChatModel(chat));
    } else {
      Get.snackbar('聊天${file.path}保存失败.', '聊天文件不存在');
    }
  }

  /// 在指定聊天中添加消息
  /// [LastMessage] :用于设置聊天"最近消息"的内容
  /// [useRegex] :添加消息前是否先进行正则替换
  Future<void> addMessage(
      {required int chatId,
      required MessageModel message,
      String? lastMessage = null,
      bool useRegex = true}) async {
    if (useRegex) {
      String rawText = message.content;
      for (final regex in chat.vaildRegexs
          .where((reg) => reg.onAddMessage)
          .where((reg) =>
              reg.isAvailable(chat, message, disableDepthCalc: true))) {
        rawText = regex.process(rawText);
      }
      message.content = rawText;
    }

    chat.messages.add(message);
    chat.lastMessage = lastMessage != null ? lastMessage : message.content;
    chat.time = message.time.toString();

    _chat.refresh();
    await saveChat();
    print("AddMessage: ${message.content}");
  }

  // 在指定聊天中删除消息
  Future<void> removeMessage(DateTime messageTime) async {
    chat.messages.removeWhere((msg) => msg.time == messageTime);
    if (chat.messages.isNotEmpty) {
      final lastMsg = chat.messages.last;
      chat.lastMessage = lastMsg.content;
      chat.time = lastMsg.time.toString();
    }
    _chat.refresh();
    await saveChat();
  }

  Future<void> addMessages(List<MessageModel> messages) async {
    chat.messages.addAll(messages);
    if (messages.isNotEmpty) {
      chat.lastMessage = messages.last.content;
      chat.time = messages.last.time.toString();
    }

    await saveChat();
    _chat.refresh();
  }

  Future<void> removeMessages(List<MessageModel> messages) async {
    chat.messages.removeWhere((msg) => messages.contains(msg));
    if (chat.messages.isNotEmpty) {
      final lastMsg = chat.messages.last;
      chat.lastMessage = lastMsg.content;
      chat.time = lastMsg.time.toString();
    }
    await saveChat();
    _chat.refresh();
  }

  // 在指定聊天中更新消息
  Future<void> updateMessage(
      DateTime messageTime, MessageModel updatedMessage) async {
    final index = chat.messages.indexWhere((msg) => msg.time == messageTime);
    if (index != -1) {
      chat.messages[index] = updatedMessage;
      if (index == chat.messages.length - 1) {
        chat.lastMessage = updatedMessage.content;
        chat.time = updatedMessage.time.toString();
      }
      await saveChat();
      _chat.refresh();
    }
  }

  /**
   * ----------- WARNING ------------
   * 以下代码是一坨  不要乱碰，如果一定得碰请联系作者重构
   */

  /// 发送信息方法
  /// 行为：创建一个新的消息插入该聊天；自动获取当前聊天默认assistant的回复
  Future<void> sendMessageAndGetReply(
      String text, List<String> selectedPath) async {
    if (text.isNotEmpty) {
      final message = MessageModel(
          id: DateTime.now().microsecondsSinceEpoch,
          content: text,
          senderId: chat.user.id,
          time: DateTime.now(),
          type: MessageTypeExtension.fromMessageStyle(chat.user.messageStyle),
          role: MessageRole.user,
          alternativeContent: [null],
          resPath: selectedPath);

      await addMessage(chatId: chat.id, message: message);

      if (chat.mode == ChatMode.group) {
        return;
      } else if (chat.mode == ChatMode.auto) {
        await for (var content in _handleLLMMessage(
          chat.assistant.bindOption, // 我也看不懂当时为什么要这么写
        )) {
          _handleAIResult(chat, content, chat.assistantId ?? -1);
        }
      } else {
        return;
      }
    }
  }

  /// 让AI直接发送一条消息，无需输入问题
  Future<void> getGroupReply(CharacterModel sender) async {
    await for (var content in _handleLLMMessage(
      sender.bindOption,
      sender: sender,
    )) {
      _handleAIResult(chat, content, sender.id);
    }
  }

  // 重新发送ai请求（会自动追加在最新的AI回复后面。若无最新AI回复且为群聊模式，则不可用）（该方法未完成）
  Future<void> retry(ChatModel chat, {int index = 1}) async {
    final msgList = chat.messages;

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
      removeMessage(message.time);
    } else {
      message = null;
    }

    if (chat.mode == ChatMode.auto) {
      // TODO:有时会无法retry，似乎是因为mode不正常，重新设置mode即可
      await for (var content in _handleLLMMessage(
        chat.assistant.bindOption,
      )) {
        _handleAIResult(chat, content, chat.assistantId ?? -1,
            existedMessage: message);
      }
    } else if (chat.mode == ChatMode.group && message != null) {
      final CharacterController controller = Get.find();
      await for (var content in _handleLLMMessage(
        message.sender.bindOption,
        sender: controller.getCharacterById(message.senderId),
      )) {
        _handleAIResult(chat, content, message.senderId,
            existedMessage: message);
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
      senderId: senderID,
      time: DateTime.now(),
      role: MessageRole.assistant,
      alternativeContent: existedContent,
    );
    await addMessage(chatId: chat.id, message: AIMessage);

    // 答复生成完成后需要判断是否销毁Controller
    if (!isViewActive) {
      Get.delete<ChatSessionController>(tag: sessionId);
    }
  }

  // 按行分割功能:已弃用
  // 处理消息功能，默认为单聊
  Stream<String> _handleLLMMessage(ChatOptionModel? option,
      {CharacterModel? sender = null}) async* {
    late List<LLMMessage> messages;

    messages = Promptbuilder(chat, option).getLLMMessageList(sender: sender);

    final reqOptions = option?.requestOptions ?? chat.requestOptions;
    LLMRequestOptions options = reqOptions.copyWith(messages: messages);

    setAIState(aiState.copyWith(
        LLMBuffer: "",
        isGenerating: true,
        GenerateState: "正在激活世界书...",
        currentAssistant:
            sender == null ? (chat.assistantId ?? 0) : sender.id));

    await for (String token in aiState.aihandler.requestTokenStream(options)) {
      final oldState = aiState;
      setAIState(oldState.copyWith(LLMBuffer: oldState.LLMBuffer + token));
      //LLMMessageBuffer.refresh();
    }

    setAIState(aiState.copyWith(isGenerating: false));
    yield aiState.LLMBuffer;
  }

  void interrupt() {
    setAIState(aiState.copyWith(isGenerating: false));
    aiState.aihandler.interrupt();
  }
}
