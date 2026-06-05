<template>
  <div class="tool-block" :class="{ 'tool-expanded': isExpanded }">
    <div class="tool-header" @click="toggle">
      <span class="tool-icon">&gt;_</span>
      <span class="tool-name">{{ name }}</span>
      <span class="tool-summary">{{ summaryText }}</span>
      <span class="tool-chevron" :class="{ rotated: isExpanded }">▶</span>
    </div>
    <div class="tool-body" v-show="isExpanded">
      <pre class="tool-args">{{ prettyArgs }}</pre>
      <div class="tool-result">{{ result.trim() || '(empty)' }}</div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue';

const props = defineProps({
  id: { type: String, default: '' },
  name: { type: String, default: '' },
  args: { type: String, default: '' },
  result: { type: String, default: '' },
});

const isExpanded = ref(false);

function toggle() {
  isExpanded.value = !isExpanded.value;
}

const summaryText = computed(() => {
  const singleLine = props.result.trim().replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
  return singleLine.length > 60 ? singleLine.substring(0, 60) + '...' : singleLine;
});

const prettyArgs = computed(() => {
  try {
    return JSON.stringify(JSON.parse(props.args), null, 2);
  } catch {
    return props.args;
  }
});
</script>

<style scoped>
.tool-block {
  margin: 4px 0;
  background-color: var(--think-bg);
  border: 1px solid var(--think-border);
  border-radius: 6px;
  overflow: hidden;
  width: 100%;
}

.tool-header {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 8px;
  cursor: pointer;
  user-select: none;
  min-width: 0;
}

.tool-icon {
  font-size: 13px;
  line-height: 1;
  color: var(--tool-accent);
  font-weight: 700;
  flex-shrink: 0;
}

.tool-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--tool-accent);
  flex-shrink: 0;
}

.tool-summary {
  font-size: 13px;
  color: var(--think-header-text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin-left: 6px;
}

.tool-chevron {
  margin-left: auto;
  font-size: 10px;
  color: var(--think-header-text);
  transition: transform 0.2s;
  flex-shrink: 0;
}

.tool-chevron.rotated {
  transform: rotate(90deg);
}

.tool-body {
  padding: 0 8px 4px;
}

.tool-args {
  width: 100%;
  padding: 6px;
  background-color: var(--tool-args-bg);
  border-radius: 4px;
  font-size: 11px;
  line-height: 1.3;
  font-family: Consolas, Monaco, "Andale Mono", monospace;
  color: var(--think-body-text);
  white-space: pre-wrap;
  margin: 0 0 4px;
}

.tool-result {
  font-size: 13px;
  line-height: 1.5;
  color: var(--think-body-text);
  white-space: pre-wrap;
}
</style>
