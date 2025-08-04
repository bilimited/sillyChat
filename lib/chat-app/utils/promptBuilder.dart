import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/models/settings/prompt_setting_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/LoreBookUtil.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/promptFormatter.dart';
import 'package:get/get.dart';

class Promptbuilder {
  String _propressMessage(String content, LLMRequestOptions options) {
    // 处理消息内容，删除thinking标记
    if (options.isDeleteThinking) {
      content =
          content.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
    }
    return content;
  }

  /// 获得全部消息的列表（不包括Prompt，不格式化）
  List<LLMMessage> getMessageList(ChatModel chat, {CharacterModel? sender}) {
    final characterController = Get.find<CharacterController>();
    PromptSettingModel promptSetting =
        Get.find<VaultSettingController>().promptSettingModel.value;

    int maxMsgs = chat.requestOptions.maxHistoryLength;
    final int total = chat.messages.length;
    final int start = total > maxMsgs ? total - maxMsgs : 0;
    final pinnedIndexes = <int>{};
    final hiddenIndexs = <int>{};
    for (int i = 0; i < chat.messages.length; i++) {
      if (chat.messages[i].isPinned == true) {
        pinnedIndexes.add(i);
      } else if (chat.messages[i].isHidden == true) {
        hiddenIndexs.add(i);
      }
    }

    final keepIndexes = <int>{
      ...List.generate(total - start, (i) => start + i),
      ...pinnedIndexes
    }..removeAll(hiddenIndexs);
    final msgIndexes = List.generate(chat.messages.length, (i) => i)
        .where((i) => keepIndexes.contains(i))
        .toList();

    return [
      //...sysPrompts,
      ...msgIndexes.map((i) {
        final msg = chat.messages[i];
        String content = _propressMessage(msg.content, chat.requestOptions);

        // 处理正则
        chat.vaildRegexs
            .where((reg) => reg.onRequest && reg.isAvailable(chat, msg))
            .forEach((regex) {
          content = regex.process(content);
        });

        // 合并消息列表：在一切消息前添加名称
        if (chat.requestOptions.isMergeMessageList) {
          return LLMMessage(
              content: promptSetting.groupFormatter
                  .replaceAll('<char>',
                      characterController.getCharacterById(msg.sender).roleName)
                  .replaceAll('<message>', content),
              role: msg.sender == (sender?.id ?? chat.assistantId)
                  ? "assistant"
                  : "user",
              fileDirs: msg.resPath,
              senderId: msg.sender);
          // 不合并消息列表，聊天模式
        } else if (sender == null) {
          return LLMMessage(
              content: content,
              role: msg.isAssistant ? "assistant" : "user",
              fileDirs: msg.resPath,
              senderId: msg.sender);
          // 不合并消息列表，群聊模式
        } else {
          return LLMMessage(
              content: msg.sender == sender.id
                  ? content
                  : promptSetting.groupFormatter
                      .replaceAll(
                          '<char>',
                          characterController
                              .getCharacterById(msg.sender)
                              .roleName)
                      .replaceAll('<message>', content),
              role: msg.sender == sender.id ? "assistant" : "user",
              fileDirs: msg.resPath,
              senderId: msg.sender);
        }
      })
    ];
  }

