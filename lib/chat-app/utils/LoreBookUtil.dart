import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:get/get.dart';

/// 优化思路：
/// 对Message,Chat和Global设Dirty标志位和激活条目缓存
/// 对于群聊，每新增消息，计算所有角色世界书（不论）激活条目
class Lorebookutil {
  final List<LLMMessage> messages;
  late List<LorebookModel> lorebooks;
  late ChatModel chat;

  final LoreBookController loreBookController = Get.find();

  Lorebookutil({
    required this.messages,
    required ChatModel chat,
    required CharacterModel? sender,
  }) {
    this.chat = chat;
    this.lorebooks = getLorebooks(chat, sender);
  }

  List<LorebookModel> getLorebooks(ChatModel chat, CharacterModel? sender) {
    final global = loreBookController.globalActivitedLoreBooks;
    final char = sender?.lorebookIds
            .map((id) => loreBookController.getLorebookById(id))
            .nonNulls
            .toList() ??
        [];

    // 去除重复世界书
    final Set<int> uniqueIds = {};
    final List<LorebookModel> uniqueLorebooks = [];
    for (var lorebook in [
      ...global,
      ...char,
    ]) {
      if (!uniqueIds.contains(lorebook.id)) {
        uniqueIds.add(lorebook.id);
        uniqueLorebooks.add(lorebook);
      }
    }
    print("获取到 ${uniqueLorebooks.length} 个世界书");
    return uniqueLorebooks;
  }

  /// 世界书激活主流程
  List<LorebookItemModel> activateLorebooks() {
    // Step 1: 对每个Lorebook单独处理
    List<LorebookItemModel> activatedItems = [];
    for (var lorebook in lorebooks) {
      activatedItems.addAll(_getActivatedItems(lorebook));
    }
    print("激活了 ${activatedItems.length} 个条目");

    /// 按照 priority 从小到大排序，priority 越小越靠前。
    activatedItems.sort((a, b) => a.priority.compareTo(b.priority));

    return activatedItems;
  }

  // Step 6: 替换Prompt Message中的<lore id=x>
  static List<PromptModel> insertIntoPrompt(
      List<PromptModel> prompts, List<LorebookItemModel> items) {
    // 过滤掉position以@开头的item
    final filteredItems =
        items.where((item) => !(item.position.startsWith('@'))).toList();

    // 按position分组
    final Map<String, List<LorebookItemModel>> grouped = {};
    for (var item in filteredItems) {
      final pos = item.position.toString();
      grouped.putIfAbsent(pos, () => []).add(item);
    }

    // 拼接同组item的content
    final Map<String, String> positionContentMap = {};
    grouped.forEach((pos, items) {
      positionContentMap[pos] = items.map((e) => e.content).join('\n');
    });

    // 替换prompts中的<lore position>
    return prompts.map((prompt) {
      String newContent = prompt.content.replaceAllMapped(
        RegExp(r'<lore\s+([^\s>]+)(?:\s+default=(.*?))?>'),
        (match) {
          String pos = match.group(1) ?? '';
          String? defaultValue = match.group(2);

          String? loreContent = positionContentMap[pos];

          if (loreContent != null && loreContent.isNotEmpty) {
            return loreContent;
          } else if (defaultValue != null) {
            return defaultValue;
          } else {
            return '';
          }
        },
      );
      return prompt.copyWith(content: newContent, role: prompt.role);
    }).toList();
  }

  /// 获取某个世界书中所有激活的条目
  List<LorebookItemModel> _getActivatedItems(LorebookModel loreBook) {
    final allItems = loreBook.items;
    List<LorebookItemModel> activatedItems = [];

    for (var item in allItems) {
      // 非手动模式特殊对待
      if (item.activationType != ActivationType.manual) {
        final stat = chat.getLorebookItemStat(loreBook.id, item.id);
        if ((stat == null && item.isActive) || stat == true) {
          activatedItems.add(item);
        }
        continue;
      }

      // 跳过未启用、activationType为Always的条目
      if (!item.isActive) continue;
      if (item.activationType == ActivationType.always) {
        activatedItems.add(item);
        continue;
      }

      // 获取激活深度,取非Prompt消息,截取最后n条
      int depth =
          item.activationDepth > 0 ? item.activationDepth : loreBook.scanDepth;
      List<LLMMessage> nonPromptMsgs =
          messages.where((m) => !m.isPrompt).toList();
      List<LLMMessage> lastMsgs = nonPromptMsgs.length > depth
          ? nonPromptMsgs.sublist(nonPromptMsgs.length - depth)
          : nonPromptMsgs;

      // 对每条消息单独判断激活
      bool activated = false;
      for (var msg in lastMsgs) {
        if (item.verify(msg.content)) {
          activated = true;
          break;
        }
      }
      if (activated) {
        activatedItems.add(item);
      }
    }
    print("共找到${activatedItems.length}个匹配的Item");

    int totalLength =
        activatedItems.fold(0, (sum, item) => sum + item.content.length);
    if (totalLength > loreBook.maxToken) {
      Get.snackbar('世界书${loreBook.name}激活条目过长', '部分条目会被裁剪');
      // 若超过则执行以下逻辑：
      // 创建一个临时列表，将所有item按照priority排序
      List<LorebookItemModel> sortedItems = List.from(activatedItems)
        ..sort((a, b) => b.priority.compareTo(a.priority));
      // 按priority从高到低遍历，去除字数超过maxToken的部分
      List<LorebookItemModel> trimmedItems = [];
      int currentLength = 0;
      for (var item in sortedItems) {
        int itemLength = item.content.length;
        if (currentLength + itemLength <= loreBook.maxToken) {
          trimmedItems.add(item);
          currentLength += itemLength;
        }
      }
      activatedItems = trimmedItems;
    }

    return activatedItems;
  }
}
