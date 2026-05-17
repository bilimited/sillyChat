# Models & Controllers 参考文档

本文档描述 Silly Chat 项目中所有 Model 和 Controller（Provider）的接口与用法。

---

## 一、Models（数据模型）

所有 model 都支持 JSON 序列化（`toJson()` / `fromJson()`）和 `copyWith()` 方法。

### 1.1 ApiModel（`models/api_model.dart`）

API 配置模型，描述一个 LLM 服务商的连接信息。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `int` | 唯一标识 |
| `apiKey` | `String` | API 密钥 |
| `displayName` | `String` | 显示名称 |
| `modelName` | `String` | 模型名 |
| `url` | `String` | API 端点 URL |
| `provider` | `ServiceType` | 服务商类型枚举 |
| `remarks` | `String?` | 备注 |
| `requestBody` | `String?` | 自定义请求体 JSON |
| `models` | `List<String>` | 缓存的模型列表 |

**枚举 `ServiceType`**：`custom_openai_compatible`, `openai`, `deepseek`, `siliconflow`, `kimi`, `google`

工具方法：
- `toLocalString()` → 返回服务商的中文名
- `defaultUrl` → 该服务商的默认 base URL
- `modelList` → 该服务商的默认模型列表

---

### 1.2 CharacterModel（`models/character_model.dart`）

角色卡模型。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `int` | 唯一标识。`-1`=内置AI助手，`0`=用户"我"，`-2`=总结姬 |
| `remark` | `String` | 备注/显示名 |
| `roleName` | `String` | 唯一角色名 |
| `avatar` | `String` | 头像路径 |
| `description` | `String?` | 描述 |
| `backgroundImage` | `String?` | 背景图 |
| `brief` | `String?` | 简略个人信息 |
| `archive` | `String` | 详细介绍（替代旧个人信息） |
| `firstMessage` | `String?` | 开场白 |
| `moreFirstMessage` | `List<String>` | 备选开场白列表 |
| `category` | `String` | 分类（用于分组显示） |
| `messageStyle` | `MessageStyle` | 消息样式：`common` / `narration` / `summary` |
| `relations` | `Map<int, Relation>` | 与其他角色的关系 |
| `lorebookIds` | `List<int>` | 关联的世界书 ID 列表 |
| `memoryBookId` | `int?` | 记忆书 ID |
| `bindOptionId` | `int?` | 绑定的聊天预设 ID |

**计算属性**：
- `loreBooks` → `List<LorebookModel>` 从 LoreBookController 获取关联世界书
- `memoryBook` → `LorebookModel?` 记忆书，`canGenMemory` 判断是否有记忆书
- `bindOption` → `ChatOptionModel?` 从 ChatOptionController 获取绑定预设
- `isDefaultAssistant` → `id == -1`

**关联类 `Relation`**：`targetId`（关联角色ID）、`type`（关系类型）、`brief`（关系简述）。`target` getter 返回关联的角色对象。

**`MessageStyle` 枚举**：`common`, `narration`, `summary`

**工厂方法**：`CharacterModel.empty()` 创建空白角色。

---

### 1.3 ChatModel（`models/chat_model.dart`）

聊天模型，一个 ChatModel 实例对应一个 `.chat` 文件。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `int` | 唯一标识 |
| `name` | `String` | 聊天名称 |
| `avatar` | `String` | 头像 |
| `backgroundImage` | `String?` | 背景图 |
| `lastMessage` | `String` | 最新一条消息预览 |
| `time` | `String` | 更新时间（字符串） |
| `messages` | `List<MessageModel>` | 消息列表（不保证按时间排列） |
| `userId` | `int?` | 用户角色 ID |
| `assistantId` | `int?` | 默认助手角色 ID |
| `mode` | `ChatMode?` | 聊天模式：`auto` / `group` |
| `characterIds` | `List<int>` | 参与角色 ID 列表 |
| `chatVars` | `Map<String, String>` | 聊天变量 |
| `metaData` | `Map<String, dynamic>` | 元数据 |
| `activitedLorebookItems` | `Map<String, bool>` | 手动激活的世界书条目。key="lorebookId@itemId" |
| `needAutoTitle` | `bool` | 是否需要自动生成标题 |
| `bookmarks` | `List<BookMarkModel>` | 书签列表 |
| `file` | `File?` | JSONIGNORE，加载时赋值，指向磁盘文件 |

