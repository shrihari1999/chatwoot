<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { required, requiredIf } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';

export default {
  name: 'CategoryDialog',
  components: {
    NextButton,
    Modal,
  },
  props: {
    // When null the dialog is in "add" mode; otherwise it edits this category.
    category: {
      type: Object,
      default: null,
    },
    onClose: {
      type: Function,
      default: () => {},
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      show: true,
      name: this.category?.name || '',
      visibility: this.category?.visibility || 'everyone',
      teamId: this.category?.team_id || null,
      isSubmitting: false,
    };
  },
  computed: {
    ...mapGetters({
      teams: 'teams/getTeams',
    }),
    isEditing() {
      return !!this.category;
    },
    title() {
      return this.isEditing
        ? this.$t('CANNED_MGMT.CATEGORY.DIALOG.EDIT_TITLE')
        : this.$t('CANNED_MGMT.CATEGORY.DIALOG.ADD_TITLE');
    },
    // Order mirrors the reference UI: Myself, Team, All agents.
    visibilityOptions() {
      return [
        {
          value: 'only_me',
          label: this.$t('CANNED_MGMT.CATEGORY.DIALOG.VISIBILITY.ONLY_ME'),
        },
        {
          value: 'specific_team',
          label: this.$t(
            'CANNED_MGMT.CATEGORY.DIALOG.VISIBILITY.SPECIFIC_TEAM'
          ),
        },
        {
          value: 'everyone',
          label: this.$t('CANNED_MGMT.CATEGORY.DIALOG.VISIBILITY.EVERYONE'),
        },
      ];
    },
    isSubmitDisabled() {
      return this.v$.$invalid || this.isSubmitting;
    },
  },
  validations() {
    return {
      name: { required },
      teamId: {
        required: requiredIf(() => this.visibility === 'specific_team'),
      },
    };
  },
  methods: {
    async submit() {
      this.v$.$touch();
      if (this.v$.$invalid) return;

      this.isSubmitting = true;
      const payload = {
        name: this.name.trim(),
        visibility: this.visibility,
        team_id: this.visibility === 'specific_team' ? this.teamId : null,
      };
      try {
        if (this.isEditing) {
          await this.$store.dispatch(
            'cannedResponseCategory/updateCannedResponseCategory',
            { id: this.category.id, ...payload }
          );
        } else {
          await this.$store.dispatch(
            'cannedResponseCategory/createCannedResponseCategory',
            payload
          );
        }
        this.onClose();
      } catch (error) {
        const fallback = this.isEditing
          ? this.$t('CANNED_MGMT.EDIT.API.ERROR_MESSAGE')
          : this.$t('CANNED_MGMT.ADD.API.ERROR_MESSAGE');
        useAlert(error?.message || fallback);
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="title" />
      <form class="flex flex-col w-full" @submit.prevent="submit">
        <div class="w-full">
          <label :class="{ error: v$.name.$error }">
            {{ $t('CANNED_MGMT.CATEGORY.DIALOG.NAME_LABEL') }}
            <input
              v-model="name"
              type="text"
              :placeholder="$t('CANNED_MGMT.CATEGORY.DIALOG.NAME_PLACEHOLDER')"
              @blur="v$.name.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label>{{
            $t('CANNED_MGMT.CATEGORY.DIALOG.VISIBILITY.LABEL')
          }}</label>
          <div class="flex flex-col gap-2 mt-1">
            <label
              v-for="option in visibilityOptions"
              :key="option.value"
              class="flex items-center gap-2 m-0 cursor-pointer text-sm text-n-slate-12"
            >
              <input
                v-model="visibility"
                type="radio"
                :value="option.value"
                class="m-0"
              />
              {{ option.label }}
            </label>
          </div>
        </div>

        <div v-if="visibility === 'specific_team'" class="w-full">
          <label :class="{ error: v$.teamId.$error }">
            {{ $t('CANNED_MGMT.CATEGORY.DIALOG.TEAM_LABEL') }}
            <select v-model="teamId" @blur="v$.teamId.$touch">
              <option :value="null" disabled>
                {{ $t('CANNED_MGMT.CATEGORY.DIALOG.TEAM_PLACEHOLDER') }}
              </option>
              <option v-for="team in teams" :key="team.id" :value="team.id">
                {{ team.name }}
              </option>
            </select>
          </label>
        </div>

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('CANNED_MGMT.CATEGORY.DIALOG.CANCEL')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CANNED_MGMT.CATEGORY.DIALOG.SUBMIT')"
            :disabled="isSubmitDisabled"
            :is-loading="isSubmitting"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
