import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showEditDialog({
  required String title,
  String initialValue = '',
  String hintText = '请输入内容',
  required Function(String) onConfirm,
}) {
  // 创建 TextEditingController 并设置初始值
  final TextEditingController textController = TextEditingController(text: initialValue);

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