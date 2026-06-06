<template>
  <div
    class="message-item"
    :class="[
      isUser ? 'message-user' : 'message-ai',
      { 'message-selected': isSelected },
    ]"
    @click="$emit('select')"
  >
    <ChatAvatar :src="avatarSrc" :visible="showAvatar" />

    <div class="bubble-wrapper">
      <template v-if="isEditing">
        <MessageEditor
          :message="message"
          @save="(content) => $emit('editSave', content)"
          @cancel="$emit('editCancel')"
        />
      </template>
      <MessageBubble
        v-else
        :content="message.content"
        :senderName="senderName"
        :showName="showName"
        :showTime="showMessageTime"
        :time="message.time"
        :isUser="isUser"
      />

      <MessageToolbar
        v-if="isSelected"
        :isLastAssistant="isLastAssistant"
        :alternativeContent="message.alternativeContent"
        :alternativeIndex="alternativeIndex"
        :charCount="message.content.length"
        :isAssistant="message.role === 'assistant'"
        @edit="$emit('edit')"
        @copy="$emit('copy')"
        @delete="$emit('delete')"
        @retry="$emit('retry')"
        @switchAlt="(dir) => $emit('switchAlt', dir)"
        @more="$emit('more')"
      />
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import ChatAvatar from './ChatAvatar.vue';
import MessageBubble from './MessageBubble.vue';
import MessageToolbar from './MessageToolbar.vue';
import MessageEditor from './MessageEditor.vue';

const props = defineProps({
  message: { type: Object, required: true },
  isUser: { type: Boolean, default: false },
  isSelected: { type: Boolean, default: false },
  isEditing: { type: Boolean, default: false },
  showAvatar: { type: Boolean, default: true },
  showAssistantName: { type: Boolean, default: false },
  showMessageTime: { type: Boolean, default: false },
  avatarSrc: { type: String, default: '' },
  senderName: { type: String, default: '' },
  isLastAssistant: { type: Boolean, default: false },
  alternativeIndex: { type: Number, default: 0 },
});

defineEmits([
  'select',
  'edit', 'editSave', 'editCancel',
  'copy', 'delete', 'retry',
  'switchAlt', 'more',
]);

const showName = computed(() => !props.isUser && props.showAssistantName);
</script>

<style scoped>
.message-item {
  display: flex;
  align-items: flex-start;
  max-width: 100%;
  min-width: 0;
  cursor: pointer;
  border-radius: 8px;
  transition: background-color 0.15s;
}

.message-ai {
  flex-direction: row;
}

.message-user {
  flex-direction: row-reverse;
}

.bubble-wrapper {
  display: flex;
  flex-direction: column;
  max-width: 80%;
  min-width: 0;
  overflow: hidden;
}

.message-ai .bubble-wrapper {
  align-items: flex-start;
  margin-left: 10px;
}

.message-user .bubble-wrapper {
  align-items: flex-end;
  margin-right: 10px;
}

/* Toolbar alignment — reaches into child component */
.message-ai :deep(.message-toolbar) {
  align-self: flex-start;
}

.message-user :deep(.message-toolbar) {
  align-self: flex-end;
}
</style>
