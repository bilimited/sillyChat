<template>
  <div class="app-container">
    <!-- 聊天滚动区域 -->
    <div class="chat-scroll-area" ref="scrollContainer" @scroll="onScroll">

      <!-- 消息列表 -->
      <div class="message-list">
        <div
          v-for="msg in displayMessages"
          :key="msg.id"
          class="message-item"
          :class="[
            msg.role === 'user' ? 'message-user' :
            msg.role === 'tool' ? 'message-tool' :
            'message-ai',
            msg.toolCalls && msg.toolCalls.length > 0 ? 'message-toolcall' : '',
            { 'message-selected': selectedMessage?.time === msg.time },
          ]"
          @click="toggleSelect(msg)"
        >
          <!-- 头像 -->
          <div class="avatar" v-if="showAvatar">
            <img :src="getAvatar(msg.sender)" alt="avatar" @error="handleImgError">
          </div>

          <!-- 消息气泡 -->
          <div class="bubble-wrapper">
            <!-- 发送者名字 -->
            <div class="sender-name" v-if="msg.role !== 'user' && showAssistantName">
              {{ getCharacterName(msg.sender) }}
            </div>

            <!-- 正在编辑此消息 → 行内编辑器 -->
            <template v-if="editingMessageTime === msg.time">
              <MessageEditor
                :message="msg"
                @save="onEditSave"
                @cancel="onEditCancel"
              />
            </template>

            <!-- 正常展示 -->
            <div v-else class="bubble">
              <!-- 工具结果消息：等宽字体紧凑显示 -->
              <template v-if="msg.role === 'tool'">
                <div class="tool-result-label">Tool Result</div>
                <div class="tool-result-content">{{ msg.content }}</div>
              </template>
              <!-- 工具调用卡片（assistant 消息包含 toolCalls 时） -->
              <template v-else>
                <div class="markdown-body" v-html="renderMarkdown(msg.content)"></div>
                <div v-if="msg.toolCalls && msg.toolCalls.length > 0" class="tool-calls-card">
                  <div class="tool-calls-label">Function Calls</div>
                  <div v-for="tc in msg.toolCalls" :key="tc.id" class="tool-call-item">
                    <span class="tool-icon">&#x1f6e0;</span>
                    <span class="tool-fn-name">{{ tc.functionName }}</span>
                    <span class="tool-args">({{ formatToolArgs(tc.arguments) }})</span>
                  </div>
                </div>
              </template>
            </div>

            <!-- 消息时间 -->
            <div class="time" v-if="showMessageTime">{{ formatTime(msg.time) }}</div>

            <!-- 消息底部工具栏 -->
            <div class="message-toolbar" v-if="selectedMessage?.time === msg.time" @click.stop>
              <button class="toolbar-btn" title="编辑" @click="onEdit(msg)">
                ✏️
              </button>
              <button class="toolbar-btn" title="复制" @click="onCopy(msg)">
                📋
              </button>
              <button class="toolbar-btn" title="删除" @click="onDelete(msg)">
                🗑️
              </button>
              <button
                v-if="isLastAssistantMessage(msg)"
                class="toolbar-btn"
                title="重试"
                @click="onRetry()"
              >
                🔄
              </button>
              <template v-if="msg.alternativeContent && msg.alternativeContent.length > 1">
                <span class="toolbar-divider"></span>
                <button class="toolbar-btn" title="上一版本" @click="onSwitchAlternative(msg, 'left')">
                  ◀
                </button>
                <span class="alternative-indicator">
                  {{ alternativeIndex(msg) + 1 }}/{{ msg.alternativeContent.length }}
                </span>
                <button class="toolbar-btn" title="下一版本" @click="onSwitchAlternative(msg, 'right')">
                  ▶
                </button>
              </template>
              <span class="toolbar-divider"></span>
              <button class="toolbar-btn" title="更多" @click="onMore(msg)">
                ⋯
              </button>
              <span class="char-count" v-if="msg.role === 'assistant'">{{ msg.content.length }}字</span>
            </div>
          </div>
        </div>

        <!-- 正在生成时的临时消息 (流式输出) -->
        <div v-if="appState.isGenerating" class="message-item message-ai generating">
           <div class="avatar" v-if="showAvatar">
            <img :src="getAvatar(appState.currentAssistant)" alt="avatar">
          </div>
          <div class="bubble-wrapper">
             <div class="sender-name" v-if="showAssistantName">{{ getCharacterName(appState.currentAssistant) }}</div>
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
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue';
import MarkdownIt from 'markdown-it';
import appApi from './api/api.js';
import MessageEditor from './components/MessageEditor.vue';

