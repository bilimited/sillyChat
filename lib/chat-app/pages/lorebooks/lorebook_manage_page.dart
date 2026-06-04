import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/lorebooks/lorebook_editor.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/common/app_option_card.dart';
import 'package:flutter_example/chat-app/widgets/common/info_chip.dart';
import 'package:flutter_example/chat-app/widgets/inner_app_bar.dart';
import 'package:get/get.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';

class LoreBookManagerPage extends StatelessWidget {
  final LoreBookController controller = Get.put(LoreBookController());
  final GlobalKey<ScaffoldState>? scaffoldKey;

  final Rx<LorebookType> _selectedType = LorebookType.world.obs;

  LoreBookManagerPage({super.key, this.scaffoldKey});

  String _getTypeLabel(LorebookType type) {
    switch (type) {
      case LorebookType.world:
        return '世界书';
      case LorebookType.character:
        return '角色书';
    }
  }

  IconData _getTypeIcon(LorebookType type) {
    switch (type) {
      case LorebookType.world:
        return Icons.public;
      case LorebookType.character:
        return Icons.person;
    }
  }

  void addNewLoreBook() async {
    late LorebookModel lb;
    switch (_selectedType.value) {
      case LorebookType.world:
        lb = LorebookModel.emptyWorldBook();
        break;
      case LorebookType.character:
        lb = LorebookModel.emptyCharacterBook();
        break;
    }
    await controller.addLorebook(lb);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: addNewLoreBook,
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final allLorebooks = controller.lorebooks;
        final globalIds = controller.globalActivitedLoreBookIds;

        final filteredLorebooks =
            allLorebooks.where((lb) => lb.type == _selectedType.value).toList();

        return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              InnerAppBar(
                title: SizedBox(
                  child: Obx(() => SegmentedButton<LorebookType>(
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        showSelectedIcon: false,
                        segments: LorebookType.values.map((type) {
                          return ButtonSegment<LorebookType>(
                            value: type,
                            label: Text(_getTypeLabel(type)),
                          );
                        }).toList(),
                        selected: {_selectedType.value},
                        onSelectionChanged: (Set<LorebookType> newSelection) {
                          _selectedType.value = newSelection.first;
                        },
                      )),
                ),
              ),
            ];
          },
          body: filteredLorebooks.isEmpty ? Center(
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
          ) : ReorderableListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80,left: 8,right: 8),
            itemCount: filteredLorebooks.length,
            onReorder: (int oldIndex, int newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }

              final item = filteredLorebooks[oldIndex];
              final globalOld = allLorebooks.indexOf(item);

              int globalNew;
              if (newIndex >= filteredLorebooks.length) {
                final lastVisible = filteredLorebooks.last;
                if (lastVisible == item) return;
                globalNew = allLorebooks.indexOf(lastVisible) + 1;
              } else {
                final targetItem = filteredLorebooks[newIndex];
                globalNew = allLorebooks.indexOf(targetItem);
                if (globalOld < globalNew) {
                  globalNew -= 1;
                }
              }

              controller.reorderLorebooks(globalOld, globalNew);
            },
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
              final itemCount = lorebook.items.length;
              final activatedCount =
                  lorebook.items.where((item) => item.isActive).length;

              return Padding(
                key: ValueKey(lorebook.id),
                padding: const EdgeInsets.only(bottom: 0.0),
                child: AppOptionCard<String>(
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      _getTypeIcon(lorebook.type),
                      color: colorScheme.secondary,
                      size: 20,
                    ),
                  ),
                  title: lorebook.name,
                  subTitle: Builder(builder: (context) {
                    final chips = <Widget>[];
                    if (isGlobal) {
                      chips.add(const InfoChip(
                        label: '全局激活',
                        color: Colors.amber,
                      ));
                      chips.add(const SizedBox(width: 6));
                    }
                    if (itemCount > 0) {
                      chips.add(InfoChip(
                        label: '已启用 $activatedCount/$itemCount',
                        color: colorScheme.secondary,
                      ));
                    }
                    if (chips.isEmpty) return const SizedBox.shrink();
                    return Wrap(children: chips);
                  }),
                  options: [
                    AppCardOptionItem<String>(
                      value: 'edit',
                      child: const Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 12),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    AppCardOptionItem<String>(
                      value: 'toggleGlobal',
                      child: Row(
                        children: [
                          Icon(
                            isGlobal ? Icons.star : Icons.star_border,
                            color: isGlobal ? Colors.amber : null,
                          ),
                          const SizedBox(width: 12),
                          Text(isGlobal ? '取消全局激活' : '全局激活'),
                        ],
                      ),
                    ),
                    AppCardOptionItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              color: colorScheme.error),
                          const SizedBox(width: 12),
                          Text(
                            '删除',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        customNavigate(
                            LoreBookEditorPage(lorebook: lorebook),
                            context: context);
                        break;
                      case 'toggleGlobal':
                        if (isGlobal) {
                          controller.globalActivitedLoreBookIds
                              .remove(lorebook.id);
                        } else {
                          controller.globalActivitedLoreBookIds
                              .add(lorebook.id);
                        }
                        controller.saveLorebooks();
                        break;
                      case 'delete':
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
                        break;
                    }
                  },
                  onTap: () {
                    customNavigate(LoreBookEditorPage(lorebook: lorebook),
                        context: context);
                  },
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
