import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/events.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/session_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/providers/web_session_controller.dart';
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

  RxBool isGeneratingTitle = false.obs;

  int backGroundTasks = 0; // 后台正在执行的任务数量（如生成标题等）

  final Rx<ChatModel> _chat = ChatModel(
      id: -1,
      name: '未加载的聊天',
      avatar: '',
      lastMessage: '',
      time: '',
      messages: []).obs;

  late Rx<ChatAIState> _aiState;
  Aihandler _autoTitleHandler = Aihandler();
  Aihandler _summaryHandler = Aihandler();

  Rx<NewMessageEvent?> newMessageEvent = Rx(null);

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

  Function(ChatModel) onChatUpdate = (cm) {};
  Worker? aiStateListener;

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
    ever(newMessageEvent, (ev) {
      if (ev == null) {
        return;
      }
      print('收到新消息...${ev.message.content}');
      if (ev.chat.needAutoTitle &&
          ev.chat.messages.length >=
              VaultSettingController.of().autoTitleSetting.value.level) {
        ev.chat.needAutoTitle = false;
        generateTitle();
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
    return !_aiState.value.isGenerating &&
        inputController.text.isEmpty &&
        backGroundTasks == 0;
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

    inputController.text = '';

    isChatUninitialized = true;
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
    onChatUpdate(chat);
    if (await file.exists()) {
      final String contents = json.encode(chat.toJson());
      await file.writeAsString(contents);

      await ChatController.of
          .updateChatMeta(file.path, ChatMetaModel.fromChatModel(chat));
      print('save Chat');
    } else {
      Get.snackbar('聊天${file.path}保存失败.', '聊天文件不存在');
    }
  }

  void useChatTemplate(ChatModel chat) {
    chat.needAutoTitle =
        VaultSettingController.of().autoTitleSetting.value.enabled;
    this._chat.value = chat;
    saveChat();
  }

  void bindWebController(WebSessionController controller) {
    const int? maxMessages = 10;

    aiStateListener = ever(_aiState, (state) {
      controller.onStateChange(state);
    });

    onChatUpdate = (chat) {
      if (maxMessages != null && chat.messages.length > maxMessages) {
        controller.onChatChange(chat.copyWith(
            messages:
                chat.messages.sublist(chat.messages.length - maxMessages)));
      } else {
        controller.onChatChange(chat);
      }
    };
    //_onChatUpdate(chat);
  }

  void closeWebController() {
    if (aiStateListener != null) {
      aiStateListener!.dispose();
    }
    onChatUpdate = (chat) {};
  }

  /// 在指定聊天中添加消息
  /// [LastMessage] :用于设置聊天"最近消息"的内容
  /// [useRegex] :添加消息前是否先进行正则替换
  Future<void> addMessage(
      {required MessageModel message,
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

    newMessageEvent.value = NewMessageEvent(message, chat);

    _chat.refresh();
    await saveChat();
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
  Future<void> onSendMessage(String text, List<String> selectedPath) async {
    if (text.isNotEmpty) {
      final message = MessageModel(
          id: DateTime.now().microsecondsSinceEpoch,
          content: text,
          senderId: chat.user.id,
          time: DateTime.now(),
          style: chat.user.messageStyle,
          role: MessageRole.user,
          alternativeContent: [null],
          resPath: selectedPath);

      await addMessage(message: message);

      if (chat.mode == ChatMode.group) {
        return;
      } else if (chat.mode == ChatMode.auto) {
        await for (var content in _getResponse(
          overrideOption: chat.assistant.bindOption, // 我也看不懂当时为什么要这么写
        )) {
          _handleAIResult(content, chat.assistantId ?? -1);
        }
      } else {
        return;
      }
    }
  }

  /// 仅群聊模式下可用
  /// 让AI直接发送一条消息，无需输入问题
  Future<void> onGroupMessage(CharacterModel assistant) async {
    await for (var content in _getResponse(
      overrideOption: assistant.bindOption,
      overrideAssistant: assistant,
    )) {
      _handleAIResult(content, assistant.id);
    }
  }

  // AI帮答
  Future<void> simulateUserMessage() async {
    await for (var content in _getResponse(
      overrideOption: ChatOptionModel(
          id: -1,
          name: 'AI帮答预设',
          requestOptions: LLMRequestOptions(messages: []),
          prompts: [
            PromptModel.chatHistoryPlaceholder(),
            PromptModel(
                id: 2,
                content: '请帮{{user}}生成一条消息。\n{{user}}:',
                role: 'user',
                name: 'name')
          ],
          regex: []),
      overrideAssistant: chat.user,
    )) {
      _handleAIResult(content, chat.user.id);
    }
  }

  // 重新发送ai请求（会自动追加在最新的AI回复后面。若无最新AI回复且为群聊模式，则不可用）
  Future<void> onRetry({int index = 1}) async {
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
      await for (var content in _getResponse(
        overrideOption: chat.assistant.bindOption,
      )) {
        _handleAIResult(content, chat.assistantId ?? -1,
            existedMessage: message);
      }
    } else if (chat.mode == ChatMode.group && message != null) {
      final CharacterController controller = Get.find();
      await for (var content in _getResponse(
        overrideOption: message.sender.bindOption,
        overrideAssistant: controller.getCharacterById(message.senderId),
      )) {
        _handleAIResult(content, message.senderId, existedMessage: message);
      }
    }
  }

  Future<void> generateTitle() async {
    isGeneratingTitle.value = true;
    String title = "";
    await for (String token in _getResponseInBackground(_autoTitleHandler,
        overrideOption:
            VaultSettingController.of().autoTitleSetting.value.option)) {
      title += token;
    }
    chat.name = title;
    _chat.refresh();
    isGeneratingTitle.value = false;

    await saveChat();
  }

  Future<void> doLocalSummary() async {
    final setting = VaultSettingController.of().summarySetting.value;
    await for (var content in _getResponse(
      overrideOption: setting.summaryOption,
      overrideAssistant: CharacterController.of
          .getCharacterById(CharacterController.SUMMARY_CHARACTER_ID),
    )) {
      // 隐藏所有
      for (final msg in chat.messages) {
        msg.visbility = MessageVisbility.hidden;
      }

      _handleAIResult(content, CharacterController.SUMMARY_CHARACTER_ID,
          overrideRole: MessageRole.user);
    }
  }

  Future<String> doSummaryBackground() async {
    final setting = VaultSettingController.of().summarySetting.value;
    var summary = "";
    await for (var content in _getResponseInBackground(
      _summaryHandler,
      overrideOption: setting.summaryOption,
    )) {
      summary += content;
    }

    return summary;
  }

  void stopSummaryInBackground() {
    _summaryHandler.interrupt();
  }

  Future<void> _handleAIResult(String content, int assistantID,
      {MessageModel? existedMessage, MessageRole? overrideRole}) async {
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
      senderId: assistantID,
      time: DateTime.now(),
      role: overrideRole ?? MessageRole.assistant,
      style: aiState.style,
      alternativeContent: existedContent,
    );
    await addMessage(message: AIMessage);

    // 答复生成完成后需要判断是否销毁Controller
    if (!isViewActive) {
      Get.delete<ChatSessionController>(tag: sessionId);
    }
  }

  /// 在当前聊天上下文下生成AI回复
  /// [overrideOption] 若设为空，则使用聊天设置的Option
  /// [overrideAssistant] 若设为空，则使用聊天设置的AI角色生成回复
  Stream<String> _getResponse({
    ChatOptionModel? overrideOption,
    CharacterModel? overrideAssistant = null,
  }) async* {
    late List<LLMMessage> messages;

    messages = Promptbuilder(chat, overrideOption)
        .getLLMMessageList(sender: overrideAssistant);

    final reqOptions = overrideOption?.requestOptions ?? chat.requestOptions;
    LLMRequestOptions options = reqOptions.copyWith(messages: messages);

    final assistantId = overrideAssistant == null
        ? (chat.assistantId ?? -1)
        : overrideAssistant.id;
    final assistant = overrideAssistant == null
        ? CharacterController.of.getCharacterById(chat.assistantId ?? -1)
        : overrideAssistant;
    setAIState(aiState.copyWith(
        LLMBuffer: "",
        isGenerating: true,
        GenerateState: "正在激活世界书...",
        style: assistant.messageStyle,
        currentAssistant: assistantId));

    await for (String token in aiState.aihandler.requestTokenStream(options)) {
      final oldState = aiState;
      setAIState(oldState.copyWith(LLMBuffer: oldState.LLMBuffer + token));
      //LLMMessageBuffer.refresh();
    }

    setAIState(aiState.copyWith(isGenerating: false));
    yield aiState.LLMBuffer;
  }

  /// 在后台生成回复
  Stream<String> _getResponseInBackground(Aihandler handler,
      {ChatOptionModel? overrideOption}) async* {
    backGroundTasks++;
    late List<LLMMessage> messages;

    messages = Promptbuilder(chat, overrideOption).getLLMMessageList();

    final reqOptions = overrideOption?.requestOptions ?? chat.requestOptions;
    LLMRequestOptions options = reqOptions.copyWith(messages: messages);

    await for (String token in handler.requestTokenStream(options)) {
      yield token;
      //LLMMessageBuffer.refresh();
    }
    backGroundTasks--;
  }

  void interrupt() {
    setAIState(aiState.copyWith(isGenerating: false));
    aiState.aihandler.interrupt();
  }
}
