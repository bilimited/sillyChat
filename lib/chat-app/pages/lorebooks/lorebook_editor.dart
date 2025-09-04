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
  late TextEditingController scanDepthController;
  late TextEditingController maxTokenController;
  late List<LorebookItemModel> items;
  late int id;
  final _formKey = GlobalKey<FormState>();
  late FocusNode nameFocusNode;
  late FocusNode scanDepthFocusNode;
  late FocusNode maxTokenFocusNode;

  @override
  void initState() {
    super.initState();
    final lorebook = widget.lorebook;
    id = lorebook?.id ?? DateTime.now().millisecondsSinceEpoch;
    nameController = TextEditingController(text: lorebook?.name ?? '');
    scanDepthController =
        TextEditingController(text: (lorebook?.scanDepth ?? 3).toString());
    maxTokenController =
        TextEditingController(text: (lorebook?.maxToken ?? 2048).toString());
    items = lorebook?.items.map((e) => e.copyWith()).toList() ?? [];
    nameFocusNode = FocusNode();
    scanDepthFocusNode = FocusNode();
    maxTokenFocusNode = FocusNode();
    for (var node in [nameFocusNode, scanDepthFocusNode, maxTokenFocusNode]) {
      node.addListener(() {
        if (!node.hasFocus) {
          saveLorebook();
        }
      });
    }
  }

  @override
  void dispose() {
    nameFocusNode.dispose();
    scanDepthFocusNode.dispose();
    maxTokenFocusNode.dispose();
    super.dispose();
  }

  Future<void> saveLorebook() async {
    final controller = Get.find<LoreBookController>();
    final lorebook = LorebookModel(
      id: id,
      name: nameController.text.trim(),
      items: items,
      scanDepth: int.tryParse(scanDepthController.text) ?? 3,
      maxToken: int.tryParse(maxTokenController.text) ?? 2048,
    );
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
      items.add(LorebookItemModel(
        id: DateTime.now().millisecondsSinceEpoch,
        name: '新条目',
        content: '',
      ));
    });
  }

  void copyItem(int index) {
    LoreBookController.of.lorebookItemClipboard.value = items[index];
    SillyChatApp.snackbar(context, '条目"${items[index].name}"已复制到剪贴板');
  }

  void pasteItem() {
    final item = LoreBookController.of.lorebookItemClipboard.value;
    if (item == null) {
      return;
    }
    setState(() {
      items.add(item.copyWith(
        id: DateTime.now().millisecondsSinceEpoch,
        name: item.name,
      ));
    });

    LoreBookController.of.lorebookItemClipboard.value = null;
  }

  void deleteItem(int index) {
    // 添加二次确认
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除此条目吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                deleteItemConfirmed(index);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  void deleteItemConfirmed(int index) {
    setState(() {
      items.removeAt(index);
      saveLorebook();
    });
  }

  void toggleItemActive(int index, bool value) {
    setState(() {
      items[index] = items[index].copyWith(isActive: value);
      saveLorebook();
    });
  }

  void reorderItems(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑世界书'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: saveLorebookAndBack,
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: addItem,
      //   icon: const Icon(Icons.add),
      //   label: const Text('添加条目'),
      // ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 基本信息
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: nameController,
                        focusNode: nameFocusNode,
                        decoration: const InputDecoration(
                          labelText: '世界书名称',
                          prefixIcon: Icon(Icons.book),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: scanDepthController,
                              focusNode: scanDepthFocusNode,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '激活深度',
                                prefixIcon: Icon(Icons.layers),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: maxTokenController,
                              focusNode: maxTokenFocusNode,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '最大Token',
                                prefixIcon: Icon(Icons.memory),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // 条目列表
              Text(
                '条目列表',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                onReorder: reorderItems,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    key: ValueKey(item.id),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        item.name,
                        style: theme.textTheme.bodyLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 30, // Example width
                            height: 20, // Example height
                            child: Transform.scale(
                              scale:
                                  0.7, // Scale down to fit within the SizedBox
                              child: Switch(
                                value: item.isActive,
                                onChanged: (v) => toggleItemActive(index, v),
                                activeColor: theme.colorScheme.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          DropdownButton<ActivationType>(
                            value: item.activationType,
                            onChanged: (v) => {
                              if (v != null)
                                setState(() {
                                  items[index] =
                                      item.copyWith(activationType: v);
                                  saveLorebook();
                                })
                            },
                            items: ActivationType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  _activationTypeLabel(type),
                                  style: TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'copy',
                                child: Row(
                                  children: const [
                                    Icon(Icons.copy, size: 18),
                                    SizedBox(width: 8),
                                    Text('复制'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: const [
                                    Icon(Icons.delete,
                                        color: Colors.red, size: 18),
                                    SizedBox(width: 8),
                                    Text('删除',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'delete') {
                                deleteItem(index);
                              } else if (value == 'copy') {
                                copyItem(index);
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        // 可跳转到条目详细编辑页
                        customNavigate(
                            LoreBookItemEditorPage(
                              item: items[index],
                              onSave: (item) {
                                setState(() {
                                  items[index] = item;
                                  saveLorebook();
                                });
                              },
                            ),
                            context: context);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(
                height: 10,
              ),
              ElevatedButton.icon(
                  onPressed: addItem,
                  icon: Icon(Icons.add),
                  label: Text('新条目')),
              const SizedBox(
                height: 10,
              ),
              Obx(() =>
                  LoreBookController.of.lorebookItemClipboard.value != null
                      ? ElevatedButton.icon(
                          onPressed: pasteItem,
                          icon: Icon(Icons.paste),
                          label: Text('粘贴条目'))
                      : SizedBox.shrink()),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

String _activationTypeLabel(ActivationType type) {
  switch (type) {
    case ActivationType.always:
      return '🔵总是';
    case ActivationType.keywords:
      return '🟢关键词';
    case ActivationType.rag:
      return '⛓️RAG';
    case ActivationType.manual:
      return '✋手动';
  }
}
