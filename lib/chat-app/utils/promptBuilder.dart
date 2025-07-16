import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/models/settings/prompt_setting_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/LoreBookUtil.dart';
import 'package:flutter_example/chat-app/utils/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/promptFormatter.dart';
import 'package:get/get.dart';

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

  /// 史诗抽象超长代码
  /// sender!=null ,则为群聊模式
  List<LLMMessage> getLLMMessageList(ChatModel chat, {CharacterModel? sender}) {
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

    /// 获取消息列表（不包含Prompt）
    ///
    /// -----------------------------------------------------------

    // 需要保留的消息索引：末尾maxMsgs条+所有pinned-所有hidden
    final keepIndexes = <int>{
      ...List.generate(total - start, (i) => start + i),
      ...pinnedIndexes
    }..removeAll(hiddenIndexs);
    final msgIndexes = List.generate(chat.messages.length, (i) => i)
        .where((i) => keepIndexes.contains(i))
        .toList();

    // 计算主消息列表，并计算它们的priority
    final msglst = [
      //...sysPrompts,
      ...msgIndexes.map((i) {
        final msg = chat.messages[i];
        final content = _propressMessage(msg.content, chat.requestOptions);
        if (sender == null) {
          return LLMMessage(
              content: content,
              role: msg.isAssistant ? "assistant" : "user",
              fileDirs: msg.resPath,
              senderId: msg.sender);
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

    // 如果出现了两个连续的assistant消息，且它们的senderId相同，则在它们之间插入一个用户消息
    if (msglst.length >= 2) {
      for (int i = 0; i < msglst.length - 1; i++) {
        if (msglst[i].role == "assistant" &&
            msglst[i + 1].role == "assistant" &&
            msglst[i].senderId == msglst[i + 1].senderId) {
          msglst.insert(
              i + 1,
              LLMMessage(
                content: promptSetting.interAssistantUserSeparator,
                role: "user",
              ));
          i++; // 跳过插入的用户消息
        }
      }
    }

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
        return msglst;
      }
      return [LLMMessage.fromPromptModel(prompt)];
    }).toList();
  }
}
