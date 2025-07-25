import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/settings/chat_displaysetting_model.dart';
import 'package:flutter_example/chat-app/pages/ContentGenerator.dart';
import 'package:flutter_example/chat-app/pages/chat/edit_chat.dart';
import 'package:flutter_example/chat-app/pages/chat/edit_message.dart';
import 'package:flutter_example/chat-app/pages/chat/search_page.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/widgets/chat/bottom_input_area.dart';
import 'package:flutter_example/chat-app/widgets/chat/new_chat.dart';
import 'package:flutter_example/chat-app/widgets/chat/think_widget.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/sizeAnimated.dart';
import 'package:flutter_example/main.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../models/message_model.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_controller.dart';
import '../../providers/character_controller.dart';
import '../../widgets/chat/character_wheel.dart';

class ChatDetailPage extends StatefulWidget {
  final int chatId;
  // 从搜索界面跳转到聊天时，跳转的目标位置
  final MessageModel? initialPosition;

  const ChatDetailPage({Key? key, required this.chatId, this.initialPosition})
      : super(key: key);

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

enum ChatMode { manual, auto, group }

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ChatController _chatController = Get.find<ChatController>();
  final CharacterController _characterController =
      Get.find<CharacterController>();
  final VaultSettingController _settingController = Get.find();
  final _imagePicker = ImagePicker();

  final bool isDesktop = SillyChatApp.isDesktop();

  ChatDisplaySettingModel get displaySetting =>
      _settingController.displaySettingModel.value;

  double get avatarRadius => displaySetting.AvatarSize;

  int chatId = 0;
  ChatModel get chat => _chatController.getChatById(chatId);
  ApiModel? get api => _settingController.getApiById(chat.requestOptions.apiId);

  bool _showWheel = false;

  // 添加选中消息状态
  MessageModel? _selectedMessage;
  bool _isMultiSelecting = false;
  // 被选中的消息（多选）
  List<MessageModel> _selectedMessages = [];

  ChatMode mode = ChatMode.auto;
  bool get isAutoMode => mode == ChatMode.auto;
  bool get isGroupMode => mode == ChatMode.group;

  bool isThinkMode = false;

  // 是否为新聊天
  bool get isNewChat => chat.id == -1;
  // 在创建新聊天中是否可以发送消息。userId延迟初始化。
  bool get canCreateNewChat => chat.assistantId != null;