**计算属性**：
- `bindCharacter` → `CharacterModel?` 从文件路径解析绑定的角色
- `bindStory` → `StoryModel?` 从文件路径解析绑定的故事
- `chatOption` → `ChatOptionModel` 获取当前有效的聊天预设（文件夹预设 > 默认预设）
- `assistant` → 助手角色（id=-1 返回默认助手）
- `user` → 用户角色
- `vaildRegexs` → `List<RegexModel>` 聊天预设的正则 + 全局正则
- `requestOptions` → `LLMRequestOptions` 快捷访问 chatOption.requestOptions
- `prompts` → `List<PromptModel>` 快捷访问 chatOption.prompts
- `characters` → `List<CharacterModel>` 参与的所有角色

**方法**：
- `setLorebookItemStat(lorebookId, itemId, bool)` — 手动设置世界书条目的激活状态
- `getLorebookItemStat(lorebookId, itemId)` → `bool?`
- `extractStoryId(String path)` / `extractCharacterId(String path)` — 从路径提取绑定 ID

**`copyWith` vs `deepCopyWith`**：`copyWith` 浅拷贝列表/Map，`deepCopyWith` 深拷贝 messages/characterIds 等集合。

**工厂方法**：`ChatModel.empty()` — 创建空白聊天；`ChatModel.fromFile(File)` — 从文件异步加载。

**关联类 `BookMarkModel`**：`messageId` + `title`，标记聊天中的特定消息。

**`ChatMode` 枚举**（定义在 `chat_page.dart`）：`auto`, `group`

---

### 1.4 MessageModel（`models/message_model.dart`）

单条消息模型。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `int` | 唯一标识 |
| `content` | `String` | 消息文本内容 |
| `role` | `MessageRole` | `user` / `assistant` / `system` |
| `senderId` | `int` | 发送者角色 ID |
| `time` | `DateTime` | 发送时间 |
| `style` | `MessageStyle` | 消息样式 |
| `token` | `int?` | Token 数 |
| `resPath` | `List<String>` | 附件路径（图片等） |
| `visbility` | `MessageVisbility` | `common`（正常）/ `pinned`（置顶）/ `hidden`（隐藏） |
| `bookmark` | `String?` | 书签 |
| `alternativeContent` | `List<String?>` | 备选文本列表，**第一个元素始终为 null**（表示当前已选内容的位置） |

**计算属性**：
- `sender` → `CharacterModel` 从 CharacterController 获取发送者
- `isAssistant` → `role == MessageRole.assistant`
- `isPinned` / `isHidden`

---

### 1.5 ChatMetaModel（`models/chat_metadata_model.dart`）

聊天元数据索引，用于聊天列表快速展示，不加载完整 ChatModel。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `int` | 聊天 ID |
| `name` | `String` | 聊天名称 |
| `lastMessage` | `String` | 最新消息 |
| `time` | `String` | 更新时间 |
| `messageCount` | `int` | 消息总数 |
| `characterIds` | `List<int>` | 参与角色 ID |
| `assistantId` | `int` | 默认助手 ID |
| `mode` | `ChatMode` | 聊天模式 |
| `path` | `String` | JSONIGNORE，文件路径 |

**方法**：`getAllAvatars()` 获取所有角色头像列表；`assistant` / `characters` 计算属性。

**工厂方法**：`ChatMetaModel.fromChatModel(ChatModel)` 从聊天对象构建索引。

---

### 1.6 ChatOptionModel（`models/chat_option_model.dart`）

聊天预设/生成选项。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `int` | 唯一标识 |
| `name` | `String` | 预设名称 |
| `messageTemplate` | `String` | 消息模板，默认 `"{{msg}}"` |
| `requestOptions` | `LLMRequestOptions` | LLM 请求参数 |
| `prompts` | `List<PromptModel>` | 提示词列表 |
| `regex` | `List<RegexModel>` | 正则规则列表 |

**工厂方法**：
- `ChatOptionModel.roleplay()` — 完整 RP 预设（角色定义+人物关系+用户设定+回忆）
- `ChatOptionModel.common()` — 简化预设（角色定义+消息列表）
- `ChatOptionModel.empty()` — 空白预设（仅消息列表）
- `ChatOptionModel.base()` — 基础预设（时间+文件夹备注+消息列表）
- `ChatOptionModel.autoTitle()` — 自动生成标题专用预设

---

### 1.7 PromptModel（`models/prompt_model.dart`）

