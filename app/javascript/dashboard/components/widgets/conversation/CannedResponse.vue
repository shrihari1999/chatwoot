<script>
import { mapGetters } from 'vuex';
import { debounce } from '@chatwoot/utils';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import MentionBox from '../mentions/MentionBox.vue';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

// Every keystroke used to trigger a full refetch of the list. Waiting for a pause
// collapses a burst of typing into a single request.
const SEARCH_DEBOUNCE_MS = 300;

export default {
  components: { MentionBox },
  props: {
    searchKey: {
      type: String,
      default: '',
    },
    channelType: {
      type: String,
      default: '',
    },
  },
  emits: ['replace', 'attachFiles'],
  setup() {
    const { getPlainText } = useMessageFormatter();
    return { getPlainText };
  },
  computed: {
    ...mapGetters({
      cannedMessages: 'getCannedResponses',
    }),
    // Only Instagram rotates. Every other channel inserts `content`, exactly as before.
    isAnInstagramChannel() {
      return this.channelType === INBOX_TYPES.INSTAGRAM;
    },
    items() {
      // `key` must be unique across the list, but the same `short_code` can now
      // appear in multiple categories — so we key by id, not short_code.
      const toItem = cannedMessage => {
        const wordings = this.wordingsFor(cannedMessage);
        const rotates = wordings.length > 1;
        const cursor = cannedMessage.content_variant_cursor || 0;
        return {
          label: cannedMessage.short_code,
          key: cannedMessage.id,
          // The wording the picker previews IS the one it will insert, so the agent
          // never sees one thing and sends another.
          description: rotates
            ? wordings[cursor % wordings.length]
            : cannedMessage.content,
          rotates,
          files: cannedMessage.files || [],
          category: cannedMessage.category,
        };
      };

      // Every canned response has a category (DB-enforced).
      const groupsByName = this.cannedMessages.reduce((acc, cannedMessage) => {
        const name = cannedMessage.category.name;
        if (!acc[name]) acc[name] = [];
        acc[name].push(cannedMessage);
        return acc;
      }, {});

      const sortedGroupNames = Object.keys(groupsByName).sort((a, b) =>
        a.localeCompare(b)
      );

      const result = [];
      sortedGroupNames.forEach(groupName => {
        result.push({ type: 'header', label: groupName });
        groupsByName[groupName].forEach(cannedMessage => {
          result.push(toItem(cannedMessage));
        });
      });

      return result;
    },
  },
  watch: {
    searchKey() {
      this.debouncedFetchCannedResponses();
    },
  },
  created() {
    this.debouncedFetchCannedResponses = debounce(
      () => this.fetchCannedResponses(),
      SEARCH_DEBOUNCE_MS
    );
  },
  mounted() {
    // The initial load is immediate — the picker has just opened and has nothing to show.
    this.fetchCannedResponses();
  },
  methods: {
    // Alternative wordings of the same response, blanks dropped. Attachments are
    // shared across wordings, so only the text differs.
    wordingsFor(cannedMessage) {
      if (!this.isAnInstagramChannel) return [];

      return [cannedMessage.content, ...(cannedMessage.content_variants || [])]
        .filter(Boolean)
        .filter(wording => wording.trim());
    },
    fetchCannedResponses() {
      this.$store.dispatch('getCannedResponse', {
        searchKey: this.searchKey,
        filterByVisibility: true,
      });
    },
    handleMentionClick(item = {}) {
      // Always emit `replace` so the editor removes the trigger text (e.g., "/img")
      // from the ProseMirror state. This causes the suggestion plugin's onExit to fire,
      // which closes the picker. For image-only responses (no description) we pass ''
      // so the trigger is deleted without inserting any text content.
      // NOTE: passing null/undefined to MessageMarkdownTransformer.parse would throw;
      // '' is safe and results in an empty paragraph that collapses to nothing on insert.
      this.$emit('replace', item.description || '');
      if (item.files && item.files.length) {
        this.$emit('attachFiles', item.files);
      }
      // Not awaited -- the wording is already in the composer, and the picker closing
      // must not wait on the network.
      if (item.rotates) {
        this.$store.dispatch('advanceCannedResponseVariant', item.key);
      }
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <MentionBox
    v-if="items.length"
    :items="items"
    @mention-select="handleMentionClick"
  >
    <template #default="{ item, selected }">
      <div
        v-if="item.files.length && !item.description"
        class="flex flex-wrap gap-1 py-0.5"
      >
        <img
          v-for="file in item.files.slice(0, 3)"
          :key="file.blob_id"
          :src="file.thumb_url"
          :alt="file.filename"
          loading="lazy"
          width="40"
          height="40"
          class="w-10 h-10 object-cover rounded"
        />
        <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
        <span
          v-if="item.files.length > 3"
          class="text-xs text-n-slate-10 self-center"
        >
          +{{ item.files.length - 3 }}
        </span>
      </div>
      <template v-else>
        <p
          class="max-w-full min-w-0 mb-0 overflow-hidden text-sm font-medium text-n-slate-11 group-hover:text-n-slate-12 text-ellipsis whitespace-nowrap"
          :class="{ 'text-n-slate-12': selected }"
        >
          {{ getPlainText(item.description) }}
        </p>
        <div v-if="item.files.length" class="flex flex-wrap gap-1 mt-0.5">
          <img
            v-for="file in item.files.slice(0, 2)"
            :key="file.blob_id"
            :src="file.thumb_url"
            :alt="file.filename"
            loading="lazy"
            width="32"
            height="32"
            class="w-8 h-8 object-cover rounded"
          />
          <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
          <span
            v-if="item.files.length > 2"
            class="text-xs text-n-slate-10 self-center"
          >
            +{{ item.files.length - 2 }}
          </span>
        </div>
      </template>
      <p
        class="max-w-full min-w-0 mb-0 overflow-hidden text-xs text-n-slate-11 group-hover:text-n-slate-12 text-ellipsis whitespace-nowrap"
        :class="{ 'text-n-slate-12': selected }"
      >
        <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
        /{{ item.label }}
      </p>
    </template>
  </MentionBox>
</template>
