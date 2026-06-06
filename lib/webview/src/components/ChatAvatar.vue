<template>
  <div class="avatar" v-if="visible">
    <img :src="src" alt="avatar" @error="handleImgError" />
  </div>
</template>

<script setup>
defineProps({
  src: { type: String, required: true },
  visible: { type: Boolean, default: true },
});

function handleImgError(e) {
  if (e.target.src !== 'https://via.placeholder.com/50') {
    e.target.src = 'https://via.placeholder.com/50';
  }
}
</script>

<style scoped>
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
</style>
