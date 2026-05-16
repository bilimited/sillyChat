import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/constants.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/models/settings/chat_displaysetting_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/chat/edit_chat.dart';
import 'package:flutter_example/chat-app/pages/chat/edit_message.dart';
import 'package:flutter_example/chat-app/pages/chat/manage_message_page.dart';
import 'package:flutter_example/chat-app/pages/chat/message_optimization_page.dart';
import 'package:flutter_example/chat-app/pages/chat/simple_chat_file_page.dart';
import 'package:flutter_example/chat-app/pages/welcome_page.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/ModalUtil.dart';
import 'package:flutter_example/chat-app/utils/chat/goto_chat.dart';
import 'package:flutter_example/chat-app/utils/chat/simulate_user_helper.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_example/chat-app/widgets/chat/bottom_input_area.dart';
import 'package:flutter_example/chat-app/widgets/chat/message_bubble.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/chat/new_chat_buttons.dart';
import 'package:flutter_example/chat-app/widgets/lorebook/lorebook_activator.dart';
import 'package:flutter_example/chat-app/widgets/sizeAnimated.dart';
import 'package:flutter_example/chat-app/widgets/toggleChip.dart';
import 'package:flutter_example/chat-app/widgets/webview/chat_webview.dart';
import 'package:flutter_example/chat-app/widgets/webview/statusbar_webview.dart';
import 'package:flutter_example/main.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../models/message_model.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_controller.dart';
import '../../providers/character_controller.dart';
import '../../widgets/chat/character_wheel.dart';

import 'package:path/path.dart' as p;

class ChatPage extends StatefulWidget {
  // 从搜索界面跳转到聊天时，跳转的目标位置
  final ChatSessionController sessionController;
  final MessageModel? initialPosition;

  final GlobalKey<ScaffoldState>? scaffoldKey;

  const ChatPage(
      {Key? key,
      required this.sessionController,
      this.initialPosition,
      this.scaffoldKey})
      : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

enum ChatMode { manual, auto, group }

class _ChatPageState extends State<ChatPage> {
  late ChatSessionController sessionController;

  final ScrollController _scrollController = ScrollController();

  // 目前仅用于剪贴板
  final ChatController _chatController = Get.find<ChatController>();
  final VaultSettingController _settingController = Get.find();

  final bool isDesktop = SillyChatApp.isDesktop();

  ChatDisplaySettingModel get displaySetting =>
      _settingController.displaySettingModel.value;

  double get avatarRadius => displaySetting.AvatarSize;

  // int chatId = 0;
  ChatModel get chat => sessionController.chat;
  ApiModel? get api => _settingController.getApiById(chat.requestOptions.apiId);

  // 添加选中消息状态
  MessageModel? _selectedMessage;

  ChatMode get mode => chat.mode ?? ChatMode.auto;
  bool get isAutoMode => mode == ChatMode.auto;
  bool get isGroupMode => mode == ChatMode.group;

  // 是否为新聊天
  bool get isNewChat => chat.id == -1;
  // 在创建新聊天中是否可以发送消息。userId延迟初始化。
  bool get canCreateNewChat => chat.assistantId != null;

  bool get useWebview => false;

  List<LorebookItemModel> get manualItems {
    final global = Get.find<LoreBookController>().globalActivitedLoreBooks;
    final chars = chat.characters.expand((char) => char.loreBooks).toList();
    final stories = chat.bindStory?.loreBooks ?? [];
    Set<LorebookItemModel> lst = {};
    for (final lorebook in [...global, ...chars, ...stories]) {
      for (final item in lorebook.items) {
        if (item.activationType == ActivationType.manual) {
          lst.add(item);
        }
      }
    }
    return lst.toList();
  }

  // 正在重试的消息在消息列表中的位置（0代表新生成的消息,1代表最后一条消息）
  int generatingMessagePosition = 0;

  Future<List<String>>? simulateUserFuture;

