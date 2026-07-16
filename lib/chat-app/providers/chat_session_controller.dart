import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/constants.dart';
import 'package:flutter_example/chat-app/events.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/agent_config_model.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_page.dart';
import 'package:flutter_example/chat-app/providers/base_controller.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/providers/web_session_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/chat/token_calc.dart';
import 'package:flutter_example/chat-app/utils/entitys/ChatAIState.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/entitys/tool_call.dart';
import 'package:flutter_example/chat-app/utils/entitys/tool_call_context.dart';
import 'package:flutter_example/chat-app/utils/tool_registry.dart';
import 'package:flutter_example/chat-app/utils/tool_call_tag.dart';
import 'package:flutter_example/chat-app/utils/promptBuilder.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:path/path.dart' as p;
import 'package:get/get.dart';

class ChatSessionController extends BaseController {
  String get sessionId => this.chatPath;
  late TextEditingController inputController;

  RxBool isLoading = false.obs;

  // 当前会话是否处于前台
  bool isViewActive = true;

  bool get isGenerating => aiState.isGenerating;

  RxBool isGeneratingTitle = false.obs;
  RxBool isCommandPinned = false.obs; // 附加指令是否常驻
  RxBool isLock = false.obs; // 是否锁定当前聊天（用于"多窗口"）
  RxInt cachedTokens = 0.obs;

  int backGroundTasks = 0; // 后台正在执行的任务数量（如生成标题等）

  final Rx<ChatModel> _chat = ChatModel(
      id: -1,
      name: '新会话',
      avatar: '',
      lastMessage: '',
      time: '',
      messages: []).obs;

  late Rx<ChatAIState> _aiState;
  Aihandler _autoTitleHandler = Aihandler();
  Aihandler _summaryHandler = Aihandler();

  // 消息变更就发出事件
  Rx<MessageEvent?> messageEvent = Rx(null);

  ChatAIState get aiState =>
      _aiState.value; //=> Get.find<ChatController>().getAIState(file.path);

  void setAIState(ChatAIState newState) {
    _aiState.value = newState;
  }

  ChatModel get chat => _chat.value;
  File? get file => _chat.value.file;

  String get tag => p.canonicalize(chatPath);
  bool get isChatUninitialized => file == null;

  String chatPath;

  Function(ChatModel) onChatUpdate = (cm) {};
  Worker? aiStateListener;
  Worker? _messageEventWorker;
  String _previousLLMBuffer = "";
  WebSessionController? _webController;

  /**
   * [chatPath] : 聊天文件的完整路径
   */
  ChatSessionController(this.chatPath) {
    this.inputController = TextEditingController();
  }

