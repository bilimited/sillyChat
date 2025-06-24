import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import '../utils/RequestOptions.dart';
import 'package:flutter_example/chat-app/models/prompt_model.dart';

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
}

class ChatModel {
  late final int fileId;

  int id = 1;
  String name;
  String avatar;
  String? backgroundImage;
  String lastMessage;
  String time;
  int? userId; // 新增：用户ID
  int? assistantId; // 新增：助手ID
  List<MessageModel> messages = [];
  List<int> characterIds = [];
  String? description; // 对话摘要或介绍
  LLMRequestOptions requestOptions;
  List<PromptModel> _prompts = []; // 新增：存储实际的PromptModel对象
  String messageTemplate = "{{msg}}"; // 新增：消息模板字段
  List<String> tags = []; // 新增：标签字段

  ChatMode? mode;
  List<BookMarkModel> bookmarks = [];

  // 是否用角色参数覆盖请求参数
  bool overriteOption = false;
  int currectOption = -1; // -1:没有使用任何配置

  List<PromptModel> get prompts {
    return _prompts;
  }

  set prompts(List<PromptModel> value) {
    _prompts = value;
  }

  void initOptions(ChatOptionModel option) {
    prompts = option.prompts.map((ele) => ele.copy()).toList();
    requestOptions = option.requestOptions.copyWith();
    messageTemplate = option.messageTemplate;
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
    this.characterIds = const [],
    this.requestOptions = const LLMRequestOptions(messages: const []),
    List<PromptModel>? prompts, // 新增参数
    this.userId, // 新增
    this.assistantId, // 新增
    this.mode = ChatMode.auto,
    this.messageTemplate = "{{msg}}", // 新增：构造函数参数
    this.tags = const [], // 新增：构造函数参数
    this.overriteOption = false, // 是否用角色参数覆盖请求参数
    this.currectOption = -1, // -1:没有使用任何配置
  }) {
    this._prompts = prompts ?? [];
  }

  List<String> getAllAvatars(CharacterController controller) {
    return characterIds
        .map((id) => controller.getCharacterById(id))
        .map((char) => char.avatar)
        .toList();
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
      characterIds: json['characterIds']?.cast<int>() ?? [],
      messages: (json['messages'] as List?)
              ?.map((e) => MessageModel.fromJson(e))
              .toList() ??
          [],
      requestOptions: json['requestOptions'] != null
          ? LLMRequestOptions.fromJson(json['requestOptions'])
          : const LLMRequestOptions(messages: []),
      prompts: (json['prompts'] as List?)
          ?.map((e) => PromptModel.fromJson(e))
          .toList(), // 新增解析
      userId: json['userId'], // 新增
      assistantId: json['assistantId'], // 新增
      messageTemplate: json['messageTemplate'] ?? "{{msg}}", // 新增：反序列化
      tags: (json['tags'] as List?)?.cast<String>() ?? [], // 新增：反序列化
      overriteOption: json['overriteOption'] ?? false, // 是否用角色参数覆盖请求参数
      currectOption: json['currectOption'] ?? -1, // -1:没有使用任何配置
    )
      ..mode = json['mode'] != null
          ? ChatMode.values.firstWhere(
              (e) => e.toString() == 'ChatMode.${json['mode']}',
              orElse: () => ChatMode.auto)
          : null
      ..bookmarks = (json['bookmarks'] as List?)
              ?.map((e) => BookMarkModel.fromJson(e))
              .toList() ??
          [];
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
        'requestOptions': requestOptions.toJson()
          ..addAll({'max_history_length': requestOptions.maxHistoryLength}),
        'prompts': _prompts.map((p) => p.toJson()).toList(), // 新增：保存实际的prompts
        'userId': userId, // 新增
        'assistantId': assistantId, // 新增
        'messageTemplate': messageTemplate, // 新增：序列化
        'tags': tags, // 新增：序列化
        'mode': mode?.toString().split('.').last,
        'overriteOption': overriteOption, // 是否用角色参数覆盖请求参数
        'currectOption': currectOption, // -1:没有使用任何配置
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
    LLMRequestOptions? requestOptions,
    List<PromptModel>? prompts,
    int? userId,
    int? assistantId,
    ChatMode? mode,
    String? messageTemplate,
    List<String>? tags,
    int? parentId,
    int? entranceId,
    bool? overriteOption,
    int? currectOption,
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
      characterIds: characterIds ?? this.characterIds,
      messages: messages ?? this.messages,
      requestOptions: requestOptions ?? this.requestOptions,
      prompts: prompts ?? this.prompts,
      userId: userId ?? this.userId,
      assistantId: assistantId ?? this.assistantId,
      mode: mode ?? this.mode,
      messageTemplate: messageTemplate ?? this.messageTemplate,
      tags: tags ?? this.tags,
      overriteOption: overriteOption ?? this.overriteOption,
      currectOption: currectOption ?? this.currectOption,
    )..bookmarks = bookmarks ?? this.bookmarks;
  }
}
