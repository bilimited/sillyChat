<template>
  <div class="message-item message-ai generating">
    <ChatAvatar :src="avatarSrc" :visible="showAvatar" />
    <div class="bubble-wrapper">
      <div class="sender-name" v-if="showAssistantName">{{ assistantName }}</div>

      <template v-for="(seg, i) in segments" :key="i">
        <ThinkBlock
          v-if="seg.type === 'think'"
          :isThinking="seg.isThinking || false"
          :content="seg.content"
        />
        <ToolCallBlock
          v-else-if="seg.type === 'toolCallResult'"
          :id="seg.attributes?.id || ''"
          :name="seg.attributes?.name || ''"
          :args="seg.attributes?.args || ''"
          :result="seg.content"
        />
        <div v-else class="bubble">
          <div class="markdown-body" v-html="renderMarkdown(seg.content)"></div>
        </div>
      </template>

      <span v-if="lastSegmentIsText" class="cursor">|</span>
      <div class="status-text">{{ statusText }}</div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import md from '../utils/markdown.js';
import { parseContentSegments, SegmentType } from '../utils/contentParser.js';
import ChatAvatar from './ChatAvatar.vue';
import ThinkBlock from './ThinkBlock.vue';
import ToolCallBlock from './ToolCallBlock.vue';

const props = defineProps({
  buffer: { type: String, default: '' },
  statusText: { type: String, default: '' },
  avatarSrc: { type: String, default: '' },
  showAvatar: { type: Boolean, default: true },
  showAssistantName: { type: Boolean, default: false },
  assistantName: { type: String, default: 'Assistant' },
});

const segments = computed(() => {
  if (!props.buffer) return [];
  return parseContentSegments(props.buffer);
});

const lastSegmentIsText = computed(() => {
  const s = segments.value;
  return s.length > 0 && s[s.length - 1].type === SegmentType.TEXT;
});

function renderMarkdown(text) {
  if (!text) return '';
  return md.render(text);
}
</script>

<style scoped>
.message-item {
  display: flex;
  align-items: flex-start;
  max-width: 100%;
}

.message-ai {
  flex-direction: row;
}

.bubble-wrapper {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  margin-left: 10px;
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
  border-top-left-radius: 2px;
  font-size: calc(15px * var(--font-scale));
  background-color: var(--bubble-bg-ai);
  color: var(--bubble-text-ai);
  box-shadow: 0 1px 2px var(--bubble-shadow);
  overflow: hidden;
}

.status-text {
  font-size: calc(10px * var(--font-scale));
  color: var(--status-text-color);
  margin-top: 2px;
}

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
</style>
