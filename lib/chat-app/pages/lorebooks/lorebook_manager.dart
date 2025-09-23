import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/lorebooks/lorebook_editor.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';

class LoreBookManagerPage extends StatelessWidget {
  final LoreBookController controller = Get.put(LoreBookController());

  LoreBookManagerPage({super.key});

  // 用于创建信息标签的辅助方法
  Widget _buildInfoChip(String label, Color color, {IconData? icon}) {
    return Chip(
      avatar: icon != null
          ? Icon(
              icon,
              color: color,
            )
          : null,
      visualDensity: VisualDensity(vertical: -2),
      label: Text(
        label,
      ),
      backgroundColor: color.withOpacity(0.12),
      labelStyle: TextStyle(color: color, fontSize: 12),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
      // shape: const StadiumBorder(),
    );
  }

  // 构建世界书卡片的核心方法
  Widget _buildLoreBookCard({
    required LorebookModel loreBook,
    required bool isGlobal,
    required BuildContext context,
    required VoidCallback onTap,
    required VoidCallback onStarPressed,
    required VoidCallback onDeletePressed,
  }) {
    final name = loreBook.name;
    final itemCount = loreBook.items.length;
    final activatedCount = loreBook.items.where((item) => item.isActive).length;
    final colors = Theme.of(context).colorScheme;

    return Card(
      shape: isGlobal
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              side: BorderSide(width: 2, color: colors.primary),
            )
          : null,
      clipBehavior: Clip.antiAlias, // 使 InkWell 的水波纹效果保持在圆角内
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8.0,
                      // runSpacing: 4.0,
                      children: [
                        if (isGlobal) _buildInfoChip('全局激活', colors.primary),
                        if (itemCount > 0)
                          _buildInfoChip('条目: $itemCount', colors.secondary),
                        if (activatedCount > 0)
                          _buildInfoChip(
                              '已激活: $activatedCount', colors.tertiary),
                      ],
                    ),
                  ],
                ),
              ),
              // const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isGlobal ? Icons.language : Icons.language_outlined,
                      color: isGlobal
                          ? Colors.amber
                          : Theme.of(context).colorScheme.outline,
                    ),
                    tooltip: isGlobal ? '取消全局激活' : '全局激活',
                    onPressed: onStarPressed,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    tooltip: '删除',
                    onPressed: onDeletePressed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newId = DateTime.now().millisecondsSinceEpoch;
          await controller.addLorebook(LorebookModel(
            id: newId,
            name: '新世界书',
            items: [],
            scanDepth: 3,
            maxToken: 2048,
          ));
        },
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        title: const Text('世界书管理'),
      ),
      body: Obx(() {
        final lorebooks = controller.lorebooks;
        final globalIds = controller.globalActivitedLoreBookIds;
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(4),
          itemCount: lorebooks.length,
          onReorder: (oldIndex, newIndex) {
            controller.reorderLorebooks(
                oldIndex, newIndex > oldIndex ? newIndex - 1 : newIndex);
          },
          itemBuilder: (context, index) {
            final lorebook = lorebooks[index];
            final isGlobal = globalIds.contains(lorebook.id);
            // 使用 Key 对于 ReorderableListView 至关重要
            return Padding(
              key: ValueKey(lorebook.id),
              padding: const EdgeInsets.only(bottom: 0.0),
              child: _buildLoreBookCard(
                loreBook: lorebook,
                isGlobal: isGlobal,
                context: context,
                onTap: () {
                  customNavigate(
                      LoreBookEditorPage(
                        lorebook: lorebook,
                      ),
                      context: context);
                },
                onStarPressed: () {
                  if (isGlobal) {
                    controller.globalActivitedLoreBookIds.remove(lorebook.id);
                    print('remove');
                  } else {
                    controller.globalActivitedLoreBookIds.add(lorebook.id);
                    print('add');
                  }
                  controller.saveLorebooks();
                },
                onDeletePressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('确认删除'),
                      content: Text('确定要删除 "${lorebook.name}" 吗？此操作不可撤销。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('删除',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await controller.deleteLorebook(lorebook.id);
                  }
                },
              ),
            );
          },
        );
      }),
    );
  }
}
