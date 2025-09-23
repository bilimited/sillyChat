import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/character/contacts_page.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_file_manager.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_page.dart';
import 'package:flutter_example/chat-app/pages/chat_options/chat_options_manager.dart';
import 'package:flutter_example/chat-app/pages/lorebooks/lorebook_manager.dart';
import 'package:flutter_example/chat-app/pages/settings/setting_page.dart';
import 'package:flutter_example/chat-app/pages/vault_manager.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';

class MainPageMobile extends StatefulWidget {
  const MainPageMobile({super.key});

  @override
  State<MainPageMobile> createState() => _MainPageMobileState();
}

class _MainPageMobileState extends State<MainPageMobile> {
  //final PageController _pageController = PageController();

  final GlobalKey<NavigatorState> _leftPageNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _rightPageNavigatorKey =
      GlobalKey<NavigatorState>();

  DateTime? _lastPressedBackAt; // 实现再按一次退出

  @override
  void dispose() {
    //_pageController.dispose();
    super.dispose();
  }

  CharacterModel get me => CharacterController.of.me;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (ChatController.of.pageController.page == 0) {
              final bool? canPopInner =
                  await _leftPageNavigatorKey.currentState?.maybePop();
              if (canPopInner == false) {
                final now = DateTime.now();
                if (_lastPressedBackAt == null ||
                    now.difference(_lastPressedBackAt!) >
                        const Duration(seconds: 2)) {
                  _lastPressedBackAt = now;
                  SillyChatApp.snackbar(context, '再按一次退出应用',
                      duration: Duration(seconds: 2));
                } else {
                  SystemNavigator.pop(); // 退出应用
                }
              }
            }
            if (ChatController.of.pageController.page == 1) {
              final bool? canPopInner =
                  await _rightPageNavigatorKey.currentState?.maybePop();
              if (canPopInner == false) {
                ChatController.of.pageController.animateToPage(0,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut);
                return;
              }
            }
          },
          child: PageView(
            controller: ChatController.of.pageController,
            children: <Widget>[
              Navigator(
                key: _leftPageNavigatorKey,
                onGenerateRoute: (settings) {
                  return MaterialPageRoute(builder: (context) => LeftPage());
                },
              ),
              Navigator(
                key: _rightPageNavigatorKey,
                onGenerateRoute: (settings) {
                  return MaterialPageRoute(
                      builder: (context) => const RightPage());
                },
              ),
            ],
          )),
    );
  }
}

// 左侧页面
class LeftPage extends StatefulWidget {
  LeftPage({super.key});

  @override
  State<LeftPage> createState() => _LeftPageState();
}

// 混入 AutomaticKeepAliveClientMixin 以保持状态
class _LeftPageState extends State<LeftPage>
    with AutomaticKeepAliveClientMixin {
  // 重写 wantKeepAlive 并返回 true
  @override
  bool get wantKeepAlive => true;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = [
    ChatManagePage(),
    const ContactsPage(),
    ChatOptionsManagerPage(),
    LoreBookManagerPage(),
    SettingPage(),
  ];

  int _currentIndex = 0;
  CharacterModel get me => CharacterController.of.me;

  void _showCharacterSelectDialog() async {
    CharacterModel? character = await customNavigate<CharacterModel>(
        CharacterSelector(),
        context: context);
    if (character != null) {
      VaultSettingController.of().myId.value = character.id;
      await VaultSettingController.of().saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 调用 super.build(context)
    final theme = Theme.of(context);
    super.build(context);
    return Scaffold(
      key: scaffoldKey,
      body: _pages[_currentIndex],
      drawer: NavigationDrawer(
        selectedIndex: _currentIndex,
        onDestinationSelected: (value) {
          setState(() {
            if (ChatController.of.pageController.page == 1) {
              ChatController.of.pageController.animateToPage(0,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut);
            }
            _currentIndex = value;
            scaffoldKey.currentState?.closeDrawer();
          });
        },
        children: [
          // 1. 顶部背景和仓库信息
          Obx(() => DrawerHeader(
                padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
                decoration: me.backgroundImage != null
                    ? BoxDecoration(
                        image: DecorationImage(
                          image: Image.file(File(me.backgroundImage!)).image,
                          fit: BoxFit.cover,
                        ),
                        gradient: LinearGradient(
                          // 渐变方向为从上到下
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          // 渐变的颜色列表
                          colors: [
                            // 渐变从完全透明的黑色开始
                            Colors.black.withOpacity(0.0),
                            // 过渡到半透明的黑色
                            Colors.black.withOpacity(0.4),
                            // 结尾是更深一点的半透明黑色，以增强效果
                            Colors.black.withOpacity(1),
                          ],
                          // 控制渐变颜色的分布位置
                          // 0.0 是顶部, 1.0 是底部
                          // 这里表示从50%的位置(0.5)才开始渐变
                          stops: [0.5, 0.8, 1.0],
                        ),
                        boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 5,
                                offset: Offset(0, 5))
                          ])
                    : BoxDecoration(color: theme.colorScheme.primary),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                        onTap: _showCharacterSelectDialog,
                        child: AvatarImage.avatar(me.avatar, 32)),
                    SizedBox(
                      height: 6,
                    ),
                  ],
                ),
              )),
          // 2. 导航列表
          NavigationDrawerDestination(
            label: Text('聊天列表'),
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
          ),
          NavigationDrawerDestination(
            label: Text('角色'),
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
          ),
          NavigationDrawerDestination(
            label: Text('预设'),
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
          ),
          NavigationDrawerDestination(
            label: Text('世界书'),
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
          ),
          NavigationDrawerDestination(
            label: Text('设置'),
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
          ),
          const Spacer(), // 将底部组件推到底部
          Divider(
            height: 20,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: Icon(Icons.brightness_6_outlined),
                  title: Text(
                    '切换昼/夜',
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    SettingController.of.toggleDarkMode();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.switch_camera),
                  title: Text(
                    '项目管理',
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    customNavigate(VaultManagerPage(), context: context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 右侧页面
class RightPage extends StatefulWidget {
  const RightPage({super.key});

  @override
  State<RightPage> createState() => _RightPageState();
}

// 混入 AutomaticKeepAliveClientMixin 以保持状态
class _RightPageState extends State<RightPage>
    with AutomaticKeepAliveClientMixin {
  // 重写 wantKeepAlive 并返回 true
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // 调用 super.build(context)
    super.build(context);
    return Obx(() => ChatPage(
          key: ValueKey(
              '${ChatController.of.currentChat.value?.chatPath ?? 'NULL'}'),
          sessionController: ChatController.of.currentChat.value ??
              ChatSessionController.uninitialized(),
        ));
  }
}
