import 'package:flutter/material.dart';
import 'package:flutter_example/main.dart';

/// 自定义跳转函数
/// [page] 目标页面
/// [context] 移动端有些页面无法跳转，需要用另一种方法跳转
/// [rootNav] 仅移动端有效：顶级页面跳转。若设为false，则会在调用该方法的页面的那一侧屏幕进行跳转
/// 返回Future<T?>，可await获取返回值
/// WARNING：在手机端若不传context参数可能导致无法跳转页面
Future<T?> customNavigate<T>(Widget page,
    {required BuildContext context, bool rootNav = true}) async {
  if (SillyChatApp.isDesktop()) {
    // 桌面端：用Dialog包裹页面
    return await showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 16, // 提高阴影
        shadowColor: Colors.black.withOpacity(0.3), // 自定义阴影颜色
        insetPadding: EdgeInsets.symmetric(horizontal: 100, vertical: 50),
        child: Padding(
          padding: const EdgeInsets.all(12.0), // 防止内容与圆角重叠
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: 800,
            ),
            child: page,
          ),
        ),
      ),
    );
  } else {
    // 移动端：直接跳转
    return await Navigator.of(context, rootNavigator: rootNav).push<T>(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}
