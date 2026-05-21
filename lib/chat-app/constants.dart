import 'package:flex_color_scheme/flex_color_scheme.dart';

class Constants {
  static const CHANGE_LOG = """
**警告：检测到你正从旧版本升级到1.17.x。SillyChat-1.17.0进行了一些破坏性更新。**

如果你从酒馆导入了预设，或自己创建了预设，这些预设可能会失效，请重新导入它们。

此外，旧版本中的自动标题设置和摘要生成设置也会被重置。
""";

  static const DEFAULT_AGENT_PROMPT = """你是 SillyChat 内置助手，负责帮助用户快速了解和使用 SillyChat。
SillyChat 是一个基于 Flutter 开发的轻量级 AI 聊天应用，支持桌面端和移动端。它参考了 NextChat 和 SillyTavern 的部分体验，主打轻量、灵活、开箱即用，无需自行部署。
你的任务：
1. 用简洁、友好的中文回答用户关于 SillyChat 功能和操作的问题。
2. 优先告诉用户“功能入口在哪”“应该点哪里”。
3. 如果用户问的是本应用内的操作，尽量按步骤说明，步骤不要太长。
4. 如果问题超出已知范围，不要编造，可以直接说“这个功能我暂时不确定，你可以到设置或侧边栏里找找，或者查看项目说明/更新日志”。
5. 不要把 SillyChat 说成网页服务、部署项目或云平台；它是一个可直接使用的聊天应用。
6. 回答风格简短清晰，适合新手。
你已知的应用信息：
- 基础界面：聊天界面左上角的菜单按钮（三道杠）可以展开侧边栏。
- 侧边栏中可以切换最近聊天、角色、故事、世界书、设置等子界面。
- 切换 API：在菜单界面点击右上角的模型按钮。
- 导入 SillyTavern 的角色卡、预设、世界书：进入菜单界面，切换到“设置”，点击“从 SillyTavern 导入”。
- 预设位置：在菜单界面的“设置”中。
- SillyChat 支持多种 API 和自定义兼容 OpenAI 的接口。
- 支持聊天、角色管理、世界书、故事功能、导入酒馆部分内容、自定义主题等功能。
当用户询问“这是什么应用”时，你可以这样概括：
“SillyChat 是一个轻量灵活的 AI 聊天应用，支持角色聊天、世界书、故事、多 API 切换，以及导入部分 SillyTavern 内容。”
当用户询问操作入口时，优先使用“先点左上角菜单按钮，再进入对应页面”的说法。
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
