<template>
  <div class="inline-editor" @click.stop>
    <textarea
      ref="textareaRef"
      class="editor-textarea"
      :value="editText"
      @input="onInput"
      @keydown="onKeydown"
      rows="4"
    ></textarea>

    <div class="editor-footer">
      <span class="editor-hint">
        <kbd>Ctrl+Enter</kbd> 保存 · <kbd>Esc</kbd> 取消
      </span>
      <span class="editor-char-count">{{ editText.length }} 字</span>
      <div class="editor-actions">
        <button class="editor-btn editor-btn-cancel" @click="$emit('cancel')">
          取消
        </button>
        <button
          class="editor-btn editor-btn-save"
          :disabled="!hasChanges || editText.length === 0"
          @click="onSave"
        >
          保存
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from 'vue';

const props = defineProps({
  message: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['save', 'cancel']);

const textareaRef = ref(null);
const editText = ref(props.message.content || '');
const hasChanges = ref(false);

/** Auto-resize textarea to fit content */
function autoResize() {
  const el = textareaRef.value;
  if (!el) return;
  el.style.height = 'auto';
  el.style.height = Math.max(el.scrollHeight, 100) + 'px';
}

function onInput(e) {
  editText.value = e.target.value;
  hasChanges.value = e.target.value !== props.message.content;
  autoResize();
}

function onKeydown(e) {
  // Ctrl+Enter / Cmd+Enter → Save
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
    e.preventDefault();
    onSave();
    return;
  }
  // Esc → Cancel
  if (e.key === 'Escape') {
    e.preventDefault();
    emit('cancel');
    return;
  }
}

function onSave() {
  const trimmed = editText.value.trim();
  if (!trimmed || trimmed === props.message.content) return;
  emit('save', trimmed);
}

onMounted(() => {
  nextTick(() => {
    if (textareaRef.value) {
      textareaRef.value.focus();
      // Place cursor at the end of the text
      const len = textareaRef.value.value.length;
      textareaRef.value.setSelectionRange(len, len);
      autoResize();
    }
  });
});
</script>

<style scoped>
.inline-editor {
  display: flex;
  flex-direction: column;
  gap: 10px;
  width: 100%;
}

.editor-textarea {
  width: 100%;
  min-height: 100px;
  padding: 12px 14px;
  border: 2px solid var(--editor-border);
  border-radius: var(--bubble-radius);
  background: var(--editor-bg);
  color: var(--editor-text);
  font-size: calc(14px * var(--font-scale));
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  line-height: 1.6;
  resize: none;
  outline: none;
  box-sizing: border-box;
  transition: border-color 0.15s;
}

.editor-textarea:focus {
  border-color: var(--theme-color);
  box-shadow: 0 0 0 3px hsla(var(--theme-h), var(--theme-s), var(--theme-l), 0.15);
}

.editor-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 6px;
}

.editor-hint {
  font-size: 11px;
  color: var(--time-color);
}

.editor-hint kbd {
  display: inline-block;
  padding: 1px 5px;
  font-size: 10px;
  font-family: inherit;
  border: 1px solid var(--toolbar-border);
  border-radius: 3px;
  background: var(--code-bg);
  color: var(--time-color);
}

.editor-char-count {
  font-size: 11px;
  color: var(--time-color);
}

.editor-actions {
  display: flex;
  gap: 6px;
}

.editor-btn {
  padding: 6px 16px;
  border: none;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.15s, opacity 0.15s;
}

.editor-btn-cancel {
  background: var(--editor-btn-bg);
  color: var(--editor-text);
}

.editor-btn-cancel:hover {
  background: var(--editor-btn-hover-bg);
}

.editor-btn-save {
  background: var(--editor-btn-primary-bg);
  color: var(--editor-btn-primary-text);
}

.editor-btn-save:hover:not(:disabled) {
  background: var(--editor-btn-primary-hover-bg);
}

.editor-btn-save:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
</style>
