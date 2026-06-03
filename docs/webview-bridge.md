# Dart ↔ WebView 通信接口

SillyChat 使用 `flutter_inappwebview` 将 Vue 3 前端嵌入为聊天消息的渲染层。Dart（Flutter）与 WebView（JavaScript）之间通过两种机制双向通信：

- **Dart → JS**：`webViewController.evaluateJavascript()` 调用 `window.*` 全局函数（被动推送）
- **JS → Dart**：`window.flutter_inappwebview.callHandler()` 调用 Dart 侧注册的 handler（主动请求）

## 关键文件

| 层级 | 文件 | 职责 |
|------|------|------|
| Dart 桥接层 | `lib/chat-app/providers/web_session_controller.dart` | JS handler 注册、Dart→JS 推送方法、握手管理、消息动作处理 |
| Dart 会话层 | `lib/chat-app/providers/chat_session_controller.dart` | `bindWebController()` 连接会话与 WebView、增量同步调度、流式 delta 计算、滚动代理 |
| Dart UI 层 | `lib/chat-app/widgets/webview/chat_webview.dart` | `InAppWebView` widget、`imgs://` 自定义 scheme 处理、生命周期管理、`onWebSessionCreated` 回调 |
| Dart UI 层 | `lib/chat-app/pages/chat/chat_page.dart` | 聊天页面、`onMessageEmit` 回调处理（clipboard、导航、BottomSheet 等需要 Flutter UI 上下文的操作） |
| Dart 数据模型 | `lib/chat-app/utils/entitys/ChatAIState.dart` | AI 状态模型，`toJson({includeBuffer})` 控制是否包含 LLMBuffer |
| JS 桥接层 | `lib/webview/src/api/api.js` | `BridgeAPI` 类：`window.*` 函数绑定、订阅/通知机制、`callHandler` 封装、消息动作便捷方法 |
| JS UI 层 | `lib/webview/src/App.vue` | Vue 3 组件：消息渲染、流式输出、主题切换、消息工具栏、滚动控制 |
| 前端项目配置 | `lib/webview/package.json` | Vite + Vue 3 项目，`npm run dev` 启动于 `localhost:5173` |

## 通信架构

```
┌──────────────────────────────────────────────────────────────────┐
│ Dart 侧                                                           │
│                                                                   │
│  ChatSessionController                                            │
│    │                                                              │
│    ├─ ever(_aiState) ──▶ delta 计算 ──▶ onTokenAppend()          │
│    │                       │                                      │
│    │                       └─▶ onStateChange()                    │
│    │                                                              │
│    ├─ ever(messageEvent) ──▶ onMessageAdded/Updated/              │
│    │                         Removed()                            │
│    │                                                              │
│    └─ onChatUpdate ──▶ onChatChange() (完整同步)                 │
│                                                                   │
│  ChatPage (chat_page.dart)                                        │
│    │                                                              │
│    ├─ onWebSessionCreated ──▶ onThemeChange() /                   │
│    │                          onDisplaySettingsChange()           │
│    │                                                              │
│    └─ onMessageEmit ◀── emitMessage default 分支                 │
│        (copyMessage, pasteMessages, addImageToMessage,            │
│         createBranch, optimizeMessage, messageMore,               │
│         scrollStateChanged)                                       │
│                                                                   │
│  WebSessionController                                             │
│    │                                                              │
│    ├─ evaluateJavascript("window.onXxx(...)") ──▶ JS             │
│    │                                                              │
│    └─ addJavaScriptHandler("notifyReady/emitMessage/..")          │
│                           ◀── callHandler() ── JS                 │
└──────────────────────────────────────────────────────────────────┘
```

## 握手与生命周期

### 启动流程

