<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import CategoryDialog from './CategoryDialog.vue';

export default {
  name: 'CategoryManager',
  components: {
    NextButton,
    Icon,
    CategoryDialog,
  },
  data() {
    return {
      showDialog: false,
      // The category being edited; null while adding a new one.
      editingCategory: null,
    };
  },
  computed: {
    ...mapGetters({
      categories: 'cannedResponseCategory/getCannedResponseCategories',
    }),
  },
  methods: {
    // A non-`everyone` category shows its scope as a small icon on the chip.
    visibilityIcon(category) {
      if (category.visibility === 'only_me') return 'i-lucide-lock';
      if (category.visibility === 'specific_team') return 'i-lucide-users';
      return null;
    },
    openAddDialog() {
      this.editingCategory = null;
      this.showDialog = true;
    },
    openEditDialog(category) {
      this.editingCategory = category;
      this.showDialog = true;
    },
    closeDialog() {
      this.showDialog = false;
      this.editingCategory = null;
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
      <NextButton
        size="sm"
        icon="i-lucide-plus"
        :label="$t('CANNED_MGMT.CATEGORY.ADD')"
        @click="openAddDialog"
      />
    </div>

    <div v-if="categories.length" class="flex flex-wrap gap-2">
      <span
        v-for="category in categories"
        :key="category.id"
        class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs rounded-full bg-n-alpha-2 text-n-slate-12 border border-n-weak"
      >
        <button
          type="button"
          class="inline-flex items-center gap-1 hover:underline decoration-dotted cursor-pointer bg-transparent border-none p-0 text-xs text-n-slate-12"
          :aria-label="
            $t('CANNED_MGMT.CATEGORY.EDIT_LABEL', { name: category.name })
          "
          @click="openEditDialog(category)"
        >
          <Icon
            v-if="visibilityIcon(category)"
            :icon="visibilityIcon(category)"
            class="size-3 text-n-slate-10"
          />
          {{ category.name }}
        </button>
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

    <CategoryDialog
      v-if="showDialog"
      :category="editingCategory"
      :on-close="closeDialog"
    />
  </div>
</template>
