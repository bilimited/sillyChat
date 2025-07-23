// ignore_for_file: invalid_use_of_protected_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/action_and_intents.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/pages/chat/search_page.dart';
import 'package:flutter_example/chat-app/pages/chat_options/chat_options_manager.dart';
import 'package:flutter_example/chat-app/pages/lorebooks/lorebook_manager.dart';
import 'package:flutter_example/chat-app/pages/settings/setting_page.dart';
import 'package:flutter_example/chat-app/pages/vault_manager.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/webdav_util.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'pages/chat/chat_page.dart';
import 'pages/character/contacts_page.dart'; // 添加这一行

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // ignore: unused_field
  static const String AppVersion = 'v1.11.1-alpha';

  int _currentIndex = 0;
  final VaultSettingController _vaultSettingController = Get.find();
  final CharacterController _characterController = Get.find();
  final ChatController _chatController = Get.find();

  final webDav = WebDavUtil();

  int desktop_destination_left = 0;
  int desktop_destination_right = 0;
  MessageModel? desktop_initialPosition;

  late List<Widget> _desktop_pages;

  CharacterModel get me => _characterController.me;

  void _showCharacterSelectDialog() async {
    CharacterModel? character = await customNavigate<CharacterModel>(
        CharacterSelector(),
        context: context);
    if (character != null) {
      _vaultSettingController.myId.value = character.id;
      await _vaultSettingController.saveSettings();
    }
  }

  void refleshAll() {
    SillyChatApp.restart();

    setState(() {
      desktop_destination_left = 0;
      desktop_destination_right = 0;
    });
  }

  void desktop_switchChat(int chatId) {
    _chatController.currentChat.value = chatId;
  }

  String getSizeString(int byteSize) {
    if (byteSize < 1024) {
      return '$byteSize B';
    } else if (byteSize < 1024 * 1024) {
      return '${(byteSize / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(byteSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  @override
  void initState() {
    super.initState();
    _desktop_pages = [
      ChatPage(onSelectChat: (chat) {
        setState(() {
          desktop_initialPosition = null;
          desktop_switchChat(chat.id);
        });
      }),
      ContactsPage(),
      ChatOptionsManagerPage(),
      LoreBookManagerPage(),
      Obx(() => SearchPage(
          chats: _chatController.chats.value,
          onMessageTap: (msg, chat) {
            setState(() {
              desktop_initialPosition = msg;
              desktop_switchChat(chat.id);
            });
          })),
    ];
    webDav.init();
  }

  final List<Widget> _pages = [
    ChatPage(),
    const ContactsPage(),
    ChatOptionsManagerPage(),
    LoreBookManagerPage(),
  ];

  Widget _buildDesktop(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const LEFT_WIDTH = 350.0;
    return Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL):
              const GotoLogPageIntent(),
        },
        child: Actions(
            actions: <Type, Action<Intent>>{
              GotoLogPageIntent: GotoLogPageAction(context),
            },
            child: FocusScope(
              autofocus: true,
                child: Scaffold(
              backgroundColor: colors.surface,
              body: Row(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child:
                            // NavigationRail as the left-side AppBar
                            NavigationRail(
                                selectedIndex: desktop_destination_left,
                                backgroundColor: colors.surface,
                                labelType: NavigationRailLabelType.all,
                                leading: Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: GestureDetector(
                                      onTap: _showCharacterSelectDialog,
                                      child: Obx(() => CircleAvatar(
                                            backgroundImage:
                                                Image.file(File(me.avatar))
                                                    .image,
                                            radius: 24,
                                          )),
                                    )),
                                destinations: [
                                  NavigationRailDestination(
                                    icon: const Icon(Icons.chat_bubble_outline),
                                    label: const Text('聊天'),
                                  ),
                                  NavigationRailDestination(
                                    icon: const Icon(Icons.person),
                                    label: const Text('角色'),
                                  ),
                                  NavigationRailDestination(
                                    icon:
                                        const Icon(Icons.settings_applications),
                                    label: const Text('对话预设'),
                                  ),
                                  NavigationRailDestination(
                                      icon: const Icon(Icons.book),
                                      label: const Text('世界书')),
                                  NavigationRailDestination(
                                    icon: const Icon(Icons.search),
                                    label: const Text('搜索'),
                                  ),
                                ],
                                onDestinationSelected: (index) {
                                  setState(() {
                                    desktop_destination_left = index;
                                  });
                                },
                                trailing: null),
                      ),
                      // 假Footer
                      Container(
                        width: 80, // 暂时和rail严丝合缝
                        color: colors.surface,
                        child: Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Column(
                              children: [
                                PopupMenuButton<int>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) {
                                    // 根据 value 执行不同操作
                                    if (value == 0) {
                                      customNavigate(SettingPage(),
                                          context: context);
                                    } else if (value == 1) {
                                      customNavigate(VaultManagerPage(),
                                          context: context);
                                    } else if (value == 2) {
                                      showLicensePage(context: context);
                                    } else if (value == 3) {}
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 0,
                                      child: Row(
                                        children: [
                                          Icon(Icons.settings, size: 20),
                                          SizedBox(width: 8),
                                          Text('设置'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 1,
                                      child: Row(
                                        children: const [
                                          Icon(Icons.switch_camera, size: 20),
                                          SizedBox(width: 8),
                                          Text('切换仓库'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 2,
                                      child: Row(
                                        children: const [
                                          Icon(Icons.info, size: 20),
                                          SizedBox(width: 8),
                                          Text('查看第三方证书'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Text('SillyChat',
                                    style: TextStyle(
                                        color: colors.outline, fontSize: 12)),
                                Text(
                                  SillyChatApp.getVersion(),
                                  style: TextStyle(
                                      color: colors.outline, fontSize: 12),
                                ),
                              ],
                            )),
                      ),
                    ],
                  ),

                  // 左侧内容区
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: colors.outline.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // 左侧固定宽度容器
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Container(
                                width: LEFT_WIDTH,
                                color: colors.surfaceContainer, // 可自定义颜色
                                child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (Widget child,
                                        Animation<double> animation) {
                                      return SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(-0.0, -0.2),
                                          end: Offset.zero,
                                        ).animate(CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        )),
                                        child: FadeTransition(
                                          opacity: CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeIn,
                                          ),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: IndexedStack(
                                      key: ValueKey(desktop_destination_left),
                                      index: desktop_destination_left,
                                      children: _desktop_pages,
                                    ))),
                          ),
                          // 主内容区（右侧），留出左侧容器宽度
                          Padding(
                            padding: const EdgeInsets.only(left: LEFT_WIDTH),
                            child: Container(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16.0),
                                  child: Obx(() => ChatDetailPage(
                                        key: ValueKey(
                                            '${_chatController.currentChat}_${desktop_initialPosition?.id ?? 0}'),
                                        chatId: _chatController.chats.isEmpty
                                            ? -1
                                            : _chatController.currentChat.value,
                                        initialPosition:
                                            desktop_initialPosition,
                                      )),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ))));
  }

  Widget _buildMobile(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: _currentIndex < 2
          ? AppBar(
              title: Obx(
                () => Row(
                  children: [
                    GestureDetector(
                      onTap: _showCharacterSelectDialog,
                      child: CircleAvatar(
                          radius: 20,
                          backgroundImage:
                              Image.file(File(_characterController.me.avatar))
                                  .image),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SettingController.currectValutName.isEmpty
                              ? "根目录"
                              : SettingController.currectValutName,
                          style: textTheme.titleLarge,
                        ),
                        Text(
                          "上次同步时间:${_vaultSettingController.lastSyncTimeString}",
                          style: textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    Get.to(() => SearchPage(
                          chats: Get.find<ChatController>().chats,
                          onMessageTap: (message, chat) {
                            Get.back();
                            Get.to(() => ChatDetailPage(
                                  chatId: chat.id,
                                  initialPosition: message,
                                ));
                          },
                        ));
                  },
                ),
                IconButton(
                  icon: Icon(Icons.switch_camera),
                  onPressed: () {
                    Get.to(() => VaultManagerPage());
                  },
                ),
                IconButton(
                    onPressed: () {
                      customNavigate(SettingPage(), context: context);
                    },
                    icon: Icon(Icons.settings))
              ],
            )
          : null,
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: '聊天',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: '通讯录',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_applications_outlined),
            selectedIcon: Icon(Icons.settings_applications),
            label: '聊天预设',
          ),
          NavigationDestination(
            icon: Icon(Icons.book),
            selectedIcon: Icon(Icons.settings_applications),
            label: '世界书',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (SillyChatApp.isDesktop()) {
      return _buildDesktop(context);
    } else {
      return _buildMobile(context);
    }
  }
}