系统提示词模型。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `int` | 唯一标识 |
| `content` | `String` | 提示词内容，可含 `{{var}}` 宏 |
| `role` | `String` | 角色：`"system"` / `"user"` / `"assistant"` |
| `name` | `String` | 显示名称 |
| `isEnable` | `bool` | 是否启用 |
| `isChatHistory` | `bool` | **是否为消息列表占位符**。content=`"messageList"` 或 `"<messageList>"` 表示该位置插入聊天记录 |
| `isInChat` | `bool` | 是否在聊天中（`true` 则不保存到 prompts.json） |
| `priority` | `int` | 优先级（默认 100） |
| `depth` | `int` | 排序深度：0=最新消息之后，1=最新消息之前 |

**常量占位符**：
- `PromptModel.chatHistoryPlaceholder()` — 消息列表占位符
- `PromptModel.userMessagePlaceholder()` — 用户消息占位符（content=`"{{lastuserMessage}}"`）

---

### 1.8 RegexModel（`models/regex_model.dart`）

正则替换规则模型（兼容 JavaScript 风格正则）。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `int` | 唯一标识 |
| `name` | `String` | 规则名称 |
| `pattern` | `String` | 正则表达式（支持 `/pattern/flags` 格式） |
| `replacement` | `String` | 替换文本（支持 `$1` `$2` 捕获组引用） |
| `trim` | `String?` | 修剪文本（按行分割后逐一移除） |
| `enabled` | `bool` | 是否启用 |
| `onRender` | `bool` | 渲染时应用 |
| `onRequest` | `bool` | 发送给 AI 前应用 |
| `onAddMessage` | `bool` | 添加消息时应用（影响消息记录） |
| `scopeUser` | `bool` | 作用于用户消息 |
| `scopeAssistant` | `bool` | 作用于助手消息 |
| `depthMin` / `depthMax` | `int` | 作用深度范围，-1 表示无限制 |

**方法**：
- `process(String input)` → `String` — 执行正则替换
- `isAvailable(ChatModel chat, MessageModel message)` → `bool` — 判断规则对某条消息是否生效
- `replaceJsRegex(String jsRegex, String input, String replacement)` → `String` — 解析 JS 风格正则并替换

---

### 1.9 LorebookModel / LorebookItemModel（`models/lorebook_model.dart`）

世界书模型。

**LorebookModel**：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `int` | 唯一标识 |
| `name` | `String` | 名称 |
| `items` | `List<LorebookItemModel>` | 条目列表 |
| `scanDepth` | `int` | 扫描深度 |
| `maxToken` | `int` | 最大 Token 数 |
| `type` | `LorebookType` | `world` / `character` / `memory` |
| `metaData` | `Map<String, dynamic>` | 元数据 |

**LorebookItemModel**：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `int` | 唯一标识 |
| `name` | `String` | 条目名称 |
| `content` | `String` | 注入到上下文的内容 |
| `keywords` | `String` | 关键词（逗号分隔） |
| `logic` | `MatchingLogic` | 匹配逻辑：`and` / `or` / `regex` |
| `activationType` | `ActivationType` | 激活方式：`always` / `keywords` / `manual` |
| `isActive` | `bool` | 是否激活 |
| `isFavorite` | `bool` | 是否收藏 |
| `activationDepth` | `int` | 激活深度（回溯消息数），0=使用全局设置 |
| `priority` | `int` | 优先级 |
| `position` | `String` | 插入位置：`before_char` / `after_char` / `before_em` / `after_em` / `@Duser` / `@Dassistant` / `@Dsystem` |
| `positionId` | `int` | 插入位置 ID |
| `createdAt` / `updatedAt` | `DateTime` | 时间戳 |

**方法**：`verify(String content)` — 根据关键词和逻辑判断条目是否匹配。

---

### 1.10 FolderSettingModel（`models/folder_setting_model.dart`）

文件夹设置，每个 `folder_setting.json` 文件对应一个。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | UUID |
| `path` | `String` | 文件路径 |
| `defaultAssistantId` | `int?` | 默认助手 |
| `characterIds` | `List<int>` | 参与角色 |
| `chatOptionId` | `int?` | 绑定的聊天预设 ID |
| `remark` | `String` | 文件夹备注 |
| `metaData` | `Map<String, dynamic>` | 元数据 |

**计算属性**：`defaultAssistant`、`chatOptionModel`

---

### 1.11 StoryModel（`models/story_model.dart`）

