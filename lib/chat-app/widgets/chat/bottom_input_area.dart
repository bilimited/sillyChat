// file: lib/chat-app/widgets/chat/bottom_input_area.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_page.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/chat/history_command_picker.dart';
import 'package:flutter_example/chat-app/widgets/toggleChip.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Defines an intent to send a message.
class SendIntent extends Intent {
  const SendIntent();
}

class BottomInputArea extends StatefulWidget {
  //final int chatId;
  final ChatController chatController = Get.find();

  final ChatSessionController sessionController;

  final ChatOptionController chatOptionController = Get.find();
  final VaultSettingController settingController = Get.find();
  final LoreBookController loreBookController = Get.find();
  bool get isDesktop => SillyChatApp.isDesktop();

  final Function(String, List<String>) onSendMessage;
  final VoidCallback onRetryLastest;
  final VoidCallback onToggleGroupWheel;
  final VoidCallback onUpdateChat;

  ChatModel get chat => sessionController.chat;
  ChatMode get mode => chat.mode ?? ChatMode.auto;
  // bool get canCreateNewChat => chat.assistantId != null && chat.userId != null;
  ApiModel? get api => settingController.getApiById(chat.requestOptions.apiId);

  final bool canSend;
  final bool showRetry;
  final bool showPlus; // 是否显示添加图片/附件
  final bool showToolBar;
  final bool havaBackgroundImage;

  final List<Widget> toolBar;
  final List<Widget> topToolBar;

  BottomInputArea({
    Key? key,
    //required this.chatId,
    required this.sessionController,
    required this.onSendMessage,
    required this.onRetryLastest,
    required this.onToggleGroupWheel,
    required this.onUpdateChat,
    this.toolBar = const [],
    this.topToolBar = const [],
    this.canSend = true,
    this.showPlus = true,
    this.showRetry = true,
    this.showToolBar = true,
    this.havaBackgroundImage = false,
  }) : super(key: key);

  @override
  State<BottomInputArea> createState() => _BottomInputAreaState();
}

class _BottomInputAreaState extends State<BottomInputArea> {
  TextEditingController get messageController =>
      widget.sessionController.inputController; //TextEditingController();

  TextEditingController get commandController =>
      widget.sessionController.commandController;

  final FocusNode _focusNode = FocusNode(); // 1. 创建 FocusNode
  bool _isFocused = false; // 跟踪焦点状态

  bool _isDirectorPanelExpanded = false;

  bool get isGroupMode => widget.mode == ChatMode.group;
  bool get isAutoMode => widget.mode == ChatMode.auto;

  bool isThinkMode = false;
  List<String> selectedPath = [];

