import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';

/// 自定义跳转函数
/// [page] 目标页面
/// [fullscreenDialog] 是否全屏Dialog（桌面端用）
/// 返回Future<T?>，可await获取返回值
Future<T?> customNavigate<T>(
  Widget page, {
  bool fullscreenDialog = false,
}) async {
  if (GetPlatform.isDesktop) {
    // 桌面端：用Dialog包裹页面
    return await Get.dialog<T>(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.blueGrey, width: 2),
        ),
        elevation: 8,
        insetPadding: EdgeInsets.symmetric(horizontal: 100, vertical: 50),
        child: Padding(
          padding: const EdgeInsets.all(16.0), // 防止内容与圆角重叠
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: 800,
            ),
            child: page,
          ),
        ),
        ),
      
      barrierDismissible: false,
    );
  } else {
    // 移动端：直接跳转
    return await Get.to<T>(
      () => page,
      fullscreenDialog: fullscreenDialog,
    );
  }
}
