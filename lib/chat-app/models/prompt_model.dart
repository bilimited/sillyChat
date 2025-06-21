import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:get/get.dart';

enum PromptCategory {
  general,
  character,
  story,
  init,
  custom,
}

class PromptModel {
  int id;
  String content;
  String role;
  DateTime createDate;
  DateTime updateDate;
  String name;
  PromptCategory category;
  String? customCategory;
  int? customPriority;

  bool isDefault = false;

  PromptModel({
    required this.id,
    required this.content,
    required this.role,
    required this.name,
    required this.category,
    this.customCategory,
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
        category = PromptCategory.values.firstWhere(
            (e) => e.toString() == 'PromptCategory.${json['category']}'),
        customCategory = json['customCategory'],
        createDate = DateTime.parse(json['createDate']),
        updateDate = DateTime.parse(json['updateDate']),
        customPriority = json['customPriority'] == 'null'
            ? null
            : int.tryParse(json['customPriority']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'role': role,
        'name': name,
        'category': category.toString().split('.').last,
        'customCategory': customCategory,
        'createDate': createDate.toIso8601String(),
        'updateDate': updateDate.toIso8601String(),
        'customPriority': customPriority.toString(),
      };

  PromptModel copy() {
    return PromptModel(
      id: id,
      content: content,
      role: role,
      name: name,
      category: category,
      customCategory: customCategory,
      createDate: createDate,
      updateDate: updateDate,
      isDefault: isDefault,
    );
  }

  String getContent(ChatModel chat, {CharacterModel? sender = null}) {
    CharacterController characterController = Get.find();
    var assistant = sender == null
        ? characterController.getCharacterById(chat.assistantId ?? -1)
        : sender;
    var prompt = content;
    prompt = prompt.replaceAll('<self>',
        characterController.getCharacterById(chat.userId ?? -1).roleName);
    prompt = BuildCharacterSystemPrompt(prompt, assistant);
    prompt = BuildRelationsPrompt(prompt, assistant, characterController, chat);
    prompt = injectCharacterLore(prompt, chat, assistant);
    return prompt;
  }

  String BuildCharacterSystemPrompt(String prompt, CharacterModel character) {
    prompt = prompt.replaceAll('<name>', character.roleName);
    prompt = prompt.replaceAll('<age>', character.age.toString());
    prompt = prompt.replaceAll(
        '<gender>', character.gender);
    prompt = prompt.replaceAll('<brief>', character.brief ?? "");
    prompt = prompt.replaceAll('<archive>', character.archive);
    // for (var entry in character.detailInfo.entries) {
    //   prompt = prompt.replaceAll('<${entry.key}>', entry.value);
    // }

    return prompt;
  }

  String injectCharacterLore(String prompt, ChatModel chat, CharacterModel sender){
    if (prompt.contains(RegExp(r'<recent-characters:\d+>'))) {
      CharacterController characterController = Get.find();

      final match = RegExp(r'<recent-characters:(\d+)>').firstMatch(prompt);
      if (match != null) {
      final count = int.parse(match.group(1)!);
      // Get characters who sent messages
      var recentChars = chat.messages
        .where((msg) => msg.sender != chat.userId && msg.sender != chat.assistantId)
        .map((msg) => msg.sender)
        .toSet();
        
      // Get characters mentioned in recent messages
      var mentionedChars = chat.messages.reversed
        .take(count)
        .expand((msg) => characterController.characters
          .where((char) => msg.content.contains(char.name))
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
          return "${char.name}-${char.gender.toString()}-${char.age}岁: ${char.brief}";
        } ).join("\n");
      
      prompt = prompt.replaceAll(match.group(0)!, recentCharsText);
      }
    }
    return prompt;
  }

  String BuildRelationsPrompt(
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
        var typeText =
            (entry.value.type != null && entry.value.type!.isNotEmpty)
                ? "${anotherOne.name}是${character.name}的${entry.value.type}。"
                : "";
        var brief = entry.value.brief;

        relationsText += """### ${anotherOne.name}-${anotherOne.gender}-${anotherOne.age}岁
${anotherOne.brief}
${typeText} ${brief}
""";
      }

      prompt = prompt.replaceAll('<relations>', relationsText==""?"无人物关系。":relationsText);
    }
    return prompt;
  }
}
