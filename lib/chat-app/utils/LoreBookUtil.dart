import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/utils/llmMessage.dart';
import 'package:get/get.dart';

class Lorebookutil {
  final List<LLMMessage> messages;
  late List<LorebookModel> lorebooks;

  final LoreBookController loreBookController = Get.find();

  Lorebookutil({
    required this.messages,
    required ChatModel chat,
    required CharacterModel? sender,
  }) {
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
  List<LLMMessage> activateLorebooks() {
    // Step 1: 对每个Lorebook单独处理
    List<LorebookItemModel> activatedItems = [];
    for (var lorebook in lorebooks) {
      activatedItems.addAll(_getActivatedItems(lorebook));
    }
    print("激活了 ${activatedItems.length} 个条目");

    // Step 5: 按positionId分组，拼接内容
    Map<int, List<LorebookItemModel>> grouped = {};
    for (var item in activatedItems) {
      grouped.putIfAbsent(item.positionId, () => []).add(item);
    }
    Map<int, String> positionLoreMap = {};
    grouped.forEach((posId, items) {
      // 按优先级排序（先不排了）
      // items.sort((a, b) => b.priority.compareTo(a.priority));
      positionLoreMap[posId] = items.map((e) => e.content).join('\n');
    });

    // Step 6: 替换Prompt Message中的<lore id=x>
    List<LLMMessage> result = messages.map((msg) {
      if (!msg.isPrompt) return msg;
      String newContent = msg.content.replaceAllMapped(
        RegExp(r'<lore id=(\d+)(?:\s+default=(.*?))?>'), // 改进后的正则表达式
        (match) {
          int posId = int.tryParse(match.group(1) ?? '') ?? 0;
          String? defaultValue = match.group(2); // 获取 default 后面的内容，可能为 null

          // 尝试从 positionLoreMap 中获取世界书内容
          String? loreContent = positionLoreMap[posId];

          // 如果世界书内容存在，则使用世界书内容
          if (loreContent != null && loreContent.isNotEmpty) {
            return loreContent;
          } else if (defaultValue != null) {
            // 如果世界书内容不存在，但提供了默认值，则使用默认值
            return defaultValue;
          } else {
            // 如果世界书内容不存在，且没有提供默认值，则替换为空字符串
            return '';
          }
        },
      );
      return LLMMessage(
        content: newContent,
        role: msg.role,
        fileDirs: msg.fileDirs,
        priority: msg.priority,
        isPrompt: msg.isPrompt,
      );
    }).toList();

    return result;
  }

  /// 获取某个世界书中所有激活的条目
  List<LorebookItemModel> _getActivatedItems(LorebookModel loreBook) {
    final allItems = loreBook.items;
    List<LorebookItemModel> activatedItems = [];

    for (var item in allItems) {
      // 跳过未启用、activationType为Always的条目
      if (!item.isActive) continue;
      if (item.activationType == ActivationType.always || item.activationType == ActivationType.manual) {
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

    // 计算所有Item的Content字数总和，若未超过loreBook.maxToken则跳过
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
