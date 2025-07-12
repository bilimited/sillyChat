// file: lib/chat-app/widgets/chat/bottom_input_area.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
// import 'package:flutter_example/chat-app/pages/chat_detail_page.dart'; // For ChatMode enum
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/icon_switch_button.dart';
import 'package:flutter_example/chat-app/widgets/lorebook/lorebook_activator.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class BottomInputArea extends StatefulWidget {
  final int chatId;
  final ChatController chatController = Get.find();
  final ChatOptionController chatOptionController = Get.find();
  final VaultSettingController settingController = Get.find();
  final LoreBookController loreBookController = Get.find();
  bool get isDesktop => SillyChatApp.isDesktop();

  final Function(String, List<String>) onSendMessage;
  final VoidCallback onRetryLastest;
  final VoidCallback onToggleGroupWheel;
  final VoidCallback onUpdateChat;

  ChatModel get chat => chatController.getChatById(chatId);
  ChatMode get mode => chat.mode ?? ChatMode.auto;
  // bool get canCreateNewChat => chat.assistantId != null && chat.userId != null;
  ApiModel? get api => settingController.getApiById(chat.requestOptions.apiId);

  // TODO；给他删了
  bool get isThinkModeToggable => false;

  final bool canSend;
  final bool showRetry;
  final bool showPlus; // 是否显示添加图片/附件
  final bool showToolBar;

  BottomInputArea({
    Key? key,
    required this.chatId,
    required this.onSendMessage,
    required this.onRetryLastest,
    required this.onToggleGroupWheel,
    required this.onUpdateChat,
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
  final _imagePicker = ImagePicker();
  bool get isGroupMode => widget.mode == ChatMode.group;
  bool get isAutoMode => widget.mode == ChatMode.auto;

  bool isThinkMode = false;
  List<String> selectedPath = [];

  void _pickImage() {
    _imagePicker.pickImage(source: ImageSource.gallery).then((pickedFile) {
      if (pickedFile != null) {
        final newPaths = [...selectedPath, pickedFile.path];
        setState(() {
          selectedPath = newPaths;
        });
      }
    });
  }

  void _removeImage(int index) {
    setState(() {
      selectedPath.removeAt(index);
    });
  }

  void _submit() {
    if (!widget.canSend || messageController.text.isEmpty) {
      return;
    }
    widget.onSendMessage(messageController.text, [...selectedPath]);
    messageController.clear();
    selectedPath = [];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Obx(() => Column(
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
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
            // Action buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side switches
                if (widget.showToolBar)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isGroupMode &&
                          !widget.chatController.isLLMGenerating.value)
                        Opacity(
                          opacity: 0.6,
                          child: IconButton(
                            icon: const Icon(Icons.group),
                            onPressed: widget.onToggleGroupWheel,
                          ),
                        ),
                      IconButton(
                          onPressed: () {
                            Get.dialog(
                              AlertDialog(
                                title: const Text('切换对话预设'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: widget.chatOptionController
                                        .chatOptions.length,
                                    itemBuilder: (context, index) {
                                      final option = widget.chatOptionController
                                          .chatOptions[index];
                                      return ListTile(
                                        title: Text(option.name),
                                        onTap: () {
                                          setState(() {
                                            widget.chat.initOptions(option);
                                            widget.onUpdateChat();
                                            Get.back();
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.settings_applications,
                            color: colors.outline,
                          )),

                      IconButton(
                          onPressed: () {
                            final global = widget
                                .loreBookController.globalActivitedLoreBooks;
                            final chars = widget.chat.characters
                                .expand((char) => char.loreBooks)
                                .toList();
                            customNavigate(
                                LoreBookActivator(lorebooks: [
                                  ...{...global, ...chars}
                                ]),
                                context: context);
                            // Get.dialog(
                            //   AlertDialog(
                            //     title: const Text('手动激活世界书'),
                            //     content: SizedBox(
                            //       width: double.maxFinite,
                            //         child:
                            //     ),
                            //   ),
                            // );
                          },
                          icon: Icon(
                            Icons.book,
                            color: colors.outline,
                          )),
                      // Think mode toggle
                      if (widget.isThinkModeToggable)
                        IconSwitchButton(
                            value: widget.chat.requestOptions.isThinkMode,
                            label: '思考模式',
                            icon: Icons.psychology,
                            onChanged: (val) {
                              setState(() {
                                widget.chat.requestOptions = widget
                                    .chat.requestOptions
                                    .copyWith(isThinkMode: val);
                                widget.onUpdateChat();
                              });
                            }),
                    ],
                  ),
              ],
            ),
            const SizedBox(
              height: 2,
            ),
            // Input field row
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
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
                    // 输入框
                    child: TextField(
                      controller: messageController,
                      decoration: InputDecoration(
                        hintText: "Ask me anything..",
                        hintStyle: TextStyle(color: colors.outlineVariant),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: widget.isDesktop
                            ? colors.surface
                            : colors.surfaceContainer,
                        hoverColor: widget.isDesktop
                            ? colors.surface
                            : colors.surfaceContainer,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Group mode button

                            // Non-generating state buttons
                            if (!widget
                                .chatController.isLLMGenerating.value) ...[
                              if (widget.showPlus)
                                Opacity(
                                  opacity: 0.6,
                                  child: IconButton(
                                      onPressed: _pickImage,
                                      icon: const Icon(Icons.add, size: 22)),
                                ),
                              if (widget.showRetry &&
                                  (isAutoMode || isGroupMode))
                                Opacity(
                                  opacity: 0.6,
                                  child: IconButton(
                                    icon: const Icon(Icons.refresh, size: 22),
                                    onPressed: widget.onRetryLastest,
                                  ),
                                ),
                              const SizedBox(
                                width: 6,
                              ),
                              // 发送
                              Container(
                                margin: const EdgeInsets.only(
                                    right: 8, top: 8, bottom: 8),
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
                            // 停止生成
                            else
                              Container(
                                margin: const EdgeInsets.only(
                                    right: 8, top: 8, bottom: 8),
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
                                    widget.chatController.interrupt();
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      minLines: 1,
                      maxLines: 8,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 8,
            ),
          ],
        ));
  }
}
