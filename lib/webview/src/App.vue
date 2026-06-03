<template>
  <div class="app-container">
    <!-- 顶部预留 AppBar 空间 -->
    <!-- <div class="app-bar-spacer"></div> -->

    <!-- 聊天滚动区域 -->
    <div class="chat-scroll-area" ref="scrollContainer">

      <!-- 消息列表 -->
      <div class="message-list">
        <div
          v-for="msg in displayMessages"
          :key="msg.id"
          class="message-item"
          :class="msg.role === 'user' ? 'message-user' : 'message-ai'"
        >
          <!-- 头像 -->
          <div class="avatar">
            <img :src="getAvatar(msg.sender)" alt="avatar" @error="handleImgError">
          </div>

          <!-- 消息气泡 -->
          <div class="bubble-wrapper">
            <!-- 发送者名字 -->
            <div class="sender-name" v-if="msg.role !== 'user'">
              {{ getCharacterName(msg.sender) }}
            </div>

            <div class="bubble">
              <!-- Markdown 渲染 -->
              <div class="markdown-body" v-html="renderMarkdown(msg.content)"></div>
            </div>

            <!-- 消息时间 -->
            <div class="time">{{ formatTime(msg.time) }}</div>
          </div>
        </div>

        <!-- 正在生成时的临时消息 (流式输出) -->
        <div v-if="appState.isGenerating" class="message-item message-ai generating">
           <div class="avatar">
            <img :src="getAvatar(appState.currentAssistant)" alt="avatar">
          </div>
          <div class="bubble-wrapper">
             <div class="sender-name">{{ getCharacterName(appState.currentAssistant) }}</div>
             <div class="bubble">
               <!-- 流式 Markdown 渲染 -->
               <div class="markdown-body streaming-content">
                 <span v-html="renderMarkdown(appState.LLMBuffer)"></span>
                 <span class="cursor">|</span>
               </div>
             </div>
             <div class="status-text">{{ appState.GenerateState }}</div>
          </div>
        </div>
      </div>

      <!-- 底部垫高 -->
      <div class="bottom-spacer"></div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue';
import MarkdownIt from 'markdown-it';
import appApi from './api/api.js';

// --- Markdown Setup ---
const md = new MarkdownIt({
  html: false,        // 禁用 HTML 标签以防 XSS (如果信任数据源可开启)
  xhtmlOut: false,    // 使用 '/' 关闭单标签 (<br />).
  breaks: true,       // 将换行符转换为 <br>
  linkify: true,      // 自动链接 URL
  typographer: true,  // 启用一些语言中立的替换 + 引号美化
});

// --- State ---
const chatData = ref(null);
const characters = ref([]);
const appState = ref({
  isGenerating: false,
  LLMBuffer: '',
  GenerateState: '',
  currentAssistant: -1
});

// DOM Ref
const scrollContainer = ref(null);

// --- Computed ---
const displayMessages = computed(() => chatData.value?.messages || []);

const characterMap = computed(() => {
  const map = {};
  characters.value.forEach(c => map[c.id] = c);
  return map;
});

// --- Methods ---

// 渲染 Markdown
const renderMarkdown = (text) => {
  if (!text) return '';
  return md.render(text);
};

const getAvatar = (senderId) => {

  const char = characterMap.value[senderId];
  if (char && char.avatar) return `imgs:///${char.avatar}`;

  if (senderId === -1 && chatData.value?.avatar) return chatData.value.avatar;

  return 'imgs:///default_avatar.png';
};

const getCharacterName = (senderId) => {
  if (senderId === 0) return 'Me';
  const char = characterMap.value[senderId];
  return char ? (char.nickname || char.name) : 'Assistant';
};

const handleImgError = (e) => {
  // 避免无限循环
  if (e.target.src !== 'https://via.placeholder.com/50') {
     e.target.src = 'https://via.placeholder.com/50';
  }
};

const formatTime = (isoTime) => {
  if (!isoTime) return '';
  const date = new Date(isoTime);
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};

// 滚动保持逻辑
const handleScrollPreservation = async (updateAction) => {
  if (!scrollContainer.value) {
    updateAction();
    return;
  }
  const el = scrollContainer.value;
  const previousScrollTop = el.scrollTop;

  updateAction();

  await nextTick();
  el.scrollTop = previousScrollTop;
};

// 辅助：检查是否在底部（用于流式输出自动跟随）
const isNearBottom = (el) => {
  return el.scrollHeight - el.scrollTop - el.clientHeight < 50;
};

