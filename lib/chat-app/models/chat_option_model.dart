import 'package:flutter_example/chat-app/models/prompt_model.dart';
import 'package:flutter_example/chat-app/providers/prompt_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:get/get.dart';

class ChatOptionModel {
  int id = 0; // 新增：用于唯一标识每个ChatOptionModel
  String name;
  String messageTemplate = "{{msg}}";
  LLMRequestOptions requestOptions;
  List<PromptModel> prompts = []; // 新增：存储实际的PromptModel对象
  // List<int> promptId = [];

  static List<PromptModel> getPromptsbyId(List<int> promptId) {
    final PromptController controller = Get.find();
    return promptId
        .map((p) {
          return controller.getPromptById(p) ?? null;
        })
        .nonNulls
        .toList();
  }

  ChatOptionModel({
    required this.id,
    required this.name,
    this.messageTemplate = "{{msg}}",
    required this.requestOptions,
    required this.prompts,
  });

  factory ChatOptionModel.fromJson(Map<String, dynamic> json) {
    return ChatOptionModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      messageTemplate: json['messageTemplate'] ?? "{{msg}}",
      requestOptions: json['requestOptions'] != null
          ? LLMRequestOptions.fromJson(json['requestOptions'])
          : const LLMRequestOptions(messages: []),
      prompts: json['prompts'] != null
          ? (json['prompts'] as List<dynamic>)
              .map((p) => PromptModel.fromJson(p as Map<String, dynamic>))
              .toList()
          : getPromptsbyId((json['promptId'] as List<dynamic>?)
                  ?.map((e) => e as int)
                  .toList() ??
              []), // 版本迁移用
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'messageTemplate': messageTemplate,
        'requestOptions': requestOptions.toJson()
          ..addAll({'max_history_length': requestOptions.maxHistoryLength}),
        'prompts': prompts.map((p) => p.toJson()).toList(),
      };

  ChatOptionModel copyWith(
    bool isDeep, {
    int? id,
    String? name,
    String? messageTemplate,
    LLMRequestOptions? requestOptions,
    List<PromptModel>? prompts,
  }) {
    return ChatOptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      messageTemplate: messageTemplate ?? this.messageTemplate,
      requestOptions: requestOptions ??
          (isDeep ? this.requestOptions.copyWith() : this.requestOptions),
      prompts: prompts ??
          (isDeep ? this.prompts.map((p) => p.copy()).toList() : this.prompts),
      //promptId: prompts?.map((p) => p.id).toList() ?? this.promptId,
    );
  }

  factory ChatOptionModel.empty() {
    int id = DateTime.now().microsecondsSinceEpoch;
    const String bilimitedComments = "作者注释：\n"
        "<lore id=x default=xxx>代表了世界书条目插入的位置，世界书条目的'插入位置ID'为x，世界书就会被插入到<lore id=x ...> 相应的位置。default=xxx的意思是如果在该位置没有匹配的世界书条目的话，就会被替换成xxx对应的内容\n"
        "<user>代表用户的名称，<char>代表发言角色的名称,<archive>代表发言角色的详细介绍，<description>为当前聊天的作者注释。\n"
        "<relations>代表发言角色的关联人物列表。只有出现在群成员中，且与该角色有关联的角色会被插入到此处。\n"
        "<recent-characters:x>处会插入最近x条消息中提到，且没有出现在人物关系列表内的角色简介。\n"
        "在发送请求时，会自动去除空白的Prompt。";
    const String userDefine = "<lore id=0>\n"
        """# 你的名字叫<char>，你将扮演以下介绍中的角色。
## 基本信息
名称:<char>
<archive>

## 人物关系
<relations>

## 其他人物
<recent-characters:5>

## 其他信息
<lore id=1 default=无>

---

<description>

<lore id=2>

我是<user>。
现在，我将开始与你聊天。
""";
    const String userMessage = """<lore id=4>
<lastUserMessage>
<lore id=5>
<char>:""";

    return ChatOptionModel(
        id: 0,
        name: '默认预设',
        requestOptions: LLMRequestOptions(messages: []),
        prompts: [
          PromptModel(
              id: id - 1,
              content: bilimitedComments,
              role: 'system',
              name: '作者注释')
            ..isEnable = false,
          PromptModel(
              id: id, content: userDefine, role: 'system', name: '角色定义'),
          PromptModel(
              id: id + 1,
              content: '<messageList>',
              role: 'system',
              name: '消息列表',
              isChatHistory: true),
          PromptModel(
              id: id + 2, content: userMessage, role: 'user', name: '用户输入')
        ]);
  }
}
