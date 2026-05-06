<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, requiredIf } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { uploadFile } from 'dashboard/helper/uploadHelper';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';

export default {
  name: 'AddCanned',
  components: {
    NextButton,
    Modal,
    WootMessageEditor,
  },
  props: {
    responseContent: {
      type: String,
      default: '',
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
      shortCode: '',
      content: this.responseContent || '',
      categoryId: null,
      addCanned: {
        showLoading: false,
        message: '',
      },
      show: true,
      attachedFiles: [],
      isUploading: false,
    };
  },
  computed: {
    ...mapGetters({
      categories: 'cannedResponseCategory/getCannedResponseCategories',
    }),
    hasNoCategories() {
      return this.categories.length === 0;
    },
    contentHasError() {
      return this.v$.content.$error && this.attachedFiles.length === 0;
    },
    isSubmitDisabled() {
      return (
        (this.v$.content.$invalid && this.attachedFiles.length === 0) ||
        this.v$.shortCode.$invalid ||
        this.v$.categoryId.$invalid ||
        this.addCanned.showLoading ||
        this.isUploading
      );
    },
  },
  watch: {
    // Default to the first category as soon as the list arrives. The parent
    // (Index.vue) dispatches `getCannedResponseCategories` on mount, so this
    // typically fires once shortly after the modal opens.
    categories: {
      immediate: true,
      handler(list) {
        if (this.categoryId == null && list.length) {
          this.categoryId = list[0].id;
        }
      },
    },
  },
  validations() {
    return {
      shortCode: {
        required,
        minLength: minLength(2),
      },
      categoryId: {
        required,
      },
      content: {
        required: requiredIf(() => this.attachedFiles.length === 0),
      },
    };
  },
  methods: {
    resetForm() {
      this.shortCode = '';
      this.content = '';
      // Restore the default selection rather than null; the form re-validates
      // immediately and an empty selection would surface a noisy error.
      this.categoryId = this.categories.length ? this.categories[0].id : null;
      this.attachedFiles = [];
      this.v$.shortCode.$reset();
      this.v$.content.$reset();
    },
    async onFileSelect(event) {
      const files = Array.from(event.target.files);
      if (!files.length) return;

      this.isUploading = true;
      try {
        const uploads = await Promise.all(
          files.map(async file => {
            const { fileUrl, blobId } = await uploadFile(file);
            return { fileUrl, blobId, filename: file.name };
          })
        );
        this.attachedFiles.push(...uploads);
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.FILES.UPLOAD_ERROR'));
      } finally {
        this.isUploading = false;
        event.target.value = '';
      }
    },
    removeFile(index) {
      this.attachedFiles.splice(index, 1);
    },
    addCannedResponse() {
      this.addCanned.showLoading = true;
      const payload = {
        short_code: this.shortCode,
        content: this.content,
        category_id: this.categoryId,
      };
      if (this.attachedFiles.length) {
        payload.file_ids = this.attachedFiles.map(f => f.blobId);
      }
      this.$store
        .dispatch('createCannedResponse', payload)
        .then(() => {
          this.addCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.ADD.API.SUCCESS_MESSAGE'));
          this.resetForm();
          this.onClose();
        })
        .catch(error => {
          this.addCanned.showLoading = false;
          const errorMessage =
            error?.message || this.$t('CANNED_MGMT.ADD.API.ERROR_MESSAGE');
          useAlert(errorMessage);
        });
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('CANNED_MGMT.ADD.TITLE')"
        :header-content="$t('CANNED_MGMT.ADD.DESC')"
      />
      <form class="flex flex-col w-full" @submit.prevent="addCannedResponse()">
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.ADD.FORM.SHORT_CODE.LABEL') }}
            <input
              v-model="shortCode"
              type="text"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.SHORT_CODE.PLACEHOLDER')"
              @blur="v$.shortCode.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label>
            {{ $t('CANNED_MGMT.CATEGORY.LABEL') }}
            <select v-model="categoryId" :disabled="hasNoCategories">
              <option
                v-for="category in categories"
                :key="category.id"
                :value="category.id"
              >
                {{ category.name }}
              </option>
            </select>
          </label>
          <p v-if="hasNoCategories" class="text-xs text-n-ruby-9 mt-1">
            {{ $t('CANNED_MGMT.CATEGORY.EMPTY_HINT') }}
          </p>
        </div>

        <div class="w-full">
          <label :class="{ error: contentHasError }">
            {{ $t('CANNED_MGMT.ADD.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <WootMessageEditor
              v-model="content"
              class="message-editor [&>div]:px-1"
              :class="{ editor_warning: contentHasError }"
              channel-type="Context::Default"
              enable-variables
              :enable-canned-responses="false"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.CONTENT.PLACEHOLDER')"
              @blur="v$.content.$touch"
            />
          </div>
        </div>

        <div class="w-full">
          <label>{{ $t('CANNED_MGMT.FILES.LABEL') }}</label>
          <div v-if="attachedFiles.length" class="flex flex-wrap gap-2 mb-2">
            <div
              v-for="(file, index) in attachedFiles"
              :key="file.blobId"
              class="relative group"
            >
              <img
                :src="file.fileUrl"
                :alt="file.filename"
                class="w-16 h-16 object-cover rounded-lg border border-n-weak"
              />
              <button
                type="button"
                class="absolute -top-1.5 -right-1.5 size-5 rounded-full bg-n-slate-12 text-n-slate-1 flex items-center justify-center text-xs opacity-0 group-hover:opacity-100 transition-opacity"
                :aria-label="$t('CANNED_MGMT.FILES.REMOVE_FILE')"
                @click="removeFile(index)"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  class="size-3"
                >
                  <path d="M18 6 6 18M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>
          <label
            class="flex h-8 items-center gap-2 px-3 py-1 text-xs cursor-pointer rounded-lg border border-dashed border-n-strong hover:bg-n-alpha-2 transition-colors w-fit"
            :class="{ 'opacity-50 pointer-events-none': isUploading }"
          >
            <input
              type="file"
              accept="image/png, image/jpeg, image/gif, image/webp"
              multiple
              class="hidden"
              @change="onFileSelect"
            />
            <span>{{
              isUploading
                ? $t('CANNED_MGMT.FILES.UPLOADING')
                : $t('CANNED_MGMT.FILES.ADD_BUTTON')
            }}</span>
          </label>
        </div>

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('CANNED_MGMT.ADD.CANCEL_BUTTON_TEXT')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CANNED_MGMT.ADD.FORM.SUBMIT')"
            :disabled="isSubmitDisabled"
            :is-loading="addCanned.showLoading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>

<style scoped lang="scss">
::v-deep {
  .ProseMirror-menubar {
    @apply hidden;
  }

  .ProseMirror-woot-style {
    @apply min-h-[12.5rem];

    p {
      @apply text-base;
    }
  }
}
</style>