// --- Lifecycle ---

onMounted(() => {
  // 1. 订阅完整聊天更新（初始加载 + 重同步）
  appApi.subscribeChat((newChat) => {
    handleScrollPreservation(() => {
      chatData.value = newChat;
      // 首次加载后重置流式缓冲区
      appState.value = { ...appState.value, LLMBuffer: '' };
    });
  });

  // 2. 订阅状态更新
  //    流式期间：metadata-only（不含 LLMBuffer），内容由 onTokenAppend 管理
  //    流式结束后：包含完整 LLMBuffer，用于最终调和
  appApi.subscribeState((newState) => {
    const el = scrollContainer.value;
    const atBottom = el ? isNearBottom(el) : false;

    if (newState.isGenerating) {
      // Metadata-only during streaming — merge, keep incrementally-built LLMBuffer
      appState.value = {
        ...appState.value,
        // 只在初始状态推送或恢复推送时用传入的 buffer
        LLMBuffer: (newState.LLMBuffer !== undefined && appState.value.LLMBuffer === '')
          ? newState.LLMBuffer
          : appState.value.LLMBuffer,
        GenerateState: newState.GenerateState,
        isGenerating: newState.isGenerating,
        currentAssistant: newState.currentAssistant,
        style: newState.style,
      };
    } else {
      // Generation ended — full reconciliation with complete buffer
      appState.value = {
        ...appState.value,
        LLMBuffer: newState.LLMBuffer ?? '',
        GenerateState: newState.GenerateState,
        isGenerating: false,
        currentAssistant: newState.currentAssistant,
        style: newState.style,
      };
    }

    if (atBottom && appState.value.isGenerating) {
      nextTick(() => { if(el) el.scrollTop = el.scrollHeight; });
    }
  });

  // 3. 订阅增量消息事件 (P1)
  appApi.subscribeMessageAdded(({ message, index }) => {
    if (!chatData.value) return;
    handleScrollPreservation(() => {
      const messages = [...chatData.value.messages];
      // 使用 splice 按指定索引插入，保持响应式
      messages.splice(index, 0, message);
      chatData.value = { ...chatData.value, messages };
    });
  });

  appApi.subscribeMessageUpdated((updatedMessage) => {
    if (!chatData.value) return;
    handleScrollPreservation(() => {
      const messages = chatData.value.messages.map(
        m => (m.id === updatedMessage.id && m.time === updatedMessage.time)
          ? updatedMessage
          : m
      );
      chatData.value = { ...chatData.value, messages };
    });
  });

  appApi.subscribeMessageRemoved((removedMessage) => {
    if (!chatData.value) return;
    handleScrollPreservation(() => {
      const messages = chatData.value.messages.filter(
        m => !(m.id === removedMessage.id && m.time === removedMessage.time)
      );
      chatData.value = { ...chatData.value, messages };
    });
  });

  // 4. 订阅流式 token 追加 (P1)
  appApi.subscribeTokenAppend((token) => {
    if (appState.value.isGenerating) {
      appState.value = {
        ...appState.value,
        LLMBuffer: appState.value.LLMBuffer + token
      };
      // 自动跟随滚动
      const el = scrollContainer.value;
      if (el) {
        const atBottom = isNearBottom(el);
        if (atBottom) {
          nextTick(() => { if(el) el.scrollTop = el.scrollHeight; });
        }
      }
    }
  });

  // 5. 初始化：获取角色列表后通知 Dart 就绪
  const initData = () => {
    console.log('Flutter Platform Ready');
    appApi.fetchAllCharacters().then((chars) => {
      characters.value = chars || [];
      // 通知 Dart：JS 已就绪，Dart 会主动推送初始聊天数据和状态
      appApi.notifyReady();
    });
  };

  if (window.flutter_inappwebview) {
    initData();
  } else {
    window.addEventListener('flutterInAppWebViewPlatformReady', initData);
  }
});
</script>

<style>
/* 全局设置 */
html, body, #app {
  margin: 0;
  padding: 0;
  width: 100%;
  height: 100%;
  background-color: transparent !important;
  overflow: hidden;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
}
</style>

<style scoped>
.app-container {
  display: flex;
  flex-direction: column;
  height: 100vh;
}

.app-bar-spacer {
  height: var(--app-bar-height, 80px);
  flex-shrink: 0;
}

.chat-scroll-area {
  flex: 1;
  overflow-y: auto;
  padding: 0 16px;
  scrollbar-width: none;
}
.chat-scroll-area::-webkit-scrollbar {
  display: none;
}

