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
    ChatOptionsManagerPage(
      scaffoldKey: _scaffoldKey,
    ),
    LoreBookManagerPage(
      scaffoldKey: _scaffoldKey,
    ),
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

  Widget _buildDrawerBottom() {
    return Padding(
      padding: EdgeInsetsGeometry.all(8),
      child: Row(
        children: [IconButton(onPressed: () {}, icon: Icon(Icons.settings))],
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
        width: screenWidth * _drawerWidthScaler,
        child: SafeArea(
          child: Column(
            children: [
              // const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 等间距分布
                children: [
                  _buildTopIconBtn(Icons.home, 0),
                  _buildTopIconBtn(Icons.people, 1),
                  _buildTopIconBtn(Icons.dashboard, 2),
                  _buildTopIconBtn(Icons.book, 3),
                ],
              ),

              const Divider(thickness: 1),

              Expanded(
                child: _drawerContents[_currentIndex],
              ),

              const Divider(thickness: 1),

              CustomBottomBar(
                centerButton: SizedBox.shrink(),
              ),
              //_buildDrawerBottom(),
              // 底部安全距离
              // const SizedBox(height: 20),
            ],
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
