// file: lib/chat-app/widgets/chat/bottom_input_area.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/image_utils.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';

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

  final List<Widget> toolBar;

  BottomInputArea({
    Key? key,
    //required this.chatId,
    required this.sessionController,
    required this.onSendMessage,
    required this.onRetryLastest,
    required this.onToggleGroupWheel,
    required this.onUpdateChat,
    this.toolBar = const [],
    this.canSend = true,
    this.showPlus = true,
    this.showRetry = true,
    this.showToolBar = true,
  }) : super(key: key);

  @override
  State<BottomInputArea> createState() => _BottomInputAreaState();
}

class _BottomInputAreaState extends State<BottomInputArea> {
  final TextEditingController messageController = TextEditingController();
  bool get isGroupMode => widget.mode == ChatMode.group;
  bool get isAutoMode => widget.mode == ChatMode.auto;

  bool isThinkMode = false;
  List<String> selectedPath = [];

  void _pickImage() async {
    final path = await ImageUtils.selectAndCropImage(context, isCrop: false);
    if (path != null) {
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Define the core UI for the input card.
    Widget inputCard = Obx(() => Container(
          decoration: BoxDecoration(
            color: widget.isDesktop ? colors.surface : colors.surfaceContainer,
            boxShadow: widget.isDesktop
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              // Input field
              TextField(
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
                        children: [...widget.toolBar],
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

        // Input field and actions card
        Row(
          children: [
            Expanded(
              child:
                  finalInputArea, // Use the final wrapped or unwrapped widget
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
