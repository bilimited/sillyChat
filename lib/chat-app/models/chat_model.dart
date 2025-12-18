import 'dart:convert';
import 'dart:io';

import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/models/regex_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:get/get.dart';
import '../utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';

class ChatModel {
  @Deprecated('不再使用了')
  late final int fileId;

  late final File file; // 加载时赋值

  int id = 1;

  String name;
  String avatar;
  String? backgroundImage;
  String lastMessage;
  String time;
  int? userId;
  int? assistantId;
  int? chatOptionId;
  List<MessageModel> messages = []; // 消息极有可能不按时间排列。
  List<int> characterIds = [];
  Map<String, String> chatVars = {};

  // meta中的字段：
  // readonly:是否为只读（归档）
  Map<String, dynamic> metaData = {};
  Map<String, bool> activitedLorebookItems = {}; // 手动激活的LorebookItem

  bool needAutoTitle = false; // 是否需要自动生成标题

  // 对话摘要，介绍或作者注释
  // 会被插入到提示词中
  String? description;

  String? get backgroundOrCharBackground =>
      backgroundImage ?? assistant.backgroundImage ?? null;

  ChatOptionModel get chatOption =>
      Get.find<ChatOptionController>().getChatOptionById(chatOptionId ?? -1) ??
      Get.find<ChatOptionController>().defaultOption;

  bool get isChatNotCreated => id == -1;

  LLMRequestOptions get requestOptions => chatOption.requestOptions;
  set requestOptions(LLMRequestOptions value) {
    chatOption.requestOptions = value;
  }

  List<PromptModel> get prompts => chatOption.prompts; // 新增：存储实际的PromptModel对象
  set prompts(List<PromptModel> value) {
    chatOption.prompts = value;
  }

  List<CharacterModel> get characters {
    CharacterController controller = Get.find();
    return characterIds
        .map((id) => controller.getCharacterById(id))
        .nonNulls
        .toList();
  }

  /// 包括聊天配置的正则和全局正则
  List<RegexModel> get vaildRegexs =>
      [...Get.find<VaultSettingController>().regexes, ...chatOption.regex];

  CharacterModel get assistant {
    CharacterController controller = Get.find();
    return controller.getCharacterById(assistantId ?? -1);
  }

  // 获取User，如User为空则取默认值
  CharacterModel get user {
    CharacterController controller = Get.find();
    return userId == null
        ? controller.me
        : controller.getCharacterById(userId!);
  }

  String messageTemplate = "{{msg}}"; // 新增：消息模板字段
  List<String> tags = []; // 新增：标签字段

  ChatMode? mode;
  List<BookMarkModel> bookmarks = [];

  void initOptions(ChatOptionModel option) {
    chatOptionId = option.id;
  }

  ChatModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.time,
    required this.messages,
    this.backgroundImage,
    this.description,
    this.chatOptionId,
    this.userId, // 新增
    this.assistantId, // 新增
    this.mode = ChatMode.auto,
    this.messageTemplate = "{{msg}}", // 新增：构造函数参数
    this.needAutoTitle = false,
  }) {}



  List<String> getAllAvatars(CharacterController controller) {
    return characterIds
        .map((id) => controller.getCharacterById(id))
        .map((char) => char.avatar)
        .toList();
  }

  void setLorebookItemStat(int lorebookId, int itemId, bool val) {
    activitedLorebookItems['$lorebookId@$itemId'] = val;
  }

  bool? getLorebookItemStat(int lorebookId, int itemId) {
    return activitedLorebookItems['$lorebookId@$itemId'];
  }

  factory ChatModel.empty(){
    return ChatModel(id: DateTime.now().microsecondsSinceEpoch, name: 
    
    "新对话", avatar: '', lastMessage: '对话已创建', time: DateTime.now().toString(), messages: [],chatOptionId: 
      Get.find<ChatOptionController>()
            .chatOptions
            .elementAtOrNull(0)
            ?.id,assistantId: -1
    );
  }


  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] ?? -1,
      name: json['name'],
      avatar: json['avatar'],
      backgroundImage: json['backgroundImage'],
      lastMessage: json['lastMessage'],
      time: json['time'],
      description: json['description'],
      messages: (json['messages'] as List?)
              ?.map((e) => MessageModel.fromJson(e))
              .toList() ??
          [],
      chatOptionId: (json['chatOption']?['id']) ?? json['chatOptionId'], // 版本迁移
      userId: json['userId'], // 新增
      assistantId: json['assistantId'], // 新增
      messageTemplate: json['messageTemplate'] ?? "{{msg}}", // 新增：反序列化
      needAutoTitle: json['needAutoTitle'] ?? false,
    )
      ..mode = json['mode'] != null
          ? ChatMode.values.firstWhere(
              (e) => e.toString() == 'ChatMode.${json['mode']}',
              orElse: () => ChatMode.auto)
          : null
      ..bookmarks = (json['bookmarks'] as List?)
              ?.map((e) => BookMarkModel.fromJson(e))
              .toList() ??
          []
      ..tags = (json['tags'] as List?)?.cast<String>() ?? []
      ..characterIds = json['characterIds']?.cast<int>() ?? []
      ..chatVars = (json['chatVars'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, value.toString())) ??
          {}
      ..metaData = (json['meta'] as Map<String, dynamic>?) ?? {}
      ..activitedLorebookItems =
          (json['activitedLorebookItems'] as Map<String, dynamic>?)
                  ?.map((key, value) => MapEntry(key, value == true)) ??
              {};
  }

  static Future<ChatModel> fromFile(File f) async {
    final content = await f.readAsString();
    return ChatModel.fromJson(json.decode(content));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'backgroundImage': backgroundImage,
        'lastMessage': lastMessage,
        'time': time,
        'description': description,
        'characterIds': characterIds,
        'messages': messages.map((msg) => msg.toJson()).toList(),
        'chatOptionId': chatOptionId, //chatOption.toJson(),

        'userId': userId, // 新增
        'assistantId': assistantId, // 新增
        'messageTemplate': messageTemplate, // 新增：序列化
        'tags': tags, // 新增：序列化
        'mode': mode?.toString().split('.').last,
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
        'chatVars': chatVars,
        'activitedLorebookItems': activitedLorebookItems,
        'needAutoTitle': needAutoTitle,
        'meta': metaData,
      };

  ChatModel copyWith(
      {bool isCopyFile = true,
      int? id,
      String? name,
      String? avatar,
      String? backgroundImage,
      String? lastMessage,
      String? time,
      String? description,
      List<int>? characterIds,
      List<MessageModel>? messages,
      int? chatOptionId,
      int? userId,
      int? assistantId,
      ChatMode? mode,
      String? messageTemplate,
      List<String>? tags,
      List<BookMarkModel>? bookmarks,
      Map<String, String>? chatVars,
      Map<String, String>? metaData,
      Map<String, bool>? activitedLorebookItems,
      bool? needAutoTitle}) {
    final chat = ChatModel(
        id: id ?? this.id,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        backgroundImage: backgroundImage ?? this.backgroundImage,
        lastMessage: lastMessage ?? this.lastMessage,
        time: time ?? this.time,
        description: description ?? this.description,
        messages: messages ?? this.messages,
        userId: userId ?? this.userId,
        assistantId: assistantId ?? this.assistantId,
        mode: mode ?? this.mode,
        messageTemplate: messageTemplate ?? this.messageTemplate,
        chatOptionId: chatOptionId ?? this.chatOptionId,
        needAutoTitle: needAutoTitle ?? this.needAutoTitle)
      ..bookmarks = bookmarks ?? this.bookmarks
      ..tags = tags ?? this.tags
      ..characterIds = characterIds ?? this.characterIds
      ..chatVars = chatVars ?? this.chatVars
      ..metaData = metaData ?? this.metaData
      ..activitedLorebookItems =
          activitedLorebookItems ?? this.activitedLorebookItems;
    if (isCopyFile) chat.file = this.file;
    return chat;
  }

  ChatModel deepCopyWith(
      {int? id,
      String? name,
      String? avatar,
      String? backgroundImage,
      String? lastMessage,
      String? time,
      String? description,
      List<int>? characterIds,
      List<MessageModel>? messages,
      int? chatOptionId,
      int? userId,
      int? assistantId,
      ChatMode? mode,
      String? messageTemplate,
      List<String>? tags,
      List<BookMarkModel>? bookmarks,
      Map<String, String>? chatVars,
      Map<String, String>? metaData,
      Map<String, bool>? activitedLorebookItems,
      bool? needAutoTitle}) {
    return ChatModel(
        id: id ?? this.id,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        backgroundImage: backgroundImage ?? this.backgroundImage,
        lastMessage: lastMessage ?? this.lastMessage,
        time: time ?? this.time,
        description: description ?? this.description,
        messages: messages ?? this.messages.map((e) => e.copyWith()).toList(),
        userId: userId ?? this.userId,
        assistantId: assistantId ?? this.assistantId,
        mode: mode ?? this.mode,
        messageTemplate: messageTemplate ?? this.messageTemplate,
        chatOptionId: chatOptionId ?? this.chatOptionId,
        needAutoTitle: needAutoTitle ?? this.needAutoTitle)
      ..tags = tags ?? [...this.tags]
      ..bookmarks = bookmarks ?? this.bookmarks.map((b) => b.copy()).toList()
      ..characterIds = characterIds ?? [...this.characterIds]
      ..chatVars = chatVars ?? this.chatVars
      ..metaData = metaData ?? this.metaData
      ..activitedLorebookItems =
          activitedLorebookItems ?? this.activitedLorebookItems;
  }
}

class BookMarkModel {
  final int messageId;
  final String title;

  BookMarkModel({
    required this.messageId,
    required this.title,
  });

  factory BookMarkModel.fromJson(Map<String, dynamic> json) {
    return BookMarkModel(
      messageId: json['messageId'],
      title: json['title'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'title': title,
    };
  }

  BookMarkModel copy() {
    return BookMarkModel(
      messageId: messageId,
      title: title,
    );
  }
}
