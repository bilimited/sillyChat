import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:get/get.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';

class LoreBookActivator extends StatefulWidget {
  final List<LorebookModel> lorebooks;
  final ChatModel chat;

  const LoreBookActivator(
      {super.key, required this.chat, required this.lorebooks});

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
        if (item.activationType == ActivationType.manual) {
          //entries.add(_LorebookItemEntry(lorebook: lorebook, item: item));
          itemMap['${lorebook.id}@${item.id}'] = item.isActive;
        }
      }
    }

    for (final entry in widget.chat.activitedLorebookItems.entries) {
      itemMap[entry.key] = entry.value;
    }
  }

  Future<void> _toggleItemActive(
      LorebookModel lorebook, LorebookItemModel item, bool value) async {
    //final controller = Get.find<LoreBookController>();
    final chatController = Get.find<ChatController>();
    // final idx = lorebook.items.indexWhere((e) => e.id == item.id);
    // if (idx == -1) return;
    // final updatedItems = List<LorebookItemModel>.from(lorebook.items);
    // updatedItems[idx] = item.copyWith(isActive: value);
    // final updatedLorebook = lorebook.copyWith(items: updatedItems);

    setState(() {
      // widget.lorebooks[widget.lorebooks
      //     .indexWhere((l) => l.id == lorebook.id)] = updatedLorebook;
      itemMap['${lorebook.id}@${item.id}'] = value;
    }); // 刷新界面
    widget.chat.activitedLorebookItems = itemMap;
    await chatController.saveChats(widget.chat.fileId);
    //await controller.updateLorebook(updatedLorebook);
  }

  @override
  Widget build(BuildContext context) {
    final List<_LorebookItemEntry> entries = [];
    for (final index in itemMap.entries) {
      int loreBookId = int.parse(index.key.split('@')[0]);
      int itemId = int.parse(index.key.split('@')[1]);
      LorebookModel? lorebookModel =
          loreBookController.getLorebookById(loreBookId);
      if (lorebookModel != null) {
        LorebookItemModel? itemModel =
            lorebookModel.items.firstWhereOrNull((item) => item.id == itemId);
        if (itemModel != null) {
          entries.add(
              _LorebookItemEntry(lorebook: lorebookModel, item: itemModel, isActive: index.value));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('手动激活世界书条目'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SwitchListTile(
          //   title: const Text('只显示手动激活的世界书条目'),
          //   value: onlyManual,
          //   onChanged: (v) => setState(() => onlyManual = v),
          // ),
          // const Divider(),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('暂无条目'))
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final item = entry.item;
                      return ListTile(
                        dense: true,
                        title: Text(
                          item.name,
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          item.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 12),
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
      ),
    );
  }
}

class _LorebookItemEntry {
  final LorebookModel lorebook;
  final LorebookItemModel item;
  final bool isActive;
  _LorebookItemEntry({required this.lorebook, required this.item, required this.isActive});
}