```
1. Flutter 创建 ChatWebview，加载 http://localhost:5173/
2. ChatWebview.onWebViewCreated → webSessionController 初始化 → onWebSessionCreated 回调
3. ChatPage 收到回调，推送初始主题和显示设置
4. Vue 应用挂载，BridgeAPI 构造函数绑定所有 window.onXxx 函数
5. App.vue onMounted → fetchAllCharacters() → notifyReady()
6. Dart 收到 notifyReady → _pushInitialData():
   - window.onChatChange(完整聊天数据)
   - window.onStateChange(完整 AI 状态)
   - window.onThemeChange(当前主题模式)
   - window.onDisplaySettingsChange(显示设置)
7. 若 JS 5 秒内未调用 notifyReady，Dart 超时强制推送
```

### 排队机制

JS 未就绪时（`_isJsReady == false`），所有 Dart→JS 推送方法将回调加入 `_pendingPushes` 队列，待 JS 就绪后批量刷新。这防止了 WebView 加载期间数据推送丢失。

### 销毁流程

```
ChatWebview.dispose()
  → webSessionController.dispose()    // 取消超时、清空队列、重置标志
  → session.closeWebController()      // 释放 Worker、清空 _webController、重置 onChatUpdate
```

## Dart → JS 通信（推送）

所有 Dart→JS 数据通过 `window.*` 全局函数传递，参数为 JSON 编码的字符串或原始值。

### 聊天数据同步

#### window.onChatChange(chatJson)

**用途**：完整聊天数据同步（初始加载 / 保存后重同步）

**触发时机**：
- JS 就绪握手后的初始推送
- 每次 `saveChat()` 调用后（通过 `onChatUpdate` 回调）

**数据格式**：`ChatModel.toJson()`，包含完整消息列表

```json
{
  "id": 1234567890,
  "name": "聊天标题",
  "avatar": "",
  "lastMessage": "最后一条消息...",
  "time": "2026-06-03T12:00:00.000",
  "characterIds": [10, 0],
  "messages": [ /* MessageModel[] */ ],
  "userId": 0,
  "assistantId": 10,
  "mode": "auto",
  "bookmarks": [],
  "chatVars": {},
  "activitedLorebookItems": {},
  "needAutoTitle": false,
  "meta": {}
}
```

#### window.onMessageAdded(messageJson, index)

**用途**：增量消息添加

**触发时机**：`ChatSessionController.addMessage()` → `messageEvent(MessageEventType.add)`

**守卫条件**：仅在 `_isJsReady && _hasSentInitialPush` 时推送。

#### window.onMessageUpdated(messageJson)

**用途**：增量消息更新

**触发时机**：`ChatSessionController.updateMessage()` → `messageEvent(MessageEventType.update)`

JS 侧通过 `id` + `time` 匹配并替换消息。

#### window.onMessageRemoved(messageJson)

**用途**：增量消息删除

**触发时机**：`ChatSessionController.removeMessage()` → `messageEvent(MessageEventType.delete)`

JS 侧通过 `id` + `time` 匹配并过滤消息。

### AI 状态 & 流式生成

#### window.onStateChange(stateJson)

**用途**：AI 生成状态同步

**触发时机**：`ChatAIState` 发生变化（`_aiState` observable 更新）

**数据格式**：`ChatAIState.toJson({includeBuffer})`

```json
{
  "id": "_",
  "GenerateState": "正在生成...",
  "isGenerating": true,
  "style": 0,
  "currentAssistant": 10
}
```

> **LLMBuffer 处理策略**：流式生成期间（`isGenerating == true`），`includeBuffer` 为 `false`，不传 LLMBuffer——文本内容通过 `onTokenAppend` 增量传递。生成结束时（`isGenerating` 翻转为 `false`），`includeBuffer` 为 `true`，携带完整 buffer 用于最终调和。

#### window.onTokenAppend(token)

**用途**：AI 流式输出的增量 token 追加

**触发时机**：`LLMBuffer` 长度增长时，每次推送新增的尾部子串

**数据格式**：原始字符串（经 `json.encode` 转义）

```javascript
// Dart: controller.onTokenAppend("你好");
// JS 收到: window.onTokenAppend("你好")
```

### 主题与显示设置

#### window.onThemeChange(themeJson)

**用途**：切换昼夜模式。WebView 使用独立的 CSS 主题系统，不与 Flutter Material 主题同步。