故事/世界模型。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | UUID 字符串 |
| `name` | `String` | 故事名称 |
| `remark` | `String` | 备注 |
| `story_prompt` | `String` | 故事提示词 |
| `chatOptionId` | `int?` | 绑定的聊天预设 |
| `characterIds` | `List<int>` | 参与角色 |
| `lorebookIds` | `List<int>` | 关联世界书 |
| `metaData` | `Map<String, dynamic>` | 元数据 |

---

### 1.12 HistoryModel（`models/history_model.dart`）

历史记录模型，存储在各 vault 的 `settings.json` 中。

| 字段 | 类型 | 说明 |
|---|---|---|
| `messageHistory` | `List<String>` | 消息发送历史 |
| `commandHistory` | `List<String>` | 命令历史 |
| `characterHistory` | `List<int>` | 最近选择的角色（最多5个） |
| `chatHistory` | `List<String>` | 最近打开的聊天（最多50个） |

---

### 1.13 Settings Models（`models/settings/`）

**ChatDisplaySettingModel** — 聊天显示设置：

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `avatarStyle` | `AvatarStyle` | `circle` | 头像样式：`circle` / `rounded` / `hidden` |
| `messageBubbleStyle` | `MessageBubbleStyle` | `bubble` | 气泡样式：`bubble` / `compact` |
| `themeColor` | `Color` | `Colors.blue` | 主题色 |
| `schemeName` | `String` | `"greyLaw"` | FlexColorScheme 方案名 |
| `ContentFontScale` | `double` | `1` | 内容字体缩放 |
| `AvatarSize` | `double` | `25` | 头像大小 |
| `GlobalFont` | `String?` | `""` | 全局字体族名 |
| `CustomFontPath` | `String?` | `""` | 自定义字体路径 |
| `displayUserName` / `displayAssistantName` | `bool` | `true` | 是否显示名称 |
| `BackgroundImageOpacity` / `BackgroundImageBlur` | `double` | `1.0` | 背景图透明度和模糊 |
| `tryParseInlineHtml` | `bool` | `true` | 是否解析内联 HTML |

**MiscSettingModel** — 杂项设置：

| 字段 | 类型 | 说明 |
|---|---|---|
| `autoTitle_enabled` | `bool` | 自动生成标题开关 |
| `autoTitle_level` | `int` | 触发标题生成的消息数 |
| `autotitleOption` | `ChatOptionModel` | 生成标题用的预设 |
| `summaryOption` | `ChatOptionModel` | 生成总结用的预设 |
| `simulateUserOption` | `ChatOptionModel` | AI 帮答用的预设 |
| `genMemOption` | `ChatOptionModel` | 生成记忆用的预设 |

**PromptSettingModel** — 提示词设置：

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `continuePrompt` | `String` | `"继续"` | 让 AI 继续输出的提示词 |
| `interAssistantUserSeparator` | `String` | `"继续"` | 连续助手消息之间的用户分隔符 |
| `groupFormatter` | `String` | `"<char>:<message>"` | 群聊消息格式化模板 |
| `isFormatMainContent` | `bool` | `false` | 是否格式化正文 |

**QuickCommand** — 快捷指令：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `int` | 唯一标识 |
| `name` | `String` | 名称 |
| `command` | `String` | 指令文本 |
| `role` | `QuickCommandRole` | `narration` / `user` / `assistant` |
| `addCommandToMessageList` | `bool` | 是否将指令加入消息列表 |
| `bindOption` | `int?` | 绑定的预设 ID |

---

### 1.14 工具实体类（`utils/entitys/`）

**LLMRequestOptions** — 发给 LLM 的请求参数：

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `messages` | `List<LLMMessage>` | 必填 | 消息列表 |
| `maxTokens` | `int` | `8000` | Token 上限 |
| `temperature` | `double` | `0.95` | 温度参数 |
| `topP` | `double` | `1.0` | 核采样 |
| `presencePenalty` | `double` | `0.0` | 话题新鲜度惩罚 |
| `frequencyPenalty` | `double` | `0.0` | 词频惩罚 |
| `maxHistoryLength` | `int` | `64` | 历史消息长度上限 |
| `apiId` | `int` | `-1` | API ID |
| `modelName` | `String?` | `null` | 覆盖模型名 |
| `isStreaming` | `bool` | `true` | 流式响应 |
| `isThinkMode` | `bool` | `false` | 思考模式 |
| `isDeleteThinking` | `bool` | `true` | 删除思考内容 |
| `isMergeMessageList` | `bool` | `false` | 合并消息列表 |
| `chatCompressionSettings` | `ChatCompressionSettings` | — | 聊天压缩设置 |