  factory ChatSessionController.uninitialized() {
    return ChatSessionController('');
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
    if (tag.isNotEmpty) {
      ChatController.of.openedChat[tag] = this;
    }

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
    ever(messageEvent, (ev) {
      if (ev == null || ev.type != MessageEventType.add) {
        return;
      }
      print('收到新消息...${ev.message.content}');

      // 更新最近聊天（同目录下只保留最新一条）
      if (chatPath.isNotEmpty) {
        final meta = ChatMetaModel.fromChatModel(ev.chat, chatPath);
        ChatController.of.pushRecentChat(chatPath, meta);
      }

      if (ev.chat.needAutoTitle &&
          ev.chat.messages.length >=
              VaultSettingController.of().miscSetting.value.autoTitle_level) {
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
    ChatController.of.openedChat.remove(tag);
    inputController.dispose();
  }

  void reflesh() {
    _chat.refresh();
  }

  /// 只有该值为True时，退出聊天时SessionController会被销毁
  bool get canDestory {
    return !_aiState.value.isGenerating &&
        inputController.text.isEmpty &&
        backGroundTasks == 0 &&
        !isLock.value;
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
    updateTokens();
    print(chat.bindStory?.name ?? "No Story!");
    print(chat.bindCharacter?.roleName ?? "No Char!");
  }

  Future<void> saveChat() async {
    final seen = <int>{};
    // 简单去重
    chat.characterIds.retainWhere((e) => seen.add(e));

    final createPath = chat.pathToCreate;
    onChatUpdate(chat);

    if (file != null && await file!.exists()) {
      final String contents = json.encode(chat.toJson());
      await file!.writeAsString(contents);

      final meta = ChatMetaModel.fromChatModel(chat, chat.filePath);
      await ChatController.of.updateChatMeta(file!.path, meta);
      print('save Chat');
      // 异步执行Token计算
      updateTokens();
    } else if (createPath != null) {
      final fullPath = await ChatController.of.createChat(chat, createPath);
      chatPath = fullPath;
    } else {}
  }

  void bindWebController(WebSessionController controller) {
    _webController = controller;

    // ---- Incremental message sync (P1) ----
    // Fires on every message add/update/delete. Only active after
    // bindWebController is called, which happens from onWebViewCreated
    // (after loadChat completes), so initial file load never triggers these.
    _messageEventWorker = ever(messageEvent, (ev) {
      if (ev == null) return;
      switch (ev.type) {
        case MessageEventType.add:
          final index = chat.messages.length - 1;
          controller.onMessageAdded(ev.message, index);
          break;
        case MessageEventType.update:
          controller.onMessageUpdated(ev.message);
          break;
        case MessageEventType.delete:
          controller.onMessageRemoved(ev.message);
          break;
      }
    });

    // ---- AI state listener with delta streaming (P1) ----
    aiStateListener = ever(_aiState, (state) {
      if (state.isGenerating) {
        // During streaming: push metadata-only state + token delta
        final newBuffer = state.LLMBuffer;
        if (newBuffer.length > _previousLLMBuffer.length) {
          final token = newBuffer.substring(_previousLLMBuffer.length);
          controller.onTokenAppend(token);
        }
        _previousLLMBuffer = newBuffer;

        // Metadata-only: exclude the full LLMBuffer
        controller.onStateChange(state, includeBuffer: false);
      } else {
        // Generation ended: push full state with buffer for reconciliation
        controller.onStateChange(state, includeBuffer: true);
        _previousLLMBuffer = "";
      }
    });

    // ---- Full chat sync (initial load + resync) ----
    // No truncation — send full message history. JS handles rendering.
    onChatUpdate = (chat) {
      controller.onChatChange(chat);
    };
  }

  Future<void> updateTokens() async {
    final messages =
        Promptbuilder(chat, chat.assistant.bindOption).getLLMMessageList();
    String allContent = "";
    messages.forEach((m) {
      allContent += m.content;
    });

    cachedTokens.value = TokenCalc.estimateTokens(allContent);
  }

  void closeWebController() {
    if (aiStateListener != null) {
      aiStateListener!.dispose();
      aiStateListener = null;
    }
    if (_messageEventWorker != null) {
      _messageEventWorker!.dispose();
      _messageEventWorker = null;
    }
    _previousLLMBuffer = "";
    _webController = null;
    onChatUpdate = (chat) {};
  }

  /// Tell WebView to scroll to the bottom of the message list.
  void scrollToBottom() {
    _webController?.scrollToBottom();
  }

  /// Tell WebView to scroll to a specific message by its id.
  void scrollToMessage(int messageId) {
    _webController?.scrollToMessage(messageId);
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

    messageEvent.value =
        MessageEvent(message, chat, type: MessageEventType.add);

    _chat.refresh();
    await saveChat();
  }

  // 在指定聊天中删除消息
  Future<void> removeMessage(DateTime messageTime) async {
    final MessageModel? messageToDelete =
        chat.messages.firstWhereOrNull((msg) => msg.time == messageTime);
    chat.messages.removeWhere((msg) => msg.time == messageTime);
    if (chat.messages.isNotEmpty) {
      final lastMsg = chat.messages.last;
      chat.lastMessage = lastMsg.content;
      chat.time = lastMsg.time.toString();
    }
    if (messageToDelete != null) {
      messageEvent.value =
          MessageEvent(messageToDelete, chat, type: MessageEventType.delete);
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
    messages.forEach((msg) {
      messageEvent.value = MessageEvent(msg, chat, type: MessageEventType.add);
    });

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
    messages.forEach((msg) {
      messageEvent.value =
          MessageEvent(msg, chat, type: MessageEventType.delete);
    });
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
      messageEvent.value =
          MessageEvent(updatedMessage, chat, type: MessageEventType.update);
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

  // 检查是否是最后一条消息
  bool isLastMessage(MessageModel message) {
    return message.id == chat.messages.last.id;
  }

  // AI帮答
  Future<List<String>> simulateUserMessage() async {
    final simUserOption =
        VaultSettingController.of().miscSetting.value.simulateUserOption;

    final messages = Promptbuilder(chat, simUserOption)
        .getLLMMessageList(sender: CharacterModel.empty());

    final reqOptions = chat.requestOptions;
    LLMRequestOptions options = reqOptions.copyWith(messages: messages);

    String result = "";
    await for (final chunk in aiState.aihandler.requestTokenStream(options)) {
      if (chunk.isThinkingStart) {
        result += '<think>';
      } else if (chunk.isThinkingEnd) {
        result += '</think>';
      } else if (chunk.isText) {
        result += chunk.content!;
      }
    }
    print(result);
    final lines = result
        .split('\n')
        .map((line) {
          String l = line.trim();
          // remove unordered list markers like "- ", "* ", "+ "
          l = l.replaceFirst(RegExp(r'^[-+*]\s*'), '');
          // remove ordered list markers like "1. " or "1) "
          l = l.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');
          return l;
        })
        .where((l) => l.isNotEmpty)
        .toList();
    return lines;
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
            VaultSettingController.of().miscSetting.value.autotitleOption)) {
      title += token;
    }
    final reg = RegExp(r'<think>.*?</think>', dotAll: true);
    chat.name = title.replaceAll(reg, '');
    _chat.refresh();
    isGeneratingTitle.value = false;

    await saveChat();
  }

  // 获取上下文中涉及的所有的角色（不是“聊天成员”）。
  List<int> getAllCharactersInContext() {
    Set<int> chars = Set();
    chat.messages.forEach((msg) {
      chars.add(msg.senderId);
    });
    return chars.toList();
  }

  Future<void> doLocalSummary() async {
    final setting = VaultSettingController.of().miscSetting.value;
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
  /// [overrideOption] 若设为空，则使用全局默认预设（所有预设中的第一个）
  /// [overrideAssistant] 若设为空，则使用聊天设置的AI角色生成回复
  ///
  /// 支持自动工具调用循环：
  /// 1. 发送请求（附带已注册的工具定义）
  /// 2. 如果模型返回 tool_calls，执行工具并将结果发回
  /// 3. 重复直到模型返回纯文本回复
  Stream<String> _getResponse({
    ChatOptionModel? overrideOption,
    CharacterModel? overrideAssistant = null,
  }) async* {
    final assistantId = overrideAssistant == null
        ? (chat.assistantId ?? -1)
        : overrideAssistant.id;
    final assistant = overrideAssistant == null
        ? CharacterController.of.getCharacterById(chat.assistantId ?? -1)
        : overrideAssistant;

    // 构建初始消息列表（只构建一次，后续迭代直接追加工具消息）
    List<LLMMessage> messages = Promptbuilder(chat, overrideOption)
        .getLLMMessageList(sender: overrideAssistant);

    final reqOptions = overrideOption?.requestOptions ?? chat.requestOptions;
    final agentConfig = overrideOption?.agentConfig ?? chat.chatOption.agentConfig;
    
    setAIState(aiState.copyWith(
        LLMBuffer: "",
        isGenerating: true,
        GenerateState: "正在激活世界书...",
        style: chat.isImmersiveMode ? MessageStyle.simulate : assistant.messageStyle,
        currentAssistant: assistantId));

    StringBuffer fullResponse = StringBuffer();
    int toolCallIterations = 0;
    final int maxToolCallIterations =
        (agentConfig?.enabled == true) ? agentConfig!.maxCallRounds : 10;

    while (toolCallIterations < maxToolCallIterations) {
      // 每次循环都重新构建 options（因为 messages 在变化）
      LLMRequestOptions options = reqOptions.copyWith(
        messages: messages,
        // 如果有已注册的工具且调用方未显式设置 tools，则自动注入
        tools: reqOptions.tools ?? _filteredDefinitions(agentConfig),
      );

      final List<ToolCall> collectedToolCalls = [];
      StringBuffer preToolCallText = StringBuffer();

      await for (final chunk
          in aiState.aihandler.requestTokenStream(options)) {
        final oldState = aiState;

        if (chunk.isThinkingStart) {
          preToolCallText.write('<think>');
          fullResponse.write('<think>');
          setAIState(
              oldState.copyWith(LLMBuffer: fullResponse.toString()));
        } else if (chunk.isThinkingEnd) {
          preToolCallText.write('</think>');
          fullResponse.write('</think>');
          setAIState(
              oldState.copyWith(LLMBuffer: fullResponse.toString()));
        } else if (chunk.isText) {
          preToolCallText.write(chunk.content);
          fullResponse.write(chunk.content);
          setAIState(
              oldState.copyWith(LLMBuffer: fullResponse.toString()));
        } else if (chunk.isToolCall) {
          collectedToolCalls.add(chunk.toolCall!);
          LogController.log(
            '工具调用: ${chunk.toolCall!.functionName}(${chunk.toolCall!.arguments})',
            LogLevel.info,
            title: 'Tool Call',
          );
        }
      }

      // 没有工具调用，生成完成
      if (collectedToolCalls.isEmpty) {
        break;
      }
 
      toolCallIterations++;

      // 将 assistant 消息（含 tool_calls）追加到消息列表
      messages.add(LLMMessage(
        content: preToolCallText.toString(),
        role: 'assistant',
        toolCalls: collectedToolCalls,
      ));

      // 执行每个工具并将结果追加为 tool 消息
      for (final tc in collectedToolCalls) {
        setAIState(aiState.copyWith(
            GenerateState: '正在执行: ${tc.functionName}...'));
        final result = await _executeToolCall(tc);
        LogController.log(
          '工具结果: ${tc.functionName} → $result',
          LogLevel.info,
          title: 'Tool Result',
        );
        messages.add(LLMMessage(
          content: result,
          role: 'tool',
          toolCallId: tc.id,
        ));

        // 将工具调用结果序列化为标签，持久化到消息正文中
        fullResponse.write(ToolCallTag.buildTag(tc, result));
      }

      // 重置 preToolCallText（下一轮迭代可能产生新的文本）
      preToolCallText.clear();

      setAIState(aiState.copyWith(
          GenerateState: '正在生成...',
          LLMBuffer: fullResponse.toString()));
    }

    if (toolCallIterations >= maxToolCallIterations) {
      LogController.log(
        '工具调用达到最大迭代次数 $maxToolCallIterations，强制终止',
        LogLevel.warning,
        title: 'Tool Call',
      );
    }

    setAIState(aiState.copyWith(isGenerating: false));

    final result = fullResponse.toString();
    if (result.isEmpty) {
      yield '（工具调用已完成，但模型未返回文本回复）';
    } else {
      yield result;
    }
  }

  /// 根据 [AgentConfig] 过滤工具定义。
  ///
  /// Agent 未启用时返回 `null`（不发送工具）；
  /// 白名单为 `null` 或空时返回所有已注册工具；
  /// 否则仅返回名称在白名单中的工具。
  List<ToolDefinition>? _filteredDefinitions(AgentConfig? agentConfig) {
    if (agentConfig?.enabled != true) return null;
    if (!ToolRegistry.instance.hasTools) return null;
    final allDefs = ToolRegistry.instance.definitions;
    final whitelist = agentConfig!.toolWhitelist;
    if (whitelist == null || whitelist.isEmpty) return allDefs;
    return allDefs
        .where((d) => whitelist.contains(d.function.name))
        .toList();
  }

  /// 执行单个工具调用
  Future<String> _executeToolCall(ToolCall tc) async {
    final executor = ToolRegistry.instance.getExecutor(tc.functionName);
    if (executor == null) {
      return '错误：未找到工具 "${tc.functionName}"';
    }
    try {
      final ctx = ToolCallContext(args: tc.parsedArguments, chat: chat);
      return await executor(ctx);
    } catch (e) {
      return '错误：执行工具 "${tc.functionName}" 时发生异常: $e';
    }
  }

  /// 在后台生成回复
  Stream<String> _getResponseInBackground(Aihandler handler,
      {ChatOptionModel? overrideOption}) async* {
    backGroundTasks++;
    late List<LLMMessage> messages;

    messages = Promptbuilder(chat, overrideOption).getLLMMessageList();
 
    final reqOptions = overrideOption?.requestOptions ?? chat.requestOptions;
    LLMRequestOptions options = reqOptions.copyWith(messages: messages);

    await for (final chunk in handler.requestTokenStream(options)) {
      if (chunk.isThinkingStart) {
        yield '<think>';
      } else if (chunk.isThinkingEnd) {
        yield '</think>';
      } else if (chunk.isText) {
        yield chunk.content!;
      }
      // 后台任务中忽略工具调用
    }
    backGroundTasks--;
  }

  void interrupt() {
    setAIState(aiState.copyWith(isGenerating: false));
    aiState.aihandler.interrupt();
  }
}
