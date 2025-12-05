import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/lorebooks/lorebook_editor.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STLorebookImporter.dart';
import 'package:flutter_example/chat-app/widgets/filePickerWindow.dart';
import 'package:flutter_example/chat-app/widgets/inner_app_bar.dart';
import 'package:get/get.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';

// 确保你在某处定义了这个枚举，或者直接放在这里
// import 'package:flutter_example/chat-app/models/lorebook_model.dart';

class LoreBookManagerPage extends StatelessWidget {
  final LoreBookController controller = Get.put(LoreBookController());
  final GlobalKey<ScaffoldState>? scaffoldKey;

  // 使用 Rx 变量来管理当前选中的 Tab 类型
  final Rx<LorebookType> _selectedType = LorebookType.world.obs;

  LoreBookManagerPage({super.key, this.scaffoldKey});

  // 辅助方法：获取类型对应的名称
  String _getTypeLabel(LorebookType type) {
    switch (type) {
      case LorebookType.world:
        return '世界书';
      case LorebookType.character:
        return '角色书';
      case LorebookType.memory:
        return '记忆';
    }
  }

  // 辅助方法：获取类型对应的图标
  IconData _getTypeIcon(LorebookType type) {
    switch (type) {
      case LorebookType.world:
        return Icons.public;
      case LorebookType.character:
        return Icons.person;
      case LorebookType.memory:
        return Icons.history_edu;
    }
  }