**LLMMessage** — 发送给 LLM 的中间消息格式：

| 字段 | 类型 | 说明 |
|---|---|---|
| `content` | `String` | 消息内容 |
| `role` | `String` | `"user"` / `"assistant"` / `"system"` |
| `fileDirs` | `List<String>` | 附件路径 |
| `isPrompt` | `bool` | 是否为提示词消息 |

**ChatAIState** — AI 生成状态：

| 字段 | 类型 | 说明 |
|---|---|---|
| `LLMBuffer` | `String` | 流式响应缓冲区 |
| `GenerateState` | `String` | 生成状态文本描述 |
| `isGenerating` | `bool` | 是否正在生成 |
| `currentAssistant` | `int` | 当前发言角色 ID |
| `aihandler` | `Aihandler` | AI Handler 引用 |

---

## 二、Controllers（GetX 控制器）

所有 Controller 在 `SillyChatApp` 构造时通过 `Get.put()` 注册为**全局单例**，通过 `.of()` 或 `Get.find<>()` 获取。

### 2.1 SettingController（`providers/setting_controller.dart`）

**职责**：全局应用设置，管理 vault 路径和版本。

**文件**：`global_settings.json`（存于应用文档目录根）

**状态**：
| 属性 | 类型 | 说明 |
|---|---|---|
| `isDarkMode` | `RxBool` | 暗色模式 |
| `colorTheme` | `Rx<ColorScheme>` | 颜色主题 |

**静态属性**：
| 属性 | 类型 | 说明 |
|---|---|---|
| `currectValutName` | `String` | 当前 vault 名称 |
| `webdav_url` / `webdav_username` / `webdav_password` | `String` | WebDAV 凭据 |
| `vaultPath` | `String` | 当前 vault 完整路径 |
| `cachedModelList` | `RxMap<ServiceType, List<String>>` | 缓存的模型列表 |

**关键方法**：
| 方法 | 返回值 | 说明 |
|---|---|---|
| `getVaultPath()` | `Future<String>` | 获取当前 vault 路径 |
| `getChatPath()` / `getChatPathSync()` | `Future<String>` / `String` | 聊天文件夹路径 |
| `getChatDirectory()` / `getChatDirectorySync()` | `Future<Directory>` / `Directory` | 聊天文件夹 Directory |
| `getImagePath()` / `getImagePathSync()` | `Future<String>` / `String` | 图片存储路径 |
| `loadVaultName()` | `static Future<void>` | **早于 runApp** 调用，设置 vault 名 |
| `loadInitialData()` | `static Future<void>` | 首次启动时从 assets 复制初始数据 |
| `checkVersion()` | `bool` | 检查版本是否已升级 |
| `toggleDarkMode()` | `void` | 切换暗色模式并保存 |
| `setCurrentVaultName(String)` | `void` | 切换 vault 并保存 |

**获取方式**：`SettingController.of` 或 `Get.find<SettingController>()`

---

### 2.2 VaultSettingController（`providers/vault_setting_controller.dart`）

**职责**：当前 vault 级别设置。包含 APIs、正则、主题、显示/杂项设置。

**文件**：`{vaultPath}/settings.json`

**状态**：
| 属性 | 类型 | 说明 |
|---|---|---|
| `apis` | `RxList<ApiModel>` | API 列表 |
| `defaultApiId` | `Rx<int?>` | 默认 API ID |
| `defaultModelName` | `Rx<String>` | 默认模型名 |
| `regexes` | `RxList<RegexModel>` | 全局正则规则 |
| `lastSyncTime` | `Rx<DateTime?>` | 最后同步时间 |
| `myId` | `RxInt` | 我的角色 ID |
| `displaySettingModel` | `Rx<ChatDisplaySettingModel>` | 显示设置 |
| `miscSetting` | `Rx<MiscSettingModel>` | 杂项设置 |
| `promptSettingModel` | `Rx<PromptSettingModel>` | 提示词设置 |
| `historyModel` | `Rx<HistoryModel>` | 历史记录 |
| `themeLight` / `themeNight` | `Rx<ThemeData>` | 亮/暗主题 |
| `isShowOnBoardPage` | `RxBool` | 是否显示引导页 |

