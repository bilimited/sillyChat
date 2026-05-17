# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Silly Chat 是一个类酒馆（SillyTavern）的 AI 聊天前端，使用 Flutter 构建，支持 android/windows/linux/macos/web。主要面向移动端，桌面端部分操作逻辑未适配。定位介于 NextChat 和 SillyTavern 之间，主打轻量灵活。

## 构建/运行命令

```bash
# 安装依赖
flutter pub get

# 生成 freezed/json_serializable 代码
dart run build_runner build

# 静态分析
flutter analyze

# 运行测试（目前只有一个空测试）
flutter test

# 构建 Android APK (仅 arm64)
flutter build apk --release --target-platform android-arm64

# 构建 Windows
flutter build windows --release

```

## 技术栈

- **Flutter SDK**: 3.35.5, Dart SDK ^3.5.4
- **状态管理**: GetX（全局用 `Get.put` 注册 controller，`Get.find` 获取，`Get.find<ChatSessionController>(tag: path)` 获取带 tag 的 controller）
- **网络**: dio + dio_http2_adapter（HTTP/2 支持，在 AIHandler 中使用）
- **持久化**: 纯文件存储（JSON），无数据库。数据存在应用文档目录下的 `SillyChat/` 文件夹
- **代码生成**: freezed + json_serializable + build_runner
- **WebView**: flutter_inappwebview（用于关系图可视化和消息渲染预览）

## 架构

### 数据层

**Vault（保管库）机制** — 应用支持多个数据仓库。每个 vault 是一个独立的文件夹（`{appDocDir}/SillyChat/{vaultName}/`），内含完全的 settings.json、chats/、角色、预设等数据，互相隔离。用户可在 vault_manager.dart 切换。

**所有数据以 JSON 文件存储在文件系统中**：
- `global_settings.json` — 全局设置（暗色模式、当前 vault 名、webdav 凭据）
- `settings.json` — 每个 vault 的设置（API 列表、正则、主题、历史记录）
- `chats/` 文件夹 — 每个聊天是一个 `.chat` 文件（JSON），聊天元数据索引在 `chat_index.json`
- 角色/预设/世界书同理，各自有独立的 controller 管理 JSON 读写

### Controller 层（GetX，`lib/chat-app/providers/`）

所有 controller 通过 `Get.put()` 在 `SillyChatApp` 构造时注册为全局单例：

| Controller | 职责 |
|---|---|
| `SettingController` | 全局设置、vault 路径、暗色模式、版本管理 |
| `VaultSettingController` | 当前 vault 的 APIs、正则有、主题、显示设置、杂项设置 |
| `ChatController` | 聊天文件索引（chatIndex）、聊天创建/删除、文件夹设置、消息剪贴板 |
| `ChatSessionController` | **单个聊天会话**的运行状态：消息列表、AI 生成状态、输入框、正则执行。带有 `tag`（文件路径），通过 `Get.find<ChatSessionController>(tag: path)` 获取。可同时存在多个活跃会话 |
| `CharacterController` | 角色卡加载/保存/管理 |
| `PromptController` | 提示词预设管理 |
| `ChatOptionController` | 聊天选项（生成参数）管理 |
| `LoreBookController` | 世界书管理 |
| `StoryController` | 故事/关系管理 |
| `WebSessionController` | WebView 会话管理 |

### 模型层（`lib/chat-app/models/`）

- `ChatModel` — 聊天数据：消息列表、角色绑定、模式（单人/群聊）、元数据、激活的世界书条目
- `MessageModel` — 单条消息：内容、角色、备选文本（alternativeContent，用于滑动选择）、可见性（common/pinned/hidden）
- `ApiModel` — API 配置：服务商类型、key、URL、模型名
- `CharacterModel` — 角色卡
- `PromptModel` — 系统提示词
- `RegexModel` — 正则替换规则
- `LoreBookModel` / `LorebookItemModel` — 世界书及其条目
- `StoryModel` — 故事/关系网

### API 通信层（`lib/chat-app/utils/service_handlers/`）

`Servicehandler` 抽象类定义了 API 接口。`ServiceHandlerFactory` 根据 `ServiceType` 枚举返回对应实例：

- `OpenAIServiceHandler` — OpenAI 及自定义兼容 API
- `GoogleServiceHandler` — Gemini
- `DeepSeekServiceHandler`
- `SiliconFlowServiceHandler`
- `KimiServiceHandler`

`AIHandler`（`lib/chat-app/utils/AIHandler.dart`）封装了 dio HTTP 客户端，管理请求/取消/后台任务生命周期。消息发送流程：ChatSessionController → PromptBuilder 构造 prompt → AIHandler.request() → Servicehandler.parseMessage() → 流式返回 → 正则处理 → 更新 UI。

### 页面/UI 结构（`lib/chat-app/pages/`）

- `MainPage` (desktop) / `MainPageMobile` — 主页面，用 PageController 管理两个子页面（列表页 / 聊天页）
- 聊天相关：`chat_detail_page.dart`（核心聊天 UI）、`edit_message.dart`、`search_page.dart`、`prompt_preview_page.dart`
- 设置类：`appearance_page.dart`、`prompt_format_setting_page.dart`、`misc_setting_page.dart`
- 管理类：`vault_manager.dart`、`character_selector.dart`、`lorebook_editor.dart`

### SillyTavern 兼容（`lib/chat-app/utils/sillyTavern/`）

- `STCharacterImporter` — 导入酒馆角色卡
- `STLorebookImporter` — 导入世界书
- `STRegexImporter` — 导入正则
- `STConfigImporter` — 导入预设配置
- `STMarcoProcesser` — 酒馆宏处理

### 事件系统（`lib/chat-app/events.dart`）

简单的 Event 类体系：`FileDeletedEvent`、`FileCreatedEvent`、`NewMessageEvent`。通过 GetX 的 `Rx` 在 controller 间传递。

## 关键约定

- 包名是 `flutter_example`（历史遗留），应用中所有 import 以此为前缀
- 常量、文件扩展名定义在 `lib/chat-app/constants.dart`
- `USER_ID` 固定为 0
- 聊天文件后缀 `.chat`，文件夹设置后缀 `folder_setting.json`
- `MessageModel.visbility` 有三种状态：common（正常）、pinned（置顶/固定）、hidden（隐藏）
- `MessageModel.alternativeContent` 的第一个元素始终为 null，表示当前选中的文本
- 数据迁移和版本兼容代码散落在各 controller 的 load 方法中，修改 model 时需注意向后兼容