import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/models/settings/prompt_setting_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/LoreBookUtil.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/promptFormatter.dart';
import 'package:get/get.dart';

// TODO: 恢复Prompt按深度插入
class Promptbuilder {
  // List<PromptModel> processVaribles(List<PromptModel> prompts){

  // }

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
        final content = _propressMessage(msg.content, chat.requestOptions);

        // 合并消息列表：在一切消息前添加名称
        if (chat.requestOptions.isMergeMessageList) {
          return LLMMessage(
              content: promptSetting.groupFormatter
                  .replaceAll('<char>',
                      characterController.getCharacterById(msg.sender).roleName)
                  .replaceAll('<message>', content),
              role: msg.sender == (sender?.id ?? chat.assistantId) ? "assistant" : "user",
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
  List<LLMMessage> getLLMMessageList(ChatModel chat, {CharacterModel? sender}) {
    PromptSettingModel promptSetting =
        Get.find<VaultSettingController>().promptSettingModel.value;

    final msglst = getMessageList(chat, sender: sender);

    late String userMessage;
    if (msglst.isNotEmpty && msglst.last.role == 'user') {
      userMessage = msglst.removeLast().content;
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
    /// 步骤：1.世界书激活 2. 插入世界书 3. 格式化所有Prompt 4. 插入正文 5. 插入用户请求
    /// -----------------------------------------------------------

    final Stopwatch stopwatch = Stopwatch()..start();
    final loreBook = Lorebookutil(
        messages: msglst,
        chat: chat,
        sender: sender ??
            Get.find<CharacterController>()
                .getCharacterById(chat.assistantId ?? 0));
    final loreMap = loreBook.activateLorebooks();
    stopwatch.stop();
    print("激活世界书耗时: ${stopwatch.elapsedMilliseconds} ms");

    final activitedPrompts =
        chat.prompts.where((prompt) => prompt.isEnable).toList();
    final promptsAfterInsertLore =
        Lorebookutil.insertIntoPrompt(activitedPrompts, loreMap);
    final promptsAfterFormat = promptsAfterInsertLore
        .map((prompt) => prompt.copyWith(
            content: Promptformatter.formatPrompt(prompt.content, chat,
                sender: sender, userMessage: userMessage)))
        .toList();

    final promptsNotEmpty = promptsAfterFormat
        .where((msg) => !(msg.content.isBlank ?? false))
        .toList();

    return promptsNotEmpty.expand<LLMMessage>((prompt) {
      if (prompt.isMessageList) {
        if (chat.requestOptions.isMergeMessageList) {
          final merged = mergeMessageList(msglst);
          return merged.content.isEmpty ? [] : [mergeMessageList(msglst)];
        } else {
          return msglst;
        }
      }
      return [LLMMessage.fromPromptModel(prompt)];
    }).toList();
  }

  LLMMessage mergeMessageList(List<LLMMessage> msglst) {
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