**关键方法**：
| 方法 | 说明 |
|---|---|
| `loadSettings()` | 从 JSON 加载所有设置 |
| `saveSettings()` | 保存所有设置到 JSON |
| `addApi(ApiModel)` / `updateApi(ApiModel)` / `deleteApi(id:)` | API CRUD |
| `getApiById(int)` → `ApiModel?` | 按 ID 查找 API |
| `getApiByUrlAndModel(url, model)` → `ApiModel?` | 按 URL+模型查找 |
| `updateTheme(themname:, fontName:)` | 更新 FlexColorScheme 主题 |
| `updateThemeStardard(color:, fontName:)` | 更新标准主题 |
| `addToChatHistory(String chatId)` | 添加到最近聊天（去重，最多50条） |
| `addToCharacterHistory(int charId)` | 添加到最近角色（去重，最多5条） |
| `lastSyncTimeString` | 格式化最后同步时间 |

**获取方式**：`VaultSettingController.of()` 或 `Get.find<VaultSettingController>()`

---

### 2.3 ChatController（`providers/chat_controller.dart`）

**职责**：聊天文件索引、聊天创建/删除、文件夹设置、消息剪贴板。**与 ChatSessionController 的区别**：ChatController 管理"有哪些聊天"，ChatSessionController 管理"某个聊天当前打开时的状态"。

**文件**：`chats/` 文件夹 + `chat_index.json` + `folder_setting.json`

**状态**：
| 属性 | 类型 | 说明 |
|---|---|---|
| `chats` | `RxList<ChatModel>` | 聊天列表（仅迁移用，已废弃） |
| `chatIndex` | `RxMap<String, ChatMetaModel>` | 聊天元数据索引，key=规范化的文件路径 |
| `currentChat` | `Rx<ChatSessionController?>` | 当前打开的聊天会话 |
| `currentPath` | `RxString` | 当前打开的聊天数据路径 |
| `pageController` | `PageController` | 主页面 PageController |
| `openedChat` | `RxMap<String, ChatSessionController?>` | 已打开的聊天会话 |
| `messageClipboard` | `RxList<MessageModel>` | 消息剪贴板 |
| `isMultiSelecting` | `RxBool` | 是否多选模式 |
| `folderSettings` | `RxMap<String, FolderSettingModel>` | 文件夹设置映射 |
| `fileDeleteEvent` / `fileCreateEvent` | `Rx` | 文件事件 |

**计算属性**：
- `messageToPaste` → `List<MessageModel>` 反转剪贴板顺序并分配新的时间戳/ID
- `atFirstPage` / `atSecondPage` → `bool`

**关键方法**：
| 方法 | 说明 |
|---|---|
| `loadChatIndex()` | 从 `chat_index.json` 加载索引 |
| `saveChatIndex()` | 保存索引 |
| `updateChatMeta(path, meta)` | 更新一条索引 |
| `getIndex(path)` → `ChatMetaModel?` | 获取索引 |
| `buildIndex(path)` → `Future<ChatMetaModel?>` | 从聊天文件构建索引（初次加载） |
| `deleteChatMetaByPath(path)` | 删除索引 |
| `createChat(chat, path)` → `Future<String>` | 创建聊天文件，返回文件路径 |
| `createQuickChat(path)` → `Future<ChatModel>` | 快速创建空白聊天 |
| `createChatForCharacter(character)` → `Future<(ChatModel, String)>` | 为角色创建聊天（含开场白） |
| `createChatForStory(story)` → `Future<(ChatModel, String)>` | 为故事创建聊天 |
| `openChat(path)` | 打开一个聊天（创建 ChatSessionController） |
| `openCharacterLatestChat(character)` | 打开某角色的最新聊天或创建新聊天 |
| `openStoryLatestChat(story)` | 打开某故事的最新聊天或创建新聊天 |
| `getFolderSettingByChatPath(chatPath)` | 查找最靠近的文件夹设置 |
| `createFolderSetting(path)` / `removeFolderSetting(path)` / `saveFolderSetting(setting)` | 文件夹设置 CRUD |
| `createUniqueFile(originalPath:)` → `Future<File>` | 创建唯一文件（自动追加 (2)(3) 等后缀） |
| `putMessageToClipboard(original, selected)` | 选中消息加入剪贴板 |

**获取方式**：`ChatController.of` 或 `Get.find<ChatController>()`

---

### 2.4 ChatSessionController（`providers/chat_session_controller.dart`）

**职责**：单个聊天会话的运行状态。管理消息列表、AI 生成、正则执行、输入框。通过 `tag`（文件路径）标识。