// --- Markdown Setup ---
const md = new MarkdownIt({
  html: false,
  xhtmlOut: false,
  breaks: true,
  linkify: true,
  typographer: true,
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
const selectedMessage = ref(null);
const editingMessageTime = ref(null);

// Display settings defaults
const displaySettings = ref({
  AvatarSize: 25,
  ContentFontScale: 1,
  MessageBubbleBorderRadius: 16,
  AvatarBorderRadius: 8,
  displayUserName: true,
  displayAssistantName: true,
  displayMessageDate: false,
  themeColor: 0xFF2196F3, // default Material blue
});

// DOM Ref
const scrollContainer = ref(null);

// --- Computed ---
const displayMessages = computed(() => chatData.value?.messages || []);

const showAvatar = computed(() => displaySettings.value.AvatarSize > 0);
const showAssistantName = computed(() => displaySettings.value.displayAssistantName);
const showMessageTime = computed(() => displaySettings.value.displayMessageDate);

const characterMap = computed(() => {
  const map = {};
  characters.value.forEach(c => map[c.id] = c);
  return map;
});

// --- Color utilities ---

/**
 * Parse a Flutter Color.value (0xAARRGGBB) into { r, g, b }.
 */
function parseFlutterColor(value) {
  const a = (value >> 24) & 0xFF;
  const r = (value >> 16) & 0xFF;
  const g = (value >> 8) & 0xFF;
  const b = value & 0xFF;
  return { r, g, b, a };
}

/**
 * Convert { r, g, b } to { h, s, l }.
 */
function rgbToHsl(r, g, b) {
  const rf = r / 255, gf = g / 255, bf = b / 255;
  const max = Math.max(rf, gf, bf), min = Math.min(rf, gf, bf);
  let h = 0, s = 0;
  const l = (max + min) / 2;

  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case rf: h = ((gf - bf) / d + (gf < bf ? 6 : 0)) / 6; break;
      case gf: h = ((bf - rf) / d + 2) / 6; break;
      case bf: h = ((rf - gf) / d + 4) / 6; break;
    }
  }

  return {
    h: Math.round(h * 360),
    s: Math.round(s * 100),
    l: Math.round(l * 100),
  };
}

// --- CSS Variable application ---

/**
 * Write dynamic theme accent variables to <html>.
 * Theme color comes from Flutter DisplaySettings.themeColor.
 */
function applyDisplaySettings(settings) {
  if (!settings) return;
  displaySettings.value = settings;

  const root = document.documentElement;
  root.style.setProperty('--avatar-size', (settings.AvatarSize || 25) + 'px');
  root.style.setProperty('--avatar-border-radius',
    (settings.avatarStyle === 0 ? '50%' : (settings.AvatarBorderRadius || 8) + 'px'));
  root.style.setProperty('--font-scale', (settings.ContentFontScale || 1));
  root.style.setProperty('--bubble-radius', (settings.MessageBubbleBorderRadius || 16) + 'px');

  // Parse themeColor and set accent CSS variables (used by tokens.css)
  const tc = settings.themeColor;
  if (tc !== undefined && tc !== null) {
    const { r, g, b } = parseFlutterColor(tc);
    const hsl = rgbToHsl(r, g, b);

    root.style.setProperty('--theme-h', hsl.h);
    root.style.setProperty('--theme-s', hsl.s + '%');
    root.style.setProperty('--theme-l', hsl.l + '%');
    root.style.setProperty('--theme-color', `rgb(${r},${g},${b})`);

    // Lighter variant (hover / subtle bg)
    const lightL = Math.min(hsl.l + 30, 88);
    root.style.setProperty('--theme-light-l', lightL + '%');
    root.style.setProperty('--theme-light', `hsl(${hsl.h},${hsl.s}%,${lightL}%)`);

    // Darker variant (active / pressed)
    const darkL = Math.max(hsl.l - 15, 15);
    root.style.setProperty('--theme-dark-l', darkL + '%');
    root.style.setProperty('--theme-dark', `hsl(${hsl.h},${hsl.s}%,${darkL}%)`);

    // Adaptive foreground (white on dark/saturated, dark on light)
    const fgL = hsl.l > 60 ? 15 : 95;
    root.style.setProperty('--theme-fg', `hsl(${hsl.h},${hsl.s}%,${fgL}%)`);
  }
}

