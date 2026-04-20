<script>
import { mapGetters } from 'vuex';
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
  />
</template>