**重要**：不是全局单例！通过 `Get.put(ChatSessionController(path), tag: path)` 注册，通过 `Get.find<ChatSessionController>(tag: path)` 获取。可以同时存在多个活跃会话。

**状态**：
| 属性 | 类型 | 说明 |
|---|---|---|
| `chatPath` | `String` | 聊天文件路径 |
| `inputController` | `TextEditingController` | 输入框控制器 |
| `commandController` | `TextEditingController` | 指令输入框控制器 |
| `isLoading` | `RxBool` | 是否加载中 |
| `isGeneratingTitle` | `RxBool` | 是否正在生成标题 |
| `isCommandPinned` | `RxBool` | 附加指令是否常驻 |
| `isLock` | `RxBool` | 是否锁定（用于"多窗口"） |
| `isViewActive` | `bool` | 当前会话是否在前台 |
| `cachedTokens` | `RxInt` | 缓存的 Token 数 |
| `backGroundTasks` | `int` | 后台任务计数 |
| `chat` | `ChatModel` | 当前聊天数据 |
| `aiState` | `ChatAIState` | AI 生成状态 |
| `onLoadFinished` | `VoidCallback?` | 加载完成回调 |
| `onAIStateUpdate` | `VoidCallback?` | AI 状态更新回调 |

**计算属性**：
- `isGenerating` → `aiState.isGenerating`
- `file` → `chat.file`
- `isChatUninitialized` → `file == null`
- `canDestory` → 当不生成 + 输入框为空 + 无后台任务 + 未锁定时，会话可被销毁

**工厂方法**：`ChatSessionController.uninitialized()` 创建未初始化的占位会话。

**静态方法**：`tryGetSession(String path)` → `ChatSessionController?` 获取可能存在的会话。

---

### 2.5 CharacterController（`providers/character_controller.dart`）

**职责**：角色卡管理。

**文件**：`{vaultPath}/characters.json`

**状态**：
| 属性 | 类型 | 说明 |
|---|---|---|
| `characters` | `RxList<CharacterModel>` | 角色卡列表 |
| `characterCilpBoard` | `Rx<CharacterModel?>` | 角色剪贴板 |

**静态常量**：
- `defaultCharacter` — id=-1 的默认助手
- `SUMMARY_CHARACTER_ID` = -2
- `summaryCharacter` — 总结姬

**属性**：
- `myId` → get/set 我的角色ID（映射到 `VaultSettingController.myId`）
- `me` → `CharacterModel` 我的角色
- `groupedCharacters` → `Map<String, List<CharacterModel>>` 按分类分组的角色

**关键方法**：
| 方法 | 说明 |
|---|---|
| `loadCharacters()` | 加载角色，若不存在 id=0 的"我"则自动创建 |
| `saveCharacters()` | 保存角色列表 |
| `addCharacter(CharacterModel)` / `updateCharacter(CharacterModel)` / `deleteCharacter(int id)` | CRUD |
| `getCharacterById(int id)` → `CharacterModel` | 查找角色，**找不到则返回 defaultCharacter** |
| `getCharactersByCategory(String)` → `List<CharacterModel>` | 按分类筛选 |
| `setRelation(targetId, type:)` / `removeRelation(targetId)` | 管理我的角色关系 |
| `getAllRelationsJson()` | 获取所有角色关系（去重，用于关系图） |

**获取方式**：`CharacterController.of` 或 `Get.find<CharacterController>()`

---

### 2.6 ChatOptionController（`providers/chat_option_controller.dart`）

**职责**：聊天预设管理。

**文件**：`{vaultPath}/chat_options.json`

**状态**：
| 属性 | 类型 | 说明 |
|---|---|---|
| `chatOptions` | `RxList<ChatOptionModel>` | 预设列表 |

**属性**：`defaultOption` → 第一个预设，若列表为空则创建 `ChatOptionModel.roleplay()`

**方法**：`addChatOption` / `updateChatOption` / `deleteChatOption(index)` / `getChatOptionByIndex` / `getChatOptionById` / `reorderChatOptions`

**获取方式**：`ChatOptionController.of()` 或 `Get.find<ChatOptionController>()`

---

### 2.7 PromptController（`providers/prompt_controller.dart`）

**职责**：系统提示词管理。

**文件**：`{vaultPath}/prompts.json`

**状态**：
| 属性 | 类型 | 说明 |
|---|---|---|
| `prompts` | `RxList<PromptModel>` | 提示词列表 |

