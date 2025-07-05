import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 处理严重错误的方法，显示一个极为惊悚的弹窗提示错误信息（使用Get.dialog）。
void handleSevereError(
  String errorMessage, [
  dynamic error,
  StackTrace? stackTrace,
]) {
  print('严重错误发生: $errorMessage');
  if (error != null) {
    print('原始错误对象: $error');
  }
  if (stackTrace != null) {
    print('堆栈跟踪: $stackTrace');
  }

  Get.dialog(
    Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red[900],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.redAccent, width: 8),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.8),
              blurRadius: 32,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.yellow[900],
              size: 80,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 12,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '!!! 致命错误 !!!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 8,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent, width: 2),
              ),
              child: Text(
                errorMessage,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  '详细信息: ${error.toString()}',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (stackTrace != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '堆栈信息:\n${stackTrace.toString().substring(0, stackTrace.toString().length > 200 ? 200 : stackTrace.toString().length)}...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                elevation: 10,
                shadowColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.dangerous, size: 32),
              label: const Text('立即关闭'),
              onPressed: () {
                Get.back();
              },
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );
}