  // 是否处于用户阅读历史的锁定状态
  bool _isUserReading = false;

  bool get isNearBottom =>
      _scrollController.hasClients && _scrollController.offset < 40;

  bool _isRendering = false;

  bool _showWheel = false;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!SettingController.of.checkVersion()) {
        SillyChatApp.showChangelogDialog(context: context);
        SettingController.of.updateVersion();
      }
    });

    _registerController(widget.sessionController);

    // if (widget.initialPosition != null) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     _scrollToMessage(widget.initialPosition!);
    //   });
    // }

    // sessionController.onLoadFinished = () {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     _jumpToTrueBottom();
    //     _isUserReading = false;
    //   });
    // };

    sessionController.onAIStateUpdate = () {
      final shouldStickToBottom = isNearBottom;
      // 更新前的数据
      final oldMaxExtent = _scrollController.position.maxScrollExtent;
      final oldOffset = _scrollController.offset;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        if (!shouldStickToBottom) {
          // 用户正在看历史，补偿被“顶上去”的距离
          final newMaxExtent = _scrollController.position.maxScrollExtent;
          final diff = newMaxExtent - oldMaxExtent;
          if (diff.abs() > 0.1) {
            final target = oldOffset + diff;
            _scrollController.jumpTo(
              target.clamp(
                0.0,
                _scrollController.position.maxScrollExtent,
              ),
            );
          }
        }
      });
    };

    // sessionController.onGenerateStart = () {
    //   setState(() {
    //     _isUserReading = false;
    //   });

    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     _scrollToBottom();
    //   });

    //_scrollToBottom();
    //};
  }

  void _registerController(ChatSessionController controller) {
    // 使用一个唯一的标识符 (tag) 来注册 controller
    final tag = controller.sessionId;

    // 如果Controller存在则复用
    if (Get.isRegistered<ChatSessionController>(tag: tag)) {
      sessionController = Get.find<ChatSessionController>(tag: tag);
      print('CONTROLLER$tag,复用!');
    } else {
      sessionController = Get.put(controller, tag: tag);
      print('CONTROLLER$tag,创建!');
    }

    sessionController.isViewActive = true;
  }

  @override
  void dispose() {
    sessionController.isViewActive = false;
    // 5. 销毁状态：当 State 对象被销毁时，清理掉它注册的 controller
    final tag = sessionController.sessionId;
    if (Get.isRegistered<ChatSessionController>(tag: tag) &&
        sessionController.canDestory) {
      Get.delete<ChatSessionController>(tag: tag);
      print('CONTROLLER$tag,销毁!');
    } else {
      print('CONTROLLER$tag,没有销毁!');
    }
    super.dispose();
  }

  // 保存对当前对话所作更改
  Future<void> _updateChat() async {
    sessionController.saveChat();
  }

  // 显示编辑消息对话框
  void _showEditDialog(MessageModel message) {
    customNavigate(
        EditMessagePage(sessionController: sessionController, message: message),
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
                leading: const Icon(Icons.image),
                title: const Text('添加图片'),
                onTap: () async {
                  Get.back();
                  final pickedFile = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  // final path =  await ImageUtils.selectAndCropImage(context,
                  //     isCrop: false);
                  if (pickedFile != null) {
                    setState(() {
                      message.resPath.add(pickedFile.path);
                      _updateChat();
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

  // 显示消息优化对话框
  void _showOptimizationDialog(MessageModel message) {
    customNavigate(
        MessageOptimizationPage(
          sessionController: sessionController,
          message: message,
        ),
        context: context);
  }

  // 选择消息时的底部操作菜单
  Widget _buildMessageToolbar(bool isSelected, MessageModel message) {
    return AnimatedOpacity(
      opacity: isSelected ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      // 当不可见时，设置 ignoring 为 true，屏蔽所有点击事件
      child: IgnorePointer(
        ignoring: !isSelected,
        child: _buildMessageToolbarCommon(message),
      ),
    );
  }

  Widget _buildMessageToolbarCommon(MessageModel message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      // 增加内边距让内部紧凑
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        // 背景色：使用 surfaceContainer 或 surface
        color: colorScheme.surfaceContainerLow,
        // 圆角：营造面板感
        borderRadius: BorderRadius.circular(10),
        // 边框：可选，让边缘更清晰
        border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.5), width: 0.5),
        // 阴影：增加层次感，防止与文字混合
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
          // --- 核心操作区 ---
          _buildCompactAction(
              Icons.edit_outlined, '编辑', () => _showEditDialog(message)),
          _buildCompactAction(Icons.copy_outlined, '复制', () async {
            await Clipboard.setData(ClipboardData(text: message.content));
            SillyChatApp.snackbar(context, '复制成功');
          }),
          _buildCompactAction(Icons.delete_outline, '删除',
              () => _showDeleteConfirmation(message)),

          // --- 条件按钮：重新生成 ---
          if (sessionController.isLastMessage(message) &&
              !sessionController.isGenerating)
            _buildCompactAction(
                Icons.refresh, '重试', () => sessionController.onRetry()),

          // --- 条件按钮：切换版本 (Alternative Content) ---
          if (message.alternativeContent.length > 1) ...[
            const VerticalDivider(width: 12, indent: 8, endIndent: 8), // 垂直分割线
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

          // --- 后置信息：字数 ---
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

  Widget _buildCompactAction(IconData icon, String? label, VoidCallback onTap) {
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
              // if (label != null) // 可选：如果希望极度紧凑，可以像微信一样长按才显示文字或只显示图标
              //   Text(label,
              //       style: TextStyle(
              //           fontSize: 9, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
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

    sessionController.updateMessage(message.time, message);
  }

  // 消息气泡
  Widget _buildMessageBubble(MessageModel message, MessageModel? lastMessage,
      {int index = 0, bool isNarration = false}) {
    var messageBubble = MessageBubble(
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
      onUpdateChat: _updateChat,
      state: sessionController.aiState,
    );

    // 防遮挡设计
    return chat.messages.isEmpty || message == chat.messages.first
        ? Column(
            children: [
              SizedBox(
                height: 104,
              ),
              messageBubble,
            ],
          )
        : messageBubble;
  }

  // 消息操作按钮小组件
  Widget _buildActionButton({
    required IconData icon,
    required String? label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return
        // isDesktop
        //     ?
        Material(
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
    );
  }

  // 消息发送方法
  void _sendMessage(String text, List<String> selectedPath) async {
    if (text.isNotEmpty) {
      if (isNewChat) {
        await _updateChat();
      }

      await sessionController.onSendMessage(text, selectedPath);

      _scrollToBottom();

      setState(() {
        _isUserReading = false;
      });
    }
  }

  void _createBranchFrom(MessageModel fromWhere) async {
    if (chat.file == null) {
      return;
    }
    // 获取fromWhere在messages中的下标
    final index = chat.messages.indexOf(fromWhere);
    // 截取fromWhere之前的所有消息（包括fromWhere本身）
    final branchMessages = chat.messages.sublist(0, index + 1);
    final newChat = chat.copyWith(
        isCopyFile: false, messages: branchMessages, name: chat.name + '的分支');
    // 简单的复制聊天方法
    final fp =
        await ChatController.of.createChat(newChat, p.dirname(chat.file!.path));
    ChatController.of.openChat(fp);
  }

  void _genMemory() async {
    if (sessionController
        .getAllCharactersInContext()
        .map((char) => CharacterController.of.getCharacterById(char))
        .where((char) => char.canGenMemory)
        .isEmpty) {
      SillyChatApp.snackbar(context, "没有可以用于生成记忆的角色，请先给角色添加记忆库");
      return;
    }

    final colors = Theme.of(context).colorScheme;
    Get.dialog(
      AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text('正在生成记忆...', style: TextStyle(color: colors.outline)),
          ],
        ),
      ),
      barrierDismissible: false,
    );

    await sessionController.genenateMemory();
    SillyChatApp.snackbar(context, "记忆生成成功!");
    if (SillyChatApp.isDesktop()) {
      Navigator.pop(context);
    } else {
      Get.back();
    }
    setState(() {});
  }

  Widget _buildInputBar() {
    return Container(
        color: Colors
            .transparent, //isDesktop ? colors.surfaceContainerHigh : colors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        // 底部输入框
        child: Obx(() {
          return BottomInputArea(
            sessionController: sessionController,
            onSendMessage: _sendMessage,
            onRetryLastest: () {
              sessionController.onRetry();
            },
            onUpdateChat: _updateChat,
            onShowWheel: () {
              setState(() {
                _showWheel = !_showWheel;
              });
            },
            topToolBar: [
              // ToggleChip(
              //     icon: Icons.chat,
              //     text: '手动模式',
              //     initialValue: chat.mode == ChatMode.group,
              //     onToggle: (value) {
              //       setState(() {
              //         if (chat.mode == ChatMode.group) {
              //           chat.mode = ChatMode.auto;
              //         } else {
              //           chat.mode = ChatMode.group;
              //         }
              //       });
              //       _updateChat();
              //     }),
              ...manualItems.map((item) {
                return ToggleChip(
                    // icon: Icons.book,
                    text: item.name,
                    initialValue: item.isActive,
                    onToggle: (val) {
                      item.isActive = val;
                      LoreBookController.of.saveLorebooks();
                    });
              }),
              ToggleChip(
                  icon: Icons.tune,
                  text: '',
                  initialValue: false,
                  asButton: true,
                  onToggle: (value) {
                    final global =
                        Get.find<LoreBookController>().globalActivitedLoreBooks;
                    final chars = chat.characters
                        .expand((char) => char.loreBooks)
                        .toSet();
                    final stories = chat.bindStory?.loreBooks ?? [];
                    if (chat.assistantId != null)
                      chars.addAll(chat.assistant!.loreBooks);
                    customNavigate(
                        LoreBookActivator(
                            chatSessionController: sessionController,
                            lorebooks: [
                              ...{...global, ...chars, ...stories}
                            ],
                            chat: chat),
                        context: context);
                  }),
            ],
            havaBackgroundImage: chat.assistant.backgroundImage != null,
          );
        }));
  }

  Widget _buildWebviewMessageList() {
    return ChatWebview(
      session: widget.sessionController,
      onMessageEmit: (args) {},
    );
  }

  Widget _buildToBottomButton() {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      bottom: 168,
      right: 24,
      child: AnimatedScale(
        scale: _isUserReading ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedOpacity(
          opacity: _isUserReading ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: colorScheme.surfaceVariant.withOpacity(0.9),
            elevation: 4,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              // 使用 InkWell 替代 IconButton，获得更灵活的控制
              onTap: () {
                _scrollToBottom();
                setState(() {
                  _isUserReading = false;
                });
              },
              customBorder: const CircleBorder(), // 确保涟漪效果是圆形的
              child: Container(
                width: 32, // 明确指定宽度
                height: 32, // 明确指定高度
                alignment: Alignment.center, // 居中图标
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colorScheme.primary,
                  size: 20, // 图标大小
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlutterMessageList() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 0.0,
        maxHeight: double.infinity,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification is UserScrollNotification) {
              // 在 reverse: true 下，ScrollDirection.forward 意味着手指往下拉（看旧消息）
              if (notification.direction == ScrollDirection.forward) {
                setState(() => _isUserReading = true);
              }
            }

            return false;
          },
          child: Stack(
            children: [
              Obx(() {
                final messages = chat.messages.reversed.toList();
                // 聊天正文
                return ListView.builder(
                    controller: _scrollController,
                    //itemScrollController: _scrollController,
                    reverse: true,
                    itemCount: messages.length + 1,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        //正在（新）生成的Message，永远位于底部
                        return Obx(() => sessionController.aiState.isGenerating
                            ? _buildMessageBubble(
                                MessageModel(
                                    id: -9999,
                                    content:
                                        sessionController.aiState.LLMBuffer,
                                    senderId: sessionController
                                        .aiState.currentAssistant,
                                    time: DateTime.now(),
                                    alternativeContent: [null],
                                    style: sessionController.aiState.style),
                                messages.length == 0 ? null : messages[0])
                            : const SizedBox.shrink());
                      } else {
                        return Builder(builder: (context) {
                          final i = index - 1;

                          final message = messages[i];
                          return _buildMessageBubble(message,
                              i < messages.length - 1 ? messages[i + 1] : null,
                              index: i,
                              isNarration:
                                  message.style == MessageStyle.narration);
                        });
                      }
                    }
                    //},
                    );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // 消息正文+输入框
  Widget _buildMainContent() {
    return Column(
      children: [
        Expanded(
          child: chat.messages.isEmpty
              ? _buildNewChatScreen()
              : useWebview
                  ? _buildWebviewMessageList()
                  : _buildFlutterMessageList(),
        ),

        // 输入框
        _buildInputBar(),
      ],
    );
  }

  void _scrollToMessage(MessageModel message) {}

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          // index: chat.messages.length,
          // alignment: -1,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOutQuad);
    }
  }

  void _jumpToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  PreferredSizeWidget? _buildAppBar() {
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.transparent, // 必须是透明的
          ),
        ),
      ),
      leading: _buildDrawerButton(),
      toolbarHeight: isDesktop ? 66 : null,
      scrolledUnderElevation: isDesktop ? 0 : 0,
      backgroundColor:
          Colors.transparent, //isDesktop ? colors.surfaceContainerHigh : null,

      title: InkWell(
        onTap: () {
          showEditDialog(
              title: "编辑标题",
              hintText: '请输入聊天标题',
              initialValue: chat.name,
              onConfirm: (name) {
                chat.name = name;
                setState(() {
                  _updateChat();
                });
              });
        },
        child: Obx(
          () => Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: sessionController.isGeneratingTitle.value
                        ? Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SpinKitWave(
                                  itemCount: 3,
                                  color: colors.onSurface,
                                  size: 15.0,
                                ),
                              ),
                              Text(
                                '正在生成标题...',
                                style: TextStyle(
                                    color: colors.outline, fontSize: 16),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Text(
                                chat.bindStory?.name ??
                                    chat.bindCharacter?.roleName ??
                                    "未知",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const Icon(Icons.chevron_right, size: 18.0),
                              Text(
                                chat.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                  Text(
                    "约 ${sessionController.cachedTokens} Tokens",
                    style: TextStyle(fontSize: 12, color: colors.outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
            onPressed: () {
              customNavigate(
                  SimpleChatFilesPage(
                      directoryPath: p.dirname(chat.file?.path ?? '')),
                  context: context);
            },
            icon: Icon(Icons.history)),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            customNavigate(
                ManageMessagePage(
                  chat: chat,
                  chatSessionController: sessionController,
                  onTapMessage: (message) {
                    _scrollToMessage(message);
                  },
                ),
                context: context);
          },
        ),
        _buildMoreVertButton(),
      ],
    );
  }

  Widget _buildMoreVertButton() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert),
      onSelected: (value) async {
        // 处理菜单项点击
        if (value == 'local_summary') {
          // 执行操作1
          sessionController.doLocalSummary();
        } else if (value == 'gen_memory') {
          _genMemory();
        } else if (value == 'auto_title') {
          sessionController.generateTitle();
        } else if (value == 'ai_help_answer') {
          sessionController.simulateUserMessage();
        } else if (value == 'search') {
          customNavigate(
              ManageMessagePage(
                chat: chat,
                chatSessionController: sessionController,
                onTapMessage: (message) {
                  _scrollToMessage(message);
                },
              ),
              context: context);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'auto_title',
          child: Row(
            children: [
              Icon(
                Icons.title,
                color: Theme.of(context).iconTheme.color,
                size: 22,
              ),
              SizedBox(width: 12),
              Text('生成标题'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'local_summary',
          child: Row(
            children: [
              Icon(
                Icons.summarize,
                color: Theme.of(context).iconTheme.color,
                size: 22,
              ),
              SizedBox(width: 12),
              Text('聊天内总结'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'recent_chat',
          child: Row(
            children: [
              Icon(
                Icons.history,
                color: Theme.of(context).iconTheme.color,
                size: 22,
              ),
              SizedBox(width: 12),
              Text('最近聊天'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundImage() {
    return Stack(
      children: [
        // 1. 背景图片
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: FileImage(File(chat.backgroundOrCharBackground!)),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        // 2. 模糊层
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: displaySetting.BackgroundImageBlur,
                sigmaY: displaySetting.BackgroundImageBlur),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        // 3. 半透明遮罩层
        Positioned.fill(
          child: Container(
            color: Theme.of(context)
                .colorScheme
                .surface
                .withOpacity(1 - displaySetting.BackgroundImageOpacity),
          ),
        ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: colors.surface,

      // APPBar
      appBar: _buildAppBar(),
      body: Container(
        child: Stack(
          children: [
            if (chat.backgroundOrCharBackground != null)
              _buildBackgroundImage(),
            _buildMainContent(),
            _buildCharacterWheelOverlay(),
            _buildToBottomButton()
          ],
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      // floatingActionButton: _buildFloatingButtonOverlay(),
      backgroundColor: colors.surfaceContainerHigh,

      body: Stack(
        children: [
          if (chat.backgroundOrCharBackground != null) _buildBackgroundImage(),
          _buildMainContent(),
        ],
      ),
      appBar: _buildAppBar(),
    );
  }

  Widget _buildLoadScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CircularProgressIndicator(), // 圆形进度指示器 [1]
        ],
      ),
    );
  }

  Widget _buildDrawerButton() {
    return IconButton(
        onPressed: () {
          widget.scaffoldKey?.currentState?.openDrawer();
        },
        icon: Icon(Icons.menu));
  }

  Widget _buildEmptyScreen() {
    return Scaffold(
      appBar: AppBar(leading: _buildDrawerButton()),
      body: WelcomePage(),
    );
  }

  Widget _buildNewChatScreen() {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCirc,
      builder: (context, offset, child) {
        final opacity = (1 - (offset.dy / 0.2)).clamp(0.0, 1.0);
        return FractionalTranslation(
          translation: offset,
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: 128, left: 30, right: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [Text("！？强强？！")],
        ),
      ),
    );
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
                      .map((id) => CharacterController.of.getCharacterById(id))
                      .toList(),
                  onCharacterSelected: (character) {
                    setState(() => _showWheel = false);
                    sessionController.onGroupMessage(character);
                  },
                ),
              ),
            ),
          ),
          visible: _showWheel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => AnimatedSwitcher(
          // 1. 设置动画的持续时间
          duration: const Duration(milliseconds: 500),

          // 2. 提供一个 transitionBuilder 来自定义动画效果 (可选，但推荐)
          transitionBuilder: (Widget child, Animation<double> animation) {
            // 使用 FadeTransition 实现淡入淡出效果
            return FadeTransition(opacity: animation, child: child);
          },

          child: sessionController.isChatUninitialized || _isRendering
              ? Container(
                  key: const ValueKey('LoadScreen'),
                  child: sessionController.isLoading.value
                      ? _buildLoadScreen()
                      : _buildEmptyScreen(),
                )
              : Container(
                  key: const ValueKey('ChatScreen'),
                  child: isDesktop
                      ? _buildDesktop(context)
                      : _buildMobile(context),
                ),
        ));
  }
}
