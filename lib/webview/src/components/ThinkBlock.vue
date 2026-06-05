<template>
  <div class="think-block" :class="{ 'think-expanded': isExpanded }">
    <div class="think-header" @click="toggle">
      <span class="think-icon">🧠</span>
      <span v-if="isThinking" class="think-spinner"></span>
      <span class="think-label">{{ isThinking ? '思考中' : '思考过程' }}</span>
      <span class="think-chevron" :class="{ rotated: isExpanded }">▶</span>
    </div>
    <div class="think-body" v-show="isExpanded">
      <div class="think-content">{{ content.trim() || '(empty)' }}</div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';

defineProps({
  isThinking: { type: Boolean, default: false },
  content: { type: String, default: '' },
});

const isExpanded = ref(false);

function toggle() {
  isExpanded.value = !isExpanded.value;
}
</script>

<style scoped>
.think-block {
  margin: 4px 0;
  background-color: var(--think-bg);
  border: 1px solid var(--think-border);
  border-radius: 6px;
  overflow: hidden;
  width: 100%;
}

.think-header {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 8px;
  cursor: pointer;
  user-select: none;
}

.think-icon {
  font-size: 13px;
  line-height: 1;
}

.think-spinner {
  width: 10px;
  height: 10px;
  border: 1.5px solid var(--think-header-text);
  border-top-color: transparent;
  border-radius: 50%;
  animation: think-spin 0.8s linear infinite;
}

@keyframes think-spin {
  to { transform: rotate(360deg); }
}

.think-label {
  font-size: 13px;
  font-weight: 500;
  color: var(--think-header-text);
}

.think-chevron {
  margin-left: auto;
  font-size: 10px;
  color: var(--think-header-text);
  transition: transform 0.2s;
}

.think-chevron.rotated {
  transform: rotate(90deg);
}

.think-body {
  padding: 0 8px 4px;
}

.think-content {
  font-size: 13px;
  line-height: 1.5;
  color: var(--think-body-text);
  white-space: pre-wrap;
}
</style>