**触发时机**：
- 初始握手时（根据设备 `platformBrightness` 推送）
- 用户切换主题设置时（后续由 ChatPage 调用）

**数据格式**：

```json
{ "mode": "light" }
```

```json
{ "mode": "dark" }
```

**JS 侧处理**：`App.vue` 切换 `<html>` 元素的 `.theme-dark` CSS 类，CSS 变量自动覆盖颜色。

#### window.onDisplaySettingsChange(settingsJson)

**用途**：同步聊天显示设置到 WebView

**触发时机**：
- 初始握手时推送
- 用户在设置中修改显示选项后重推

**数据格式**：`ChatDisplaySettingModel.toJson()`

```json
{
  "avatarStyle": 0,
  "messageBubbleStyle": 0,
  "ContentFontSize": 1.0,
  "AvatarSize": 25,
  "AvatarBorderRadius": 8,
  "MessageBubbleBorderRadius": 16,
  "displayUserName": true,
  "displayAssistantName": true,
  "displayMessageDate": false,
  "BackgroundImageOpacity": 1.0,
  "BackgroundImageBlur": 1.0
}
```

**JS 侧处理**：`App.vue` 将设置值写入 CSS 自定义属性（`--avatar-size`、`--font-scale`、`--bubble-radius` 等）。

### 滚动控制

#### window.scrollToBottom()

**用途**：强制 WebView 滚动到消息列表底部

**触发时机**：
- 用户发送消息后
- AI 开始生成时
- 用户点击"回到底部"浮动按钮

#### window.scrollToMessage(id)

**用途**：滚动到指定消息

**触发时机**：搜索 / 消息管理页面跳转到特定消息

**参数**：`int` — 消息 ID

## JS → Dart 通信（请求）

JS 通过 `window.flutter_inappwebview.callHandler(handlerName, ...args)` 调用 Dart 侧注册的 handler。

### notifyReady

**用途**：通知 Dart JS 已就绪，可以开始推送数据

```javascript
appApi.notifyReady();
```

**调用时机**：`App.vue` 的 `onMounted` 中，`fetchAllCharacters()` 完成后

### fetchChat

**用途**：手动请求完整聊天数据（重同步）

```javascript
appApi.fetchChat();
```

**调用时机**：通常无需主动调用（初始数据由握手推送），保留用于需要强制重同步的异常场景

### fetchAllCharacters

**用途**：获取所有角色列表

```javascript
const chars = await appApi.fetchAllCharacters();
```

**返回**：`Promise<Array<Character>>`，直接返回角色对象数组（不走 push 通道）

### emitMessage

**用途**：WebView 中的用户交互事件。通过 `action` 字段区分不同类型。

**通用格式**：

```javascript
window.flutter_inappwebview.callHandler('emitMessage', {
  action: '<action-name>',
  data: { /* action-specific payload */ }
});
```

**支持的 action 完整列表**：

| action | data 字段 | 处理位置 | 说明 |
|--------|-----------|----------|------|
| `sendMessage` | `text: string`, `selectedPath: string[]` | WebSessionController | 发送新消息 |
| `retry` | `index?: number`（默认 1） | WebSessionController | 重新生成 AI 回复 |
| `editMessage` | `time: string (ISO)`, `newContent: string` | WebSessionController | 编辑消息内容 |
| `deleteMessage` | `time: string (ISO)` | WebSessionController | 删除消息 |
| `interrupt` | — | WebSessionController | 中断 AI 生成 |
| `switchAlternative` | `time: string (ISO)`, `direction: "left"\|"right"` | WebSessionController | 切换备选回复版本 |
| `deleteAlternatives` | `time: string (ISO)` | WebSessionController | 删除所有备选条目 |
| `copyMessage` | `text: string` | ChatPage (onMessageEmit) | 复制消息到系统剪贴板 |
| `pasteMessages` | `time: string (ISO)`, `position: "above"\|"below"` | ChatPage (onMessageEmit) | 粘贴剪贴板消息 |
| `addImageToMessage` | `time: string (ISO)` | ChatPage (onMessageEmit) | 打开图片选择器添加到消息 |
| `createBranch` | `time: string (ISO)` | ChatPage (onMessageEmit) | 从消息位置创建分支聊天 |
| `optimizeMessage` | `time: string (ISO)` | ChatPage (onMessageEmit) | 打开消息优化页面 |
| `messageMore` | `time: string (ISO)` | ChatPage (onMessageEmit) | 弹出更多操作 BottomSheet |
| `scrollStateChanged` | `isNearBottom: bool` | ChatPage (onMessageEmit) | 通知滚动位置变化 |

