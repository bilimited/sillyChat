<template>
  <div class="sender-name" v-if="showName">{{ senderName }}</div>
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
    <div v-else class="bubble" :class="isUser ? 'bubble-user' : 'bubble-ai'">
      <div class="markdown-body" v-html="renderMarkdown(seg.content)"></div>
    </div>
  </template>
  <div class="time" v-if="showTime">{{ formattedTime }}</div>
</template>

<script setup>
import { computed } from 'vue';
import md from '../utils/markdown.js';
import { parseContentSegments } from '../utils/contentParser.js';
import ThinkBlock from './ThinkBlock.vue';
import ToolCallBlock from './ToolCallBlock.vue';

const props = defineProps({
  content: { type: String, required: true },
  senderName: { type: String, default: '' },
  showName: { type: Boolean, default: false },
  showTime: { type: Boolean, default: false },
  time: { type: String, default: '' },
  isUser: { type: Boolean, default: false },
});
 
const segments = computed(() => {
  if (!props.content) return [];
  return parseContentSegments(props.content);
});
 
function renderMarkdown(text) {
  if (!text) return '';
  return md.render(text);
}

const formattedTime = computed(() => {
  if (!props.time) return '';
  const date = new Date(props.time);
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
});
</script>

<style scoped>
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

.bubble-ai {
  background-color: var(--bubble-bg-ai);
  color: var(--bubble-text-ai);
  border-top-left-radius: 2px;
}

.bubble-user {
  background-color: var(--bubble-bg-user);
  color: var(--bubble-text-user);
  border-top-right-radius: 2px;
}

.time {
  font-size: calc(10px * var(--font-scale));
  color: var(--time-color);
  margin-top: 4px;
  margin-left: 4px;
}
</style>
