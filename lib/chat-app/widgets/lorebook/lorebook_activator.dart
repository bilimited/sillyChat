import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/pages/lorebooks/lorebook_editor.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';

class LoreBookActivator extends StatefulWidget {
  final List<LorebookModel> lorebooks;
  final ChatSessionController chatSessionController;

  const LoreBookActivator(
      {super.key,
      required this.chatSessionController,
      required this.lorebooks,
      required ChatModel chat});

  @override
  State<LoreBookActivator> createState() => _LoreBookActivatorState();
}

class _LoreBookActivatorState extends State<LoreBookActivator> {
  bool onlyManual = true;
  final Map<String, bool> itemMap = {};
  final LoreBookController loreBookController = Get.find();

  @override
  void initState() {
    super.initState();
    for (final lorebook in widget.lorebooks) {
      for (final item in lorebook.items) {
        if (item.activationType != ActivationType.manual) {
          //entries.add(_LorebookItemEntry(lorebook: lorebook, item: item));
          itemMap['${lorebook.id}@${item.id}'] = item.isActive;
        }
      }
    }

    for (final entry
        in widget.chatSessionController.chat.activitedLorebookItems.entries) {
      itemMap[entry.key] = entry.value;
    }
  }

  Future<void> _toggleItemActive(
      LorebookModel lorebook, LorebookItemModel item, bool value) async {
    setState(() {
      itemMap['${lorebook.id}@${item.id}'] = value;
    }); // 刷新界面
    widget.chatSessionController.chat.activitedLorebookItems = itemMap;
    await widget.chatSessionController.saveChat();
  }

  @override
  Widget build(BuildContext context) {
    final Map<LorebookModel, List<_LorebookItemEntry>> groupedEntries = {};

    for (final index in itemMap.entries) {
      int loreBookId = int.parse(index.key.split('@')[0]);
      int itemId = int.parse(index.key.split('@')[1]);
      LorebookModel? lorebookModel =
          loreBookController.getLorebookById(loreBookId);
      if (lorebookModel != null) {
        LorebookItemModel? itemModel =
            lorebookModel.items.firstWhereOrNull((item) => item.id == itemId);
        if (itemModel != null) {
          final entry = _LorebookItemEntry(
              lorebook: lorebookModel, item: itemModel, isActive: index.value);
          if (!groupedEntries.containsKey(lorebookModel)) {
            groupedEntries[lorebookModel] = [];
          }
          groupedEntries[lorebookModel]!.add(entry);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '临时开关世界书条目',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '做出的更改仅在当前聊天有效',
              style: TextStyle(fontSize: 13),
            )
          ],
        ),
      ),
      body: groupedEntries.isEmpty
          ? const Center(child: Text('暂无条目'))
          : ListView.builder(
              itemCount: groupedEntries.length,
              itemBuilder: (context, index) {
                final lorebook = groupedEntries.keys.elementAt(index);
                final entries = groupedEntries[lorebook]!;
                // 使用 ExpansionTile 替代 Column 来实现可折叠效果
                return ExpansionTile(
                  // 分组标题
                  title: Text(
                    lorebook.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  trailing: IconButton(
                      onPressed: () {
                        customNavigate(
                            LoreBookEditorPage(
                              lorebook: lorebook,
                            ),
                            context: context);
                      },
                      icon: Icon(Icons.more_horiz)),
                  // 默认保持展开状态
                  initiallyExpanded: true,
                  // 可折叠的内容，即条目列表
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, itemIndex) {
                          final entry = entries[itemIndex];
                          final item = entry.item;
                          return ListTile(
                            dense: true,
                            title: Text(
                              item.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              item.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.outline,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Transform.scale(
                              scale: 0.7,
                              child: Switch(
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                value: entry.isActive,
                                onChanged: (v) =>
                                    _toggleItemActive(entry.lorebook, item, v),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _LorebookItemEntry {
  final LorebookModel lorebook;
  final LorebookItemModel item;
  final bool isActive;
  _LorebookItemEntry(
      {required this.lorebook, required this.item, required this.isActive});
}