**处理分工原则**：
- **WebSessionController 直接处理**：纯数据操作（`sendMessage`, `retry`, `editMessage`, `deleteMessage`, `interrupt`, `switchAlternative`, `deleteAlternatives`）— 这些只需访问 `chatSessionController`
- **ChatPage onMessageEmit 处理**：需要 Flutter UI 上下文的操作（`copyMessage`, `pasteMessages`, `addImageToMessage`, `createBranch`, `optimizeMessage`, `messageMore`, `scrollStateChanged`）— 这些需要 `Scaffold`、`Navigator`、`BuildContext`、系统剪贴板等

## JS 侧 BridgeAPI

`lib/webview/src/api/api.js` 提供 `BridgeAPI` 类，封装所有通信逻辑。

### 订阅方法

```javascript
import appApi from './api/api.js';

// 完整聊天更新
appApi.subscribeChat((chat) => { /* Chat 对象 */ });

// AI 状态更新（含流式）
appApi.subscribeState((state) => { /* AppState 对象 */ });

// 增量消息
appApi.subscribeMessageAdded(({ message, index }) => { /* Message + index */ });
appApi.subscribeMessageUpdated((message) => { /* Message */ });
appApi.subscribeMessageRemoved((message) => { /* Message */ });

// 流式 token 追加
appApi.subscribeTokenAppend((token) => { /* string */ });

// 主题切换
appApi.subscribeTheme((themeData) => { /* { mode: "light" | "dark" } */ });

// 显示设置更新
appApi.subscribeDisplaySettings((settings) => { /* ChatDisplaySettingModel JSON */ });

// 滚动控制
appApi.subscribeScrollToBottom(() => { /* 滚到底部 */ });
appApi.subscribeScrollToMessage((msgId) => { /* 滚到指定消息 */ });
```

### 请求方法（actions）

```javascript
// 握手
appApi.notifyReady();               // 通知 Dart JS 已就绪
appApi.fetchChat();                 // 手动请求完整聊天
appApi.fetchAllCharacters();        // 获取角色列表 → Promise<Array>

// 消息操作
appApi.sendMessage(text, selectedPath);  // 发送消息
appApi.retry(index);                     // 重新生成
appApi.interrupt();                      // 中断生成
appApi.editMessage(time, newContent);    // 编辑消息
appApi.deleteMessage(time);              // 删除消息
appApi.copyMessage(text);                // 复制到剪贴板
appApi.switchAlternative(time, dir);     // 切换备选版本
appApi.pasteMessages(time, position);    // 粘贴消息
appApi.addImageToMessage(time);          // 添加图片
appApi.createBranch(time);               // 创建分支
appApi.deleteAlternatives(time);         // 删除备选条目
appApi.optimizeMessage(time);            // 消息优化

// 滚动状态
appApi.notifyScrollState(isNearBottom);  // 通知滚动位置
appApi.messageMore(time);                // 更多操作（弹出 Flutter BottomSheet）
```

### 内部机制

- `window.onXxx` 在 `BridgeAPI` 构造函数中绑定，早于 Vue 组件挂载，确保 Dart 推送时 JS 函数始终可用
- `_safeParse(data)` 自动处理 JSON 字符串和已解析对象
- `_notify(eventName, data)` 调用所有已注册的回调
- 所有 `window.onXxx` 函数挂载在全局 `window` 上，可直接通过浏览器控制台调试

