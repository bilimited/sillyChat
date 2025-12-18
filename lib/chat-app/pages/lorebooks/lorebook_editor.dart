import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/pages/lorebooks/lorebook_item_editor.dart';

class LoreBookEditorPage extends StatefulWidget {
  final LorebookModel? lorebook;
  final bool isNew;

  const LoreBookEditorPage({super.key, this.lorebook, this.isNew = false});

  @override
  State<LoreBookEditorPage> createState() => _LoreBookEditorPageState();
}

class _LoreBookEditorPageState extends State<LoreBookEditorPage> {
  late TextEditingController nameController;
  late TextEditingController searchController; // 新增搜索控制器
  late List<LorebookItemModel> items;
  late LorebookType _selectedType;
  late int id;

  // 简单的元数据控制器，如果需要更多设置（如scanDepth），建议放入右上角菜单或折叠面板，保持界面整洁
  // 这里为了保持原有逻辑，暂存数据，但界面上仅展示核心的名称
  int scanDepth = 3;
  int maxToken = 2048;

  late FocusNode nameFocusNode;

  String searchText = '';

  @override
  void initState() {
    super.initState();
    final lorebook = widget.lorebook;
    id = lorebook?.id ?? DateTime.now().millisecondsSinceEpoch;
    nameController = TextEditingController(text: lorebook?.name ?? '');
    searchController = TextEditingController();

    scanDepth = lorebook?.scanDepth ?? 3;
    maxToken = lorebook?.maxToken ?? 2048;

    items = lorebook?.items.map((e) => e.copyWith()).toList() ?? [];
    _selectedType = lorebook?.type ?? LorebookType.world;

    nameFocusNode = FocusNode();
    nameFocusNode.addListener(() {
      if (!nameFocusNode.hasFocus) {
        saveLorebook();
      }
    });
  }

  @override
  void dispose() {
    nameFocusNode.dispose();
    searchController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> saveLorebook() async {
    final controller = Get.find<LoreBookController>();
    final lorebook = LorebookModel(
        id: id,
        name: nameController.text.trim(),
        items: items,
        scanDepth: scanDepth,
        maxToken: maxToken,
        type: _selectedType);
    if (widget.isNew) {
      await controller.addLorebook(lorebook);
    } else {
      await controller.updateLorebook(lorebook);
    }
  }

  void saveLorebookAndBack() async {
    await saveLorebook();
    Get.back();
  }

  void addItem() {
    setState(() {
      String pos = "before_char";
      if(_selectedType == LorebookType.character){
        pos = "after_char";
      }else if(_selectedType == LorebookType.memory){{
        pos = "memory";
      }}
      // 新条目插入到顶部还是底部？通常底部，或者顶部以便编辑。这里默认底部。
      items.add(LorebookItemModel(
        id: DateTime.now().millisecondsSinceEpoch,
        name: '新条目',
        content: '',
        position: pos
      ));
      searchController.clear();
      searchText = '';
    });
    saveLorebook();
  }

  void copyItem(LorebookItemModel item) {
    LoreBookController.of.lorebookItemClipboard.value = item;
    SillyChatApp.snackbar(context, '条目"${item.name}"已复制');
  }

  void pasteItem() {
    final item = LoreBookController.of.lorebookItemClipboard.value;
    if (item == null) return;

    setState(() {
      items.add(item.copyWith(
        id: DateTime.now().millisecondsSinceEpoch,
        name: '${item.name} (副本)',
      ));
      searchController.clear();
      searchText = '';
    });
    saveLorebook();
    // 粘贴后清空剪贴板可根据需求决定，这里不清空方便连续粘贴
    LoreBookController.of.lorebookItemClipboard.value = null;
  }

  void deleteItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${items[index].name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                items.removeAt(index);
                saveLorebook();
              });
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void toggleItemActive(int index, bool value) {
    setState(() {
      items[index] = items[index].copyWith(isActive: value);
      saveLorebook();
    });
  }

  // --- 排序操作 ---

  void moveItem(int index, int newIndex) {
    if (newIndex < 0 || newIndex >= items.length) return;
    setState(() {
      final item = items.removeAt(index);
      items.insert(newIndex, item);
      saveLorebook();
    });
  }

  void moveToTop(int index) {
    if (index == 0) return;
    moveItem(index, 0);
  }

  void moveUp(int index) {
    moveItem(index, index - 1);
  }

  void moveDown(int index) {
    moveItem(index, index + 1);
  }

