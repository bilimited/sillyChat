<template>
  <div class="message-toolbar" @click.stop>
    <button class="toolbar-btn" title="编辑" @click="$emit('edit')">✏️</button>
    <button class="toolbar-btn" title="复制" @click="$emit('copy')">📋</button>
    <button class="toolbar-btn" title="删除" @click="$emit('delete')">🗑️</button>
    <button v-if="isLastAssistant" class="toolbar-btn" title="重试" @click="$emit('retry')">🔄</button>
    <template v-if="hasAlternatives">
      <span class="toolbar-divider"></span>
      <button class="toolbar-btn" title="上一版本" @click="$emit('switchAlt', 'left')">◀</button>
      <span class="alternative-indicator">{{ altIndex + 1 }}/{{ altCount }}</span>
      <button class="toolbar-btn" title="下一版本" @click="$emit('switchAlt', 'right')">▶</button>
    </template>
    <span class="toolbar-divider"></span>
    <button class="toolbar-btn" title="更多" @click="$emit('more')">⋯</button>
    <span class="char-count" v-if="isAssistant">{{ charCount }}字</span>
  </div>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  isLastAssistant: { type: Boolean, default: false },
  alternativeContent: { type: Array, default: null },
  alternativeIndex: { type: Number, default: 0 },
  charCount: { type: Number, default: 0 },
  isAssistant: { type: Boolean, default: false },
});

defineEmits(['edit', 'copy', 'delete', 'retry', 'switchAlt', 'more']);

const hasAlternatives = computed(() => {
  return props.alternativeContent && props.alternativeContent.length > 1;
});

const altCount = computed(() => props.alternativeContent?.length || 0);
const altIndex = computed(() => props.alternativeIndex);
</script>

<style scoped>
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
  animation: toolbar-in 0.15s ease-out;
}

@keyframes toolbar-in {
  from { opacity: 0; transform: translateY(-4px); }
  to   { opacity: 1; transform: translateY(0); }
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
</style>
