import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_message_list_view.dart';
import 'package:flutter_example/chat-app/pages/chat/edit_message.dart';
import 'package:flutter_example/chat-app/pages/chat/message_optimization_page.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/chat/message_bubble.dart';
import 'package:flutter_example/chat-app/widgets/chat/new_chat_screen.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// Native Flutter message list implementation.
///
/// Renders messages using a [ListView.builder] with [MessageBubble] widgets.
/// Handles message selection, toolbar UI, alternative content switching,
/// and message action dialogs internally (has its own [BuildContext]).
class FlutterChatMessageListView extends ChatMessageListView {
  const FlutterChatMessageListView({
    super.key,
    required super.sessionController,
    required super.scrollController,
    required super.onReadingStateChanged,
  });

  @override
  State<FlutterChatMessageListView> createState() =>
      _FlutterChatMessageListState();
}

class _FlutterChatMessageListState extends State<FlutterChatMessageListView> {
  final ScrollController _scrollCtrl = ScrollController();

  late final ChatController _chatController = Get.find<ChatController>();

  // Currently selected message (for toolbar display)
  MessageModel? _selectedMessage;

  ChatSessionController get sessionController => widget.sessionController;
  ChatModel get chat => sessionController.chat;

  @override
  void initState() {
    super.initState();

    // Wire up scroll control so ChatPage can trigger scrolling
    widget.scrollController.scrollToBottom = () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutQuad);
      }
    };
    widget.scrollController.jumpToBottom = () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(0);
      }
    };
    widget.scrollController.scrollToMessage = (int messageId) {
      // Flutter scroll-to-message implementation — find index and scroll
      final messages = chat.messages;
      final idx = messages.indexWhere((m) => m.id == messageId);
      if (idx != -1 && _scrollCtrl.hasClients) {
        // reverse: true means index 0 is at bottom; convert
        final reversedIdx = messages.length - 1 - idx;
        final itemHeight = 120.0; // approximate
        final offset = reversedIdx * itemHeight;
        _scrollCtrl.animateTo(offset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuad);
      }
    };
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Message List ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 0.0,
        maxHeight: double.infinity,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification is UserScrollNotification) {
              // In reverse: true mode, ScrollDirection.forward means the
              // user is pulling down to read older messages.
              if (notification.direction == ScrollDirection.forward) {
                widget.onReadingStateChanged(true);
              }
            }
            return false;
          },
          child: Obx(() {
            final messages = chat.messages.reversed.toList();
            return ListView.builder(
              controller: _scrollCtrl,
              reverse: true,
              itemCount: messages.length + 1 + 1,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Currently generating message — always at the bottom
                  return Obx(() => sessionController.aiState.isGenerating
                      ? _buildMessageBubble(
                          MessageModel(
                              id: -9999,
                              content: sessionController.aiState.LLMBuffer,
                              senderId:
                                  sessionController.aiState.currentAssistant,
                              time: DateTime.now(),
                              alternativeContent: [null],
                              style: sessionController.aiState.style),
                          messages.isEmpty ? null : messages.first)
                      : const SizedBox.shrink());
                } else if (index == messages.length + 1) {
                  return NewChatScreen(chat: chat);
                } else {
                  return Builder(builder: (context) {
                    final i = index - 1;
                    final message = messages[i];
                    return _buildMessageBubble(
                        message,
                        i < messages.length - 1 ? messages[i + 1] : null,
                        index: i,
                        isNarration:
                            message.style == MessageStyle.narration);
                  });
                }
              },
            );
          }),
        ),
      ),
    );
  }

  // ─── Message Bubble ─────────────────────────────────────────────────

  Widget _buildMessageBubble(MessageModel message, MessageModel? lastMessage,
      {int index = 0, bool isNarration = false}) {
    return MessageBubble(
      chat: chat,
      message: message,
      isSelected: _selectedMessage == message,
      onTap: () {
        setState(() {
          _selectedMessage =
              _selectedMessage?.time == message.time ? null : message;
        });
      },
      index: index,
      buildBottomButtons: _buildMessageToolbar,
      onUpdateChat: sessionController.saveChat,
      state: sessionController.aiState,
    );
  }

  // ─── Message Toolbar ────────────────────────────────────────────────

  Widget _buildMessageToolbar(bool isSelected, MessageModel message) {
    return AnimatedOpacity(
      opacity: isSelected ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !isSelected,
        child: _buildMessageToolbarCommon(message),
      ),
    );
  }

  Widget _buildMessageToolbarCommon(MessageModel message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.5), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildCompactAction(
              Icons.edit_outlined, '编辑', () => _showEditDialog(message)),
          _buildCompactAction(Icons.copy_outlined, '复制', () async {
            await Clipboard.setData(ClipboardData(text: message.content));
            SillyChatApp.snackbar(context, '复制成功');
          }),
          _buildCompactAction(Icons.delete_outline, '删除',
              () => _showDeleteConfirmation(message)),

          // Retry button — only on last AI message when not generating
          if (sessionController.isLastMessage(message) &&
              !sessionController.isGenerating)
            _buildCompactAction(
                Icons.refresh, '重试', () => sessionController.onRetry()),

          // Alternative content version switcher
          if (message.alternativeContent.length > 1) ...[
            const VerticalDivider(width: 12, indent: 8, endIndent: 8),
            _buildCompactAction(Icons.chevron_left, null,
                () => _switchAlternativeContent(message, false)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '${message.alternativeContent.indexWhere((e) => e == null) + 1}/${message.alternativeContent.length}',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary),
              ),
            ),
            _buildCompactAction(Icons.chevron_right, null,
                () => _switchAlternativeContent(message, true)),
          ],

          _buildCompactAction(
              Icons.more_horiz, '更多', () => _showMoreMessageButton(message)),

          // Word count for assistant messages
          if (message.isAssistant) ...[
            const SizedBox(width: 6),
            Text(
              '${message.content.length}字',
              style: TextStyle(fontSize: 10, color: colorScheme.outline),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactAction(
      IconData icon, String? label, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Alternative Content ────────────────────────────────────────────

  void _switchAlternativeContent(MessageModel message, bool direction) {
    if (message.alternativeContent.length <= 1) {
      return;
    }
    int nullIndex = message.alternativeContent.indexWhere((e) => e == null);
    if (nullIndex == -1) return;

    int targetIndex;
    if (direction) {
      targetIndex = (nullIndex + 1) % message.alternativeContent.length;
    } else {
      targetIndex = (nullIndex - 1 + message.alternativeContent.length) %
          message.alternativeContent.length;
    }

    String oldContent = message.content;
    message.content = message.alternativeContent[targetIndex] ?? '';
    message.alternativeContent[nullIndex] = oldContent;
    message.alternativeContent[targetIndex] = null;

    sessionController.updateMessage(message.time, message);
  }

  // ─── Message Action Dialogs ─────────────────────────────────────────

  void _showEditDialog(MessageModel message) {
    customNavigate(
        EditMessagePage(
            sessionController: sessionController, message: message),
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
              sessionController.removeMessage(message.time);
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
                      await sessionController.saveChat();
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
                      await sessionController.saveChat();
                      setState(() {});
                    }
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('添加图片'),
                onTap: () async {
                  Get.back();
                  final pickedFile = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    setState(() {
                      message.resPath.add(pickedFile.path);
                      sessionController.saveChat();
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.call_split),
                title: const Text('从这里创建分支'),
                onTap: () {
                  Get.back();
                  _createBranchFrom(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('删除备选条目'),
                onTap: () {
                  Get.back();
                  message.alternativeContent.clear();
                  message.alternativeContent.add(null);
                  sessionController.updateMessage(message.time, message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_fix_high),
                title: const Text('消息优化'),
                onTap: () {
                  _showOptimizationDialog(message);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptimizationDialog(MessageModel message) {
    customNavigate(
        MessageOptimizationPage(
          sessionController: sessionController,
          message: message,
        ),
        context: context);
  }

  void _createBranchFrom(MessageModel fromWhere) async {
    if (chat.file == null) {
      return;
    }
    final index = chat.messages.indexOf(fromWhere);
    final branchMessages = chat.messages.sublist(0, index + 1);
    final newChat = chat.copyWith(
        isCopyFile: false, messages: branchMessages, name: '${chat.name}的分支');
    final fp = await ChatController.of
        .createChat(newChat, p.dirname(chat.file!.path));
    ChatController.of.openChat(fp);
  }
}
