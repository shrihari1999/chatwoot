<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

export default {
  name: 'CategoryManager',
  components: {
    NextButton,
    Icon,
  },
  data() {
    return {
      newCategoryName: '',
      isSubmitting: false,
    };
  },
  computed: {
    ...mapGetters({
      categories: 'cannedResponseCategory/getCannedResponseCategories',
    }),
    canAdd() {
      return !!this.newCategoryName.trim() && !this.isSubmitting;
    },
  },
  methods: {
    async addCategory() {
      const name = this.newCategoryName.trim();
      if (!name) return;
      this.isSubmitting = true;
      try {
        await this.$store.dispatch(
          'cannedResponseCategory/createCannedResponseCategory',
          { name }
        );
        this.newCategoryName = '';
      } catch (error) {
        const errorMessage =
          error?.message || this.$t('CANNED_MGMT.ADD.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      } finally {
        this.isSubmitting = false;
      }
    },
    async removeCategory(category) {
      // eslint-disable-next-line no-alert
      const confirmed = window.confirm(
        this.$t('CANNED_MGMT.CATEGORY.DELETE_CONFIRM')
      );
      if (!confirmed) return;
      try {
        await this.$store.dispatch(
          'cannedResponseCategory/deleteCannedResponseCategory',
          category.id
        );
        // Refresh canned responses since backend nullifies category_id on affected records
        await this.$store.dispatch('getCannedResponse');
      } catch (error) {
        const errorMessage =
          error?.message || this.$t('CANNED_MGMT.DELETE.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 mb-4 border rounded-lg border-n-weak bg-n-alpha-1"
  >
    <div class="flex items-center justify-between">
      <h4 class="mb-0 text-sm font-medium text-n-slate-12">
        {{ $t('CANNED_MGMT.CATEGORY.MANAGE') }}
      </h4>
    </div>

    <div v-if="categories.length" class="flex flex-wrap gap-2">
      <span
        v-for="category in categories"
        :key="category.id"
        class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs rounded-full bg-n-alpha-2 text-n-slate-12 border border-n-weak"
      >
        <span>{{ category.name }}</span>
        <button
          type="button"
          class="flex items-center justify-center size-4 rounded-full text-n-slate-11 hover:bg-n-ruby-2 hover:text-n-ruby-11 transition-colors"
          :aria-label="$t('CANNED_MGMT.DELETE.BUTTON_TEXT')"
          @click="removeCategory(category)"
        >
          <Icon icon="i-lucide-x" class="size-3" />
        </button>
      </span>
    </div>

    <form class="flex items-center gap-2" @submit.prevent="addCategory">
      <input
        v-model="newCategoryName"
        type="text"
        class="flex-1 h-8 px-3 py-1 m-0 text-sm rounded-lg border border-n-weak bg-n-alpha-1"
        :placeholder="$t('CANNED_MGMT.CATEGORY.PLACEHOLDER')"
      />
      <NextButton
        type="submit"
        size="sm"
        :label="$t('CANNED_MGMT.CATEGORY.ADD')"
        :disabled="!canAdd"
        :is-loading="isSubmitting"
      />
    </form>
  </div>
</template>