  @override
  void initState() {
    super.initState();
    // 2. 监听焦点变化
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    // 3. 移除监听并释放资源
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    //messageController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // 4. 当焦点变化时更新状态
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _pickImage() async {
    // 消息中发送的图片不会复制到应用路径
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    // await ImageUtils.selectAndCropImage(context, isCrop: false);

    if (pickedFile != null) {
      final path = pickedFile.path;
      final newPaths = [...selectedPath, path];
      setState(() {
        selectedPath = newPaths;
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      selectedPath.removeAt(index);
    });
  }

  void _submit() {
    if (!widget.canSend || messageController.text.trim().isEmpty) {
      return;
    }
    widget.onSendMessage(messageController.text, [...selectedPath]);
    messageController.clear();
    setState(() {
      selectedPath = [];
    });
  }

  Widget _buildDirectorModePanel() {
    final colors = Theme.of(context).colorScheme;
    final h = VaultSettingController.of().historyModel.value.commandHistory;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  // focusNode: _focusNode, // 6. 将 FocusNode 附加到 TextField
                  controller: commandController,
                  onChanged: (text) {
                    // 每次输入都触发 rebuild，确保 suffixIcon 最新
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    // labelText: "在这里输入附加指令",
                    hintText: "在这里输入附加指令",
                    hintStyle: TextStyle(color: colors.outlineVariant),

                    suffixIcon: commandController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              commandController.text = "";
                              setState(() {});
                            },
                            icon: Icon(Icons.close))
                        : IconButton(
                            onPressed: () async {
                              final command = await HistoryCommandPicker
                                  .showHistoryCommandPicker(context);
                              if (command != null) {
                                commandController.text = command;
                              }
                            },
                            icon: Icon(Icons.history)),
                  ),
                  minLines: 1,
                  maxLines: 3,
                  // onSubmitted is removed to allow custom handling via Actions.
                ),
              ),
              SizedBox(
                width: 6,
              ),
              IconButton(
                  onPressed: () {
                    widget.sessionController.isCommandPinned.value =
                        !widget.sessionController.isCommandPinned.value;
                  },
                  icon: Obx(() => widget.sessionController.isCommandPinned.value
                      ? Icon(
                          Icons.push_pin,
                          color: colors.primaryFixed,
                        )
                      : Icon(Icons.push_pin_outlined)))
            ],
          ),
          SizedBox(
            height: 8,
          ),
          Wrap(
            runSpacing: 4,
            direction: Axis.horizontal,
            children: widget.topToolBar,
          ),

          Divider(
            height: 24,
          ),
          // Divider(
          //   height: 16,
          // ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // 定义外发光效果
    final glowColor = colors.primary;
    var cardColor = widget.isDesktop ? colors.surface : colors.surfaceContainer;
    if (widget.havaBackgroundImage) {
      cardColor = cardColor.withOpacity(0.75);
    }

    // Define the core UI for the input card.
    Widget inputCard = Obx(() => AnimatedContainer(
          // 5. 使用 AnimatedContainer
          duration: const Duration(milliseconds: 200), // 过渡动画时长
          curve: Curves.easeInOut, // 动画曲线
          decoration: BoxDecoration(
            color: cardColor,
            border: _isFocused ? Border.all(color: glowColor, width: 2) : null,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              AnimatedSize(
                duration: Durations.medium1,
                curve: Curves.easeOut,
                child: _isDirectorPanelExpanded
                    ? _buildDirectorModePanel()
                    : SizedBox.shrink(),
              ),

              // Input field
              TextField(
                focusNode: _focusNode, // 6. 将 FocusNode 附加到 TextField
                controller: messageController,
                decoration: InputDecoration(
                  hintText: "Ask me anything..",
                  hintStyle: TextStyle(color: colors.outlineVariant),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                minLines: 1,
                maxLines: 8,
                // onSubmitted is removed to allow custom handling via Actions.
              ),

              // Toolbar and action buttons row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left side: Toolbar
                  if (widget.showToolBar)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.tune,
                                color: _isDirectorPanelExpanded
                                    ? colors.primaryFixed
                                    : colors.outline),
                            onPressed: () {
                              setState(() => _isDirectorPanelExpanded =
                                  !_isDirectorPanelExpanded);
                            },
                          ),
                          ...widget.toolBar
                        ],
                      ),
                    ),

                  const Spacer(),

                  // Right side: Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Non-generating state buttons
                      if (!widget.sessionController.aiState.isGenerating) ...[
                        if (widget.showPlus)
                          Opacity(
                            opacity: 0.6,
                            child: IconButton(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.add, size: 22)),
                          ),
                        if (widget.showRetry && (isAutoMode || isGroupMode))
                          Opacity(
                            opacity: 0.6,
                            child: IconButton(
                              icon: const Icon(Icons.refresh, size: 22),
                              onPressed: widget.onRetryLastest,
                            ),
                          ),

                        SizedBox(
                          width: 6,
                        ),
                        // Send button
                        Container(
                          margin: const EdgeInsets.only(
                              right: 8, top: 4, bottom: 4),
                          decoration: BoxDecoration(
                            color: widget.canSend
                                ? colors.primary
                                : colors.outline,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.send,
                              color: widget.canSend
                                  ? colors.onPrimary
                                  : colors.surface,
                              size: 18,
                            ),
                            onPressed: _submit,
                          ),
                        ),
                      ]
                      // Stop generating button
                      else
                        Container(
                          margin: const EdgeInsets.only(
                              right: 8, top: 4, bottom: 4),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.pause,
                              color: colors.onPrimary,
                              size: 18,
                            ),
                            onPressed: () {
                              widget.sessionController.interrupt();
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              SizedBox(
                height: 4,
              )
            ],
          ),
        ));

    // Conditionally wrap for desktop shortcuts.
    Widget finalInputArea;
    if (widget.isDesktop) {
      finalInputArea = Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          // Maps the Enter key to a SendIntent, overriding the default newline behavior.
          // Shift+Enter is not mapped, so it retains its default behavior of adding a newline.
          LogicalKeySet(LogicalKeyboardKey.enter): const SendIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            // Associates the SendIntent with the _submit action.
            SendIntent: CallbackAction<SendIntent>(
              onInvoke: (SendIntent intent) => _submit(),
            ),
          },
          child: inputCard,
        ),
      );
    } else {
      finalInputArea = inputCard;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image preview area
        if (selectedPath.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: selectedPath.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final path = entry.value;
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(path),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _removeImage(idx),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        // SingleChildScrollView(
        //   // 设置滚动方向为水平方向
        //   scrollDirection: Axis.horizontal,
        //   child: Row(
        //     children: widget.topToolBar,
        //   ),
        // ),
        // SizedBox(
        //   height: 12,
        // ),
        // Input field and actions card
        Row(
          children: [
            Expanded(
              child: SillyChatApp.isDesktop()
                  ? finalInputArea
                  : SafeArea(
                      top: false,
                      child:
                          finalInputArea), // Use the final wrapped or unwrapped widget
            ),
          ],
        ),
        const SizedBox(
          height: 8,
        ),
      ],
    );
  }
}
