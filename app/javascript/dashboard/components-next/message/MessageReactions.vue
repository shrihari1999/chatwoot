<script setup>
import { computed } from 'vue';

const props = defineProps({
  reactions: {
    type: Object,
    default: () => ({}),
  },
});

const reactionList = computed(() =>
  Object.entries(props.reactions)
    .map(([emoji, senders]) => ({
      emoji,
      count: senders?.length ?? 0,
    }))
    .filter(r => r.count > 0)
);
</script>

<template>
  <div v-if="reactionList.length > 0" class="flex flex-wrap gap-1 mt-1">
    <span
      v-for="r in reactionList"
      :key="r.emoji"
      data-testid="reaction-pill"
      class="inline-flex items-center gap-0.5 rounded-full bg-n-alpha-1 px-1.5 py-0.5 text-xs"
    >
      {{ r.emoji }}<span class="text-n-slate-11">{{ r.count }}</span>
    </span>
  </div>
</template>