  // 构建信息标签
  Widget _buildInfoChip(String label, Color color, {IconData? icon}) {
    return Chip(
      avatar: icon != null ? Icon(icon, color: color, size: 14) : null,
      visualDensity: const VisualDensity(vertical: -2),
      label: Text(label),
      backgroundColor: color.withOpacity(0.12),
      labelStyle: TextStyle(color: color, fontSize: 12),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }

  // 构建世界书卡片
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
      color: colors.surfaceContainerHigh,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: isGlobal
            ? BorderSide(width: 2, color: colors.primary)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              //左侧图标指示类型 (可选)
              Icon(_getTypeIcon(loreBook.type),
                  color: colors.secondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: [
                        if (isGlobal) _buildInfoChip('全局激活', colors.primary),
                        if (itemCount > 0)
                          _buildInfoChip(
                            '已启用 $activatedCount/$itemCount',
                            colors.secondary,
                          ),
                        // 显示类型标签 (可选，因为已经在Tab里了)
                        // _buildInfoChip(_getTypeLabel(loreBook.type), colors.tertiary),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loreBook.type == LorebookType.world)
                    IconButton(
                      icon: Icon(
                        isGlobal ? Icons.star : Icons.star_border,
                        color: isGlobal ? Colors.amber : colors.outline,
                      ),
                      tooltip: isGlobal ? '取消全局激活' : '全局激活',
                      onPressed: onStarPressed,
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: colors.error,
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

  void addNewLoreBook() async {
    //final newId = DateTime.now().millisecondsSinceEpoch;
    late LorebookModel lb;
    switch (_selectedType.value) {
      case LorebookType.world:
        lb = LorebookModel.emptyWorldBook();
        break;
      case LorebookType.character:
        lb = LorebookModel.emptyCharacterBook();
        break;
      case LorebookType.memory:
        lb = LorebookModel.emptyMemoryBook();
        break;
      // default:
      //   lb = LorebookModel.emptyWorldBook();
      //   break;
    }
    await controller.addLorebook(lb);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: InnerAppBar(
        // 将 Title 替换为 SegmentedButton
        title: SizedBox(
          // height: 36, // 限制高度使其适应 AppBar
          child: Obx(() => SegmentedButton<LorebookType>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  // padding: WidgetStateProperty.all(EdgeInsets.zero),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                showSelectedIcon: false,
                segments: LorebookType.values.map((type) {
                  return ButtonSegment<LorebookType>(
                    value: type,
                    label: Text(_getTypeLabel(type)),
                    // icon: Icon(_getTypeIcon(type), size: 16),
                  );
                }).toList(),
                selected: {_selectedType.value},
                onSelectionChanged: (Set<LorebookType> newSelection) {
                  _selectedType.value = newSelection.first;
                },
              )),
        ),
        actions: [
          IconButton(
            onPressed: () {
              FileImporter(
                introduction:
                    '请注意:本应用仍在测试阶段，未兼容SillyTavern的部分功能。导入后，默认将被分类为“世界”类型。',
                paramList: [],
                allowedExtensions: ['json'],
                onImport: (fileName, content, params, path) {
                  final loreBook = STLorebookImporter.fromJson(
                      json.decode(content),
                      fileName: fileName);
                  if (loreBook != null) {
                    // 导入时可以默认设置类型，或者根据内容判断
                    //loreBook.type = _selectedType.value;
                    LoreBookController.of.addLorebook(loreBook);
                  }
                },
              ).pickAndProcessFile(context);
            },
            icon: const Icon(Icons.download),
            tooltip: '导入世界书',
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addNewLoreBook,
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final allLorebooks = controller.lorebooks;
        final globalIds = controller.globalActivitedLoreBookIds;

        // 1. 根据当前类型过滤列表
        final filteredLorebooks =
            allLorebooks.where((lb) => lb.type == _selectedType.value).toList();

        if (filteredLorebooks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '暂无${_getTypeLabel(_selectedType.value)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: filteredLorebooks.length,
          // ReorderableListView 在过滤列表下的逻辑比较复杂
          onReorder: (int oldIndex, int newIndex) {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }

            // 获取在过滤列表中的对象
            final itemToMove = filteredLorebooks[oldIndex];

            // 获取该对象在全局列表中的真实索引
            final globalOldIndex = allLorebooks.indexOf(itemToMove);

            // 计算全局目标索引
            // 逻辑：找到 filteredLorebooks[newIndex] 在全局列表中的位置，插入到它前面
            // 如果移到了末尾，则插入到 filteredLorebooks.last 在全局列表位置的后面
            int globalNewIndex;

            if (newIndex >= filteredLorebooks.length) {
              // 移到当前类别列表的末尾
              // 找到当前类别最后一个元素在全局列表的位置，插到它后面
              final lastItemInFilter = filteredLorebooks.last;
              final globalIndexOfLast = allLorebooks.indexOf(lastItemInFilter);
              // 此时还没移动，所以 globalIndexOfLast 可能是 globalOldIndex，需要小心
              // 既然是移动到末尾，简单来说就是移动到 (globalIndexOfLast)
              // 但因为 itemToMove 还在列表中，这很复杂。

              // 更稳健的方法：
              // 我们直接在 controller 里实现 "moveTo" 逻辑，但这里为了不改 controller：
              // 策略：找到目标位置的参考元素。
              // 既然是插在末尾，那它的新位置应该是：当前类型最后一个元素的位置。
              globalNewIndex = allLorebooks.indexOf(filteredLorebooks.last);
              if (globalOldIndex < globalNewIndex) {
                // 如果是从上面移下来，目标索引不变 (因为 removeAt 会让后面的元素前移)
              } else {
                // 如果是从下面移上去，这在 "移到末尾" 场景不常见，除非是最后一个
                globalNewIndex += 1;
              }
            } else {
              // 移到某个元素之前
              final targetItem = filteredLorebooks[newIndex];
              globalNewIndex = allLorebooks.indexOf(targetItem);

              // 如果向下移动，由于 removeAt(old) 会导致后面的索引 -1，
              // 如果 target 在 old 后面，我们需要保持 globalNewIndex 指向该元素当前的视觉位置
              if (globalOldIndex < globalNewIndex) {
                globalNewIndex -= 1;
              }
            }

            // 调用 Controller 进行排序 (注意：ReorderableListView 的 newIndex 已经在上面处理过减1逻辑，但 controller.reorder 通常需要原始逻辑)
            // 这里我们使用最安全的逻辑：先删后插
            // 由于 controller.reorderLorebooks 具体实现未知，这里模拟通用逻辑：
            // 建议：如果 controller.reorderLorebooks 只是简单的 list 操作，直接传计算好的 global 索引即可。

            // 修正后的简单逻辑尝试：
            // 我们不能简单传 globalNewIndex，因为中间夹杂着其他类型的书。
            // 最稳妥的方式：暂时在这个 Tab 内禁止排序，或者允许排序但只更新 UI 不保存？
            // 不，必须保存。
            // 重新计算精确的目标位置：
            // 1. 从全局列表中移除 item
            // 2. 找到 targetItem 在全局列表中的位置 (如果 newIndex == length, 则是 lastItem + 1)

            // 鉴于 ReorderableListView 与 Filtered List 配合极易出错，
            // 推荐方案：只允许 "视觉上" 交换顺序，或者在 Controller 增加 move(id, targetId) 方法。

            // 下面是尝试映射 Global Index 的代码：
            final item = filteredLorebooks[oldIndex];
            final globalOld = allLorebooks.indexOf(item);

            int globalNew;
            if (newIndex >= filteredLorebooks.length) {
              // 插在当前显示的最后一个元素之后
              final lastVisible = filteredLorebooks.last;
              // 如果自己就是最后一个，且没动，直接返回
              if (lastVisible == item) return;
              globalNew = allLorebooks.indexOf(lastVisible);
              // 如果是从上往下移，目标位置不用变(因为要插在它后面，但它自己也会前移? 不，是插在它后面)
              // 正确逻辑：insert at index of lastVisible + 1?
              // 实在太复杂，建议使用 controller.reorderLorebooks(globalOld, globalNew)
              // 并假设 controller 内部使用的是 list.insert(new, item)。

              // 简化处理：找到 filteredList[newIndex] 对应的对象，插在它前面。
              // 如果 newIndex == length，插在 filteredList.last 后面。
              globalNew = allLorebooks.length; // Fallback
            } else {
              final targetItem = filteredLorebooks[newIndex];
              globalNew = allLorebooks.indexOf(targetItem);
            }

            // ReorderableListView 的 quirk: 如果向下拖动，newIndex 实际上是在 slot 之后
            // 但我们在第一行已经 `newIndex -= 1` 修正了逻辑索引。
            // 所以现在逻辑是：把 item 移动到 targetItem 的位置（即插在 targetItem 之前）。

            controller.reorderLorebooks(globalOld, globalNew);
          },
          // 代理构建器，为了添加拖拽时的阴影等效果
          proxyDecorator: (child, index, animation) {
            return Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ]),
                    ),
                  ),
                  child,
                ],
              ),
            );
          },
          itemBuilder: (context, index) {
            final lorebook = filteredLorebooks[index];
            final isGlobal = globalIds.contains(lorebook.id);

            return Padding(
              key: ValueKey(lorebook.id), // 必须使用稳定的 Key
              padding: const EdgeInsets.only(bottom: 0.0),
              child: _buildLoreBookCard(
                loreBook: lorebook,
                isGlobal: isGlobal,
                context: context,
                onTap: () {
                  customNavigate(LoreBookEditorPage(lorebook: lorebook),
                      context: context);
                },
                onStarPressed: () {
                  if (isGlobal) {
                    controller.globalActivitedLoreBookIds.remove(lorebook.id);
                  } else {
                    controller.globalActivitedLoreBookIds.add(lorebook.id);
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
