<template>
  <div class="app-container">
    <DynamicScroller
      ref="scroller"
      :items="displayMessages"
      :min-item-size="60"
      key-field="id"
      class="chat-scroll-area"
      :prerender="20"
      :buffer="600"
      @scroll="onScroll"
    >
      <template #default="{ item, active }">
        <DynamicScrollerItem
          :item="item"
          :active="active"
          :data-msg-id="item.id"
        >
          <div class="msg-row">
            <ChatMessage
            :message="item"
            :isUser="item.role === 'user'"
            :isSelected="selectedMessage?.time === item.time"
            :isEditing="editingMessageTime === item.time"
            :showAvatar="showAvatar"
            :showAssistantName="showAssistantName"
            :showMessageTime="showMessageTime"
            :avatarSrc="getAvatar(item.sender)"
            :senderName="getCharacterName(item.sender)"
            :isLastAssistant="isLastAssistantMessage(item)"
            :alternativeIndex="alternativeIndex(item)"
            @select="toggleSelect(item)"
            @edit="onEdit(item)"
            @editSave="(content) => onEditSave(item, content)"
            @editCancel="onEditCancel"
            @copy="onCopy(item)"
            @delete="onDelete(item)"
            @retry="onRetry"
            @switchAlt="(dir) => onSwitchAlternative(item, dir)"
            @more="onMore(item)"
          />
          </div>
        </DynamicScrollerItem>
      </template>
    </DynamicScroller>

    <div v-if="appState.isGenerating" class="streaming-wrapper">
      <StreamingMessage
        :buffer="appState.LLMBuffer"
        :statusText="appState.GenerateState"
        :avatarSrc="getAvatar(appState.currentAssistant)"
        :showAvatar="showAvatar"
        :showAssistantName="showAssistantName"
        :assistantName="getCharacterName(appState.currentAssistant)"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue';
import appApi from './api/api.js';
import ChatMessage from './components/ChatMessage.vue';
import StreamingMessage from './components/StreamingMessage.vue';

// --- State ---
const chatData = ref(null);
const characters = ref([]);
const appState = ref({
  isGenerating: false,
  LLMBuffer: '',
  GenerateState: '',
  currentAssistant: -1,
});
const selectedMessage = ref(null);
const editingMessageTime = ref(null);

const displaySettings = ref({
  AvatarSize: 25,
  ContentFontScale: 1,
  MessageBubbleBorderRadius: 16,
  AvatarBorderRadius: 8,
  displayUserName: true,
  displayAssistantName: true,
  displayMessageDate: false,
  themeColor: 0xFF2196F3,
});

// DOM Ref
const scroller = ref(null);

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

function parseFlutterColor(value) {
  const a = (value >> 24) & 0xFF;
  const r = (value >> 16) & 0xFF;
  const g = (value >> 8) & 0xFF;
  const b = value & 0xFF;
  return { r, g, b, a };
}

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

function applyDisplaySettings(settings) {
  if (!settings) return;
  displaySettings.value = settings;

  const root = document.documentElement;
  root.style.setProperty('--avatar-size', (settings.AvatarSize || 25) + 'px');
  root.style.setProperty('--avatar-border-radius',
    (settings.avatarStyle === 0 ? '50%' : (settings.AvatarBorderRadius || 8) + 'px'));
  root.style.setProperty('--font-scale', (settings.ContentFontScale || 1));
  root.style.setProperty('--bubble-radius', (settings.MessageBubbleBorderRadius || 16) + 'px');

  const tc = settings.themeColor;
  if (tc !== undefined && tc !== null) {
    const { r, g, b } = parseFlutterColor(tc);
    const hsl = rgbToHsl(r, g, b);

    root.style.setProperty('--theme-h', hsl.h);
    root.style.setProperty('--theme-s', hsl.s + '%');
    root.style.setProperty('--theme-l', hsl.l + '%');
    root.style.setProperty('--theme-color', `rgb(${r},${g},${b})`);

    const lightL = Math.min(hsl.l + 30, 88);
    root.style.setProperty('--theme-light-l', lightL + '%');
    root.style.setProperty('--theme-light', `hsl(${hsl.h},${hsl.s}%,${lightL}%)`);

    const darkL = Math.max(hsl.l - 15, 15);
    root.style.setProperty('--theme-dark-l', darkL + '%');
    root.style.setProperty('--theme-dark', `hsl(${hsl.h},${hsl.s}%,${darkL}%)`);

    const fgL = hsl.l > 60 ? 15 : 95;
    root.style.setProperty('--theme-fg', `hsl(${hsl.h},${hsl.s}%,${fgL}%)`);
  }
}

function applyTheme(themeData) {
  if (!themeData) return;
  const mode = themeData.mode || 'light';
  if (mode === 'dark') {
    document.documentElement.classList.add('theme-dark');
  } else {
    document.documentElement.classList.remove('theme-dark');
  }
}

// --- Helpers ---

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

const isLastAssistantMessage = (msg) => {
  if (!chatData.value || !msg) return false;
  const msgs = chatData.value.messages;
  if (msgs.length === 0) return false;
  return msgs[msgs.length - 1].id === msg.id && msg.role === 'assistant';
};

const alternativeIndex = (msg) => {
  if (!msg.alternativeContent) return 0;
  return msg.alternativeContent.findIndex(e => e === null);
};

// --- Scroll helpers ---

const getScrollEl = () => scroller.value?.$el;

