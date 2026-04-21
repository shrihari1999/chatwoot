<script>
import { mapGetters } from 'vuex';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import MentionBox from '../mentions/MentionBox.vue';

export default {
  components: { MentionBox },
  props: {
    searchKey: {
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
    items() {
      const toItem = cannedMessage => ({
        label: cannedMessage.short_code,
        key: cannedMessage.short_code,
        description: cannedMessage.content,
        files: cannedMessage.files || [],
        category: cannedMessage.category || null,
      });

      const categorized = [];
      const uncategorized = [];
      this.cannedMessages.forEach(cannedMessage => {
        if (cannedMessage.category) {
          categorized.push(cannedMessage);
        } else {
          uncategorized.push(cannedMessage);
        }
      });

      // If all responses are uncategorised, return them flat without headers
      if (categorized.length === 0) {
        return uncategorized.map(toItem);
      }

      // Group categorized records by category name
      const groupsByName = categorized.reduce((acc, cannedMessage) => {
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

      if (uncategorized.length) {
        result.push({ type: 'header', label: 'Other' });
        uncategorized.forEach(cannedMessage => {
          result.push(toItem(cannedMessage));
        });
      }

      return result;
    },
  },
  watch: {
    searchKey() {
      this.fetchCannedResponses();
    },
  },
  mounted() {
    this.fetchCannedResponses();
  },
  methods: {
    fetchCannedResponses() {
      this.$store.dispatch('getCannedResponse', { searchKey: this.searchKey });
    },
    handleMentionClick(item = {}) {
      this.$emit('replace', item.description);
      if (item.files && item.files.length) {
        this.$emit('attachFiles', item.files);
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
        v-if="item.files && item.files.length && !item.description"
        class="flex flex-wrap gap-1 py-0.5"
      >
        <img
          v-for="file in item.files.slice(0, 3)"
          :key="file.blob_id"
          :src="file.file_url"
          :alt="file.filename"
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
        <div
          v-if="item.files && item.files.length"
          class="flex flex-wrap gap-1 mt-0.5"
        >
          <img
            v-for="file in item.files.slice(0, 2)"
            :key="file.blob_id"
            :src="file.file_url"
            :alt="file.filename"
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
