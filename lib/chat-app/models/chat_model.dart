import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:get/get.dart';
import '../utils/RequestOptions.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';

class ChatModel {
  late final int fileId;

  int id = 1;
  String name;
  String avatar;
  String? backgroundImage;
  String lastMessage;
  String time;
  int? userId;
  int? assistantId; // TODO:解除外部对id的应用，直接从get方法获取实体类
  List<MessageModel> messages = []; // 消息极有可能不按时间排列。
  List<int> characterIds = [];

  // 对话摘要，介绍或作者注释
  // 会被插入到提示词中
  String? description; 


  late ChatOptionModel chatOption;

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
    chatOption = option.copyWith(true);
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
    chatOption,
    this.userId, // 新增
    this.assistantId, // 新增
    this.mode = ChatMode.auto,
    this.messageTemplate = "{{msg}}", // 新增：构造函数参数
  }) {
    //this._prompts = prompts ?? [];
    if (chatOption != null) {
      this.chatOption = chatOption;
    } else {
      this.chatOption = ChatOptionModel.empty();
    }
  }

  List<String> getAllAvatars(CharacterController controller) {
    return characterIds
        .map((id) => controller.getCharacterById(id))
        .map((char) => char.avatar)
        .toList();
  }

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    // 版本迁移
    final requestOptions = json['requestOptions'] != null
        ? LLMRequestOptions.fromJson(json['requestOptions'])
        : null;
    final prompts = (json['prompts'] as List?)
        ?.map((e) => PromptModel.fromJson(e))
        .toList();
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
      chatOption: json['chatOption'] != null
          ? ChatOptionModel.fromJson(json['chatOption'])
          : (requestOptions != null && prompts != null)
              ? ChatOptionModel(
                  id: 0,
                  name: '从旧版本导入的预设',
                  requestOptions: requestOptions,
                  prompts: prompts)
              : ChatOptionModel.empty(),
      userId: json['userId'], // 新增
      assistantId: json['assistantId'], // 新增
      messageTemplate: json['messageTemplate'] ?? "{{msg}}", // 新增：反序列化
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
      ..characterIds = json['characterIds']?.cast<int>() ?? [];
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
        'chatOption': chatOption.toJson(),

        'userId': userId, // 新增
        'assistantId': assistantId, // 新增
        'messageTemplate': messageTemplate, // 新增：序列化
        'tags': tags, // 新增：序列化
        'mode': mode?.toString().split('.').last,
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
      };

  ChatModel shallowCopyWith({
    int? id,
    String? name,
    String? avatar,
    String? backgroundImage,
    String? lastMessage,
    String? time,
    String? description,
    List<int>? characterIds,
    List<MessageModel>? messages,
    ChatOptionModel? chatOptions,
    int? userId,
    int? assistantId,
    ChatMode? mode,
    String? messageTemplate,
    List<String>? tags,
    int? parentId,
    int? entranceId,
    List<BookMarkModel>? bookmarks,
  }) {
    return ChatModel(
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
      chatOption: chatOptions ?? this.chatOption,
    )
      ..bookmarks = bookmarks ?? this.bookmarks
      ..tags = tags ?? []
      ..characterIds = characterIds ?? this.characterIds;
  }

  ChatModel deepCopyWith({
    int? id,
    String? name,
    String? avatar,
    String? backgroundImage,
    String? lastMessage,
    String? time,
    String? description,
    List<int>? characterIds,
    List<MessageModel>? messages,
    ChatOptionModel? chatOptions,
    int? userId,
    int? assistantId,
    ChatMode? mode,
    String? messageTemplate,
    List<String>? tags,
    List<BookMarkModel>? bookmarks,
  }) {
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
      chatOption: chatOptions ?? this.chatOption.copyWith(true),
    )
      ..tags = tags ?? [...this.tags]
      ..bookmarks = bookmarks ?? this.bookmarks.map((b) => b.copy()).toList()
      ..characterIds = characterIds ?? [...this.characterIds];
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
