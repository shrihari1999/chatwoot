<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from '../provider.js';
import Icon from 'next/icon/Icon.vue';
import BaseBubble from 'next/message/bubbles/Base.vue';

import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import { MESSAGE_VARIANTS } from '../constants';

const { t } = useI18n();
const { variant, content, contentAttributes } = useMessageContext();

const postPermalink = computed(() => contentAttributes.value?.postPermalink);

const formattedContent = computed(() => {
  if (variant.value === MESSAGE_VARIANTS.ACTIVITY) {
    return content.value;
  }
  return new MessageFormatter(content.value).formattedMessage;
});
</script>

<template>
  <BaseBubble class="p-3 overflow-hidden" data-bubble-name="ig-comment">
    <div class="flex items-center gap-1 mb-1 text-xs text-n-slate-11">
      <Icon icon="i-ri-instagram-fill" class="size-3.5" />
      <span>{{ t('COMPONENTS.FILE_BUBBLE.INSTAGRAM_COMMENT_ON_POST') }}</span>
      <template v-if="postPermalink">
        <span class="text-n-slate-10">·</span>
        <a
          :href="postPermalink"
          target="_blank"
          rel="noopener noreferrer"
          class="underline hover:text-n-slate-12"
        >
          {{ t('COMPONENTS.FILE_BUBBLE.INSTAGRAM_VIEW_POST') }}
        </a>
      </template>
    </div>
    <div
      v-if="content"
      v-dompurify-html="formattedContent"
      class="prose prose-bubble"
    />
  </BaseBubble>
</template>
