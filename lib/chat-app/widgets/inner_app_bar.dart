import 'package:flutter/material.dart';

class InnerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;

  static const double height = 40.0; // 默认是 56.0，这里设为 40
  static const double iconSize = 20.0; // 默认是 24.0
  static const double titleSize = 16.0; // 默认是 20.0

  const InnerAppBar({
    Key? key,
    this.title,
    this.actions,
    this.leading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      titleTextStyle: TextStyle(
          fontSize: titleSize,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface
          // color: Colors.black, // 需根据背景调整颜色
          ),
      toolbarHeight: height,
      iconTheme: const IconThemeData(
        size: iconSize,
        // color: Colors.black,
      ),
      actionsIconTheme: const IconThemeData(
        size: iconSize,
        // color: Colors.black,
      ),

      // 3. 调整左侧区域宽度
      // 默认是 56，如果不改小，左上角图标旁边会有大片空白
      leadingWidth: height,
      backgroundColor: Colors.transparent, // 核心样式
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      foregroundColor: Colors.transparent,
      elevation: 0, // 去除阴影
      title: title,
      actions: actions,
      leading: leading,
      // 可以在这里统一处理状态栏颜色（黑/白）
      // systemOverlayStyle: SystemUiOverlayStyle.dark,

      // 这里可以添加更多统一的逻辑，比如统一的返回按钮图标等
    );
  }

  @override
  // 必须实现此方法，指定AppBar的高度，通常是 kToolbarHeight (56.0)
  Size get preferredSize => const Size.fromHeight(height);
}
