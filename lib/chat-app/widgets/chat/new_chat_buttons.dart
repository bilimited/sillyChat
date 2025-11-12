import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:path/path.dart' as p;

/// NewChatButtons 组件
/// 包含一个 “选择角色” 按钮，下面一行文字 “或 使用模板”，并展示一个模板列表（占位组件）
/// 获取模板的方法（fetchTemplates）目前为占位实现，后续替换为真实数据源。
class NewChatButtons extends StatelessWidget {
  final VoidCallback? onSelectRole;
  final ValueChanged<ChatTemplate>? onTemplateSelected;

  const NewChatButtons({
    Key? key,
    this.onSelectRole,
    this.onTemplateSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TextButton(
          onPressed: onSelectRole ?? () => debugPrint('选择角色'),
          child: const Text('选择角色'),
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(
              child: Divider(thickness: 1),
            ),
            SizedBox(width: 8),
            Text('或 使用模板', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            Expanded(
              child: Divider(thickness: 1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 模板列表占位组件（普通列表样式）
        TemplateList(
          onTemplateSelected: onTemplateSelected,
        ),
      ],
    );
  }
}

/// 模板模型（简单占位）
class ChatTemplate {
  final String id;
  final String title;
  final ChatMetaModel? meta;

  ChatTemplate({
    required this.id,
    required this.title,
    this.meta,
  });
}

/// 模板列表组件（占位实现） - 普通列表样式，不再使用卡片
/// TODO: 将 fetchTemplates 替换为真实的数据获取逻辑
class TemplateList extends StatelessWidget {
  final ValueChanged<ChatTemplate>? onTemplateSelected;

  const TemplateList({Key? key, this.onTemplateSelected}) : super(key: key);

  Future<List<ChatTemplate>> fetchTemplates() async {
    return (await ChatController.of.getAllChatTemplate())
        .indexed
        .map((meta) => ChatTemplate(
            id: meta.$1.toString(),
            title: p.basenameWithoutExtension(meta.$2.name)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChatTemplate>>(
      future: fetchTemplates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final templates = snapshot.data ?? [];
        if (templates.isEmpty) {
          return const Center(child: Text('暂无模板'));
        }
        // 使用普通垂直列表展示模板，适合放在 Column 中
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: templates.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final t = templates[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.description_outlined),
              title: Text(t.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                if (onTemplateSelected != null) onTemplateSelected!(t);
                debugPrint('选中模板: ${t.title}');
              },
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            );
          },
        );
      },
    );
  }
}
