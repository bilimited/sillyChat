import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/models/settings/chat_displaysetting_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/chat/edit_chat.dart';
import 'package:flutter_example/chat-app/pages/chat/edit_message.dart';
import 'package:flutter_example/chat-app/pages/chat/manage_message_page.dart';
import 'package:flutter_example/chat-app/pages/chat/message_optimization_page.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_example/chat-app/widgets/chat/bottom_input_area.dart';
import 'package:flutter_example/chat-app/widgets/chat/message_bubble.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/chat/new_chat_buttons.dart';
import 'package:flutter_example/chat-app/widgets/sizeAnimated.dart';
import 'package:flutter_example/chat-app/widgets/toggleChip.dart';
import 'package:flutter_example/chat-app/widgets/webview/chat_webview.dart';
import 'package:flutter_example/chat-app/widgets/webview/message_webview.dart';
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

  const ChatPage(
      {Key? key, required this.sessionController, this.initialPosition})
      : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

enum ChatMode { manual, auto, group }

class _ChatPageState extends State<ChatPage> {
  late ChatSessionController sessionController;

  final ItemScrollController _scrollController = ItemScrollController();

  // 目前仅用于剪贴板
  final ChatController _chatController = Get.find<ChatController>();
  final CharacterController _characterController =
      Get.find<CharacterController>();
  final VaultSettingController _settingController = Get.find();

  final bool isDesktop = SillyChatApp.isDesktop();

  ChatDisplaySettingModel get displaySetting =>
      _settingController.displaySettingModel.value;

  double get avatarRadius => displaySetting.AvatarSize;

  // int chatId = 0;
  ChatModel get chat => sessionController.chat;
  ApiModel? get api => _settingController.getApiById(chat.requestOptions.apiId);

  bool _showWheel = false;

  // 添加选中消息状态
  MessageModel? _selectedMessage;
  bool _isMultiSelecting = false;
  // 被选中的消息（多选）
  List<MessageModel> _selectedMessages = [];

  ChatMode get mode => chat.mode ?? ChatMode.auto;
  bool get isAutoMode => mode == ChatMode.auto;
  bool get isGroupMode => mode == ChatMode.group;

  bool isThinkMode = false;

  // 是否为新聊天
  bool get isNewChat => chat.id == -1;
  // 在创建新聊天中是否可以发送消息。userId延迟初始化。
  bool get canCreateNewChat => chat.assistantId != null;

  bool get useWebview => false;

