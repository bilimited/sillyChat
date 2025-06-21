import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/pages/chat/edit_chat.dart';
import 'package:flutter_example/chat-app/pages/log_page.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/widgets/chat/think_widget.dart';
import 'package:flutter_example/chat-app/widgets/icon_switch_button.dart';
import 'package:flutter_example/chat-app/widgets/sizeAnimated.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/message_model.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_controller.dart';
import '../../providers/character_controller.dart';
import '../../widgets/chat/character_wheel.dart';

class ChatDetailPage extends StatefulWidget {
  // final ChatModel chat;
  final int chatId;

  const ChatDetailPage({Key? key, required this.chatId}) : super(key: key);

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

enum ChatMode { manual, auto, group }

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatController _chatController = Get.find<ChatController>();
  final CharacterController _characterController =
      Get.find<CharacterController>();
  final VaultSettingController _settingController = Get.find();
  final LogController _logController = Get.find();
  final ChatOptionController _chatOptionController = Get.find();
  final _imagePicker = ImagePicker();

  static const double avatarRadius = 25;

  ChatModel get chat => _chatController.getChatById(widget.chatId);
  ApiModel? get api => _settingController.getApiById(chat.requestOptions.apiId);

  bool _showWheel = false;
  // bool _autoSplit = false;

  CharacterModel get me =>
      _characterController.getCharacterById(chat.userId ?? -1);
  CharacterModel get assistantCharacter =>
      _characterController.getCharacterById(chat.assistantId ?? -1);
  int get assistantCharacterId => assistantCharacter.id;

  // 添加编辑消息的控制器
  final TextEditingController _editController = TextEditingController();

  // 添加选中消息状态
  MessageModel? _selectedMessage;
  bool _isMultiSelecting = false;
  // 被选中的消息（多选）
  List<MessageModel> _selectedMessages = [];

  ChatMode mode = ChatMode.auto;
  bool get isAutoMode => mode == ChatMode.auto;
  bool get isGroupMode => mode == ChatMode.group;

  bool get isThinkModeToggable =>
      api != null &&
      api!.provider == ServiceProvider.deepseek &&
      api!.modelName_think != '';
  bool isThinkMode = false;