  /// 史诗抽象超长代码
  /// sender!=null ,则为群聊模式
  /// TODO:和酒馆有一个区别：最新消息（用户发的那条）会被移除并放到<lastUserMessage>宏里。需要加一个开关显式控制
  /// 另一个 TODO:因为Gemini没有system，融合同role消息开关可能要与API绑定
  List<LLMMessage> getLLMMessageList(ChatModel chat, {CharacterModel? sender}) {
    PromptSettingModel promptSetting =
        Get.find<VaultSettingController>().promptSettingModel.value;

    final msglst = getMessageList(chat, sender: sender);

    /// 用户消息提取：一般是最后一条消息，如果最后一条消息为空则填充默认消息
    /// 更改：现在默认不会删除用户消息，以和ST逻辑保持一致。
    late String userMessage;
    if (msglst.isNotEmpty && msglst.last.role == 'user') {
      userMessage = msglst.last.content;
    } else {
      if (sender == null) {
        userMessage = promptSetting.continuePrompt;
      } else {
        userMessage = promptSetting.groupFormatter
            .replaceAll('char', sender.roleName)
            .replaceAll('<message>', '');
      }
    }

    /// Prompt处理
    /// 步骤：1. 2. 3. 3.5: 4.,PM->LLM 5.
    /// -----------------------------------------------------------

    /// Step 1 世界书激活
    final Stopwatch stopwatch = Stopwatch()..start();
    final loreBook = Lorebookutil(
        messages: msglst,
        chat: chat,
        sender: sender ??
            Get.find<CharacterController>()
                .getCharacterById(chat.assistantId ?? 0));
    final loreBooks = loreBook.activateLorebooks();
    stopwatch.stop();
    print("激活世界书耗时: ${stopwatch.elapsedMilliseconds} ms");

    final activitedPrompts =
        chat.prompts.where((prompt) => prompt.isEnable).toList();

    /// Step 2 世界书插入PM
    final promptsAfterInsertLore =
        Lorebookutil.insertIntoPrompt(activitedPrompts, loreBooks);

    final STVars = <String, String>{};

    /// Step 3 宏和用户消息插入PM
    final promptsAfterFormat = promptsAfterInsertLore
        .map((prompt) => prompt.copyWith(
            content: Promptformatter.formatPrompt(prompt.content, chat,
                sender: sender, userMessage: userMessage, STVaribles: STVars)))
        .toList();
    final promptsNotEmpty = promptsAfterFormat
        .where((msg) => !(msg.content.isBlank ?? false))
        .toList();

    /// Step 3.5 单独提取"聊天中"Prompt
    final promptsInChat = <PromptModel>[];
    promptsNotEmpty.removeWhere((prompt) {
      if (prompt.isInChat) {
        promptsInChat.add(prompt);
        return true;
      } else {
        return false;
      }
    });

    /// Step 4 将”聊天中“Prompt、@D世界书插入正文
    
    _insertInChatLoreBook(msglst, loreBooks);
    _insertInChatPrompt(msglst, promptsInChat);
    

    final llmMessages = promptsNotEmpty.expand<LLMMessage>((prompt) {
      if (prompt.isChatHistory) {
        if (chat.requestOptions.isMergeMessageList) {
          final merged = _mergeChatHistory(msglst);
          return merged.content.isEmpty ? [] : [_mergeChatHistory(msglst)];
        } else {
          return msglst;
        }
      }
      return [LLMMessage.fromPromptModel(prompt)];
    }).toList();

    return llmMessages;
  }

  /// 排序并插入”聊天中“Prompt
  List<LLMMessage> _insertInChatPrompt(
      List<LLMMessage> llmMessages, List<PromptModel> inChatPrompts) {
    if (inChatPrompts.isEmpty) {
      return llmMessages;
    }

    /// Step 1: inChatPrompts按照priority排序，若priority相同则按照User,Assistant,System的顺序进行稳定排序
    inChatPrompts.sort((a, b) {
      if (a.priority == b.priority) {
        return _compareRole(a.role, b.role);
      }
      return a.priority.compareTo(b.priority);
    });

    /// Step 2: 对排序后的Prompt进行遍历，按照其depth转换并插入llmMessages(0代表最后一条消息之后，1代表最后一条消息之前，以此类推)
    for (final prompt in inChatPrompts) {
      int depth = prompt.depth;
      if (depth < 0) continue;

      if (depth > llmMessages.length) depth = llmMessages.length;

      llmMessages.insert(
          llmMessages.length - depth, LLMMessage.fromPromptModel(prompt));
    }

    return llmMessages;
  }

  List<LLMMessage> _insertInChatLoreBook(
      List<LLMMessage> llmMessages, List<LorebookItemModel> lorebooks) {
    final filteredItems =
        lorebooks.where((item) => item.position.startsWith('@D'));

    if (filteredItems.isEmpty) {
      return llmMessages;
    }


    for (final item in filteredItems) {
      int depth = item.positionId;
      if (depth < 0) continue;

      if (depth > llmMessages.length) depth = llmMessages.length;

      llmMessages.insert(
          llmMessages.length - depth,
          LLMMessage(
              content: item.content, role: item.position.replaceAll('@D', '')));
    }
    return llmMessages;
  }

  int _compareRole(String role1, String role2) {
    if (role1 == role2) return 0;
    if (role1 == 'assistant') return -1; // assistant < user < system
    if (role2 == 'assistant') return 1;
    if (role1 == 'user') return -1; // user < system
    if (role2 == 'user') return 1;
    return 0; // system
  }

  LLMMessage _mergeChatHistory(List<LLMMessage> msglst) {
    return msglst.fold(LLMMessage(content: '', role: 'user', fileDirs: []),
        (res, msg) {
      res.fileDirs.addAll(msg.fileDirs);
      return LLMMessage(
          content: res.content + '\n' + msg.content,
          role: 'user',
          fileDirs: res.fileDirs);
    });
  }
}