/**
 * Toggle .theme-dark class on <html>.
 * This activates the dark-mode overrides in themes/tokens.css.
 */
function applyTheme(themeData) {
  if (!themeData) return;
  const mode = themeData.mode || 'light';
  if (mode === 'dark') {
    document.documentElement.classList.add('theme-dark');
  } else {
    document.documentElement.classList.remove('theme-dark');
  }
}

// --- Methods ---

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
  if (e.target.src !== 'https://via.placeholder.com/50') {
     e.target.src = 'https://via.placeholder.com/50';
  }
};

const formatTime = (isoTime) => {
  if (!isoTime) return '';
  const date = new Date(isoTime);
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};

// 格式化工具调用参数为可读字符串
const formatToolArgs = (argsStr) => {
  try {
    const parsed = JSON.parse(argsStr);
    return Object.entries(parsed).map(([k, v]) => `${k}: ${v}`).join(', ');
  } catch {
    return argsStr;
  }
};

// 检查是否是最后一条助手消息（含工具调用链中的消息）
const isLastAssistantMessage = (msg) => {
  if (!chatData.value || !msg) return false;
  const msgs = chatData.value.messages;
  if (msgs.length === 0) return false;
  const last = msgs[msgs.length - 1];
  return last.id === msg.id &&
    (msg.role === 'assistant' || msg.role === 'tool');
};