  List<LorebookItemModel> get manualItems {
    final global = Get.find<LoreBookController>().globalActivitedLoreBooks;
    final chars = chat.characters.expand((char) => char.loreBooks).toList();
    Set<LorebookItemModel> lst = {};
    for (final lorebook in [...global, ...chars]) {
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

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _registerController(widget.sessionController);
    // if (chat.mode != null) {
    //   mode = chat.mode!;
    //   print('$mode');
    // }

    if (widget.initialPosition != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMessage(widget.initialPosition!);
      });
    }
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
                              sessionController.updateMessage(
                                  message.time, message);
                            }
                            Get.back();
                          },
                          child: const Text('提交'),
                        ),
                        TextButton(
                          onPressed: () {
                            message.bookmark = null;
                            sessionController.updateMessage(
                                message.time, message);
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
                leading: const Icon(Icons.web),
                title: const Text('预览Html代码'),
                onTap: () async {
                  Get.to(() => MessageWebview(content: message.content));
                  // customNavigate(MessageWebview(content: message.content),
                  //     context: context);
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
            SillyChatApp.snackbar(context, '复制成功');
          },
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.auto_fix_high,
          label: '优化',
          onTap: () => _showOptimizationDialog(message),
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
          if (_isMultiSelecting) {
            _onMultiSelectMessage(message);
            return;
          }
          _selectedMessage =
              _selectedMessage?.time == message.time ? null : message;
        });
      },
      index: index,
      onLongPress: () => _startMultiSelect(message),
      buildBottomButtons: _buildMessageButtonGroup,
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
    final colors = Theme.of(context).colorScheme;
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
    )
        // :
        // Material(
        //     color: colors.surfaceContainerHighest.withOpacity(0.9),
        //     borderRadius: BorderRadius.circular(12),
        //     child: InkWell(
        //       borderRadius: BorderRadius.circular(12),
        //       onTap: onTap,
        //       child: Padding(
        //         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        //         child: Row(
        //           mainAxisSize: MainAxisSize.min,
        //           children: [
        //             Icon(icon, size: 14, color: iconColor),
        //           ],
        //         ),
        //       ),
        //     ),
        //   )
        ;
  }

  // 消息发送方法
  void _sendMessage(String text, List<String> selectedPath) async {
    if (text.isNotEmpty) {
      if (isNewChat) {
        await _updateChat();
      }

      sessionController.onSendMessage(text, selectedPath);
    }
  }

  void _copyThisChat() async {
    final newChat =
        chat.copyWith(isCopyFile: false, messages: [], name: chat.name + '-副本');
    // 简单的复制聊天方法
    final fp =
        await ChatController.of.createChat(newChat, p.dirname(chat.file.path));
    ChatController.of.currentChat.value = ChatSessionController(fp);
  }

  void _createBranchFrom(MessageModel fromWhere) async {
    // 获取fromWhere在messages中的下标
    final index = chat.messages.indexOf(fromWhere);
    // 截取fromWhere之前的所有消息（包括fromWhere本身）
    final branchMessages = chat.messages.sublist(0, index + 1);
    final newChat = chat.copyWith(
        isCopyFile: false, messages: branchMessages, name: chat.name + '的分支');
    // 简单的复制聊天方法
    final fp =
        await ChatController.of.createChat(newChat, p.dirname(chat.file.path));
    ChatController.of.currentChat.value = ChatSessionController(fp);
  }

  void _summaryInNewChat() async {
    final colors = Theme.of(context).colorScheme;
    // 显示加载对话框
    Get.dialog(
      AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text('正在生成总结...', style: TextStyle(color: colors.outline)),
          ],
        ),
      ),
      barrierDismissible: false,
    );
    final content = await sessionController.doSummaryBackground();
    if (SillyChatApp.isDesktop()) {
      Navigator.pop(context);
    } else {
      Get.back();
    }

    if (content.isEmpty) {
      return;
    }
    final newChat =
        chat.copyWith(isCopyFile: false, name: chat.name + '-总结', messages: [
      MessageModel(
          id: DateTime.now().microsecondsSinceEpoch,
          content: content,
          senderId: -2,
          time: DateTime.now(),
          alternativeContent: [null],
          style: MessageStyle.summary),
    ]);
    // 简单的复制聊天方法
    final fp =
        await ChatController.of.createChat(newChat, p.dirname(chat.file.path));
    ChatController.of.currentChat.value = ChatSessionController(fp);
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

  // 多选时的底部按钮组
  Widget _buildBottomButtonGroup() {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 131,
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
                          // _selectedMessages内消息的顺序与实际顺序不同。
                          // 因此需要先调整顺序
                          _chatController.putMessageToClipboard(
                              chat.messages, _selectedMessages);

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
                          _chatController.putMessageToClipboard(
                              chat.messages, _selectedMessages);
                          sessionController.removeMessages(_selectedMessages);
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
                          Icons.visibility_off,
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
                                      sessionController
                                          .removeMessages(_selectedMessages);
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

  Widget _buildInputBar() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: Colors
          .transparent, //isDesktop ? colors.surfaceContainerHigh : colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      // 底部输入框
      child: Stack(
        children: [
          // BottomInputArea 只在未多选时显示，但始终保留在树中
          Opacity(
            opacity: !_isMultiSelecting ? 1.0 : 0.0,
            child: IgnorePointer(
                ignoring: _isMultiSelecting,
                child: Obx(() {
                  final isGenerating = sessionController.aiState.isGenerating;

                  return BottomInputArea(
                    sessionController: sessionController,
                    onSendMessage: _sendMessage,
                    onRetryLastest: () {
                      sessionController.onRetry();
                    },
                    onToggleGroupWheel: () {
                      setState(() => _showWheel = !_showWheel);
                    },
                    onUpdateChat: _updateChat,
                    topToolBar: [
                      ToggleChip(
                          icon: Icons.chat,
                          text: '群聊模式',
                          initialValue: chat.mode == ChatMode.group,
                          onToggle: (value) {
                            setState(() {
                              if (chat.mode == ChatMode.group) {
                                chat.mode = ChatMode.auto;
                              } else {
                                chat.mode = ChatMode.group;
                              }
                            });

                            _updateChat();
                          }),
                      ...manualItems.map((item) {
                        return ToggleChip(
                            icon: Icons.book,
                            text: item.name,
                            initialValue: item.isActive,
                            onToggle: (val) {
                              item.isActive = val;
                              LoreBookController.of.saveLorebooks();
                            });
                      })
                    ],
                    havaBackgroundImage: chat.assistant.backgroundImage != null,
                    // TOOL BAR
                    toolBar: [
                      if (isGroupMode && !isGenerating)
                        IconButton(
                          icon: Icon(Icons.group, color: colors.outline),
                          onPressed: () {
                            setState(() => _showWheel = !_showWheel);
                          },
                        ),
                      // IconButton(
                      //     onPressed: _showLoreBookActiviator,
                      //     icon: Icon(
                      //       Icons.book,
                      //       color: colors.outline,
                      //     )),
                    ],
                  );
                })),
          ),
          // 多选时显示底部按钮组
          if (_isMultiSelecting) _buildBottomButtonGroup(),
        ],
      ),
    );
  }

  Widget _buildWebviewMessageList() {
    return ChatWebview(session: widget.sessionController);
  }

  Widget _buildFlutterMessageList() {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 0.0,
        maxHeight: double.infinity,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Stack(
          children: [
            Obx(() {
              //final messages = chat.messages.reversed.toList();
              final messages = chat.messages.reversed.toList();
              // 聊天正文
              return ScrollablePositionedList.builder(
                  reverse: true,
                  // TODO:页面原地刷新时  ScrollerController报错
                  // Failed assertion: line 264 pos 12: '_scrollableListState == null': is not true.
                  //itemScrollController: _scrollController,
                  itemCount: messages.length + 1,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      //正在（新）生成的Message，永远位于底部
                      return Obx(() => sessionController.aiState.isGenerating
                          ? _buildMessageBubble(
                              MessageModel(
                                  id: -9999,
                                  content: sessionController.aiState.LLMBuffer,
                                  senderId: sessionController
                                      .aiState.currentAssistant,
                                  time: DateTime.now(),
                                  alternativeContent: [null],
                                  style: sessionController.aiState.style),
                              messages.length == 0 ? null : messages[0])
                          : const SizedBox.shrink());
                    } else {
                      return Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: _isMultiSelecting ? 36 : 0,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: _isMultiSelecting
                                ? Icon(
                                    color: colors.secondary,
                                    _selectedMessages
                                            .contains(messages[index - 1])
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 20,
                                  )
                                : SizedBox.shrink(),
                          ),
                          Expanded(
                            child: Builder(builder: (context) {
                              final i = index - 1;

                              final message = messages[i];
                              return _buildMessageBubble(
                                  message,
                                  i < messages.length - 1
                                      ? messages[i + 1]
                                      : null,
                                  index: i,
                                  isNarration:
                                      message.style == MessageStyle.narration);
                            }),
                          )
                        ],
                      );
                    }
                  }
                  //},
                  );
            }),
          ],
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
                    sessionController.onGroupMessage(character);
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

  PreferredSizeWidget? _buildAppBar() {
    final colors = Theme.of(context).colorScheme;
    return isNewChat
        ? AppBar(
            backgroundColor: isDesktop ? colors.surfaceContainerHigh : null,
            actions: [],
          )
        : AppBar(
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.transparent, // 必须是透明的
                ),
              ),
            ),
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
            backgroundColor: Colors
                .transparent, //isDesktop ? colors.surfaceContainerHigh : null,

            title: Obx(
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
                                      size: 16.0,
                                    ),
                                  ),
                                  Text(
                                    '正在生成标题...',
                                    style: TextStyle(
                                        color: colors.outline, fontSize: 19),
                                  ),
                                ],
                              )
                            : Text(
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
              _buildMoreVertButton(),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  customNavigate(
                      ManageMessagePage(
                        chat: chat,
                        chatSessionController: sessionController,
                      ),
                      context: context);
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.settings,
                ),
                onPressed: () {
                  customNavigate(EditChatPage(session: sessionController),
                      context: context);
                },
              ),
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
        } else if (value == 'summary_in_new_chat') {
          // 执行操作2
          _summaryInNewChat();
        } else if (value == 'global_summary') {
          //final content = await sessionController.doSummaryBackground();
        } else if (value == 'new_chat') {
          _copyThisChat();
        } else if (value == 'auto_title') {
          sessionController.generateTitle();
        } else if (value == 'ai_help_answer') {
          sessionController.simulateUserMessage();
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
              Text('在聊天中总结'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'summary_in_new_chat',
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: Theme.of(context).iconTheme.color,
                size: 22,
              ),
              SizedBox(width: 12),
              Text('总结并开启新聊天'),
            ],
          ),
        ),
        // PopupMenuItem<String>(
        //   value: 'ai_help_answer',
        //   child: Row(
        //     children: [
        //       Icon(
        //         Icons.book,
        //         color: Theme.of(context).iconTheme.color,
        //         size: 22,
        //       ),
        //       SizedBox(width: 12),
        //       Text('AI帮答'),
        //     ],
        //   ),
        // ),
        PopupMenuItem<String>(
          value: 'new_chat',
          child: Row(
            children: [
              Icon(
                Icons.add_comment,
                color: Theme.of(context).iconTheme.color,
                size: 22,
              ),
              SizedBox(width: 12),
              Text('开启新话题'),
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

    return GestureDetector(
      onTap: () {
        if (_selectedMessage != null) {
          setState(() => _selectedMessage = null);
        }
      },
      child: Scaffold(
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
      extendBodyBehindAppBar: true,
      // floatingActionButton: _buildFloatingButtonOverlay(),
      backgroundColor: colors.surfaceContainerHigh,

      body: Stack(
        children: [
          if (chat.backgroundOrCharBackground != null) _buildBackgroundImage(),
          _buildMainContent(),
          _buildCharacterWheelOverlay(),
          _buildFloatingButtonOverlay()
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

  Widget _buildEmptyScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('未选择会话，请在左侧聊天窗口选择一个会话'), // 显示的文本 [3, 6]
        ],
      ),
    );
  }

  Widget _buildNewChatScreen() {
    VoidCallback selectCharacter = () async {
      CharacterModel? char = await customNavigate(
          CharacterSelector(excludeCharacters: [chat.user]),
          context: context);
      if (char != null) {
        chat.assistantId = char.id;
        if (char.firstMessage != null && char.firstMessage!.isNotEmpty) {
          sessionController.addMessage(
              message: MessageModel(
                  id: DateTime.now().millisecondsSinceEpoch,
                  content: char.firstMessage!,
                  senderId: char.id,
                  time: DateTime.now(),
                  alternativeContent: [null]));
        }

        _updateChat();
        sessionController.reflesh();
      }
    };

    return Padding(
      padding: EdgeInsetsGeometry.only(bottom: 30, left: 30, right: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          InkWell(
            child: AvatarImage.round(chat.assistant.avatar, 30),
            onTap: selectCharacter,
          ),
          SizedBox(
            height: 8,
          ),
          NewChatButtons(
            onSelectRole: selectCharacter,
            onTemplateSelected: (value) {
              final meta = value.meta!;
              final file = File(meta.path);
              final chat =
                  ChatModel.fromJson(json.decode(file.readAsStringSync()));
              chat.file = sessionController.file;
              sessionController.useChatTemplate(chat);
            },
          ),
        ],
      ),
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
            return;
          }
        },
        child: Obx(() => AnimatedSwitcher(
              // 1. 设置动画的持续时间
              duration: const Duration(milliseconds: 500),

              // 2. 提供一个 transitionBuilder 来自定义动画效果 (可选，但推荐)
              transitionBuilder: (Widget child, Animation<double> animation) {
                // 使用 FadeTransition 实现淡入淡出效果
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },

              child: sessionController.isChatLoading
                  ? Container(
                      key: const ValueKey('LoadScreen'),
                      child: !sessionController.isChatUninitialized
                          ? _buildLoadScreen()
                          : _buildEmptyScreen(),
                    )
                  : Container(
                      key: const ValueKey('ChatScreen'),
                      child: isDesktop
                          ? _buildDesktop(context)
                          : _buildMobile(context),
                    ),
            )));
  }
}