const isNearBottom = (el) => {
  return el.scrollHeight - el.scrollTop - el.clientHeight < 50;
};

const doScrollToBottom = () => {
  const el = getScrollEl();
  if (!el) return;
  el.scrollTop = el.scrollHeight;
  // Re-apply after a frame in case the scroller is still measuring heights
  requestAnimationFrame(() => {
    const el2 = getScrollEl();
    if (el2) el2.scrollTop = el2.scrollHeight;
  });
};

const doScrollToMessage = (msgId) => {
  if (!scroller.value) return;
  scroller.value.scrollToItem(msgId);
};

// --- Message selection & toolbar ---

const toggleSelect = (msg) => {
  if (editingMessageTime.value && editingMessageTime.value !== msg.time) {
    editingMessageTime.value = null;
  }
  if (selectedMessage.value?.time === msg.time) {
    selectedMessage.value = null;
  } else {
    selectedMessage.value = msg;
  }
};

const onEdit = (msg) => {
  editingMessageTime.value = msg.time;
  selectedMessage.value = null;
};

const onEditSave = (msg, newContent) => {
  if (newContent !== msg.content) {
    appApi.editMessage(msg.time, newContent);
  }
  editingMessageTime.value = null;
};

const onEditCancel = () => {
  editingMessageTime.value = null;
};

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
  appApi.messageMore(msg.time);
  selectedMessage.value = null;
};

// --- Scroll listener ---

let scrollDebounceTimer = null;
const onScroll = () => {
  const el = getScrollEl();
  if (!el) return;
  if (scrollDebounceTimer) clearTimeout(scrollDebounceTimer);
  scrollDebounceTimer = setTimeout(() => {
    const near = isNearBottom(el);
    appApi.notifyScrollState(near);
  }, 150);
};

// --- Lifecycle ---

onMounted(() => {
  appApi.subscribeChat((newChat) => {
    const chatChanged = !chatData.value || chatData.value.id !== newChat.id;
    editingMessageTime.value = null;
    chatData.value = newChat;
    appState.value = { ...appState.value, LLMBuffer: '' };

    // Scroll to bottom when entering a new chat.
    // Double rAF: the DynamicScroller updates heights asynchronously
    // (ResizeObserver), so one frame is not enough.
    if (chatChanged) {
      nextTick(() => {
        requestAnimationFrame(() => {
          requestAnimationFrame(() => doScrollToBottom());
        });
      });
    }
  });

  appApi.subscribeState((newState) => {
    const el = getScrollEl();
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
      nextTick(() => doScrollToBottom());
    }
  });

  appApi.subscribeMessageAdded(({ message, index }) => {
    if (!chatData.value) return;
    const el = getScrollEl();
    const atBottom = el ? isNearBottom(el) : false;

    const messages = [...chatData.value.messages];
    messages.splice(index, 0, message);
    chatData.value = { ...chatData.value, messages };

    if (atBottom) {
      nextTick(() => doScrollToBottom());
    }
  });

  appApi.subscribeMessageUpdated((updatedMessage) => {
    if (!chatData.value) return;
    if (editingMessageTime.value === updatedMessage.time) {
      editingMessageTime.value = null;
    }
    const messages = chatData.value.messages.map(
      m => (m.id === updatedMessage.id && m.time === updatedMessage.time)
        ? updatedMessage
        : m
    );
    chatData.value = { ...chatData.value, messages };
  });

  appApi.subscribeMessageRemoved((removedMessage) => {
    if (!chatData.value) return;
    const messages = chatData.value.messages.filter(
      m => !(m.id === removedMessage.id && m.time === removedMessage.time)
    );
    chatData.value = { ...chatData.value, messages };
  });

  appApi.subscribeTokenAppend((token) => {
    if (appState.value.isGenerating) {
      appState.value = {
        ...appState.value,
        LLMBuffer: appState.value.LLMBuffer + token,
      };
      const el = getScrollEl();
      if (el) {
        const atBottom = isNearBottom(el);
        if (atBottom) {
          nextTick(() => doScrollToBottom());
        }
      }
    }
  });

  appApi.subscribeTheme((themeData) => {
    applyTheme(themeData);
  });

  appApi.subscribeDisplaySettings((settings) => {
    applyDisplaySettings(settings);
  });

  appApi.subscribeScrollToBottom(() => {
    nextTick(() => doScrollToBottom());
  });

  appApi.subscribeScrollToMessage((msgId) => {
    nextTick(() => doScrollToMessage(msgId));
  });

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
   App-level layout & Markdown content styles
   Component-specific styles live in each .vue file.
   Theme tokens are in themes/tokens.css.
   ========================================================================== */

.app-container {
  display: flex;
  flex-direction: column;
  height: 100vh;
}

.chat-scroll-area {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 0 16px;
  scrollbar-width: none;
}

.chat-scroll-area::-webkit-scrollbar {
  display: none;
}

.streaming-wrapper {
  padding: 0 16px;
}

/* Spacing between messages — on a wrapper inside each scroller item
   so it participates in the scroller's height measurement. */
.msg-row {
  padding-bottom: 20px;
}

/* Give the whole scroller content area breathing room at top & bottom */
:deep(.vue-recycle-scroller__item-wrapper) {
  padding-top: 12px;
  padding-bottom: 20px;
}

/* ---- Markdown rendered content (deep styles — penetrate child components) ---- */
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
</style>
