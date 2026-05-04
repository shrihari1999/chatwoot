<script>
import { useAlert } from 'dashboard/composables';
import SlaForm from './SlaForm.vue';

export default {
  components: {
    SlaForm,
  },
  props: {
    selectedResponse: {
      type: Object,
      default: () => ({}),
    },
  },
  emits: ['close'],
  computed: {
    pageTitle() {
      return `${this.$t('SLA.EDIT.TITLE')} - ${this.selectedResponse.name}`;
    },
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    async editSLA(payload) {
      try {
        await this.$store.dispatch('sla/update', {
          id: this.selectedResponse.id,
          ...payload,
        });
        useAlert(this.$t('SLA.EDIT.API.SUCCESS_MESSAGE'));
        this.onClose();
      } catch (error) {
        const errorMessage =
          error.message || this.$t('SLA.EDIT.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="pageTitle" />
    <SlaForm
      :selected-response="selectedResponse"
      :submit-label="$t('SLA.FORM.EDIT')"
      @submit-sla="editSLA"
      @close="onClose"
    />
  </div>
</template>
