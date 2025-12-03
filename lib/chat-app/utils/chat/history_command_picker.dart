import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';

class HistoryCommandPicker {
  // 添加命令到历史记录（自动去重、截断、保留收藏项）
  static void addCommandToHistory(
    String command,
  ) {
    final controller = VaultSettingController.of();
    final historyList = controller.historyModel.value.commandHistory.toList();

    // 移除完全相同的条目（包括带或不带 favorite:: 的情况）
    // 注意：如果用户输入的是普通命令，但历史中已有带 favorite:: 的同名命令，我们认为它们是同一个命令
    final normalizedCommand = command;
    historyList.removeWhere((item) {
      if (item == normalizedCommand) return true;
      if (item.startsWith('favorite::') &&
          item.substring('favorite::'.length) == normalizedCommand) return true;
      return false;
    });

    // 插入到最前面（最新）
    historyList.insert(0, normalizedCommand);

    // 分离收藏项和普通项
    final favorites = <String>[];
    final regulars = <String>[];

    for (final item in historyList) {
      if (item.startsWith('favorite::')) {
        favorites.add(item);
      } else {
        regulars.add(item);
      }
    }

    // 保留最多 30 条普通命令（新到旧）
    if (regulars.length > 30) {
      regulars.removeRange(30, regulars.length);
    }

    // 合并：先收藏（保持原有顺序），再普通命令（已截断）
    // 注意：收藏项通常数量少且用户希望保留，因此不参与数量限制
    final newHistory = <String>[
      ...favorites,
      ...regulars,
    ];

    // 更新模型
    controller.historyModel.value = controller.historyModel.value.copyWith(
      commandHistory: newHistory,
    );
  }

  static Future<String?> showHistoryCommandPicker(BuildContext context) async {
    final history =
        VaultSettingController.of().historyModel.value.commandHistory;

    // 分离收藏与普通命令
    final favoriteCommands = <String>[];
    final regularCommands = <String>[];

    for (final cmd in history) {
      if (cmd.startsWith('favorite::')) {
        favoriteCommands.add(cmd.substring('favorite::'.length));
      } else {
        regularCommands.add(cmd);
      }
    }

    // 构建列表项
    final items = <Widget>[];

    if (favoriteCommands.isNotEmpty) {
      items.add(const ListTile(
        title: Text('⭐ 收藏命令'),
        enabled: false,
        dense: true,
      ));
      for (final cmd in favoriteCommands) {
        items.add(
          ListTile(
            title: Text(cmd),
            onTap: () {
              Navigator.of(context).pop(cmd);
            },
          ),
        );
      }
      if (regularCommands.isNotEmpty) {
        items.add(const Divider()); // 分隔线
      }
    }

    if (regularCommands.isNotEmpty) {
      items.add(const ListTile(
        title: Text('🕒 历史命令'),
        enabled: false,
        dense: true,
      ));
      for (final cmd in regularCommands) {
        items.add(
          ListTile(
            title: Text(cmd),
            onTap: () {
              Navigator.of(context).pop(cmd);
            },
          ),
        );
      }
    }

    // 如果没有历史命令
    if (items.isEmpty) {
      items.add(const ListTile(
        title: Text('暂无历史命令'),
        enabled: false,
      ));
    }

    return await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text('选择历史命令',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: items,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