## WebView 主题系统

WebView 使用独立的 CSS 自定义属性（CSS Variables）主题系统，完全不依赖 Flutter 的 `ColorScheme`。

### 主题变量

在 `App.vue` 的 `<style>` 中定义了两套 CSS 变量：

- `:root` — 浅色主题（默认）
- `html.theme-dark` — 深色主题（覆盖）

**主要变量**：

| 变量 | 用途 |
|------|------|
| `--bubble-bg-ai` / `--bubble-bg-user` | AI/用户气泡背景色 |
| `--bubble-text-ai` / `--bubble-text-user` | AI/用户气泡文字色 |
| `--bubble-shadow` | 气泡/头像阴影 |
| `--sender-name-color` | 发送者名称颜色 |
| `--time-color` | 时间戳颜色 |
| `--code-bg` / `--code-border` | 代码块背景/边框 |
| `--inline-code-bg` | 行内代码背景 |
| `--blockquote-border` / `--blockquote-color` | 引用块样式 |
| `--toolbar-bg` / `--toolbar-border` / `--toolbar-text` | 消息工具栏样式 |
| `--cursor-color` | 流式输出光标颜色 |
| `--avatar-bg` | 头像占位背景 |

### 切换流程

```
Dart: onThemeChange({ mode: "dark" })
  → JS: window.onThemeChange({ mode: "dark" })
  → BridgeAPI._notify('onThemeChange', { mode: "dark" })
  → App.vue applyTheme({ mode: "dark" })
  → document.documentElement.classList.add('theme-dark')
  → CSS 变量自动覆盖为深色值
```

### 显示设置变量

`onDisplaySettingsChange` 推送的设置值通过以下 CSS 变量应用：

| 设置项 | CSS 变量 |
|--------|----------|
| `AvatarSize` | `--avatar-size` |
| `AvatarBorderRadius` / `avatarStyle` | `--avatar-border-radius` |
| `ContentFontScale` | `--font-scale` |
| `MessageBubbleBorderRadius` | `--bubble-radius` |

## 消息工具栏

当用户在 WebView 中点击一条消息时，消息底部会出现工具栏按钮：

| 按钮 | 触发方法 | 说明 |
|------|----------|------|
| 编辑 ✏️ | `appApi.editMessage()` | 弹出浏览器 prompt 编辑内容 |
| 复制 📋 | `appApi.copyMessage()` | 复制到系统剪贴板（通过 Dart） |
| 删除 🗑️ | `appApi.deleteMessage()` | 确认后删除消息 |
| 重试 🔄 | `appApi.retry()` | 仅最后一条 AI 消息可见 |
| 版本切换 ◀/▶ | `appApi.switchAlternative()` | 仅有多条备选回复时可见 |
| 更多 ⋯ | `appApi.messageMore()` | 弹出 Flutter BottomSheet（粘贴/图片/分支/优化等） |

选中状态由 Vue 组件内部管理（`selectedMessage` ref），Dart 不感知选中状态。

## 流式生成数据流

这是最复杂的通信路径，完整流程如下：

```
1. Dart: setAIState(copyWith(LLMBuffer: "", isGenerating: true))
   → ever(_aiState) 触发
   → onStateChange(state, includeBuffer: false)
   → window.onStateChange({isGenerating: true, LLMBuffer: (无), ...})
   → JS: appState 设为生成模式，显示光标

2. Token 到达（循环）
   Dart: setAIState(copyWith(LLMBuffer: old + token))
   → ever(_aiState) 触发
   → if (newBuffer.length > _previousLLMBuffer.length)
       → delta = newBuffer.substring(_previousLLMBuffer.length)
       → onTokenAppend(delta)
       → window.onTokenAppend("新token")
       → JS: appState.LLMBuffer += token，自动滚动
   → onStateChange(state, includeBuffer: false)
       → window.onStateChange({isGenerating: true, LLMBuffer: (无), ...})
       → JS: 仅合并 metadata，保留增量构建的 LLMBuffer

3. 生成结束
   Dart: setAIState(copyWith(isGenerating: false, LLMBuffer: "完整文本"))
   → ever(_aiState) 触发
   → onStateChange(state, includeBuffer: true)
   → window.onStateChange({isGenerating: false, LLMBuffer: "完整文本", ...})
   → JS: 完整调和，设置最终 LLMBuffer，移除光标
   → _previousLLMBuffer = ""
```

