import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/category_config.dart';
import 'package:flutter_example/chat-app/utils/ModalUtil.dart';
import 'package:flutter_example/chat-app/widgets/inner_app_bar.dart';
import 'package:get/get.dart';

class CategoryManagePage extends StatefulWidget {
  final String title;
  final RxList<CategoryConfig> categories;
  final int Function(String name) entityCount;
  final Future<void> Function(String name) onAdd;
  final Future<void> Function(String oldName, String newName) onRename;
  final Future<void> Function(String name) onDelete;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  const CategoryManagePage({
    super.key,
    required this.title,
    required this.categories,
    required this.entityCount,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage> {
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    if (widget.categories.any((c) => c.name == name)) {
      Get.snackbar('提示', '分组「$name」已存在');
      return;
    }
    await widget.onAdd(name);
    _addController.clear();
  }

  Future<void> _rename(CategoryConfig config) async {
    showEditDialog(
      title: '重命名分组',
      initialValue: config.name,
      hintText: '输入新名称',
      onConfirm: (newName) async {
        final trimmed = newName.trim();
        if (trimmed.isEmpty || trimmed == config.name) return;
        if (widget.categories.any((c) => c.name == trimmed)) {
          Get.snackbar('提示', '分组「$trimmed」已存在');
          return;
        }
        await widget.onRename(config.name, trimmed);
      },
    );
  }

  Future<void> _delete(BuildContext context, CategoryConfig config) async {
    final count = widget.entityCount(config.name);
    await showConfirmDialog(
      context: context,
      title: '删除分组',
      content: '确定要删除分组「${config.name}」吗？\n'
          '${count > 0 ? '该分组下 $count 个实体的分组将被清空。' : ''}',
      isDestructive: true,
      onConfirm: () => widget.onDelete(config.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            InnerAppBar(title: Text(widget.title)),
          ];
        },
        body: Obx(() {
          final list = widget.categories.toList();
          list.sort((a, b) => a.order.compareTo(b.order));

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addController,
                        decoration: InputDecoration(
                          hintText: '输入新分组名称',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              if (list.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      '暂无分组，请添加',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ReorderableListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: list.length,
                    onReorder: (oldIndex, newIndex) =>
                        widget.onReorder(oldIndex, newIndex),
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        color: colorScheme.surfaceContainerHighest,
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final config = list[index];
                      final count = widget.entityCount(config.name);
                      return _CategoryTile(
                        key: ValueKey(config.name),
                        config: config,
                        index: index,
                        count: count,
                        colorScheme: colorScheme,
                        onRename: () => _rename(config),
                        onDelete: () => _delete(context, config),
                      );
                    },
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryConfig config;
  final int index;
  final int count;
  final ColorScheme colorScheme;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CategoryTile({
    super.key,
    required this.config,
    required this.index,
    required this.count,
    required this.colorScheme,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, size: 22),
        ),
        title: Text(config.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onRename,
              tooltip: '重命名',
            ),
            IconButton(
              icon: Icon(Icons.delete, size: 20, color: colorScheme.error),
              onPressed: onDelete,
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }
}
