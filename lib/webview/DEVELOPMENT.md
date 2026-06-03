# SillyChat WebView 前端开发文档

本文档面向 WebView 侧（Vue 3 前端）的开发者，介绍项目结构、通信接口、数据模型、主题系统以及如何扩展新功能。不涉及 Flutter 侧实现细节。

## 目录

- [项目概览](#项目概览)
- [本地开发](#本地开发)
- [架构概述](#架构概述)
- [通信接口](#通信接口)
  - [Dart → JS（被动接收）](#dart--js被动接收)
  - [JS → Dart（主动请求）](#js--dart主动请求)
- [数据模型](#数据模型)
- [主题系统](#主题系统)
- [添加新功能](#添加新功能)
- [浏览器独立测试](#浏览器独立测试)

---

## 项目概览

| 项目 | 说明 |
|------|------|
| 框架 | Vue 3 (Composition API, `<script setup>`) |
| 构建 | Vite 7 |
| Markdown | markdown-it 14 |
| 入口 | `src/main.js` → `src/App.vue` |
| 桥接层 | `src/api/api.js` (BridgeAPI) |
| 部署方式 | 内嵌于 Flutter `InAppWebView`，加载 `http://localhost:5173/` |

目录结构：

```
lib/webview/
├── index.html              # HTML 入口
├── package.json            # 依赖 & 脚本
├── vite.config.js          # Vite 配置
├── DEVELOPMENT.md          # 本文档
└── src/
    ├── main.js             # Vue 应用入口
    ├── style.css           # 全局样式
    ├── App.vue             # 主组件（消息列表、工具栏、流式渲染）
    └── api/
        └── api.js          # BridgeAPI — 与 Flutter 通信的完整封装
```

---

## 本地开发

```bash
# 安装依赖（首次）
cd lib/webview
npm install

# 启动开发服务器（默认 http://localhost:5173）
npm run dev

# 构建生产版本
npm run build

# 预览构建产物
npm run preview
```

Flutter 侧在调试模式下会自动连接 `http://localhost:5173/`。启动 Vite dev server 后，在 Flutter 应用中打开聊天页面即可看到 WebView 加载前端内容，修改 Vue 源码后 Vite 会 HMR 热更新。

---

## 架构概述

```
┌──────────────────────────────────────────────────────┐
│ WebView (Vue 3)                                      │
│                                                      │
│  App.vue ──── 消息渲染、流式显示、工具栏交互          │
│    │                                                 │
│    ├── 订阅: appApi.subscribeXxx(callback)           │
│    │        收到数据更新 → 响应式状态 → 重新渲染       │
│    │                                                 │
│    └── 请求: appApi.sendMessage(text)                │
│             appApi.editMessage(time, content)        │
│             appApi.retry(index)                      │
│             ... (通过 callHandler → Flutter)         │
└──────────────────────────────────────────────────────┘
```

通信方向：

- **Dart → JS**：Flutter 调用 `window.onXxx(data)` 全局函数，BridgeAPI 在构造函数中绑定这些函数，收到数据后通过订阅/通知机制分发给所有已注册的回调
- **JS → Dart**：Vue 组件调用 `appApi.someMethod()` → `window.flutter_inappwebview.callHandler('handlerName', ...args)` → Flutter 侧注册的 handler 处理

---

## 通信接口

所有通信封装在 `src/api/api.js` 的 `BridgeAPI` 类中，以单例形式挂载在 `window.appApi`。

### Dart → JS（被动接收）

Dart 侧调用 `window.*` 全局函数推送数据。通过 `appApi.subscribe*()` 注册监听。

#### 数据推送

| window 函数 | 参数 | 说明 |
|-------------|------|------|
| `onChatChange(chatJson)` | `Chat` 对象 | 完整聊天数据同步（初始加载 & 保存后重同步） |
| `onStateChange(stateJson)` | `AppState` 对象 | AI 生成状态变更 |
| `onMessageAdded(msgJson, index)` | `Message` + 插入位置 | 增量：新消息添加 |
| `onMessageUpdated(msgJson)` | `Message` | 增量：消息更新（按 `id` + `time` 匹配） |
| `onMessageRemoved(msgJson)` | `Message` | 增量：消息删除（按 `id` + `time` 匹配） |
| `onTokenAppend(token)` | `string` | 流式生成：单个 token 追加 |

#### 配置推送

| window 函数 | 参数 | 说明 |
|-------------|------|------|
| `onThemeChange(themeJson)` | `{ mode: "light" \| "dark" }` | 昼夜模式切换 |
| `onDisplaySettingsChange(json)` | `DisplaySettings` 对象 | 显示设置同步 |

#### 滚动控制

| window 函数 | 参数 | 说明 |
|-------------|------|------|
| `scrollToBottom()` | 无 | 强制滚动到列表底部 |
| `scrollToMessage(id)` | `number` | 滚动到指定消息 |

#### 订阅方法

```js
import appApi from './api/api.js'

// 完整聊天更新（初始加载 + 重同步）
appApi.subscribeChat((chat) => { /* Chat */ })

// AI 生成状态
appApi.subscribeState((state) => { /* AppState */ })

// 增量消息事件
appApi.subscribeMessageAdded(({ message, index }) => { /* message: Message, index: number */ })
appApi.subscribeMessageUpdated((message) => { /* Message */ })
appApi.subscribeMessageRemoved((message) => { /* Message */ })

// 流式 token
appApi.subscribeTokenAppend((token) => { /* string */ })

// 主题 & 显示设置
appApi.subscribeTheme((theme) => { /* { mode: "light" | "dark" } */ })
appApi.subscribeDisplaySettings((settings) => { /* DisplaySettings */ })

// 滚动指令
appApi.subscribeScrollToBottom(() => { /* 无参数 */ })
appApi.subscribeScrollToMessage((msgId) => { /* number */ })
```

### JS → Dart（主动请求）

#### 握手 & 数据获取

| 方法 | 说明 | 返回值 |
|------|------|--------|
| `appApi.notifyReady()` | 通知 Flutter JS 已就绪 | `Promise<void>` |
| `appApi.fetchChat()` | 手动重请求完整聊天数据（结果通过 `onChatChange` 回调返回） | `Promise<void>` |
| `appApi.fetchAllCharacters()` | 获取所有角色列表 | `Promise<Character[]>` |

#### 消息操作（均通过 `emitMessage` 通道）

| 方法 | 参数 | 说明 |
|------|------|------|
| `appApi.sendMessage(text, selectedPath?)` | `text: string`, `selectedPath: string[]` | 发送消息 |
| `appApi.retry(index?)` | `index: number`（默认 1） | 重新生成最后一条 AI 回复 |
| `appApi.interrupt()` | 无 | 中断当前 AI 生成 |
| `appApi.editMessage(time, newContent)` | `time: string (ISO)`, `newContent: string` | 编辑消息内容 |
| `appApi.deleteMessage(time)` | `time: string (ISO)` | 删除消息 |
| `appApi.copyMessage(text)` | `text: string` | 复制消息文本到系统剪贴板 |
| `appApi.switchAlternative(time, direction)` | `time: string (ISO)`, `direction: "left" \| "right"` | 切换备选回复版本 |
| `appApi.pasteMessages(time, position)` | `time: string (ISO)`, `position: "above" \| "below"` | 从剪贴板粘贴消息 |
| `appApi.addImageToMessage(time)` | `time: string (ISO)` | 给消息添加图片附件 |
| `appApi.createBranch(time)` | `time: string (ISO)` | 从该消息创建分支聊天 |
| `appApi.deleteAlternatives(time)` | `time: string (ISO)` | 删除所有备选回复 |
| `appApi.optimizeMessage(time)` | `time: string (ISO)` | 打开消息优化页面 |
| `appApi.messageMore(time)` | `time: string (ISO)` | 打开"更多操作"菜单（由 Flutter 弹出 BottomSheet） |
| `appApi.notifyScrollState(isNearBottom)` | `isNearBottom: boolean` | 通知 Flutter 当前是否接近底部 |

#### 生命周期说明

1. **启动**：Vue 应用挂载 → `fetchAllCharacters()` → `notifyReady()` → Flutter 推送初始数据（`onChatChange` + `onStateChange` + `onThemeChange` + `onDisplaySettingsChange`）
2. **排队机制**：JS 未就绪时 Flutter 侧会排队等待，`notifyReady` 后批量刷新，保证不丢数据
3. **超时兜底**：5 秒内 JS 未调用 `notifyReady`，Flutter 会强制推送

---

## 数据模型

### Message

```typescript
interface Message {
  id: number;            // 唯一 ID（微秒时间戳）
  content: string;       // 消息正文（Markdown）
  sender: number;        // 发送者 ID（0 = 用户）
  time: string;          // ISO 8601 时间戳
  type: string;          // 消息类型："common" | "narration" | "summary"
  role: string;          // 角色："user" | "assistant" | "system"
  token: number;         // Token 数量（通常为 0）
  visbility: string;     // 可见性："common" | "pinned" | "hidden"
  bookmark: string|null; // 书签文本
  resPath: string[];     // 附件文件路径
  alternativeContent: (string|null)[];  // 备选回复列表，null 表示当前选中版本
}
```

### Chat

```typescript
interface Chat {
  id: number;                      // 会话 ID
  name: string;                    // 会话名称
  avatar: string;                  // 头像路径
  lastMessage: string;             // 最后一条消息预览
  time: string;                    // 最后更新时间 (ISO)
  characterIds: number[];          // 关联角色 ID 列表
  messages: Message[];             // 消息列表
  userId: number|null;             // 用户 ID
  assistantId: number|null;        // 助手 ID
  mode: "auto" | "manual" | "group";  // 聊天模式
  bookmarks: any[];                // 书签列表
  chatVars: Record<string, any>;   // 聊天变量
  activitedLorebookItems: Record<string, any>;  // 激活的 World Book 条目
  needAutoTitle: boolean;          // 是否需要自动生成标题
  meta: Record<string, any>;       // 元数据
}
```

### AppState

```typescript
interface AppState {
  id: string;              // 状态 ID（固定 "_"）
  LLMBuffer?: string;      // AI 流式生成缓冲区（includeBuffer=false 时省略）
  GenerateState: string;   // 生成阶段描述文本
  isGenerating: boolean;   // 是否正在生成
  style: number;           // MessageStyle 枚举索引
  currentAssistant: number;// 当前正在回复的助手角色 ID
}
```

> **流式生成协议**：生成期间 `isGenerating=true` 时 `LLMBuffer` 不会携带在 `onStateChange` 中——文本通过 `onTokenAppend` 增量推送，JS 侧自行拼接。生成结束时 `isGenerating=false` 的推送会携带完整 `LLMBuffer` 用于最终调和。

### Character（来自 `fetchAllCharacters`）

```typescript
interface Character {
  id: number;              // 角色 ID
  nickname: string;        // 角色昵称
  avatar?: string;         // 头像路径
  backgroundImage?: string;// 背景图路径
  category?: string;       // 分类
  brief?: string;          // 简介
  archive?: string;        // 档案
  firstMessage?: string;   // 首条消息
  moreFirstMessage?: string[]; // 更多首条消息
  relations: Record<string, RelationInfo>; // 关系网
  messageStyle: string;    // 消息样式枚举
}
```

### DisplaySettings

```typescript
interface DisplaySettings {
  AvatarSize: number;             // 头像大小 (px)
  AvatarBorderRadius: number;     // 头像圆角 (px)
  avatarStyle: number;            // 0 = 圆形, 1 = 圆角, 2 = 隐藏
  ContentFontScale: number;       // 字体缩放倍数
  MessageBubbleBorderRadius: number; // 气泡圆角 (px)
  themeColor: number;             // 主题色（Flutter Color.value, 0xAARRGGBB）
  displayUserName: boolean;       // 是否显示用户名称
  displayAssistantName: boolean;  // 是否显示助手名称
  displayMessageDate: boolean;    // 是否显示消息时间
  tryParseInlineHtml: boolean;    // 是否尝试解析内联 HTML
  BackgroundImageOpacity: number; // 背景图不透明度
  BackgroundImageBlur: number;    // 背景图模糊度
}
```

> `themeColor` 是 Flutter 的 `Color.value`，格式为 `0xAARRGGBB`（如 Material Blue = `0xFF2196F3` = `4291552755`）。

---

## 主题系统

WebView 维护独立的 CSS 主题系统，不依赖 Flutter 的 Material 主题。

### 昼夜模式

Flutter 通过 `onThemeChange({ mode: "light" | "dark" })` 通知模式切换。`App.vue` 中的 `applyTheme()` 会在 `<html>` 元素上添加/移除 `.theme-dark` CSS 类。

```css
/* 默认 light 模式 */
:root {
  --bubble-bg-ai: #ffffff;
  --bubble-text-ai: #333333;
  /* ... */
}

/* dark 模式覆盖 */
html.theme-dark {
  --bubble-bg-ai: #2a2a2a;
  --bubble-text-ai: #e0e0e0;
  /* ... */
}
```

### 主题色 (Theme Color)

`themeColor` 来自 `DisplaySettings`，由 `applyDisplaySettings()` 解析为 CSS 自定义属性：

| CSS 变量 | 说明 |
|----------|------|
| `--theme-h`, `--theme-s`, `--theme-l` | 主题色的 HSL 分量 |
| `--theme-color` | 主题色 RGB 值 |
| `--theme-light` | 主题色提亮 30%（hover 状态背景） |
| `--theme-dark` | 主题色变暗 15%（active 状态） |

语义别名（在 `:root` 和 `html.theme-dark` 中分别定义）：

| CSS 变量 | 用途 |
|----------|------|
| `--link-color` | Markdown 链接颜色 |
| `--link-hover-color` | 链接 hover 颜色 |
| `--alt-indicator-color` | 备选回复版本指示器颜色 |
| `--toolbar-btn-hover-bg` | 工具栏按钮 hover 背景 |

### 在样式中使用

```css
/* 直接使用 */
.my-accent {
  color: var(--theme-color);
}

/* 使用语义别名（推荐） */
.markdown-body a {
  color: var(--link-color);
}
.markdown-body a:hover {
  color: var(--link-hover-color);
}

/* 使用 HSL 分量做精细调整 */
.custom-tint {
  background: hsl(var(--theme-h), var(--theme-s), 90%);
}
```

---

## 添加新功能

### 添加新的 Dart→JS 数据通道

1. 在 `api.js` 的 `listeners` 中添加新事件名
2. 在 `_bindWindowMethods()` 中绑定 `window.onNewEvent`
3. 添加对应的 `subscribeNewEvent(callback)` 方法
4. 在 `App.vue` 的 `onMounted` 中订阅

```js
// api.js — 以添加 "onFooChanged" 为例

// 1. listeners
this.listeners = {
  // ... existing ...
  onFooChanged: [],
};

// 2. _bindWindowMethods
window.onFooChanged = (data) => {
  this._notify('onFooChanged', this._safeParse(data));
};

// 3. subscribe
subscribeFooChanged(callback) {
  this.listeners.onFooChanged.push(callback);
}
```

### 添加新的 JS→Dart 请求

在 `api.js` 中新增方法，使用 `emitMessage` 通道（如需自定义 handler 则联系 Flutter 侧添加）：

```js
// api.js
doSomething(param1, param2) {
  this._callFlutter('emitMessage', {
    action: 'doSomething',
    data: { param1, param2 }
  });
}
```

如果 `action` 已知且需要 Flutter UI 交互（如弹窗、导航、系统剪贴板），走 `emitMessage` 的 `default` 分支会转发到 Flutter 的 `onMessageEmit` 回调——确保在 Flutter 侧 `chat_page.dart` 的 `_onWebviewMessageEmit()` 中添加对应的 `case` 处理。

### 添加新组件

遵循 Vue 3 Composition API 规范，在 `src/` 下按需创建子目录：

```
src/
├── components/
│   ├── MessageToolbar.vue    # 消息工具栏（可抽取）
│   └── ...
├── composables/
│   └── useScroll.js          # 滚动逻辑（可抽取）
└── ...
```

---

## 浏览器独立测试

当 Flutter 环境不可用时（如在桌面浏览器中直接打开 `http://localhost:5173`），BridgeAPI 的 `_callFlutter` 会打印警告并返回 rejected Promise。此时可以进行纯 UI 调试：

1. 打开浏览器控制台
2. 手动模拟数据推送：

```js
// 模拟 AI 状态
window.onStateChange({ id: '_', isGenerating: true, LLMBuffer: '', GenerateState: '正在生成...', currentAssistant: -1, style: 0 })

// 模拟 token 追加
window.onTokenAppend('你好，我是 AI 助手...')

// 模拟聊天数据
window.onChatChange({ id: 1, name: '测试聊天', messages: [], ... })
```

3. 使用 `window.appApi` 查看可用的 BridgeAPI 方法
4. 主题切换可直接操作 DOM：`document.documentElement.classList.toggle('theme-dark')`

> 注意：`imgs://` scheme 的图片加载仅在 Flutter WebView 环境中生效，浏览器中会加载失败。
