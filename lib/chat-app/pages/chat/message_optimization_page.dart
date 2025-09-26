import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/chat/prompt_preview_page.dart';
import 'package:flutter_example/chat-app/pages/chat_options/edit_chat_option.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/promptBuilder.dart';
import 'package:flutter_example/chat-app/utils/LoreBookUtil.dart';
import 'package:flutter_example/chat-app/utils/promptFormatter.dart';
import 'package:get/get.dart';

enum ContextSendMode {
  userAndAssistant, // user与assistant
  userOnly, // 仅user消息
  assistantOnly, // 仅assistant消息
}

enum OptimizationType {
  blank,
  plot, // 剧情优化
  text, // 正文优化
}

class MessageOptimizationPage extends StatefulWidget {
  final ChatSessionController sessionController;
  final MessageModel message;

  const MessageOptimizationPage({
    Key? key,
    required this.sessionController,
    required this.message,
  }) : super(key: key);

  @override
  State<MessageOptimizationPage> createState() =>
      _MessageOptimizationPageState();
}

class _MessageOptimizationPageState extends State<MessageOptimizationPage> {
  final CharacterController _characterController =
      Get.find<CharacterController>();
  final ChatOptionController _chatOptionController =
      Get.find<ChatOptionController>();

  // 静态变量来保存上次的选择
  static int? _lastSelectedCharacterId;
  static int? _lastSelectedOptionId;
  static int _lastContextDepth = 1;
  static ContextSendMode _lastContextSendMode =
      ContextSendMode.userAndAssistant;
  static OptimizationType _lastOptimizationType = OptimizationType.text;
  static bool _lastOnlyRenderContent = false;

  // 选择的角色
  CharacterModel? selectedCharacter;

  // 选择的预设
  ChatOptionModel? selectedOption;

  // 上下文深度
  int contextDepth = 1;

  // 上下文发送设置
  ContextSendMode contextSendMode = ContextSendMode.userAndAssistant;

  // 优化类型
  OptimizationType optimizationType = OptimizationType.text;

  // 仅发送渲染内容
  bool onlyRenderContent = false;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    // 恢复上次的选择，如果没有则使用默认值
    if (_lastSelectedCharacterId != null) {
      selectedCharacter =
          _characterController.getCharacterById(_lastSelectedCharacterId!);
    }
    // 如果上次选择的角色不存在，则选择当前聊天的助手角色
    selectedCharacter ??= _characterController
        .getCharacterById(widget.sessionController.chat.assistantId ?? 0);

    if (_lastSelectedOptionId != null) {
      selectedOption =
          _chatOptionController.getChatOptionById(_lastSelectedOptionId!);
    }
    // 如果上次选择的预设不存在，则选择第一个预设
    if (selectedOption == null &&
        _chatOptionController.chatOptions.isNotEmpty) {
      selectedOption = _chatOptionController.chatOptions.first;
    }

