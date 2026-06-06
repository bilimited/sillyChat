<template>
  <div class="app-container">
    <div class="chat-scroll-area" ref="scrollContainer" @scroll="onScroll">
      <div class="message-list">
        <ChatMessage
          v-for="msg in displayMessages"
          :key="msg.id"
          :message="msg"
          :isUser="msg.role === 'user'"
          :isSelected="selectedMessage?.time === msg.time"
          :isEditing="editingMessageTime === msg.time"
          :showAvatar="showAvatar"
          :showAssistantName="showAssistantName"
          :showMessageTime="showMessageTime"
          :avatarSrc="getAvatar(msg.sender)"
          :senderName="getCharacterName(msg.sender)"
          :isLastAssistant="isLastAssistantMessage(msg)"
          :alternativeIndex="alternativeIndex(msg)"
          @select="toggleSelect(msg)"
          @edit="onEdit(msg)"
          @editSave="(content) => onEditSave(msg, content)"
          @editCancel="onEditCancel"
          @copy="onCopy(msg)"
          @delete="onDelete(msg)"
          @retry="onRetry"
          @switchAlt="(dir) => onSwitchAlternative(msg, dir)"
          @more="onMore(msg)" 
        />

        <StreamingMessage
          v-if="appState.isGenerating"
          :buffer="appState.LLMBuffer"
          :statusText="appState.GenerateState"
          :avatarSrc="getAvatar(appState.currentAssistant)"
          :showAvatar="showAvatar"
          :showAssistantName="showAssistantName"
          :assistantName="getCharacterName(appState.currentAssistant)"
        />
      </div>
      <div class="bottom-spacer"></div>
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

const isNearBottom = (el) => {
  return el.scrollHeight - el.scrollTop - el.clientHeight < 50;
};

const doScrollToBottom = () => {
  if (!scrollContainer.value) return;
  scrollContainer.value.scrollTop = scrollContainer.value.scrollHeight;
};

const doScrollToMessage = (msgId) => {
  if (!scrollContainer.value) return;
  const target = scrollContainer.value.querySelector(`[data-msg-id="${msgId}"]`);
  if (target) {
    target.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
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
  if (!scrollContainer.value) return;
  if (scrollDebounceTimer) clearTimeout(scrollDebounceTimer);
  scrollDebounceTimer = setTimeout(() => {
    const near = isNearBottom(scrollContainer.value);
    appApi.notifyScrollState(near);
  }, 150);
};

// --- Lifecycle ---

onMounted(() => {
  appApi.subscribeChat((newChat) => {
    editingMessageTime.value = null;
    handleScrollPreservation(() => {
      chatData.value = newChat;
      appState.value = { ...appState.value, LLMBuffer: '' };
    });
  });

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

  appApi.subscribeTokenAppend((token) => {
    if (appState.value.isGenerating) {
      appState.value = {
        ...appState.value,
        LLMBuffer: appState.value.LLMBuffer + token,
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

.message-list {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding-bottom: 20px;
}

.bottom-spacer {
  height: 20px;
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
