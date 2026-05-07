<script setup>
defineProps({
  team: {
    type: Object,
    default: () => ({}),
  },
});
</script>

<template>
  <div :title="team.name" class="flex items-center gap-0.5 min-w-0">
    <fluent-icon
      icon="people-team"
      size="14"
      class="flex-shrink-0 text-n-slate-11"
    />
    <span class="truncate text-label-small text-n-slate-11">
      {{ team.name }}
    </span>
  </div>
</template>