  // --- 构建 UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 过滤列表
    // 注意：当处于搜索模式时，操作的是过滤后的视图，但修改必须映射回原始 items 列表。
    // 简单起见，搜索模式下禁用排序功能，只允许编辑和删除。
    final bool isSearching = searchText.trim().isNotEmpty;
    final List<int> filteredIndices = [];
    for (int i = 0; i < items.length; i++) {
      if (!isSearching ||
          items[i].name.toLowerCase().contains(searchText.toLowerCase())) {
        filteredIndices.add(i);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑世界书'),
        elevation: 0,
        actions: [
          PopupMenuButton<LorebookType>(
            icon: const Icon(Icons.swap_vert),
            tooltip: '转换类型',
            onSelected: (type) {
              setState(() {
                _selectedType = type;
              });
              saveLorebook();
              // 简单提示
              final map = {
                LorebookType.world: '世界书',
                LorebookType.character: '角色书',
                LorebookType.memory: '记忆书',
              };
              SillyChatApp.snackbar(context, '已转换为${map[type] ?? '未知类型'}');
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: LorebookType.world,
                child: Text('转换为世界书'),
              ),
              const PopupMenuItem(
                value: LorebookType.character,
                child: Text('转换为角色书'),
              ),
              const PopupMenuItem(
                value: LorebookType.memory,
                child: Text('转换为记忆书'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部紧凑的设置区域
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  focusNode: nameFocusNode,
                  decoration: const InputDecoration(
                    labelText: '世界书名称',
                    // isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: '搜索条目...',
                    prefixIcon: Icon(Icons.search),
                    // isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchText = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 列表区域
          Expanded(
            child: filteredIndices.isEmpty
                ? Center(
                    child: Text(
                      items.isEmpty ? '暂无条目' : '未找到匹配条目',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: filteredIndices.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, displayIndex) {
                      final actualIndex = filteredIndices[displayIndex];
                      final item = items[actualIndex];

                      return InkWell(
                        onTap: () {
                          customNavigate(
                              LoreBookItemEditorPage(
                                item: item,
                                onSave: (newItem) {
                                  setState(() {
                                    items[actualIndex] = newItem;
                                    saveLorebook();
                                  });
                                },
                              ),
                              context: context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              // 激活开关
                              SizedBox(
                                height: 24,
                                child: Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                    value: item.isActive,
                                    onChanged: (v) =>
                                        toggleItemActive(actualIndex, v),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // 内容信息
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item.name.isEmpty ? "无标题" : item.name,
                                      style: theme.textTheme.bodyLarge,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      item.content.replaceAll('\n', ' '),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // 菜单按钮
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.grey),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'top':
                                      moveToTop(actualIndex);
                                      break;
                                    case 'up':
                                      moveUp(actualIndex);
                                      break;
                                    case 'down':
                                      moveDown(actualIndex);
                                      break;
                                    case 'copy':
                                      copyItem(item);
                                      break;
                                    case 'delete':
                                      deleteItem(actualIndex);
                                      break;
                                  }
                                },
                                itemBuilder: (context) {
                                  // 搜索状态下禁用排序选项，防止索引混乱
                                  return [
                                    if (!isSearching) ...[
                                      const PopupMenuItem(
                                        value: 'top',
                                        child: ListTile(
                                          leading:
                                              Icon(Icons.vertical_align_top),
                                          title: Text('置顶'),
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'up',
                                        child: ListTile(
                                          leading: Icon(Icons.arrow_upward),
                                          title: Text('上移'),
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'down',
                                        child: ListTile(
                                          leading: Icon(Icons.arrow_downward),
                                          title: Text('下移'),
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                    ],
                                    const PopupMenuItem(
                                      value: 'copy',
                                      child: ListTile(
                                        leading: Icon(Icons.copy),
                                        title: Text('复制'),
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete,
                                            color: Colors.red),
                                        title: Text('删除',
                                            style:
                                                TextStyle(color: Colors.red)),
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                    ),
                                  ];
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            final hasClipboard =
                LoreBookController.of.lorebookItemClipboard.value != null;
            if (!hasClipboard) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton.small(
                heroTag: 'paste_fab',
                onPressed: pasteItem,
                tooltip: '粘贴条目',
                child: const Icon(Icons.paste),
              ),
            );
          }),
          FloatingActionButton(
            heroTag: 'add_fab',
            onPressed: addItem,
            tooltip: '新条目',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