// 备选文本当前索引
const alternativeIndex = (msg) => {
  if (!msg.alternativeContent) return 0;
  return msg.alternativeContent.findIndex(e => e === null);
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

// 辅助：检查是否在底部
const isNearBottom = (el) => {
  return el.scrollHeight - el.scrollTop - el.clientHeight < 50;
};

// --- Message selection & toolbar ---
const toggleSelect = (msg) => {
  // Cancel editing if clicking elsewhere
  if (editingMessageTime.value && editingMessageTime.value !== msg.time) {
    editingMessageTime.value = null;
  }
  if (selectedMessage.value?.time === msg.time) {
    selectedMessage.value = null;
  } else {
    selectedMessage.value = msg;
  }
};

// --- Inline editing ---
const onEdit = (msg) => {
  editingMessageTime.value = msg.time;
  selectedMessage.value = null;
};

const onEditSave = (newContent) => {
  const msg = displayMessages.value.find(m => m.time === editingMessageTime.value);
  if (msg && newContent !== msg.content) {
    appApi.editMessage(msg.time, newContent);
  }
  editingMessageTime.value = null;
};

const onEditCancel = () => {
  editingMessageTime.value = null;
};

// --- Other toolbar actions ---
const onCopy = (msg) => {
  appApi.copyMessage(msg.content);
  selectedMessage.value = null;
};

const onDelete = (msg) => {
  if (confirm('确定要删除这条消息吗？')) {
    appApi.deleteMessage(msg.time);
  }
  selectedMessage.value = null;
};

const onRetry = () => {
  appApi.retry(1);
  selectedMessage.value = null;
};

const onSwitchAlternative = (msg, direction) => {
  appApi.switchAlternative(msg.time, direction);
};

const onMore = (msg) => {
  // Opens Flutter BottomSheet via onMessageEmit callback
  appApi.messageMore(msg.time);
  selectedMessage.value = null;
};

// --- Scroll listener ---
let scrollDebounceTimer = null;
const onScroll = () => {
  if (!scrollContainer.value) return;
  if (scrollDebounceTimer) clearTimeout(scrollDebounceTimer);
  scrollDebounceTimer = setTimeout(() => {
    const near = isNearBottom(scrollContainer.value);
    appApi.notifyScrollState(near);
  }, 150);
};

// --- Perform scroll to bottom ---
const doScrollToBottom = () => {
  if (!scrollContainer.value) return;
  scrollContainer.value.scrollTop = scrollContainer.value.scrollHeight;
};

// --- Perform scroll to specific message ---
const doScrollToMessage = (msgId) => {
  if (!scrollContainer.value) return;
  const target = scrollContainer.value.querySelector(`[data-msg-id="${msgId}"]`);
  if (target) {
    target.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
};

// --- Lifecycle ---

onMounted(() => {
  // 1. Subscribe to full chat updates
  appApi.subscribeChat((newChat) => {
    // Full re-sync cancels any in-progress edit
    editingMessageTime.value = null;
    handleScrollPreservation(() => {
      chatData.value = newChat;
      appState.value = { ...appState.value, LLMBuffer: '' };
    });
  });

  // 2. Subscribe to state updates
  appApi.subscribeState((newState) => {
    const el = scrollContainer.value;
    const atBottom = el ? isNearBottom(el) : false;

    if (newState.isGenerating) {
      appState.value = {
        ...appState.value,
        LLMBuffer: (newState.LLMBuffer !== undefined && appState.value.LLMBuffer === '')
          ? newState.LLMBuffer
          : appState.value.LLMBuffer,
        GenerateState: newState.GenerateState,
        isGenerating: newState.isGenerating,
        currentAssistant: newState.currentAssistant,
        style: newState.style,
      };
    } else {
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

  // 3. Subscribe to incremental message events
  appApi.subscribeMessageAdded(({ message, index }) => {
    if (!chatData.value) return;
    handleScrollPreservation(() => {
      const messages = [...chatData.value.messages];
      messages.splice(index, 0, message);
      chatData.value = { ...chatData.value, messages };
    });
  });

  appApi.subscribeMessageUpdated((updatedMessage) => {
    if (!chatData.value) return;
    // If the updated message is currently being edited, cancel the edit
    if (editingMessageTime.value === updatedMessage.time) {
      editingMessageTime.value = null;
    }
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

  // 4. Subscribe to streaming token append
  appApi.subscribeTokenAppend((token) => {
    if (appState.value.isGenerating) {
      appState.value = {
        ...appState.value,
        LLMBuffer: appState.value.LLMBuffer + token
      };
      const el = scrollContainer.value;
      if (el) {
        const atBottom = isNearBottom(el);
        if (atBottom) {
          nextTick(() => { if(el) el.scrollTop = el.scrollHeight; });
        }
      }
    }
  });

  // 5. Subscribe to theme changes
  appApi.subscribeTheme((themeData) => {
    applyTheme(themeData);
  });

  // 6. Subscribe to display settings changes
  appApi.subscribeDisplaySettings((settings) => {
    applyDisplaySettings(settings);
  });

  // 7. Subscribe to scroll control
  appApi.subscribeScrollToBottom(() => {
    nextTick(() => doScrollToBottom());
  });

  appApi.subscribeScrollToMessage((msgId) => {
    nextTick(() => doScrollToMessage(msgId));
  });

  // 8. Initialize: fetch characters then notify Dart
  const initData = () => {
    console.log('Flutter Platform Ready');
    appApi.fetchAllCharacters().then((chars) => {
      characters.value = chars || [];
      appApi.notifyReady();
    });
  };

  if (window.flutter_inappwebview) {
    initData();
  } else {
    window.addEventListener('flutterInAppWebViewPlatformReady', initData);
  }
});

onUnmounted(() => {
  if (scrollDebounceTimer) clearTimeout(scrollDebounceTimer);
});
</script>

<style scoped>
/* ==========================================================================
   Component Styles — App.vue
   Theme tokens (CSS custom properties) are in themes/tokens.css.
   ========================================================================== */

.app-container {
  display: flex;
  flex-direction: column;
  height: 100vh;
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

/* ---- Message layout ---- */
.message-item {
  display: flex;
  align-items: flex-start;
  max-width: 100%;
  cursor: pointer;
  border-radius: 8px;
  transition: background-color 0.15s;
}

.message-item.message-selected {
  /* Subtle selection feedback — the toolbar is the primary indicator */
}

.avatar {
  width: var(--avatar-size);
  height: var(--avatar-size);
  border-radius: var(--avatar-border-radius);
  overflow: hidden;
  flex-shrink: 0;
  background-color: var(--avatar-bg);
  box-shadow: 0 2px 4px var(--bubble-shadow);
}

.avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.bubble-wrapper {
  display: flex;
  flex-direction: column;
  max-width: 80%;
}

.sender-name {
  font-size: calc(12px * var(--font-scale));
  color: var(--sender-name-color);
  margin-bottom: 4px;
  margin-left: 4px;
}

.bubble {
  text-align: left;
  padding: 8px 14px;
  border-radius: var(--bubble-radius);
  font-size: calc(15px * var(--font-scale));
  position: relative;
  box-shadow: 0 1px 2px var(--bubble-shadow);
  overflow: hidden;
}

.time {
  font-size: calc(10px * var(--font-scale));
  color: var(--time-color);
  margin-top: 4px;
  margin-left: 4px;
}

/* ---- AI message ---- */
.message-ai {
  flex-direction: row;
}
.message-ai .bubble-wrapper {
  align-items: flex-start;
  margin-left: 10px;
}
.message-ai .bubble {
  background-color: var(--bubble-bg-ai);
  color: var(--bubble-text-ai);
  border-top-left-radius: 2px;
}

/* ---- User message — uses theme-derived bubble colors ---- */
.message-user {
  flex-direction: row-reverse;
}
.message-user .bubble-wrapper {
  align-items: flex-end;
  margin-right: 10px;
}
.message-user .bubble {
  background-color: var(--bubble-bg-user);
  color: var(--bubble-text-user);
  border-top-right-radius: 2px;
}

/* ---- Status text (streaming) ---- */
.status-text {
  font-size: calc(10px * var(--font-scale));
  color: var(--status-text-color);
  margin-top: 2px;
}

/* ---- Streaming cursor ---- */
.cursor {
  display: inline-block;
  font-weight: bold;
  color: var(--theme-color);
  margin-left: 2px;
  animation: blink 1s step-end infinite;
}

@keyframes blink {
  0%, 100% { opacity: 1; }
  50% { opacity: 0; }
}

/* ---- Message toolbar ---- */
.message-toolbar {
  display: flex;
  align-items: center;
  gap: 2px;
  margin-top: 6px;
  padding: 4px 8px;
  background-color: var(--toolbar-bg);
  border: 1px solid var(--toolbar-border);
  border-radius: 10px;
  box-shadow: 0 2px 8px var(--bubble-shadow);
  white-space: nowrap;
  /* Animate in */
  animation: toolbar-in 0.15s ease-out;
}

@keyframes toolbar-in {
  from { opacity: 0; transform: translateY(-4px); }
  to   { opacity: 1; transform: translateY(0); }
}

.message-ai .message-toolbar {
  align-self: flex-start;
}

.message-user .message-toolbar {
  align-self: flex-end;
}

.toolbar-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  padding: 0;
  border: none;
  background: transparent;
  border-radius: 6px;
  cursor: pointer;
  font-size: 14px;
  color: var(--toolbar-text);
  transition: background-color 0.15s;
}
.toolbar-btn:hover {
  background-color: var(--toolbar-btn-hover-bg);
}
.toolbar-btn:active {
  background-color: rgba(128,128,128,0.35);
}

.toolbar-divider {
  width: 1px;
  height: 18px;
  background-color: var(--toolbar-border);
  margin: 0 4px;
}

.alternative-indicator {
  font-size: 11px;
  font-weight: bold;
  color: var(--alt-indicator-color);
  min-width: 28px;
  text-align: center;
}

.char-count {
  font-size: 10px;
  color: var(--time-color);
  margin-left: 4px;
}

/* ---- Markdown rendered content (deep styles) ---- */
:deep(.markdown-body) {
  line-height: 1.6;
  font-size: calc(15px * var(--font-scale));
  word-wrap: break-word;
}

:deep(.markdown-body > *:first-child) {
  margin-top: 0;
}
:deep(.markdown-body > *:last-child) {
  margin-bottom: 0;
}

:deep(.markdown-body p) {
  margin: 0.5em 0;
}

:deep(.markdown-body a) {
  color: var(--link-color);
  text-decoration: none;
}
:deep(.markdown-body a:hover) {
  color: var(--link-hover-color);
  text-decoration: underline;
}

:deep(.markdown-body ul),
:deep(.markdown-body ol) {
  padding-left: 20px;
  margin: 0.5em 0;
}

:deep(.markdown-body pre) {
  background-color: var(--code-bg);
  border-radius: 6px;
  padding: 10px;
  overflow-x: auto;
  margin: 0.5em 0;
  border: 1px solid var(--code-border);
}

:deep(.markdown-body code) {
  font-family: Consolas, Monaco, "Andale Mono", monospace;
  font-size: 0.9em;
}

:deep(.markdown-body :not(pre) > code) {
  background-color: var(--inline-code-bg);
  padding: 0.2em 0.4em;
  border-radius: 3px;
}

:deep(.markdown-body blockquote) {
  margin: 0.5em 0;
  padding-left: 10px;
  border-left: 3px solid var(--blockquote-border);
  color: var(--blockquote-color);
}

:deep(.markdown-body img) {
  max-width: 100%;
  height: auto;
  border-radius: 4px;
  margin: 0.5em 0;
}

/* ---- Inline editor integration ---- */
.message-ai .inline-editor {
  max-width: 100%;
}

.message-user .inline-editor {
  max-width: 100%;
}

/* ---- Tool message (role: tool) ---- */
.message-tool {
  flex-direction: row;
}
.message-tool .bubble-wrapper {
  align-items: flex-start;
  margin-left: 10px;
}
.message-tool .bubble {
  background-color: var(--bubble-bg-tool, rgba(128,128,128,0.08));
  color: var(--bubble-text-tool);
  border-left: 3px solid var(--tool-accent, #9e9e9e);
  border-top-left-radius: 2px;
  font-family: 'Consolas', 'Monaco', monospace;
  font-size: calc(12px * var(--font-scale));
  padding: 8px 12px;
}

.tool-result-label {
  font-size: 10px;
  font-weight: 600;
  color: var(--time-color);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 4px;
}

.tool-result-content {
  white-space: pre-wrap;
  word-break: break-word;
  color: var(--tool-content-color);
}

/* ---- Tool calls card inside assistant message ---- */
.tool-calls-card {
  margin-top: 8px;
  padding: 6px 10px;
  background: var(--toolcall-bg, rgba(var(--theme-r, 66), var(--theme-g, 133), var(--theme-b, 244), 0.08));
  border-radius: 6px;
  border: 1px solid var(--toolcall-border, rgba(var(--theme-r, 66), var(--theme-g, 133), var(--theme-b, 244), 0.2));
}

.tool-calls-label {
  font-size: 10px;
  font-weight: 600;
  color: var(--time-color);
  text-transform: uppercase;
  margin-bottom: 4px;
}

.tool-call-item {
  font-size: 11px;
  font-family: 'Consolas', 'Monaco', monospace;
  padding: 1px 0;
  color: var(--toolcall-text);
}

.tool-fn-name {
  font-weight: 600;
}

.tool-args {
  color: var(--toolcall-args-color);
  font-size: 10px;
}

.message-tool .message-toolbar {
  align-self: flex-start;
}
</style>
