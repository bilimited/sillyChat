import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STMarcoProcesser.dart';
import 'package:get/get.dart';

abstract class Promptformatter {
  static String formatPrompt(String content, ChatModel chat,
      {CharacterModel? sender = null,
      String userMessage = '',
      Map<String, String>? STVaribles}) {
    CharacterController characterController = Get.find();
    var assistant = sender == null ? chat.assistant : sender;
    var prompt = content;

    var user = chat.userId == null
        ? characterController.me
        : characterController.getCharacterById(chat.userId!);
    prompt = prompt.replaceAll(
        RegExp(r'\{\{user\}\}', caseSensitive: false), user.roleName);
    prompt = prompt.replaceAll('{{userbrief}}', user.brief ?? '');
    prompt = prompt.replaceAll('{{description}}', chat.description ?? '');
    prompt = prompt.replaceAll(
        RegExp(r'\{\{lastuserMessage\}\}|\{\{lastmessage\}\}',
            caseSensitive: false),
        userMessage); // 兼容酒馆
    prompt = BuildCharacterSystemPrompt(prompt, assistant);
    prompt = BuildRelationsPrompt(prompt, assistant, characterController, chat);
    prompt = injectCharacterLore(prompt, chat, assistant);
    if (STVaribles != null) {
      prompt = handleSTMacro(prompt, STVaribles);
    }
    // 清除注释
    prompt = prompt.replaceAll(RegExp(r"\{\{.*?\}\}"), '');
    return prompt;
  }

  static String BuildCharacterSystemPrompt(
      String prompt, CharacterModel character) {
    prompt = prompt.replaceAll(
        RegExp(r'\{\{char\}\}', caseSensitive: false), character.roleName);
    prompt = prompt.replaceAll('{{brief}}', character.brief ?? "");
    prompt = prompt.replaceAll('{{archive}}', character.archive);

    return prompt;
  }

  static String injectCharacterLore(
      String prompt, ChatModel chat, CharacterModel sender) {
    if (prompt.contains(RegExp(r'{{recent-characters:\d+}}'))) {
      CharacterController characterController = Get.find();

      final match = RegExp(r'{{recent-characters:(\d+)}}').firstMatch(prompt);
      if (match != null) {
        final count = int.parse(match.group(1)!);
        // Get characters who sent messages
        var recentChars = chat.messages
            .where((msg) =>
                msg.senderId != chat.userId && msg.senderId != chat.assistantId)
            .map((msg) => msg.senderId)
            .toSet();

        // Get characters mentioned in recent messages
        var mentionedChars = chat.messages.reversed
            .take(count)
            .expand((msg) => characterController.characters
                .where((char) => msg.content.contains(char.roleName))
                .map((char) => char.id))
            .toSet();

        // Combine both sets and take requested count
        recentChars.addAll(mentionedChars);
        recentChars.remove(sender.id);
        // 已存在于关系列表中的角色不会被注入
        recentChars.removeAll(sender.relations.keys);
        recentChars.remove(0); // 旁白不会被注入

        String recentCharsText = recentChars.isEmpty
            ? "无更多角色。"
            : recentChars.map((id) {
                final char = characterController.getCharacterById(id);
                return "${char.roleName}: ${char.brief}";
              }).join("\n");

        prompt = prompt.replaceAll(match.group(0)!, recentCharsText);
      }
    }
    return prompt;
  }

  static String BuildRelationsPrompt(
    String prompt,
    CharacterModel character,
    CharacterController character_controller,
    ChatModel chat,
  ) {
    if (prompt.contains("{{relations}}")) {
      var relationsText = "";
      var relatedCharacters = Map<int, dynamic>.from(character.relations)
        ..removeWhere((key, value) => !chat.characterIds.contains(key))
        ..keys.toList();

      for (var entry in relatedCharacters.entries) {
        var anotherOne = character_controller.getCharacterById(entry.key);
        var typeText = (entry.value.type != null &&
                entry.value.type!.isNotEmpty)
            ? "${anotherOne.roleName}是${character.roleName}的${entry.value.type}。"
            : "";
        var brief = entry.value.brief;

        relationsText += """### ${anotherOne.roleName}
${anotherOne.brief}
${typeText} ${brief}
""";
      }

      prompt = prompt.replaceAll(
          '{{relations}}', relationsText == "" ? "无人物关系。" : relationsText);
    }
    return prompt;
  }

  /// 兼容SillyTarvern宏
  /// 对传入Prompt进行正则匹配
  static String handleSTMacro(String prompt, Map<String, String> varibles) {
    return STMacroProcessor.handleSTMacro(prompt, varibles);
  }
}
