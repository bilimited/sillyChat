import 'package:flutter/material.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';

/// 自定义跳转函数
/// [page] 目标页面
/// [context] 安卓端有些页面无法跳转，需要用另一种方法跳转
/// 返回Future<T?>，可await获取返回值
Future<T?> customNavigate<T>(Widget page, {BuildContext? context}) async {
  
  if (SillyChatApp.isDesktop()) {
    // 桌面端：用Dialog包裹页面
    return await Get.dialog<T>(
      Dialog(
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
      barrierDismissible: true,
    );
  } else {
    if (context != null) {
      // 移动端：直接跳转
      return await Navigator.of(context).push<T>(
        MaterialPageRoute(builder: (_) => page),
      );
    } else {
      return await Get.to(
        () => page,
      );
    }
  }
}