  String test = "A";

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
  }

  @override
  void initState() {
    super.initState();
    if (chat.mode != null) {
      mode = chat.mode!;
    }
  }

  // 保存对当前对话所作更改
  Future<void> _updateChat() async {
    await _chatController.saveChats(chat.fileId);
  }

  // 显示编辑消息对话框
  void _showEditDialog(MessageModel message) {
    _editController.text = message.content;
    bool isAssistant = message.isAssistant;

    Get.dialog(
      AlertDialog(
        title: const Text('编辑消息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 200,
              ),
              child: SingleChildScrollView(
                child: TextField(
                  controller: _editController,
                  decoration: const InputDecoration(
                    hintText: '输入新的消息内容',
                  ),
                  maxLines: null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setState) {
                return CheckboxListTile(
                  title: const Text('assistant消息'),
                  value: isAssistant,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (bool? value) {
                    setState(() => isAssistant = value ?? false);
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (_editController.text.isNotEmpty) {
                message.content = _editController.text;
                message.isAssistant = isAssistant;
                _chatController.updateMessage(
                    widget.chatId, message.time, message);
                Get.back();
              }
            },
            child: const Text('保存'),
          ),
          TextButton(
            onPressed: () {
              if (_editController.text.isNotEmpty) {
                int firstNull = message.alternativeContent.indexOf(null);
                message.alternativeContent[firstNull] = message.content;
                message.alternativeContent.add(null);
                message.content = _editController.text;
                message.isAssistant = isAssistant;
                _chatController.updateMessage(chat.id, message.time, message);
                Get.back();
              }
            },
            child: const Text('追加保存'),
          ),
        ],
      ),
    );
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
              _chatController.removeMessage(widget.chatId, message.time);
              setState(() => _selectedMessage = null);
              Get.back();
            },
            child: Text('删除', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }

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
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('添加新条目'),
                onTap: () {
                  Get.back();
                  int firstNull = message.alternativeContent.indexOf(null);
                  message.alternativeContent[firstNull] = message.content;
                  message.alternativeContent.add(null);
                  message.content = " ";
                  _chatController.updateMessage(chat.id, message.time, message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('复制到新条目'),
                onTap: () {
                  Get.back();
                  int firstNull = message.alternativeContent.indexOf(null);
                  message.alternativeContent[firstNull] = message.content;
                  message.alternativeContent.add(null);
                  _chatController.updateMessage(chat.id, message.time, message);
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
          icon: Icons.edit,
          label: '编辑',
          onTap: () {
            _showEditDialog(message);
          },
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.delete,
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

  // 消息气泡
  Widget _buildMessageBubble(MessageModel message, MessageModel? lastMessage) {
    final colors = Theme.of(context).colorScheme;
    final character = _characterController.getCharacterById(message.sender);
    final isMe = chat.userId == message.sender;
    final avatar = character.avatar;
    final isSelected = _selectedMessage?.time == message.time;

    final isHideName =
        lastMessage != null && lastMessage.sender == message.sender;

    String thinkContent = '';
    String afterThink = '';
    bool isThinking = false;

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

    return GestureDetector(
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
                  CircleAvatar(
                    backgroundImage: Image.file(File(avatar)).image,
                    radius: avatarRadius,
                  ),
                  const SizedBox(width: 10),
                ],

                // 用于让连续消息对齐
                if (!isMe && isHideName)
                  const SizedBox(
                    width: avatarRadius * 2 + 10,
                  ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!isHideName) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          // 用户名
                          children: [
                            if (!isMe) Text(character.roleName),
                            if (!isMe) const SizedBox(width: 8),
                            if (isMe) const SizedBox(width: 8),
                            if (isMe) Text(character.roleName),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (thinkContent.isNotEmpty)
                        //思考过程块
                        ThinkWidget(
                            isThinking: isThinking, thinkContent: thinkContent),
                      Container(
                        padding: message.type == MessageType.image
                            ? null
                            : const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isMe ? colors.primary : colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: message.type == MessageType.image
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  frameBuilder: (context, child, frame,
                                      wasSynchronouslyLoaded) {
                                    if (frame == null) {
                                      return Container(
                                        width: 200,
                                        height: 100,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    return child;
                                  },
                                  File(message.resPath ?? ''),
                                  width: 200,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : message.content.isEmpty
                                // 消息为空显示转圈圈
                                ? Container(
                                    constraints:
                                        const BoxConstraints(maxWidth: 200),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: isMe
                                                ? colors.onPrimary
                                                : colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : MarkdownBody(
                                    data: afterThink,
                                    styleSheet: MarkdownStyleSheet(
                                      p: TextStyle(
                                        color: isMe
                                            ? colors.onPrimary
                                            : colors.onSurface,
                                      ),
                                    ),
                                    softLineBreak: true,
                                    shrinkWrap: true,
                                  ),
                      ),
                      SizedBox(height: 8.0),
                      _buildMessageButtonGroup(isSelected, message),
                    ],
                  ),
                ),

                if (isMe && !isHideName) ...[
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundImage: Image.file(File(avatar)).image,
                    radius: avatarRadius,
                  ),
                ],
                if (isMe && isHideName)
                  const SizedBox(
                    width: avatarRadius * 2 + 10,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 消息操作按钮小组件
  Widget _buildActionButton({
    required IconData icon,
    required String? label,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
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
              Icon(icon, size: 14),
              // 空间太小了啦！不显示label了！
              // if (label != null) ...[
              //   const SizedBox(width: 4),
              //   Text(label, style: const TextStyle(fontSize: 12)),
              // ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNarration(MessageModel message) {
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              height: 12,
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

  Future<void> _sendPicture() async {
    final XFile? image =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final message = MessageModel(
          id: DateTime.now().microsecondsSinceEpoch,
          content: '(这里是一张图片)',
          sender: chat.userId ?? 0,
          type: MessageType.image,
          time: DateTime.now(),
          resPath: image.path,
          alternativeContent: [null]);
      await _chatController.addMessage(
          chatId: widget.chatId, message: message, lastMessage: "[图片]");
      _messageController.clear();

      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 消息发送方法
  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      final message = MessageModel(
        id: DateTime.now().microsecondsSinceEpoch,
        content: _messageController.text,
        sender: chat.userId ?? -1,
        time: DateTime.now(),
        type: MessageTypeExtension.fromMessageStyle(me.messageStyle),
        isAssistant: false,
        alternativeContent: [null],
      );

      await _chatController.addMessage(chatId: widget.chatId, message: message);
      _messageController.clear();

      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      if (mode == ChatMode.group) {
        return;
        //await _chatController.handleLLMMessage(chat);
      } else if (mode == ChatMode.auto) {
        await for (var content
            in _chatController.handleLLMMessage(chat, think: isThinkMode)) {
          _handleAIResult(content, assistantCharacterId);
        }
      } else {
        return;
      }
    }
  }

  // 重新发送ai请求（会自动追加在最新的AI回复后面。若无最新AI回复且为群聊模式，则不可用）
  Future<void> retryLastest() async {
    final msgList = _chatController.getChatById(chat.id).messages;
    MessageModel? message = msgList[msgList.length - 1];
    if (message.isAssistant) {
      _chatController.removeMessage(chat.id, message.time);
    } else {
      message = null;
    }
    if (mode == ChatMode.auto) {
      await for (var content
          in _chatController.handleLLMMessage(chat, think: isThinkMode)) {
        _handleAIResult(content, assistantCharacterId, existedMessage: message);
      }
    } else if (mode == ChatMode.group && message != null) {
      await for (var content in _chatController.handleLLMMessage(chat,
          sender: _characterController.getCharacterById(message.sender),
          think: isThinkMode)) {
        _handleAIResult(content, message.sender, existedMessage: message);
      }
    }
  }

  void _groupMessage(CharacterModel sender) async {
    await for (var content in _chatController.handleLLMMessage(chat,
        sender: sender, think: isThinkMode)) {
      _handleAIResult(content, sender.id);
    }
  }

  void _startMultiSelect(MessageModel firstSelectedMessage) {
    setState(() {
      _selectedMessage = null;
      _isMultiSelecting = true;
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

  Future<void> _handleAIResult(String content, int senderID,
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
      isAssistant: true,
      token: _chatController.chatAIHandler.token_used,
      alternativeContent: existedContent,
    );
    await _chatController.addMessage(chatId: widget.chatId, message: AIMessage);
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
      return _buildNarration(message);
    }
    return _buildMessageBubble(
      message,
      index < messages.length - 1 ? messages[index + 1] : null,
    );
  }

  // 底部输入框
  Widget _buildBottomInputArea() {
    final colors = Theme.of(context).colorScheme;
    return Obx(() => Column(
          children: [
            // Input field row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "发送者:${me.name}",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colors.surfaceContainer,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
              ],
            ),

            // Action buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side switches
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        onPressed: () {
                          Get.dialog(
                            AlertDialog(
                              title: Text('切换对话配置'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount:
                                      _chatOptionController.chatOptions.length,
                                  itemBuilder: (context, index) {
                                    final option = _chatOptionController
                                        .chatOptions[index];
                                    return ListTile(
                                      title: Text(option.name),
                                      onTap: () {
                                        setState(() {
                                          chat.initOptions(option);
                                        });
                                        _updateChat();
                                        Get.back();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.settings_applications)),
                    // Think mode toggle
                    if (isThinkModeToggable)
                      IconSwitchButton(
                          value: chat.requestOptions.isThinkMode,
                          label: '思考模式',
                          icon: Icons.psychology,
                          onChanged: (val) {
                            setState(() {
                              chat.requestOptions = chat.requestOptions
                                  .copyWith(isThinkMode: val);
                              _updateChat();
                            });
                          }),
                  ],
                ),

                // Right side action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Group mode button
                    if (isGroupMode)
                      IconButton(
                        icon: Icon(Icons.group),
                        onPressed: () {
                          setState(() => _showWheel = !_showWheel);
                        },
                      ),

                    // Non-generating state buttons
                    if (!_chatController.isLLMGenerating.value) ...[
                      if (mode == ChatMode.auto || mode == ChatMode.group)
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: retryLastest,
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.image),
                          onPressed: _sendPicture,
                        ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendMessage,
                      ),
                    ]
                    // Generating state button
                    else
                      SizedBox(
                        width: 96,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            _chatController.interrupt();
                          },
                          child: Icon(
                            Icons.pause,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ));
  }

  // 多选时的底部按钮组
  Widget _buildBottomButtonGroup() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_upward,
                color: colors.onPrimary,
              ),
              style: IconButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(8),
                backgroundColor: colors.primary,
              ),
              onPressed: () {
                setState(() {
                  if (_selectedMessages.isEmpty) {
                    return;
                  }
                  final lastSelected = _selectedMessages.last;
                  // Find current message index
                  int currentIndex = chat.messages
                      .indexWhere((msg) => msg.time == lastSelected.time);
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
            ),
            SizedBox(
              height: 12,
            ),
            IconButton(
              icon: Icon(
                Icons.arrow_downward,
                color: colors.onPrimary,
              ),
              style: IconButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(8),
                backgroundColor: colors.primary,
              ),
              onPressed: () {
                setState(() {
                  if (_selectedMessages.isEmpty) {
                    return;
                  }
                  final lastSelected = _selectedMessages.last;
                  // Find current message index
                  int currentIndex = chat.messages
                      .indexWhere((msg) => msg.time == lastSelected.time);
                  if (currentIndex != -1) {
                    // Select all messages after current message
                    for (int i = currentIndex; i < chat.messages.length; i++) {
                      if (!_selectedMessages.contains(chat.messages[i])) {
                        _selectedMessages.add(chat.messages[i]);
                      }
                    }
                  }
                });
              },
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Get.dialog(
                          AlertDialog(
                            title: const Text('删除消息'),
                            content:
                                Text('确定要删除${_selectedMessages.length}条消息吗？'),
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
                                  for (var message in _selectedMessages) {
                                    _chatController.removeMessage(
                                        widget.chatId, message.time);
                                  }
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
                      child: Text(
                        '删除',
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isMultiSelecting = false;
                          _selectedMessages.clear();
                        });
                      },
                      child: Text('取消'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
        appBar: AppBar(
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
            Obx(
              () => IconButton(
                icon: _logController.unread != 0
                    ? Badge(
                        label: Text('${_logController.unread}'),
                        child: const Icon(Icons.warning),
                      )
                    : const Icon(Icons.warning),
                onPressed: () {
                  LogController.to.clearUnread();
                  Get.to(() => LogPage());
                },
              ),
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
                          mode =
                              value == true ? ChatMode.group : ChatMode.manual;
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
                Get.to(() => EditChatPage(chat: chat));
              },
            ),
          ],
        ),

        body: Container(
          // 背景图
          // decoration: assistantCharacter.backgroundImage != null
          //     ? BoxDecoration(
          //         image: DecorationImage(
          //           image: FileImage(File(assistantCharacter.backgroundImage!)),
          //           fit: BoxFit.cover,
          //         ),
          //       )
          //     : null,
          child: Stack(
            children: [
              Column(
                children: [
                  // 消息正文
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
                          return ListView.builder(
                            reverse: true,
                            controller: _scrollController,
                            itemCount: messages.length + 1,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // 正在生成的Message
                                return Obx(() =>
                                    _chatController.isLLMGenerating.value
                                        ? _buildMessageBubble(
                                            MessageModel(
                                                id: -9999,
                                                content: _chatController
                                                    .LLMMessageBuffer.value,
                                                sender: _chatController
                                                    .currentAssistant.value,
                                                time: DateTime.now(),
                                                alternativeContent: [null]),
                                            messages.length == 0
                                                ? null
                                                : messages[0])
                                        : const SizedBox.shrink());
                              } else {
                                if (_isMultiSelecting) {
                                  return Row(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0),
                                        child: Icon(
                                          color: colors.secondary,
                                          _selectedMessages
                                                  .contains(messages[index - 1])
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          size: 20,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildMessge(
                                            context, index, messages),
                                      )
                                    ],
                                  );
                                } else {
                                  return _buildMessge(context, index, messages);
                                }
                              }
                            },
                          );
                        }),
                      ),
                    ),
                  ),

                  // 输入框
                  Container(
                      color: colors.surfaceBright,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      // 底部输入框
                      child: !_isMultiSelecting
                          ? _buildBottomInputArea()
                          : _buildBottomButtonGroup()),
                ],
              ),
              Positioned.fill(
                child: SizeAnimatedWidget(
                    child: GestureDetector(
                      onTap: () => setState(() => _showWheel = false),
                      child: Container(
                        child: Center(
                          child: CharacterWheel(
                            characters: chat.characterIds
                                .map((id) =>
                                    _characterController.getCharacterById(id))
                                .toList(),
                            onCharacterSelected: (character) {
                              setState(() => _showWheel = false);
                              _groupMessage(character);
                            },
                          ),
                        ),
                      ),
                    ),
                    visible: _showWheel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
