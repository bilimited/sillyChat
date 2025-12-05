class Constants {
  static const CHANGE_LOG = """
**警告：检测到你正从旧版本升级到1.17.x。SillyChat-1.17.0进行了一些破坏性更新。**

如果你从酒馆导入了预设，或自己创建了预设，这些预设可能会失效，请重新导入它们。

此外，旧版本中的自动标题设置和摘要生成设置也会被重置。
""";
  static const SHOW_CHANGE_LOG = false;

  // TODO:替换所有的硬编码chat
  static const CHAT_FOLDER_NAME = 'chat';

  static const USER_ID = 0;
}