  // 正在重试的消息在消息列表中的位置（0代表新生成的消息,1代表最后一条消息）
  int generatingMessagePosition = 0;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
  }

  @override
  void initState() {
    super.initState();
    chatId = widget.chatId;
    if (chat.mode != null) {
      mode = chat.mode!;
    }

    if (widget.initialPosition != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMessage(widget.initialPosition!);
      });
    }
  }

  // 保存对当前对话所作更改
  Future<void> _updateChat() async {
    if (isNewChat) {
      final newChat = _chatController.saveDefaultChat();
      setState(() {
        chatId = newChat.id;
      });
      _chatController.currentChat.value = chatId;
    } else {
      await _chatController.saveChats(chat.fileId);
    }
  }

  // 显示编辑消息对话框
  void _showEditDialog(MessageModel message) {
    customNavigate(EditMessagePage(chatId: chatId, message: message),
        context: context);
  }

  void _showDeleteConfirmation(MessageModel message) {
    final colors = Theme.of(context).colorScheme;
    Get.dialog(
      AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定要删除这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _chatController.removeMessage(chatId, message.time);
              setState(() => _selectedMessage = null);
              Get.back();
            },
            child: Text('删除', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }

  // 显示更多消息操作（粘贴消息，书签、添加图片等等）
  void _showMoreMessageButton(MessageModel message) {
    final colors = Theme.of(context).colorScheme;
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_chatController.messageClipboard.isNotEmpty) ...[
                Text('剪贴板中共${_chatController.messageClipboard.length}条消息'),
                ListTile(
                  leading: const Icon(Icons.paste),
                  title: const Text('粘贴到上方'),
                  onTap: () async {
                    Get.back();
                    final messagesToPaste = _chatController.messageToPaste;
                    final msgList = chat.messages;
                    final idx =
                        msgList.indexWhere((m) => m.time == message.time);
                    if (idx != -1) {
                      msgList.insertAll(idx, messagesToPaste);
                      await _updateChat();
                      setState(() {});
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.paste),
                  title: const Text('粘贴到下方'),
                  onTap: () async {
                    Get.back();
                    final messagesToPaste = _chatController.messageToPaste;
                    final msgList = chat.messages;
                    final idx =
                        msgList.indexWhere((m) => m.time == message.time);
                    if (idx != -1) {
                      msgList.insertAll(idx + 1, messagesToPaste);
                      await _updateChat();
                      setState(() {});
                    }
                  },
                ),
              ],
              ListTile(
                leading: message.bookmark != null
                    ? const Icon(Icons.bookmark)
                    : const Icon(Icons.bookmark_add),
                title: message.bookmark != null
                    ? Text(message.bookmark!)
                    : const Text('设为书签'),
                onTap: () {
                  Get.back();
                  Get.dialog(
                    AlertDialog(
                      title: const Text('编辑书签'),
                      content: TextFormField(
                        initialValue: message.bookmark ?? '',
                        decoration: const InputDecoration(
                          hintText: '输入书签内容',
                        ),
                        onChanged: (value) {
                          message.bookmark = value;
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            if ((message.bookmark ?? '').isNotEmpty) {
                              _chatController.updateMessage(
                                  chatId, message.time, message);
                            }
                            Get.back();
                          },
                          child: const Text('提交'),
                        ),
                        TextButton(
                          onPressed: () {
                            message.bookmark = null;
                            _chatController.updateMessage(
                                chatId, message.time, message);
                            Get.back();
                          },
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  _updateChat();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('添加图片'),
                onTap: () {
                  Get.back();
                  _imagePicker
                      .pickImage(source: ImageSource.gallery)
                      .then((pickedFile) {
                    if (pickedFile != null) {
                      setState(() {
                        message.resPath.add(pickedFile.path);
                        _updateChat();
                      });
                    }
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet_rounded),
                title: const Text('LLM重写'),
                onTap: () async {
                  Get.back();
                  final result = await customNavigate<String?>(
                      ContentGenerator(
                          messages: [LLMMessage.fromMessageModel(message)]),
                      context: context);
                  if (result != null) {
                    message.content = result;
                    _updateChat();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('删除备选条目'),
                onTap: () {
                  Get.back();
                  message.alternativeContent.clear();
                  message.alternativeContent.add(null);
                  _chatController.updateMessage(chat.id, message.time, message);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 选择消息时的底部操作菜单
  Widget _buildMessageButtonGroup(bool isSelected, MessageModel message) {
    return AnimatedOpacity(
      opacity: isSelected ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: isSelected
          ? _buildMessageButtonGroupCommon(message)
          : const SizedBox.shrink(),
    );
  }

  Widget _buildMessageButtonGroupCommon(MessageModel message) {
    var colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: Icons.edit_outlined,
          label: '编辑',
          onTap: () {
            _showEditDialog(message);
          },
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.delete_outline,
          label: '删除',
          onTap: () => _showDeleteConfirmation(message),
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.copy,
          label: '复制',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: message.content));
            Get.showSnackbar(const GetSnackBar(
              message: "复制成功",
              duration: Duration(seconds: 1),
            ));
          },
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: message.isPinned
              ? Icons.push_pin_outlined
              : message.isHidden
                  ? Icons.hide_source_rounded
                  : Icons.remove_red_eye,
          label: 'Pin',
          iconColor: message.isPinned
              ? Colors.orange
              : message.isHidden
                  ? Colors.blueGrey
                  : null,
          onTap: () async {
            setState(() {
              if (message.isPinned) {
                message.visbility = MessageVisbility.hidden;
              } else if (message.isHidden) {
                message.visbility = MessageVisbility.common;
              } else {
                message.visbility = MessageVisbility.pinned;
              }
            });
            _updateChat();
          },
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.more_horiz,
          label: '更多',
          onTap: () => _showMoreMessageButton(message),
        ),
        const SizedBox(width: 8),
        if (message.alternativeContent.length > 1) ...[
          _buildActionButton(
            icon: Icons.chevron_left,
            label: null,
            onTap: () => _switchAlternativeContent(message, false),
          ),
          Padding(
            child: Text(
              '${message.alternativeContent.indexWhere((e) => e == null) + 1}/${message.alternativeContent.length}',
              style: TextStyle(fontSize: 12),
            ),
            padding: EdgeInsets.only(bottom: 2, left: 2, right: 2),
          ),
          _buildActionButton(
            icon: Icons.chevron_right,
            label: null,
            onTap: () => _switchAlternativeContent(message, true),
          ),
        ],
        if (message.isAssistant) ...[
          const SizedBox(width: 8),
          Text(
            '${message.content.length}字',
            style: TextStyle(fontSize: 12.0, color: colors.outline),
          )
        ],
      ],
    );
  }

  // 切换消息备选文本。direction：false为左，true为右
  void _switchAlternativeContent(MessageModel message, bool direction) {
    if (message.alternativeContent.length <= 1) {
      return;
    }
    // 获取当前null元素的位置
    int nullIndex = message.alternativeContent.indexWhere((e) => e == null);
    if (nullIndex == -1) return;

    // 计算目标位置
    int targetIndex;
    if (direction) {
      // 向右移动
      targetIndex = (nullIndex + 1) % message.alternativeContent.length;
    } else {
      // 向左移动
      targetIndex = (nullIndex - 1 + message.alternativeContent.length) %
          message.alternativeContent.length;
    }
    print("target:$targetIndex");

    // 移动null元素，并更新content
    String oldContent = message.content;
    message.content = message.alternativeContent[targetIndex] ?? '';
    message.alternativeContent[nullIndex] = oldContent;
    message.alternativeContent[targetIndex] = null;

    _chatController.updateMessage(chat.id, message.time, message);
  }

  void _showPhotoView(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(0),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: PhotoView(
              imageProvider: FileImage(File(imagePath)),
              backgroundDecoration: BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageImage(MessageModel message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: message.resPath.length == 1
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(message.resPath.first),
                    fit: BoxFit.contain,
                    height: 250, // 限制图片高度
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _showPhotoView(context, message.resPath.first),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        message.resPath.removeAt(0);
                        _updateChat();
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.resPath.asMap().entries.map((entry) {
                final idx = entry.key;
                final path = entry.value;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(path),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _showPhotoView(context, path),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            message.resPath.removeAt(idx);
                            _updateChat();
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
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
    );
  }

  // 若character为空则不显示发言者名称
  Widget _buildMessageUserName(
      MessageModel message, CharacterModel? character, bool isMe,
      {int index = 0}) {
    bool isNarration = character == null;

    bool shouldDisplayRoleName =
        (displaySetting.displayAssistantName && !isMe) ||
            (displaySetting.displayUserName && isMe);

    final widgets = [
      if (!isNarration && shouldDisplayRoleName) ...[
        Text(
          character.roleName,
          textScaler: TextScaler.linear(displaySetting.ContentFontScale),
        ),
        const SizedBox(width: 8)
      ],
      if (displaySetting.displayMessageIndex)
        Text(
          '#${chat.messages.length - index}',
          style: TextStyle(color: Colors.grey, fontSize: 12),
          textScaler: TextScaler.linear(displaySetting.ContentFontScale),
        ),
      if (displaySetting.displayMessageDate)
        Text(
          ' ${message.time.toIso8601String()} ',
          style: TextStyle(color: Colors.grey, fontSize: 12),
          textScaler: TextScaler.linear(displaySetting.ContentFontScale),
        ),
      // BookMark icon (blue)
      if (message.bookmark != null)
        const Icon(Icons.bookmark, color: Colors.blue, size: 16),
      // Pin icon (orange)
      if (message.isPinned)
        const Icon(Icons.push_pin, color: Colors.orange, size: 16),
      if (message.isHidden)
        const Icon(Icons.hide_source, color: Colors.blueGrey, size: 16),
    ];

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: isMe ? widgets.reversed.toList() : widgets,
        ),
        if (widgets.isNotEmpty)
          SizedBox(
            height: 4,
          ),
      ],
    );
  }

  Widget _buildMessageAvatar(CharacterModel character) {
    switch (displaySetting.avatarStyle) {
      case AvatarStyle.circle:
        return CircleAvatar(
          backgroundImage: Image.file(File(character.avatar)).image,
          radius: avatarRadius,
        );
      case AvatarStyle.rounded:
        return ClipRRect(
          borderRadius:
              BorderRadius.circular(displaySetting.AvatarBorderRadius),
          child: Image.file(
            File(character.avatar),
            width: avatarRadius * 2,
            height: avatarRadius * 2,
            fit: BoxFit.cover,
          ),
        );
      case AvatarStyle.hidden:
        return SizedBox.shrink();
      default:
        return CircleAvatar(
          backgroundImage: Image.file(File(character.avatar)).image,
          radius: avatarRadius,
        );
    }
  }

  // 消息气泡
  Widget _buildMessageBubble(MessageModel message, MessageModel? lastMessage,
      {int index = 0}) {
    final character = _characterController.getCharacterById(message.sender);
    final isMe = chat.user.id == message.sender;
    final isSelected = _selectedMessage?.time == message.time;

    final isHideName =
        lastMessage != null && lastMessage.sender == message.sender;

    String thinkContent = '';
    String afterThink = '';
    bool isThinking = false;

    // 内置正则：渲染<think>
    if (message.content.contains('<think>')) {
      int startIndex = message.content.indexOf('<think>') + 7;
      int endIndex = message.content.indexOf('</think>');

      if (endIndex == -1) {
        // Only has opening <think>
        thinkContent = message.content.substring(startIndex);
        afterThink = '';
        isThinking = true;
      } else {
        // Has both <think> and </think>
        thinkContent = message.content.substring(startIndex, endIndex);
        afterThink = message.content.substring(endIndex + 8);
      }
    } else {
      afterThink = message.content;
    }

    // 优化显示
    afterThink = afterThink.replaceAll('~', '〜');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          if (_isMultiSelecting) {
            _onMultiSelectMessage(message);
            return;
          }
          _selectedMessage =
              _selectedMessage?.time == message.time ? null : message;
        });
      },
      onLongPress: () => _startMultiSelect(message),
      // onLongPress: () => _showMessageOptions(message),
      child: Padding(
        padding: isHideName
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 3)
            : const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 4),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe && !isHideName) ...[
                  _buildMessageAvatar(character),
                  const SizedBox(width: 10),
                ],

                // 用于让连续消息对齐
                if (!isMe && isHideName)
                  SizedBox(
                    width: avatarRadius * 2 + 10,
                  ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!isHideName)
                        _buildMessageUserName(message, character, isMe,
                            index: index),

                      if (thinkContent.isNotEmpty)
                        //思考过程块
                        ThinkWidget(
                            isThinking: isThinking, thinkContent: thinkContent),
                      // 主消息气泡
                      _buildMessageBubbleBody(message, afterThink, isMe),
                      SizedBox(height: 8.0),
                      _buildMessageButtonGroup(isSelected, message),
                    ],
                  ),
                ),

                if (isMe && !isHideName) ...[
                  const SizedBox(width: 10),
                  _buildMessageAvatar(character),
                ],
                if (isMe && isHideName)
                  SizedBox(
                    width: avatarRadius * 2 + 10,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubbleBody(
      MessageModel message, String content, bool isMe) {
    final colors = Theme.of(context).colorScheme;

    final textColor =
        displaySetting.messageBubbleStyle == MessageBubbleStyle.bubble
            ? (isMe ? colors.onPrimary : colors.onSurfaceVariant)
            : colors.onSurfaceVariant;

    final isLoading = message.id == -9999;

    // 消息气泡里面的
    final messageContent = content.isEmpty
        // 消息为空显示转圈圈
        ? Container(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chat.aiState.GenerateState,
                  style: TextStyle(color: colors.outline),
                )
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.resPath.isNotEmpty) _buildMessageImage(message),
              MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: textColor,
                  ),
                  em: TextStyle(
                    color: isMe ? textColor : colors.outline,
                  ),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border.all(width: 1, color: colors.outlineVariant),
                  ),
                  textScaler:
                      TextScaler.linear(displaySetting.ContentFontScale),
                ),
                softLineBreak: true,
                shrinkWrap: true,
                inlineSyntaxes: [],
                // selectable: true,
              ),
            ],
          );

    // 气泡本身
    final bubble =
        displaySetting.messageBubbleStyle == MessageBubbleStyle.bubble
            ? Container(
                decoration: BoxDecoration(
                  color: isMe
                      ? colors.primary
                      : isDesktop
                          ? colors.surface
                          : colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(
                      displaySetting.MessageBubbleBorderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: messageContent)
            : displaySetting.messageBubbleStyle == MessageBubbleStyle.compact
                ? Column(
                    children: [
                      messageContent,
                      SizedBox(
                        height: 16,
                      )
                    ],
                  )
                : messageContent;

    // 气泡外的动画效果、加载条
    return AnimatedSize(
      alignment: Alignment.topLeft,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Stack(
        children: [
          bubble,
          if (isLoading)
            Positioned(
              left: 0,
              right: 0,
              top: 0, // 假设一个ProgressIndicator的高度
              child: const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }

  // 消息操作按钮小组件
  Widget _buildActionButton({
    required IconData icon,
    required String? label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final colors = Theme.of(context).colorScheme;
    return isDesktop
        ? Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor ?? Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          )
        : Material(
            color: colors.surfaceContainerHighest.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: iconColor),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildNarration(MessageModel message, {int index = 0}) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = _selectedMessage?.time == message.time;
    return GestureDetector(
      onLongPress: () => _startMultiSelect(message),
      onTap: () {
        setState(() {
          if (_isMultiSelecting) {
            _onMultiSelectMessage(message);
            return;
          }
          _selectedMessage =
              _selectedMessage?.time == message.time ? null : message;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
        child: Center(
            child: Column(
          children: [
            SizedBox(
              height: 16,
            ),
            if (message.resPath.isNotEmpty) _buildMessageImage(message),
            _buildMessageUserName(message, null, false, index: index),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: MarkdownBody(
                  data: message.content,
                  softLineBreak: true,
                  shrinkWrap: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: colors.outline),
                    textScaler:
                        TextScaler.linear(displaySetting.ContentFontScale),
                    horizontalRuleDecoration: BoxDecoration(
                      border:
                          Border.all(width: 1, color: colors.outlineVariant),
                    ),
                    // selectable: true,
                  )),
            ),
            SizedBox(
              height: 16,
            ),
            _buildMessageButtonGroup(isSelected, message)
          ],
        )),
      ),
    );
  }

  Widget _buildDivider(MessageModel message) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: GestureDetector(
        onLongPress: () => _startMultiSelect(message),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: colors.outline.withOpacity(0.3),
              ),
            ),
            if (message.content.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: colors.outline,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            Expanded(
              child: Container(
                height: 1,
                color: colors.outline.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 消息发送方法
  void _sendMessage(String text, List<String> selectedPath) async {
    if (text.isNotEmpty) {
      if (isNewChat) {
        await _updateChat();
      }
      setState(() {
        selectedPath = [];
      });

      _chatController.sendMessageAndGetReply(chat, text, selectedPath);
    }
  }

  void _startMultiSelect(MessageModel firstSelectedMessage) {
    setState(() {
      _selectedMessage = null;
      _isMultiSelecting = true;
      _selectedMessages = [];
      _selectedMessages.add(firstSelectedMessage);
    });
  }

  // 多选时选中消息的方法
  void _onMultiSelectMessage(MessageModel message) {
    setState(() {
      if (_selectedMessages.contains(message)) {
        _selectedMessages.remove(message);
      } else {
        _selectedMessages.add(message);
      }
    });
  }

  // 构建消息，包括三种已有的消息类型
  Widget _buildMessge(
      BuildContext context, int index, List<MessageModel> messages) {
    // 普通Message
    index = index - 1;

    final message = messages[index];
    if (message.type == MessageType.divider) {
      return _buildDivider(message);
    } else if (message.type == MessageType.narration) {
      return _buildNarration(message, index: index);
    }

    return _buildMessageBubble(
        message, index < messages.length - 1 ? messages[index + 1] : null,
        index: index);
  }

  // 多选时的底部按钮组
  Widget _buildBottomButtonGroup() {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 91,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // COPY MSG
                      IconButton(
                        onPressed: () {
                          _chatController.messageClipboard.value = [
                            ..._selectedMessages
                          ];
                          setState(() {
                            _isMultiSelecting = false;
                            _selectedMessages.clear();
                          });
                        },
                        icon: Icon(
                          Icons.copy_all,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      // CUT MSG
                      IconButton(
                        onPressed: () {
                          _chatController.messageClipboard.value = [
                            ..._selectedMessages
                          ];
                          _chatController.removeMessages(
                              chatId, _selectedMessages);
                          setState(() {
                            _isMultiSelecting = false;
                            _selectedMessages.clear();
                          });
                        },
                        icon: Icon(
                          Icons.cut,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            for (final msg in _selectedMessages) {
                              msg.visbility = MessageVisbility.hidden;
                            }
                            _updateChat();
                            _isMultiSelecting = false;
                            _selectedMessages.clear();
                          });
                        },
                        icon: Icon(
                          Icons.hide_source,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            for (final msg in _selectedMessages) {
                              msg.visbility = MessageVisbility.pinned;
                            }
                            _updateChat();
                            _isMultiSelecting = false;
                            _selectedMessages.clear();
                          });
                        },
                        icon: Icon(
                          Icons.push_pin,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            for (final msg in _selectedMessages) {
                              msg.visbility = MessageVisbility.common;
                            }
                            _updateChat();
                            _isMultiSelecting = false;
                            _selectedMessages.clear();
                          });
                        },
                        icon: Icon(Icons.remove_red_eye),
                        tooltip: '将可见性设为常规',
                      ),
                      IconButton(
                          onPressed: () {
                            Get.dialog(
                              AlertDialog(
                                title: const Text('删除消息'),
                                content: Text(
                                    '确定要删除${_selectedMessages.length}条消息吗？'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Get.back(),
                                      child: const Text('取消')),
                                  TextButton(
                                    child: const Text('确定'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: colors.error,
                                    ),
                                    onPressed: () {
                                      _chatController.removeMessages(
                                          chatId, _selectedMessages);
                                      setState(() {
                                        _isMultiSelecting = false;
                                        _selectedMessages.clear();
                                      });
                                      Get.back();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.delete,
                            color: colors.error,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 消息正文+输入框
  Widget _buildMainContent() {
    final colors = Theme.of(context).colorScheme;
    return isNewChat
        ? _buildNewChatScreen()
        : Column(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 0.0,
                    maxHeight: double.infinity,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Obx(() {
                      final messages = chat.messages.reversed.toList();
                      // 聊天正文
                      return ScrollablePositionedList.builder(
                          reverse: true,
                          itemScrollController: _scrollController,
                          itemCount: messages.length + 1,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              //正在（新）生成的Message，永远位于底部
                              return Obx(() => chat.aiState.isGenerating
                                  ? _buildMessageBubble(
                                      MessageModel(
                                          id: -9999,
                                          content: chat.aiState.LLMBuffer,
                                          sender: chat.aiState.currentAssistant,
                                          time: DateTime.now(),
                                          alternativeContent: [null]),
                                      messages.length == 0 ? null : messages[0])
                                  : const SizedBox.shrink());
                            } else {
                              return Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutCubic,
                                    width: _isMultiSelecting ? 36 : 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: _isMultiSelecting
                                        ? Icon(
                                            color: colors.secondary,
                                            _selectedMessages.contains(
                                                    messages[index - 1])
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            size: 20,
                                          )
                                        : SizedBox.shrink(),
                                  ),
                                  Expanded(
                                    child:
                                        _buildMessge(context, index, messages),
                                  )
                                ],
                              );
                            }
                          }
                          //},
                          );
                    }),
                  ),
                ),
              ),

              // 输入框
              Container(
                color: isDesktop ? colors.surfaceContainerHigh : colors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                // 底部输入框
                child: Stack(
                  children: [
                    // BottomInputArea 只在未多选时显示，但始终保留在树中
                    Opacity(
                      opacity: !_isMultiSelecting ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: _isMultiSelecting,
                        child: BottomInputArea(
                          chatId: chatId,
                          onSendMessage: _sendMessage,
                          onRetryLastest: () {
                            _chatController.retry(chat);
                          },
                          onToggleGroupWheel: () {
                            setState(() => _showWheel = !_showWheel);
                          },
                          onUpdateChat: _updateChat,
                        ),
                      ),
                    ),
                    // 多选时显示底部按钮组
                    if (_isMultiSelecting) _buildBottomButtonGroup(),
                  ],
                ),
              )
            ],
          );
  }

  // chat为空时的正文内容
  Widget _buildNewChatScreen() {
    return NewChat(
      onSubmit: (_p1, _p2) {
        _sendMessage(_p1, _p2);
      },
    );
  }

  Widget _buildFloatingButtonOverlay() {
    final colors = Theme.of(context).colorScheme;
    return _isMultiSelecting
        ? Positioned(
            bottom: 94,
            right: 24,
            child: Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.primary,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() {
                        if (_selectedMessages.isEmpty) {
                          return;
                        }
                        final lastSelected = _selectedMessages.last;
                        // Find current message index
                        int currentIndex = chat.messages
                            .indexWhere((msg) => msg.id == lastSelected.id);
                        if (currentIndex != -1) {
                          // Select all messages before current message
                          for (int i = currentIndex; i >= 0; i--) {
                            if (!_selectedMessages.contains(chat.messages[i])) {
                              _selectedMessages.add(chat.messages[i]);
                            }
                          }
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.arrow_upward,
                          size: 20, color: colors.onPrimary),
                    ),
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                Material(
                  color: Theme.of(context).colorScheme.primary,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() {
                        if (_selectedMessages.isEmpty) {
                          return;
                        }
                        final lastSelected = _selectedMessages.last;
                        // Find current message index
                        int currentIndex = chat.messages
                            .indexWhere((msg) => msg.id == lastSelected.id);
                        if (currentIndex != -1) {
                          // Select all messages after current message
                          for (int i = currentIndex;
                              i < chat.messages.length;
                              i++) {
                            if (!_selectedMessages.contains(chat.messages[i])) {
                              _selectedMessages.add(chat.messages[i]);
                            }
                          }
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.arrow_downward,
                          size: 20, color: colors.onPrimary),
                    ),
                  ),
                )
              ],
            ),
          )
        : SizedBox.shrink();
  }

  Widget _buildCharacterWheelOverlay() {
    return Positioned.fill(
      child: SizeAnimatedWidget(
          child: GestureDetector(
            onTap: () => setState(() => _showWheel = false),
            child: Container(
              child: Center(
                child: CharacterWheel(
                  characters: chat.characterIds
                      .map((id) => _characterController.getCharacterById(id))
                      .toList(),
                  onCharacterSelected: (character) {
                    setState(() => _showWheel = false);
                    _chatController.getGroupReply(chat, character);
                  },
                ),
              ),
            ),
          ),
          visible: _showWheel),
    );
  }

  void _scrollToMessage(MessageModel message) {
    final index = chat.messages.reversed.toList().indexOf(message);
    if (index >= 0 || index < chat.messages.length)
      _scrollController.scrollTo(
          index: index,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut);
  }

  void _scrollToTop() {
    _scrollController.scrollTo(
        index: chat.messages.length - 1,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut);
  }

  PreferredSizeWidget? _buildAppBar() {
    final colors = Theme.of(context).colorScheme;
    return isNewChat
        ? AppBar(
            backgroundColor: isDesktop ? colors.surfaceContainerHigh : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  customNavigate(EditChatPage(chat: chat), context: context);
                },
              ),
            ],
          )
        : AppBar(
            leading: _isMultiSelecting
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        _isMultiSelecting = false;
                        _selectedMessages = [];
                      });
                    },
                    icon: Icon(Icons.arrow_back))
                : null,
            toolbarHeight: isDesktop ? 66 : null,
            scrolledUnderElevation: isDesktop ? 0 : 0,
            backgroundColor: isDesktop ? colors.surfaceContainerHigh : null,
            title: Obx(
              () => Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.5,
                        child: Text(
                          chat.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 19),
                        ),
                      ),
                      Text(
                        "${chat.characterIds.length}位成员",
                        style: TextStyle(fontSize: 12, color: colors.outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  customNavigate(
                      SearchPage(
                        chats: [chat],
                        onMessageTap: (message, chat) {
                          Get.back();
                          _scrollToMessage(message);
                        },
                      ),
                      context: context);
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () {
                  final List<PopupMenuEntry<String>> menuItems = [
                    PopupMenuItem<String>(
                      child: CheckboxListTile(
                        title: const Text('聊天模式'),
                        value: isAutoMode,
                        onChanged: (bool? value) {
                          setState(() {
                            mode =
                                value == true ? ChatMode.auto : ChatMode.manual;
                            chat.mode = mode;
                            _updateChat();
                          });
                          Get.back(); // 关闭菜单
                        },
                      ),
                    ),
                    PopupMenuItem<String>(
                      child: CheckboxListTile(
                        title: const Text('群聊模式'),
                        value: isGroupMode,
                        onChanged: (bool? value) {
                          setState(() {
                            mode = value == true
                                ? ChatMode.group
                                : ChatMode.manual;
                            chat.mode = mode;
                            _updateChat();
                          });
                          Get.back(); // 关闭菜单
                        },
                      ),
                    ),
                  ];

                  showMenu(
                    context: context,
                    position: RelativeRect.fromLTRB(1000, 0, 0, 0),
                    items: menuItems,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  customNavigate(EditChatPage(chat: chat), context: context);
                },
              ),
            ],
          );
  }

  Widget _buildMobile(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        if (_selectedMessage != null) {
          setState(() => _selectedMessage = null);
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < 0) {
          Get.to(() => EditChatPage(chat: chat));
        }
      },
      child: Scaffold(
        backgroundColor: colors.surface,

        // APPBar
        appBar: _buildAppBar(),
        body: Container(
          child: Stack(
            children: [
              _buildMainContent(),
              _buildCharacterWheelOverlay(),
              _buildFloatingButtonOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      // floatingActionButton: _buildFloatingButtonOverlay(),
      backgroundColor: colors.surfaceContainerHigh,
      body: Stack(
        children: [
          _buildMainContent(),
          _buildCharacterWheelOverlay(),
          _buildFloatingButtonOverlay()
        ],
      ),
      appBar: _buildAppBar(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !_isMultiSelecting,
        onPopInvokedWithResult: (didPop, result) {
          if (_isMultiSelecting) {
            setState(() {
              _isMultiSelecting = false;
              _selectedMessages = [];
            });
          }
        },
        child: isDesktop ? _buildDesktop(context) : _buildMobile(context));
  }
}
