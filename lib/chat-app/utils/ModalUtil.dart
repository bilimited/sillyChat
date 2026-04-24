import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showEditDialog({
  required String title,
  String initialValue = '',
  String hintText = '请输入内容',
  required Function(String) onConfirm,
}) {
  // 创建 TextEditingController 并设置初始值
  final TextEditingController textController =
      TextEditingController(text: initialValue);

  Get.dialog(
    AlertDialog(
      title: Text(title),
      content: TextField(
        controller: textController,
        autofocus: true, // 自动弹出键盘
        decoration: InputDecoration(
          hintText: hintText,
          // 可以在这里自定义边框样式
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        // 支持回车直接提交
        onSubmitted: (value) {
          onConfirm(value);
          Get.back();
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            // 执行回调函数，并将输入框的值传出去
            onConfirm(textController.text);
            Get.back();
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

void showConfirmDialog({
  required BuildContext context,
  required String content,
  String? title,
  String confirmText = '确定',
  String cancelText = '取消',
  Color? confirmTextColor,
  Color? confirmButtonColor,
  bool isDestructive = false, // 是否为破坏性操作（如删除，设为true确认按钮通常显示红色）
  required VoidCallback onConfirm,
  VoidCallback? onCancel,
}) {
  final colors = Theme.of(context).colorScheme;
  Get.dialog(
    AlertDialog(
      title: title != null ? Text(title!) : null,
      content: Text(content),
      actions: [
        // 取消按钮
        TextButton(
          onPressed: () {
            if (onCancel != null) onCancel();
            Get.back();
          },
          child: Text(
            cancelText,
            style: TextStyle(color: colors.outline),
          ),
        ),
        // 确定按钮
        TextButton(
          onPressed: () {
            onConfirm();
            Get.back();
          },
          // style: ElevatedButton.styleFrom(
          //   // 如果是破坏性操作且未指定颜色，默认用红色
          //   backgroundColor: confirmButtonColor ??
          //       (isDestructive ? Colors.red : Colors.blue),
          //   foregroundColor: confirmTextColor ?? Colors.white,
          //   elevation: 0,
          // ),
          child: Text(
            confirmText,
            style: TextStyle(
                color: confirmButtonColor ??
                    (isDestructive ? colors.error : colors.onSurface)),
          ),
        ),
      ],
    ),
    // 点击背景是否可以关闭对话框
    barrierDismissible: true,
  );
}
