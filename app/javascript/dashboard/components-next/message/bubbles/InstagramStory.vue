<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from '../provider.js';
import Icon from 'next/icon/Icon.vue';
import BaseBubble from 'next/message/bubbles/Base.vue';

import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import { MESSAGE_VARIANTS, ATTACHMENT_TYPES } from '../constants';

const emit = defineEmits(['error']);
const { t } = useI18n();
const { variant, content, contentAttributes, attachments } =
  useMessageContext();

const attachment = computed(() => {
  return attachments.value[0];
});

const isStoryReply = computed(() => {
  return contentAttributes.value?.imageType === ATTACHMENT_TYPES.IG_STORY_REPLY;
});

const hasImgStoryError = ref(false);
const hasVideoStoryError = ref(false);

const formattedContent = computed(() => {
  if (variant.value === MESSAGE_VARIANTS.ACTIVITY) {
    return content.value;
  }

  return new MessageFormatter(content.value).formattedMessage;
});

const onImageLoadError = () => {
  hasImgStoryError.value = true;
  emit('error');
};

const onVideoLoadError = () => {
  hasVideoStoryError.value = true;
  emit('error');
};
</script>

<template>
  <BaseBubble class="p-3 overflow-hidden" data-bubble-name="ig-story">
    <p v-if="isStoryReply" class="mb-1 text-xs text-n-slate-11">
      {{ t('COMPONENTS.FILE_BUBBLE.INSTAGRAM_STORY_REPLY') }}
    </p>
    <div v-if="content" v-dompurify-html="formattedContent" class="mb-2" />
    <!--
      attachments can be empty: the story asset expired, or the bubble re-rendered
      after the agent navigated away while a load-error handler was in flight.
      Without the attachment guard the img/video branch still evaluated
      attachment.dataUrl on undefined and crashed the render, so guard the whole
      chain and fall through to the unavailable state instead.
    -->
    <img
      v-if="attachment && !hasImgStoryError"
      class="rounded-lg max-w-80 skip-context-menu"
      :src="attachment.dataUrl"
      @error="onImageLoadError"
    />
    <video
      v-else-if="attachment && !hasVideoStoryError"
      class="rounded-lg max-w-80 skip-context-menu"
      controls
      :src="attachment.dataUrl"
      @error="onVideoLoadError"
    />
    <div
      v-else
      class="flex items-center gap-1 px-5 py-4 text-center rounded-lg bg-n-alpha-1"
    >
      <Icon icon="i-lucide-circle-off" class="text-n-slate-11" />
      <p class="mb-0 text-n-slate-11">
        {{ $t('COMPONENTS.FILE_BUBBLE.INSTAGRAM_STORY_UNAVAILABLE') }}
      </p>
    </div>
  </BaseBubble>
</template>