## 自定义 Scheme：imgs://

聊天 WebView 使用自定义 URL scheme 加载本地图片文件。

```
JS: <img src="imgs:///path/to/avatar.png">
  → InAppWebView 拦截
  → onLoadResourceWithCustomScheme (chat_webview.dart)
  → AvatarImage.getPath(request.url.path) 解析实际文件路径
  → File.readAsBytes() + lookupMimeType()
  → 返回 CustomSchemeResponse(data, contentType) 给 WebView
```

## 数据模型参考

### MessageModel JSON

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `int` | 消息唯一 ID（`DateTime.now().microsecondsSinceEpoch`） |
| `content` | `string` | 消息正文 |
| `sender` | `int` | 发送者角色 ID（0 = 用户，-1 = 默认助手） |
| `time` | `string` | ISO 8601 时间戳 |
| `type` | `string` | 消息样式：`"common"` / `"narration"` / `"summary"` |
| `role` | `string` | 角色：`"user"` / `"assistant"` / `"system"` |
| `token` | `int` | Token 数量（通常为 0） |
| `visbility` | `string` | 可见性：`"common"` / `"pinned"` / `"hidden"` |
| `bookmark` | `string\|null` | 书签文本 |
| `resPath` | `string[]` | 附件文件路径 |
| `alternativeContent` | `(string\|null)[]` | 备选回复列表，`null` 表示当前选中版本 |

### ChatAIState JSON

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `string` | 状态 ID（固定 `"_"`） |
| `LLMBuffer` | `string` | 流式生成累积文本（`includeBuffer=false` 时省略） |
| `GenerateState` | `string` | 生成阶段描述文本 |
| `isGenerating` | `bool` | 是否正在生成 |
| `style` | `int` | `MessageStyle` 枚举索引 |
| `currentAssistant` | `int` | 当前正在回复的助手角色 ID |

## 实现注意事项

1. **Worker 生命周期**：`ChatSessionController` 中的 `ever()` 返回的 `Worker` 必须在 `closeWebController()` 中手动 dispose，避免内存泄漏
2. **增量同步守卫**：`_messageEventWorker` 仅在 `bindWebController()` 之后激活，此时 `loadChat()` 已完成，因此从磁盘加载历史消息不会触发增量事件
3. **超时兜底**：若 WebView 加载但 JS 因任何原因未调用 `notifyReady`，5 秒超时强制推送，防止永久阻塞
4. **`includeBuffer` 默认值**：`ChatAIState.toJson({includeBuffer: true})` 默认包含 buffer，保证所有未显式传入 `false` 的现有调用点行为不变
5. **Delta 安全性**：`LLMBuffer` 重置（如开始新生成时设为空字符串）通过 `newBuffer.length > _previousLLMBuffer.length` 守卫安全跳过
6. **JSON 转义**：所有 Dart→JS 推送通过 `json.encode()` 序列化，特殊字符（引号、换行、反斜杠）自动安全转义
7. **动作分流**：`emitMessage` 中不需要 Flutter UI 上下文的动作（纯数据操作）在 `WebSessionController` 直接处理；需要 `BuildContext`/`Navigator`/系统 API 的动作通过 `default` 分支转发到 `ChatPage.onMessageEmit` 回调
8. **主题独立**：WebView 使用 CSS 自定义属性管理主题，与 Flutter Material 主题完全解耦。Dart 仅推送 `"light"` / `"dark"` 模式字符串
9. **工具栏状态**：消息选中/取消选中由 Vue 组件内部管理（`selectedMessage` ref），Dart 不感知。只有在用户点击工具栏按钮时，JS 才通过 `emitMessage` 通知 Dart
