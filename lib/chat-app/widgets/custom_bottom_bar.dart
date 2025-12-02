import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/other/api_manager.dart';
import 'package:flutter_example/chat-app/pages/settings/setting_page.dart';
import 'package:flutter_example/chat-app/pages/vault_manager.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';

// 定义一个自定义的 Bottom Bar Widget
class CustomBottomBar extends StatelessWidget {
  // 两个固定按钮的点击回调

  // 可被覆盖（定制）的主要按钮 Widget
  final Widget centerButton;

  // 构造函数
  const CustomBottomBar({
    Key? key,
    required this.centerButton, // 要求传入中央按钮
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 使用 Stack 允许中央按钮可以覆盖在底部栏的上方或浮动
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        // 左侧按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              icon: Icon(SettingController.of.isDarkMode.value
                  ? Icons.dark_mode
                  : Icons.light_mode),
              onPressed: () {
                SettingController.of.toggleDarkMode();
              },
              tooltip: '切换主题',
            ),
            IconButton(
              icon: const Icon(Icons.api),
              onPressed: () {
                customNavigate(ApiManagerPage(), context: context);
              },
              tooltip: 'API',
            ),
            // 右侧按钮 (注意：在中心按钮位置留空，所以这里只放两个)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                customNavigate(SettingPage(), context: context);
              },
              tooltip: '设置',
            ),
          ],
        ),
        centerButton
      ],
    );
  }
}
