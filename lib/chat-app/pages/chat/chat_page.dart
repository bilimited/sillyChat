import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/models/settings/chat_displaysetting_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_message_list_view.dart';
import 'package:flutter_example/chat-app/pages/chat/flutter_chat_message_list.dart';
import 'package:flutter_example/chat-app/pages/chat/manage_message_page.dart';
import 'package:flutter_example/chat-app/pages/chat/message_optimization_page.dart';
import 'package:flutter_example/chat-app/pages/chat/simple_chat_file_page.dart';
import 'package:flutter_example/chat-app/pages/chat/webview_chat_message_list.dart';

import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/ModalUtil.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';

import 'package:flutter_example/chat-app/widgets/chat/bottom_input_area.dart';
import 'package:flutter_example/chat-app/widgets/lorebook/lorebook_activator.dart';
import 'package:flutter_example/chat-app/widgets/common/size_animated.dart';
import 'package:flutter_example/chat-app/widgets/common/toggle_chip.dart';
import 'package:flutter_example/main.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
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

  /// Scroll controller that bridges ChatPage to the active message list
  /// implementation (Flutter or WebView). Each implementation wires its
  /// concrete scroll behavior into this controller.
  final MessageListScrollController _scrollCtrl =
      MessageListScrollController();

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
      _scrollCtrl.scrollToBottom != null; // simplified

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
    _scrollCtrl.dispose();
    super.dispose();
  }

  // 保存对当前对话所作更改
  Future<void> _updateChat() async {
    sessionController.saveChat();
  }

  // ─── WebView UI-context callbacks ─────────────────────────────────────
  //
  // These are invoked by WebviewChatMessageListView when the Vue frontend
  // triggers actions that need Flutter UI context (Clipboard, Navigator,
  // ImagePicker, dialogs). The Flutter message list handles these actions
  // internally via its own BuildContext.

  void _onCopyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    SillyChatApp.snackbar(context, '复制成功');
  }

  void _onPasteMessages(String timeStr, String position) {
    final messagesToPaste = _chatController.messageToPaste;
    if (messagesToPaste.isEmpty) return;
    final msgList = chat.messages;
    final targetTime = DateTime.parse(timeStr);
    final idx = msgList.indexWhere((m) => m.time == targetTime);
    if (idx != -1) {
      final insertIdx = position == 'above' ? idx : idx + 1;
      msgList.insertAll(insertIdx, messagesToPaste);
      _updateChat();
      setState(() {});
    }
  }

  Future<void> _onPickImageForMessage(String timeStr) async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final time = DateTime.parse(timeStr);
      final msg = chat.messages.firstWhereOrNull((m) => m.time == time);
      if (msg != null) {
        setState(() {
          msg.resPath.add(pickedFile.path);
          _updateChat();
        });
      }
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
        isCopyFile: false, messages: branchMessages, name: '${chat.name}的分支');
    // 简单的复制聊天方法
    final fp =
        await ChatController.of.createChat(newChat, p.dirname(chat.file!.path));
    ChatController.of.openChat(fp);
  }

  void _showOptimizationDialog(MessageModel message) {
    customNavigate(
        MessageOptimizationPage(
          sessionController: sessionController,
          message: message,
        ),
        context: context);
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

  // ─── Message sending ────────────────────────────────────────────────

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

  // ─── Input bar ──────────────────────────────────────────────────────

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

  // ─── Main content (message list + input) ────────────────────────────

  Widget _buildMainContent() {
    return Column(
      children: [
        Expanded(
          child: useWebview
              ? WebviewChatMessageListView(
                  sessionController: sessionController,
                  scrollController: _scrollCtrl,
                  onReadingStateChanged: (bool isReading) {
                    setState(() => _isUserReading = isReading);
                  },
                  onCopyToClipboard: _onCopyToClipboard,
                  onPasteMessages: _onPasteMessages,
                  onPickImageForMessage: _onPickImageForMessage,
                  onCreateBranch: _createBranchFrom,
                  onOptimizeMessage: _showOptimizationDialog,
                  onMoreActions: _showMoreMessageButton,
                )
              : FlutterChatMessageListView(
                  sessionController: sessionController,
                  scrollController: _scrollCtrl,
                  onReadingStateChanged: (bool isReading) {
                    setState(() => _isUserReading = isReading);
                  },
                ),
        ),

        // 输入框
        _buildInputBar(),
      ],
    );
  }

  // ─── Scroll control (delegates to active message list) ──────────────

  void _scrollToMessage(MessageModel message) {
    _scrollCtrl.scrollToMessage?.call(message.id);
  }

  void _scrollToBottom() {
    _scrollCtrl.scrollToBottom?.call();
  }

  // ─── "To bottom" floating button ────────────────────────────────────

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
              onTap: () {
                _scrollToBottom();
                setState(() {
                  _isUserReading = false;
                });
              },
              customBorder: const CircleBorder(),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── App bar ────────────────────────────────────────────────────────

  PreferredSizeWidget? _buildAppBar() {
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.transparent,
          ),
        ),
      ),
      leading: _buildDrawerButton(),
      toolbarHeight: isDesktop ? 66 : null,
      scrolledUnderElevation: isDesktop ? 0 : 0,
      backgroundColor: Colors.transparent,

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
            icon: const Icon(Icons.history)),
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
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        if (value == 'local_summary') {
          sessionController.doLocalSummary();
        } else if(value == 'auto_title') {
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
              const SizedBox(width: 12),
              const Text('生成标题'),
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
              const SizedBox(width: 12),
              const Text('聊天内总结'),
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
              const SizedBox(width: 12),
              const Text('最近聊天'),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Background image ───────────────────────────────────────────────

  Widget _buildBackgroundImage() {
    return Stack(
      children: [
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

  // ─── Layout ─────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: colors.surface,

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
          CircularProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildDrawerButton() {
    return IconButton(
        onPressed: () {
          widget.scaffoldKey?.currentState?.openDrawer();
        },
        icon: const Icon(Icons.menu));
  }

  Widget _buildEmptyScreen() {
    return Scaffold(
        appBar: AppBar(leading: _buildDrawerButton()),
        body: Center(
            child:
                const Text("如果你看到了这个，一定是出了点啥问题。请点击左上角菜单按钮创建新聊天吧。")),
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
                  characters: chat.characters,
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
          duration: const Duration(milliseconds: 500),

          transitionBuilder: (Widget child, Animation<double> animation) {
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
