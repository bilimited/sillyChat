import 'dart:convert';
import 'dart:io';

import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/promptBuilder.dart';
import 'package:get/get.dart';

class ChatSessionController extends GetxController {
  RxBool isLoading = false.obs;
  late Rx<ChatModel> _chat;

  ChatModel get chat => _chat.value;
  File get file => _chat.value.file;

  final String chatPath;

  /**
   * [chatPath] : 聊天文件的完整路径
   */
  ChatSessionController(this.chatPath);

  Future<void> loadChat() async {
    isLoading.value = true;

    final chatFile = File(chatPath);

    if (await chatFile.exists()) {
      final String contents = await chatFile.readAsString();
      final Map<String, dynamic> data = json.decode(contents);
      _chat.value = ChatModel.fromJson(data);
      chat.fileId = 0; // fileId字段已弃用
      chat.file = chatFile;
    } else {
      Get.snackbar('聊天加载失败.', '聊天文件不存在');
    }

    isLoading.value = false;
  }

  Future<void> saveChat() async {
    if (await file.exists()) {
      final String contents = json.encode(chat.toJson());
      await file.writeAsString(contents);
    } else {
      Get.snackbar('聊天保存失败.', '聊天文件不存在');
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
  Future<void> removeMessage(int chatId, DateTime messageTime) async {
    chat.messages.removeWhere((msg) => msg.time == messageTime);
    if (chat.messages.isNotEmpty) {
      final lastMsg = chat.messages.last;
      chat.lastMessage = lastMsg.content;
      chat.time = lastMsg.time.toString();
    }
    _chat.refresh();
    await saveChat();
  }

  Future<void> addMessages(int chatId, List<MessageModel> messages) async {
    chat.messages.addAll(messages);
    if (messages.isNotEmpty) {
      chat.lastMessage = messages.last.content;
      chat.time = messages.last.time.toString();
    }

    await saveChat();
    _chat.refresh();
  }

  Future<void> removeMessages(int chatId, List<MessageModel> messages) async {
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

  /// 发送信息方法
  /// 行为：创建一个新的消息插入该聊天；自动获取当前聊天默认assistant的回复
  Future<void> sendMessageAndGetReply(
      String text, List<String> selectedPath) async {
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
        await for (var content
            in _handleLLMMessage(think: chat.requestOptions.isThinkMode)) {
          _handleAIResult(chat, content, chat.assistantId ?? -1);
        }
      } else {
        return;
      }
    }
  }

  void getGroupReply(CharacterModel sender) async {
    await for (var content in _handleLLMMessage(
        sender: sender, think: chat.requestOptions.isThinkMode)) {
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
      removeMessage(chat.id, message.time);
    } else {
      message = null;
    }

    if (chat.mode == ChatMode.auto) {
      //
      await for (var content
          in _handleLLMMessage(think: chat.requestOptions.isThinkMode)) {
        _handleAIResult(chat, content, chat.assistantId ?? -1,
            existedMessage: message);
      }
    } else if (chat.mode == ChatMode.group && message != null) {
      final CharacterController controller = Get.find();
      await for (var content in _handleLLMMessage(
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
  Stream<String> _handleLLMMessage(
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
    yield chat.aiState.LLMBuffer;
  }

  void interrupt(ChatModel chat) {
    chat.setAIState(chat.aiState.copyWith(isGenerating: false));
    chat.aiState.aihandler.interrupt();
  }
}
