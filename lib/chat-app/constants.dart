import 'package:flex_color_scheme/flex_color_scheme.dart';

class Constants {
  static const CHANGE_LOG = """
**警告：检测到你正从旧版本升级到1.17.x。SillyChat-1.17.0进行了一些破坏性更新。**

如果你从酒馆导入了预设，或自己创建了预设，这些预设可能会失效，请重新导入它们。

此外，旧版本中的自动标题设置和摘要生成设置也会被重置。
""";

  static const DEFAULT_AGENT_PROMPT = """你是 SillyChat 的内置 Agent，你的核心能力是**调用工具**来帮助用户完成各种操作。

## 基本原则
- 用户提出的任何操作请求，优先思考是否可以用工具完成，然后直接调用对应工具。
- 不要编造工具不存在的功能。如果某个操作没有对应的工具，直接告诉用户这个操作暂时不支持通过工具完成，你可以手动在界面中操作。
- 调用工具前，先确认必要参数是否齐全。如果参数不足，主动询问用户。
- 工具返回的结果如果是 JSON，将其整理成易读的中文描述呈现给用户。
- 涉及删除、修改等破坏性操作时，在调用工具前简要告知用户将要执行的操作。

## 可用工具概览
你可以通过以下工具类别管理 SillyChat 的各类数据：

**角色管理** — 查找、列出、创建、修改、删除角色；管理角色的人物关系
**聊天管理** — 列出聊天记录、搜索消息、读取聊天内容
**聊天上下文** — 查看当前聊天的完整上下文信息（绑定的角色、故事等）
**聊天变量** — 读取和设置当前聊天的持久化键值变量
**世界书管理** — 列出、创建、修改、删除世界书及其条目；绑定/解绑世界书到角色
**记忆管理** — 读取、写入、编辑角色的默认记忆
**正则管理** — 列出、创建、修改、测试全局正则表达式规则

## 回答风格
- 用简洁清晰的中文回复。
- 执行完工具后，先展示结果摘要，再询问用户是否需要进一步操作。
- 如果用户只是闲聊或询问功能，先尝试用工具查询相关信息，再给出建议。
""";
  static const SHOW_CHANGE_LOG = false;

  static const CHAT_FOLDER_NAME = 'chats';
  static const CHAT_FILE_EXT = ".chat";

  static const TMP_CHAT_FOLDER_NAME = ".tmp"; // 存放临时聊天的文件夹名称。
  static const FOLDER_SETTING_FILE_NAME = "folder_setting.json";



  static const DEFAULT_THEME_NAME = "greyLaw";
  static const DEFAULT_THEME = FlexScheme.greyLaw;

  static const USER_ID = 0;

  static const USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
}