    // 恢复其他设置
    contextDepth = _lastContextDepth;
    contextSendMode = _lastContextSendMode;
    optimizationType = _lastOptimizationType;
    onlyRenderContent = _lastOnlyRenderContent;
  }

  @override
  void dispose() {
    // 硕保在页面销毁时的清理工作
    super.dispose();
  }

  // 获取上下文消息（作为前文）
  List<MessageModel> _getContextMessages() {
    final chat = widget.sessionController.chat;
    final messageIndex = chat.messages.indexOf(widget.message);
    if (messageIndex == -1) return [];

    final contextMessages = <MessageModel>[];
    // 只获取要优化消息之前的消息作为前文
    final startIndex = (messageIndex - contextDepth).clamp(0, messageIndex);

    for (int i = startIndex; i < messageIndex; i++) {
      final msg = chat.messages[i];

      // 根据上下文发送设置过滤消息
      switch (contextSendMode) {
        case ContextSendMode.userAndAssistant:
          contextMessages.add(msg);
          break;
        case ContextSendMode.userOnly:
          if (!msg.isAssistant) {
            contextMessages.add(msg);
          }
          break;
        case ContextSendMode.assistantOnly:
          if (msg.isAssistant) {
            contextMessages.add(msg);
          }
          break;
      }
    }

    return contextMessages;
  }

  // 获取当前选中的消息内容，应用正则处理
  String _getCurrentMessageContent() {
    final chat = widget.sessionController.chat;
    String content = widget.message.content;
    print('Debug: original message content = $content');

    // 根据"仅发送渲染内容"设置选择不同的正则处理方式
    final regexList = onlyRenderContent
        ? chat.vaildRegexs.where((reg) => reg.onRender)
        : chat.vaildRegexs.where((reg) => reg.onRequest);

    for (final regex in regexList) {
      if (regex.isAvailable(chat, widget.message)) {
        final originalContent = content;
        content = regex.process(content);
        print(
            'Debug: regex ${regex.name} processed content from "$originalContent" to "$content"');
      }
    }

    return content;
  }

  // 构建用于预览的prompt
  List<LLMMessage> _buildPreviewPrompt() {
    if (selectedOption == null) return [];

    final contextMessages = _getContextMessages();
    final chat = widget.sessionController.chat;

    // 创建临时聊天模型，只包含前文消息（不包含要优化的消息）
    // 使用深拷贝确保不会修改原始聊天对象
    final tempChat = chat.shallowCopyWith(messages: List.from(contextMessages));

    // 添加优化指令
    String optimizationPrompt = '';
    switch (optimizationType) {
      case OptimizationType.plot:
        optimizationPrompt =
            '请优化上述消息内容的剧情逻辑，关注故事的逻辑一致性、情节发展以及角色设定，使其更加合理和引人入胜。';
        break;
      case OptimizationType.text:
        optimizationPrompt = '请优化上述消息内容的文字表达，关注文字的美感、表达力以及修辞手法的运用，使其更加自然流畅。';
        break;
      default:
        optimizationPrompt = '';
        break;
    }
    // 按照 Promptbuilder 的标准流程构建 prompt
    // 获取当前选中的待优化消息内容，不包含前文
    final targetContent = '\n<待优化文段>' +
        _getCurrentMessageContent() +
        '</待优化文段>\n\n' +
        optimizationPrompt;
    print('Debug: targetContent = $targetContent');
    print('Debug: widget.message.content = ${widget.message.content}');
    final promptBuilder = Promptbuilder(
        tempChat,
        ChatOptionModel.empty().copyWith(true,
            prompts: selectedOption!.prompts
                .map((prompt) => prompt.copyWith(
                    content: prompt.content.replaceAll(
                        RegExp(
                            r'\{\{lastuserMessage\}\}|\{\{lastUserMessage\}\}|\{\{lastmessage\}\}',
                            caseSensitive: false),
                        targetContent)))
                .toList()));

    // 使用 PromptBuilder 的标准 getLLMMessageList 流程，但需要特殊处理 userMessage
    // 因为我们需要将要优化的消息作为 userMessage 传递给宏系统

    // 首先调用标准的 getLLMMessageList 方法，这会处理所有的 prompt 构建流程
    final llmMessages = promptBuilder.getLLMMessageList();

    return llmMessages;
  }

  // 执行优化
  Future<void> _performOptimization() async {
    if (selectedOption == null || selectedCharacter == null) {
      Get.snackbar('错误', '请选择角色和预设');
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      // 保存当前选择到静态变量
      _lastSelectedCharacterId = selectedCharacter?.id;
      _lastSelectedOptionId = selectedOption?.id;
      _lastContextDepth = contextDepth;
      _lastContextSendMode = contextSendMode;
      _lastOptimizationType = optimizationType;
      _lastOnlyRenderContent = onlyRenderContent;

      final contextMessages = _getContextMessages();
      final chat = widget.sessionController.chat;

      // 创建临时聊天模型，只包含前文消息（不包含要优化的消息）
      // 使用深拷贝确保不会修改原始聊天对象
      final tempChat =
          chat.shallowCopyWith(messages: List.from(contextMessages));

      // 添加优化指令
      String optimizationPrompt = '';
      switch (optimizationType) {
        case OptimizationType.plot:
          optimizationPrompt =
              '请优化上述消息内容的剧情逻辑，关注故事的逻辑一致性、情节发展以及角色设定，使其更加合理和引人入胜。';
          break;
        case OptimizationType.text:
          optimizationPrompt = '请优化上述消息内容的文字表达，关注文字的美感、表达力以及修辞手法的运用，使其更加自然流畅。';
          break;
        default:
          optimizationPrompt = '';
          break;
      }
      // 按照 Promptbuilder 的标准流程构建 prompt
      // 获取当前选中的待优化消息内容，不包含前文
      final targetContent = '\n<待优化文段>' +
          _getCurrentMessageContent() +
          '</待优化文段>\n\n' +
          optimizationPrompt;
      print('Debug: targetContent = $targetContent');
      print('Debug: widget.message.content = ${widget.message.content}');
      final promptBuilder = Promptbuilder(
          tempChat,
          ChatOptionModel.empty().copyWith(true,
              prompts: selectedOption!.prompts
                  .map((prompt) => prompt.copyWith(
                      content: prompt.content.replaceAll(
                          RegExp(
                              r'\{\{lastuserMessage\}\}|\{\{lastUserMessage\}\}|\{\{lastmessage\}\}',
                              caseSensitive: false),
                          targetContent)))
                  .toList()));

      // 直接使用 getLLMMessageList，它会处理所有的 prompt 构建，包括宏替换
      final llmMessages = promptBuilder.getLLMMessageList();

      // 先回到聊天页面
      Get.back();

      // 准备优化消息的alternativeContent
      final message = widget.message;
      if (message.alternativeContent.isEmpty) {
        message.alternativeContent.add(null);
      }

      // 找到当前显示内容的位置并保存
      int currentIndex =
          message.alternativeContent.indexWhere((content) => content == null);
      if (currentIndex == -1) {
        message.alternativeContent.add(message.content);
        message.alternativeContent.add(null);
        currentIndex = message.alternativeContent.length - 1;
      } else {
        message.alternativeContent[currentIndex] = message.content;
      }

      // 添加新的备选内容占位
      message.alternativeContent.add('');
      message.content = '';
      message.alternativeContent[message.alternativeContent.length - 1] = null;

      // 更新消息以显示空内容（准备接收生成内容）
      await widget.sessionController.updateMessage(message.time, message);

      // 设置AI状态为生成中
      final aiState = widget.sessionController.aiState;
      widget.sessionController.setAIState(aiState.copyWith(
        LLMBuffer: "",
        isGenerating: true,
        GenerateState: optimizationType == OptimizationType.plot
            ? "正在进行剧情优化..."
            : "正在进行正文优化...",
        currentAssistant: selectedCharacter!.id,
      ));

      // 发送请求并获取优化结果，根据优化类型设置不同token数
      final maxTokens =
          optimizationType == OptimizationType.plot ? 20000 : 65500;
      final requestOptions = selectedOption!.requestOptions.copyWith(
        messages: llmMessages,
        maxTokens: maxTokens,
      );
      final StringBuffer result = StringBuffer();

      await for (String token
          in aiState.aihandler.requestTokenStream(requestOptions)) {
        result.write(token);
        // 实时更新显示内容
        message.content = result.toString();
        widget.sessionController.setAIState(aiState.copyWith(
          LLMBuffer: result.toString(),
          isGenerating: true,
        ));
      }

      final optimizedContent = result.toString();

      // 完成生成
      widget.sessionController
          .setAIState(aiState.copyWith(isGenerating: false));

      if (optimizedContent.isNotEmpty) {
        // 更新最终内容
        message.content = optimizedContent;
        await widget.sessionController.updateMessage(message.time, message);
        Get.snackbar('成功', '消息优化完成');
      } else {
        // 优化失败，恢复原内容
        final originalIndex = message.alternativeContent.length - 2;
        if (originalIndex >= 0 &&
            message.alternativeContent[originalIndex] != null) {
          message.content = message.alternativeContent[originalIndex]!;
          message.alternativeContent[currentIndex] = null;
          message.alternativeContent.removeAt(originalIndex);
          message.alternativeContent.removeLast();
        }
        await widget.sessionController.updateMessage(message.time, message);
        Get.snackbar('错误', '优化失败，已恢复原内容');
      }
    } catch (e) {
      // 错误处理，恢复原状态
      widget.sessionController.setAIState(
          widget.sessionController.aiState.copyWith(isGenerating: false));
      Get.snackbar('错误', '优化过程中出现错误: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    String type_info = '';
    switch (optimizationType) {
      case OptimizationType.plot:
        type_info = '主要关注故事的逻辑一致性、情节发展以及角色设定';
        break;
      case OptimizationType.text:
        type_info = '主要关注文字的美感、表达力以及修辞手法的运用';
        break;
      default:
        type_info = '请自行在所用预设{{lastusermessage}}之后插入需要的优化描述';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息优化'),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _performOptimization,
            child: const Text('进行优化'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 选择角色
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择角色',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final character =
                            await Get.to(() => CharacterSelector());
                        if (character != null) {
                          setState(() {
                            selectedCharacter = character;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: colors.outline.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (selectedCharacter != null) ...[
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: selectedCharacter!
                                        .avatar.isNotEmpty
                                    ? FileImage(File(selectedCharacter!.avatar))
                                    : null,
                                child: selectedCharacter!.avatar.isEmpty
                                    ? Icon(Icons.person, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(selectedCharacter!.roleName),
                              ),
                            ] else ...[
                              const Icon(Icons.person_add),
                              const SizedBox(width: 12),
                              const Text('选择角色'),
                            ],
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 选择预设
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择预设',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Obx(() {
                            // 确保 selectedOption 在当前选项列表中存在
                            final currentOptions =
                                _chatOptionController.chatOptions;
                            ChatOptionModel? validSelectedOption;

                            if (selectedOption != null) {
                              // 通过 ID 查找匹配的选项
                              try {
                                validSelectedOption = currentOptions.firstWhere(
                                  (option) => option.id == selectedOption!.id,
                                );
                              } catch (e) {
                                // 如果找不到匹配的选项，使用第一个选项
                                validSelectedOption = currentOptions.isNotEmpty
                                    ? currentOptions.first
                                    : null;
                              }
                            } else if (currentOptions.isNotEmpty) {
                              validSelectedOption = currentOptions.first;
                            }

                            // 如果发现选项发生了变化，更新 selectedOption
                            if (validSelectedOption != selectedOption) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    selectedOption = validSelectedOption;
                                  });
                                }
                              });
                            }

                            return DropdownButtonFormField<ChatOptionModel>(
                              value: validSelectedOption,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: currentOptions.map((option) {
                                return DropdownMenuItem(
                                  value: option,
                                  child: Text(option.name),
                                );
                              }).toList(),
                              onChanged: (ChatOptionModel? value) {
                                setState(() {
                                  selectedOption = value;
                                });
                              },
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            if (selectedOption != null) {
                              customNavigate(
                                  EditChatOptionPage(
                                    option: selectedOption,
                                  ),
                                  context: context);
                            }
                          },
                          icon: const Icon(Icons.edit),
                          tooltip: '编辑预设',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 优化类型选择
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '优化类型',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<OptimizationType>(
                      value: optimizationType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: OptimizationType.plot,
                          child: Text('剧情优化 (20K tokens)'),
                        ),
                        DropdownMenuItem(
                          value: OptimizationType.text,
                          child: Text('正文优化 (65.5K tokens)'),
                        ),
                        DropdownMenuItem(
                          value: OptimizationType.blank,
                          child: Text('不使用默认优化词'),
                        ),
                      ],
                      onChanged: (OptimizationType? value) {
                        setState(() {
                          optimizationType = value ?? OptimizationType.text;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      type_info,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.outline,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 上下文深度
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '上下文深度',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          contextDepth.toString(),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colors.primary,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: contextDepth.toDouble(),
                      min: 0,
                      max: 64,
                      divisions: 64,
                      label: contextDepth.toString(),
                      onChanged: (double value) {
                        setState(() {
                          contextDepth = value.toInt();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 上下文发送设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '上下文发送设置',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ContextSendMode>(
                      value: contextSendMode,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ContextSendMode.userAndAssistant,
                          child: Text('user与assistant'),
                        ),
                        DropdownMenuItem(
                          value: ContextSendMode.userOnly,
                          child: Text('仅user消息'),
                        ),
                        DropdownMenuItem(
                          value: ContextSendMode.assistantOnly,
                          child: Text('仅assistant消息'),
                        ),
                      ],
                      onChanged: (ContextSendMode? value) {
                        setState(() {
                          contextSendMode =
                              value ?? ContextSendMode.userAndAssistant;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 仅发送渲染内容
            Card(
              child: CheckboxListTile(
                title: const Text('仅发送渲染内容'),
                subtitle: const Text(
                    '勾选后发送经过"在渲染时应用"正则处理的内容，否则发送经过"在发送请求时应用"正则处理的内容'),
                value: onlyRenderContent,
                onChanged: (bool? value) {
                  setState(() {
                    onlyRenderContent = value ?? false;
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // Prompt预览
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Prompt预览',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton(
                          onPressed: () {
                            final previewMessages = _buildPreviewPrompt();
                            customNavigate(
                              PromptPreviewPage(messages: previewMessages),
                              context: context,
                            );
                          },
                          child: const Text('查看详细'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 120,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: colors.outline.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(8),
                        color: colors.surfaceContainerHighest.withOpacity(0.3),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _buildPreviewPrompt()
                              .map((msg) => '${msg.role}: ${msg.content}')
                              .join('\n\n'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