**方法**：`loadPrompts()` / `savePrompts()` / `addPrompt` / `updatePrompt` / `deletePrompt(id)` / `getPromptById(id)` / `getPromptByNameAndRole(name, role)` / `reorderPrompts`

**注意**：`savePrompts()` 会过滤掉 `isInChat == true` 的 prompt（聊天内嵌 prompt 不持久化）。

---

### 2.8 LoreBookController（`providers/lorebook_controller.dart`）

**职责**：世界书管理。

**文件**：`{vaultPath}/lorebooks.json`

**状态**：
| 属性 | 类型 | 说明 |
|---|---|---|
| `lorebooks` | `RxList<LorebookModel>` | 世界书列表 |
| `globalActivitedLoreBookIds` | `RxList<int>` | 全局激活的世界书 ID |
| `lorebookItemClipboard` | `Rx<LorebookItemModel?>` | 世界书条目剪贴板 |

**计算属性**：`globalActivitedLoreBooks` → 全局激活的世界书模型列表。

**方法**：`loadLorebooks()` / `saveLorebooks()` / `addLorebook` / `updateLorebook` / `deleteLorebook(id)` / `getLorebookById(id)` / `reorderLorebooks`

**获取方式**：`LoreBookController.of` 或 `Get.find<LoreBookController>()`

---

### 2.9 StoryController（`providers/story_controller.dart`）

**职责**：故事/关系网管理。

**文件**：`{vaultPath}/stories.json`

**状态**：
| 属性 | 类型 | 说明 |
|---|---|---|
| `stories` | `RxList<StoryModel>` | 故事列表 |

**属性**：`defaultStory` → 第一个故事。

**方法**：`loadStories()` / `saveStories()` / `addStory` / `updateStory` / `deleteStory(index)` / `getStoryByIndex(index)` / `getStoryById(String id)` / `reorderStories`

**获取方式**：`StoryController.of()` 或 `Get.find<StoryController>()`

---

### 2.10 LogController（`providers/log_controller.dart`）

**职责**：应用日志记录。

**状态**：
| 属性 | 类型 | 说明 |
|---|---|---|
| `logs` | `List<LogEntry>` | 日志列表（最多 30 条） |
| `unread` | `int` | 未读日志数 |

**LogLevel**：`info`, `warning`, `error`

**LogType**：`text`, `json`

**`LogEntry`**：`message`, `level`, `timestamp`, `type`, `title`

**方法**：
| 方法 | 说明 |
|---|---|
| `addLog(message, level, type:, title:)` → `LogEntry` | 添加日志（插入到列表头部） |
| `clearLogs()` / `clearUnread()` | 清除日志 / 清除未读标记 |
| `getLogsByLevel(level)` | 按级别过滤 |

**静态便捷方法**：`LogController.log(message, level)` 直接记录日志。

**获取方式**：`LogController.to` 或 `Get.find<LogController>()`

---

### 2.11 WebSessionController（`providers/web_session_controller.dart`）

**职责**：WebView 与 Flutter 之间的桥接。用于关系图可视化和消息渲染。

**非单例**，每次创建 WebView 时新建。

**构造参数**：
- `webViewController` — `InAppWebViewController`
- `chatSessionController` — `ChatSessionController`
- `onMessageEmit` — `Function(dynamic args)` 消息回调

**方法**：
- `onWebViewCreated(controller)` — 注册 JS handler（`fetchChat`, `fetchAllCharacters`, `emitMessage`）
- `onStateChange(ChatAIState)` — 将 AI 状态推送到 WebView
- `onChatChange(ChatModel)` — 将聊天数据推送到 WebView

---

## 三、数据流概览

```
用户输入
  → ChatSessionController.inputController
  → PromptBuilder.buildMessages()        ← PromptController, CharacterController, LoreBookController
  → LLMRequestOptions (请求参数封装)
  → AIHandler.request()                  ← Servicehandler (OpenAI/DeepSeek/Gemini...)
  → Servicehandler.parseMessage()        ← 将 API 响应转为 LLMMessage
  → RegexModel.process()                 ← 正则后处理
  → ChatModel.messages 更新
  → ChatController.saveChatIndex()       ← 更新索引
  → UI 刷新 (Obx / GetBuilder)
```

**数据持久化**：所有数据以 JSON 文件存储在 `{appDocDir}/SillyChat/{vaultName}/` 下，各 Controller 自行管理读写。切换 vault 时调用 `SillyChatApp.restart()` 清空所有状态并重新加载。