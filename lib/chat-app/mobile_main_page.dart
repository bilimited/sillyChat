import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/character/contacts_page.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_file_manager.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_page.dart';
import 'package:flutter_example/chat-app/pages/chat/search_page.dart';
import 'package:flutter_example/chat-app/pages/chat_options/chat_options_manager.dart';
import 'package:flutter_example/chat-app/pages/lorebooks/lorebook_manager.dart';
import 'package:flutter_example/chat-app/pages/other/api_manager.dart';
import 'package:flutter_example/chat-app/pages/settings/setting_page.dart';
import 'package:flutter_example/chat-app/pages/vault_manager.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_example/chat-app/widgets/custom_bottom_bar.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:marquee/marquee.dart';

class MainPageMobile extends StatefulWidget {
  const MainPageMobile({super.key});

  @override
  State<MainPageMobile> createState() => _MainPageMobileState();
}

class _MainPageMobileState extends State<MainPageMobile> {
  //final PageController _pageController = PageController();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // final GlobalKey<NavigatorState> _rightPageNavigatorKey =
  //     GlobalKey<NavigatorState>();

  DateTime? _lastPressedBackAt; // 实现再按一次退出

  static const double _drawerWidthScaler = 1;
  static const double _maxDrawerWidth = 500;

  @override
  void dispose() {
    //_pageController.dispose();
    super.dispose();
  }

  CharacterModel get me => CharacterController.of.me;
  // 记录当前Drawer内部选中的Tab索引
  int _currentIndex = 0;

  // Drawer内部切换的具体内容视图
  late List<Widget> _drawerContents = [
    ChatManagePage(
      scaffoldKey: _scaffoldKey,
    ),
    ContactsPage(
      scaffoldKey: _scaffoldKey,
    ),
    // ChatOptionsManagerPage(
    //   scaffoldKey: _scaffoldKey,
    // ),
    LoreBookManagerPage(
      scaffoldKey: _scaffoldKey,
    ),
    SettingPage()

    // ApiManagerPage(
    //   scaffoldKey: _scaffoldKey,
    // ),
  ];

  Widget _buildTopIconBtn(IconData icon, int index) {
    final colors = Theme.of(context).colorScheme;
    final bool isSelected = _currentIndex == index;
    return IconButton(
      icon: Icon(
        icon,
        // 选中时高亮颜色，未选中灰色
        color: isSelected ? colors.primary : colors.outline,
        size: 28,
      ),
      onPressed: () {
        // 核心逻辑：点击图标只更新 Drawer 内部的状态
        setState(() {
          _currentIndex = index;
        });
      },
    );
  }

  // WTF 为什么min也要我定义？
  double myMin(double n1, double n2) {
    return n1 > n2 ? n2 : n1;
  }

  Widget _buildAPIButton(BuildContext context) {
    return Tooltip(
      message: "设置API",
      child: InkWell(
        onTap: () {
          customNavigate(ApiManagerPage(), context: context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const Icon(Icons.power),
              const SizedBox(width: 8),
              SizedBox(
                height: 24, // 需要指定高度
                width: 86,
                child: Obx(() {
                  String label =
                      VaultSettingController.of().defaultApi?.displayName ??
                          "未设置API";

                  // 只有当文字较长时才使用 Marquee，否则居左显示普通 Text
                  // 这里可以根据业务需求调整判断逻辑
                  return Marquee(
                    text: label,
                    style: const TextStyle(fontSize: 14), // 保持与原 Text 样式一致
                    scrollAxis: Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    blankSpace: 20.0, // 循环滚动时的间距
                    velocity: 30.0, // 滚动速度
                    pauseAfterRound: const Duration(seconds: 1), // 每圈滚动后的暂停时间
                    accelerationDuration: const Duration(seconds: 1),
                    accelerationCurve: Curves.linear,
                    decelerationDuration: const Duration(milliseconds: 500),
                    decelerationCurve: Curves.easeOut,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // 2. 提取屏幕宽度
    final screenWidth = size.width;

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        width: myMin(_maxDrawerWidth, screenWidth * _drawerWidthScaler),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Center(
              child: InkWell(
                onTap: () {
                  customNavigate(VaultManagerPage(), context: context);
                },
                child: Row(
                  children: [
                    Text(
                      SettingController.currectValutName,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.expand_more,
                      color: Theme.of(context).colorScheme.outline,
                      size: 18,
                    )
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(SettingController.of.isDarkMode.value
                    ? Icons.dark_mode
                    : Icons.light_mode),
                onPressed: () {
                  SettingController.of.toggleDarkMode();
                },
                tooltip: '切换主题',
              ),
              _buildAPIButton(context)
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            showUnselectedLabels: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble), label: '聊天'),
              BottomNavigationBarItem(icon: Icon(Icons.people), label: '角色'),
              BottomNavigationBarItem(icon: Icon(Icons.book), label: '世界书'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
            ],
            currentIndex: _currentIndex,
            onTap: (value) {
              setState(() {
                _currentIndex = value;
              });
            },
          ),
          body: SafeArea(
            child: Column(
              children: [
                const Divider(
                  thickness: 1,
                  height: 0,
                ),
                Expanded(
                  child: _drawerContents[_currentIndex],
                ),
              ],
            ),
          ),
        ),
      ),
      body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
              _scaffoldKey.currentState?.closeDrawer();
              return;
            }

            if (ChatController.of.isMultiSelecting.value) {
              return;
            }
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
          },
          child: Obx(() => ChatPage(
                key: ValueKey(
                    '${ChatController.of.currentChat.value?.chatPath ?? 'NULL'}'),
                sessionController: ChatController.of.currentChat.value ??
                    ChatSessionController.uninitialized(),
                scaffoldKey: _scaffoldKey,
              ))),
    );
  }
}
