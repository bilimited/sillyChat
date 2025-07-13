import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/lorebooks/lorebook_editor.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';

class LoreBookManagerPage extends StatelessWidget {
  final LoreBookController controller = Get.put(LoreBookController());

  LoreBookManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 这里可弹出对话框或跳转到编辑页
          // 示例：添加一个空世界书
          final newId = DateTime.now().millisecondsSinceEpoch;
          await controller.addLorebook(LorebookModel(
            id: newId,
            name: '新世界书',
            items: [],
            scanDepth: 3,
            maxToken: 2048,
          ));
        },
        child: Icon(Icons.add),
      ),
      appBar: AppBar(
        title: const Text('世界书管理'),
      ),
      body: Obx(() {
        final lorebooks = controller.lorebooks;
        final globalIds = controller.globalActivitedLoreBookIds;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部Tag显示全局激活的世界书
            if (globalIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  spacing: 8,
                  children: controller.globalActivitedLoreBooks
                      .map((lorebook) => Chip(
                            label: Text(lorebook.name),
                            onDeleted: () {
                              controller.globalActivitedLoreBookIds
                                  .remove(lorebook.id);
                              controller.saveLorebooks();
                            },
                          ))
                      .toList(),
                ),
              )
            else
              SizedBox(
                height: 48,
                child: Center(
                  child: Text('无启用的世界书'),
                ),
              ),
            Divider(),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: lorebooks.length,
                onReorder: (oldIndex, newIndex) {
                  controller.reorderLorebooks(
                      oldIndex, newIndex > oldIndex ? newIndex - 1 : newIndex);
                },
                itemBuilder: (context, index) {
                  final lorebook = lorebooks[index];
                  final isGlobal = globalIds.contains(lorebook.id);
                  return ListTile(
                    key: ValueKey(lorebook.id),
                    title: Text(lorebook.name),
                    subtitle: Text('条目数: ${lorebook.items.length}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            isGlobal ? Icons.star : Icons.star_border,
                            color: isGlobal ? Colors.amber : Theme.of(context).colorScheme.outline,
                          ),
                          onPressed: () {
                            if (isGlobal) {
                              controller.globalActivitedLoreBookIds
                                  .remove(lorebook.id);
                            } else {
                              controller.globalActivitedLoreBookIds
                                  .add(lorebook.id);
                            }
                            controller.saveLorebooks();
                          },
                        ),
                        IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: '删除',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('确认删除'),
                                  content: Text(
                                      '确定要删除 "${lorebook.name}" 吗？此操作不可撤销。'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('删除',
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await controller.deleteLorebook(lorebook.id);
                              }
                            }),
                      ],
                    ),
                    onTap: () {
                      customNavigate(
                          LoreBookEditorPage(
                            lorebook: lorebook,
                          ),
                          context: context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}
