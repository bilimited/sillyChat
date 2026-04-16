import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_page.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_example/chat-app/widgets/stack_avatar.dart';
import 'package:path/path.dart' as p;

/// NewChatButtons 组件
/// 包含一个 “选择角色” 按钮，下面一行文字 “或 使用模板”，并展示一个模板列表（占位组件）
/// 获取模板的方法（fetchTemplates）目前为占位实现，后续替换为真实数据源。
class NewChatButtons extends StatelessWidget {
  final VoidCallback? onSelectRole;

  const NewChatButtons({
    Key? key,
    this.onSelectRole,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
      ],
    );
  }
}

