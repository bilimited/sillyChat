import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:get/get.dart';

class PromptModel {
  int id;
  String content;
  String role;
  DateTime createDate;
  DateTime updateDate;
  String name;

  bool isDefault = false;

  bool isEnable = true;

  int? priority; // prompt排序，0代表最新消息之后，1代表最新消息之前

  PromptModel({
    required this.id,
    required this.content,
    required this.role,
    required this.name,
    DateTime? createDate,
    DateTime? updateDate,
    bool this.isDefault = false,
  })  : this.createDate = createDate ?? DateTime.now(),
        this.updateDate = updateDate ?? DateTime.now();

  PromptModel.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        content = json['content'],
        role = json['role'],
        name = json['name'],
        createDate = DateTime.parse(json['createDate']),
        updateDate = DateTime.parse(json['updateDate']),
        isEnable = json['isEnable'] ?? true,
        priority = json['priority'] ?? null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'role': role,
        'name': name,
        'createDate': createDate.toIso8601String(),
        'updateDate': updateDate.toIso8601String(),
        'isEnable': isEnable,
        'priority': priority,
      };

  PromptModel copy() {
    return PromptModel(
      id: id,
      content: content,
      role: role,
      name: name,
      createDate: createDate,
      updateDate: updateDate,
      isDefault: isDefault,
    )
      ..isEnable = isEnable
      ..priority = priority;
  }

  String getContent(ChatModel chat, {CharacterModel? sender = null}) {
    CharacterController characterController = Get.find();
    var assistant = sender == null ? chat.assistant : sender;
    var prompt = content;

    var user = chat.userId == null
        ? characterController.me
        : characterController.getCharacterById(chat.userId!);
    prompt = prompt.replaceAll('<user>', user.roleName);
    prompt = prompt.replaceAll('<userbrief>', user.brief ?? '');
    prompt = prompt.replaceAll('<description>', chat.description ?? '');
    prompt = BuildCharacterSystemPrompt(prompt, assistant);
    prompt = BuildRelationsPrompt(prompt, assistant, characterController, chat);
    prompt = injectCharacterLore(prompt, chat, assistant);
    return prompt;
  }

  static String BuildCharacterSystemPrompt(
      String prompt, CharacterModel character) {
    prompt = prompt.replaceAll('<char>', character.roleName);
    prompt = prompt.replaceAll('<brief>', character.brief ?? "");
    prompt = prompt.replaceAll('<archive>', character.archive);

    return prompt;
  }

  static String injectCharacterLore(
      String prompt, ChatModel chat, CharacterModel sender) {
    if (prompt.contains(RegExp(r'<recent-characters:\d+>'))) {
      CharacterController characterController = Get.find();

      final match = RegExp(r'<recent-characters:(\d+)>').firstMatch(prompt);
      if (match != null) {
        final count = int.parse(match.group(1)!);
        // Get characters who sent messages
        var recentChars = chat.messages
            .where((msg) =>
                msg.sender != chat.userId && msg.sender != chat.assistantId)
            .map((msg) => msg.sender)
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
    if (prompt.contains("<relations>")) {
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
          '<relations>', relationsText == "" ? "无人物关系。" : relationsText);
    }
    return prompt;
  }
}