.message-list {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding-bottom: 20px;
}

.bottom-spacer {
  height: 20px;
}

/* 消息布局 */
.message-item {
  display: flex;
  align-items: flex-start;
  max-width: 100%;
}

.avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
  background-color: #ddd;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.bubble-wrapper {
  display: flex;
  flex-direction: column;
  max-width: 80%; /* 稍微加宽以容纳代码块 */
}

.sender-name {
  font-size: 12px;
  color: #555;
  margin-bottom: 4px;
  margin-left: 4px;
}

.bubble {
  text-align: left;
  padding: 8px 14px; /* 稍微减少上下padding，交给 markdown 元素控制 */
  border-radius: 12px;
  font-size: 15px;
  position: relative;
  box-shadow: 0 1px 2px rgba(0,0,0,0.1);
  overflow: hidden; /* 防止内容（如大图或代码）溢出圆角 */
}

.time {
  font-size: 10px;
  color: #888;
  margin-top: 4px;
  margin-left: 4px;
}

/* AI 样式 */
.message-ai {
  flex-direction: row;
}
.message-ai .bubble-wrapper {
  align-items: flex-start;
  margin-left: 10px;
}
.message-ai .bubble {
  background-color: #ffffff;
  color: #333;
  border-top-left-radius: 2px;
}

/* User 样式 */
.message-user {
  flex-direction: row-reverse;
}
.message-user .bubble-wrapper {
  align-items: flex-end;
  margin-right: 10px;
}
.message-user .bubble {
  background-color: #95ec69;
  color: #000;
  border-top-right-radius: 2px;
}

/* 状态文本 */
.status-text {
  font-size: 10px;
  color: #999;
  margin-top: 2px;
}

/* 光标 */
.cursor {
  display: inline-block;
  font-weight: bold;
  color: #333;
  margin-left: 2px;
  animation: blink 1s step-end infinite;
}

@keyframes blink {
  0%, 100% { opacity: 1; }
  50% { opacity: 0; }
}

/* --- Markdown Styles (Scoped Deep) --- */
/* 使用 :deep() 因为 v-html 渲染的内容不会自动应用 scoped 样式 */

:deep(.markdown-body) {
  line-height: 1.6;
  font-size: 15px;
  word-wrap: break-word;
}

/* 去除首尾元素的 margin，完美适配气泡 */
:deep(.markdown-body > *:first-child) {
  margin-top: 0;
}
:deep(.markdown-body > *:last-child) {
  margin-bottom: 0;
}

:deep(.markdown-body p) {
  margin: 0.5em 0;
}

/* 链接样式 */
:deep(.markdown-body a) {
  color: #007bff;
  text-decoration: none;
}
:deep(.markdown-body a:hover) {
  text-decoration: underline;
}

/* 列表样式 */
:deep(.markdown-body ul),
:deep(.markdown-body ol) {
  padding-left: 20px;
  margin: 0.5em 0;
}

/* 代码块样式 */
:deep(.markdown-body pre) {
  background-color: #f6f8fa;
  border-radius: 6px;
  padding: 10px;
  overflow-x: auto; /* 允许横向滚动 */
  margin: 0.5em 0;
  border: 1px solid #e1e4e8;
}
/* 针对 User 绿色气泡的代码块微调，使其不那么突兀 */
.message-user :deep(.markdown-body pre) {
  background-color: rgba(0,0,0,0.05);
  border-color: rgba(0,0,0,0.1);
}

:deep(.markdown-body code) {
  font-family: Consolas, Monaco, "Andale Mono", monospace;
  font-size: 0.9em;
}

/* 行内代码 */
:deep(.markdown-body :not(pre) > code) {
  background-color: rgba(27,31,35,0.05);
  padding: 0.2em 0.4em;
  border-radius: 3px;
}
.message-user :deep(.markdown-body :not(pre) > code) {
  background-color: rgba(0,0,0,0.1); /* 在绿色背景下深一点 */
}

/* 引用块 */
:deep(.markdown-body blockquote) {
  margin: 0.5em 0;
  padding-left: 10px;
  border-left: 3px solid #dfe2e5;
  color: #6a737d;
}
.message-user :deep(.markdown-body blockquote) {
  border-left-color: rgba(0,0,0,0.2);
  color: rgba(0,0,0,0.6);
}

/* 图片最大宽度限制 */
:deep(.markdown-body img) {
  max-width: 100%;
  height: auto;
  border-radius: 4px;
  margin: 0.5em 0;
}
</style>
