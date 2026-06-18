<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, requiredIf } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';

export default {
  components: {
    NextButton,
    Modal,
    WootMessageEditor,
  },
  props: {
    id: { type: Number, default: null },
    edcontent: { type: String, default: '' },
    edshortCode: { type: String, default: '' },
    edfiles: { type: Array, default: () => [] },
    edcategoryId: { type: Number, default: null },
    onClose: { type: Function, default: () => {} },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      editCanned: {
        showAlert: false,
        showLoading: false,
      },
      shortCode: this.edshortCode,
      content: this.edcontent,
      localCategoryId: this.edcategoryId,
      show: true,
      attachedFiles: (this.edfiles || []).map(f => ({
        fileUrl: f.file_url,
        blobId: f.blob_signed_id,
        filename: f.filename,
      })),
      isUploading: false,
    };
  },
  validations() {
    return {
      shortCode: {
        required,
        minLength: minLength(2),
      },
      localCategoryId: {
        required,
      },
      content: {
        required: requiredIf(() => this.attachedFiles.length === 0),
      },
    };
  },
  computed: {
    ...mapGetters({
      categories: 'cannedResponseCategory/getCannedResponseCategories',
    }),
    pageTitle() {
      return `${this.$t('CANNED_MGMT.EDIT.TITLE')} - ${this.edshortCode}`;
    },
    contentHasError() {
      return this.v$.content.$error && this.attachedFiles.length === 0;
    },
    isSubmitDisabled() {
      return (
        (this.v$.content.$invalid && this.attachedFiles.length === 0) ||
        this.v$.shortCode.$invalid ||
        this.v$.localCategoryId.$invalid ||
        this.editCanned.showLoading ||
        this.isUploading
      );
    },
  },
  watch: {
    edcategoryId(newVal) {
      this.localCategoryId = newVal;
    },
  },
  methods: {
    resetForm() {
      this.shortCode = '';
      this.content = '';
      this.localCategoryId = null;
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
    editCannedResponse() {
      this.editCanned.showLoading = true;
      this.$store
        .dispatch('updateCannedResponse', {
          id: this.id,
          short_code: this.shortCode,
          content: this.content,
          category_id: this.localCategoryId,
          file_ids: this.attachedFiles.map(f => f.blobId),
        })
        .then(() => {
          this.editCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.EDIT.API.SUCCESS_MESSAGE'));
          this.resetForm();
          setTimeout(() => {
            this.onClose();
          }, 10);
        })
        .catch(error => {
          this.editCanned.showLoading = false;
          const errorMessage =
            error?.message || this.$t('CANNED_MGMT.EDIT.API.ERROR_MESSAGE');
          useAlert(errorMessage);
        });
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="pageTitle" />
      <form class="flex flex-col w-full" @submit.prevent="editCannedResponse()">
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.EDIT.FORM.SHORT_CODE.LABEL') }}
            <input
              v-model="shortCode"
              type="text"
              :placeholder="$t('CANNED_MGMT.EDIT.FORM.SHORT_CODE.PLACEHOLDER')"
              @input="v$.shortCode.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label>
            {{ $t('CANNED_MGMT.CATEGORY.LABEL') }}
            <select v-model="localCategoryId">
              <option
                v-for="category in categories"
                :key="category.id"
                :value="category.id"
              >
                {{ category.name }}
              </option>
            </select>
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: contentHasError }">
            {{ $t('CANNED_MGMT.EDIT.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <WootMessageEditor
              v-model="content"
              class="message-editor [&>div]:px-1"
              :class="{ editor_warning: contentHasError }"
              channel-type="Context::Default"
              enable-variables
              :enable-canned-responses="false"
              :placeholder="$t('CANNED_MGMT.EDIT.FORM.CONTENT.PLACEHOLDER')"
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
            :label="$t('CANNED_MGMT.EDIT.CANCEL_BUTTON_TEXT')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CANNED_MGMT.EDIT.FORM.SUBMIT')"
            :disabled="isSubmitDisabled"
            :is-loading="editCanned.showLoading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>

<style scoped lang="scss">
:deep(.ProseMirror-menubar) {
  @apply hidden;
}

:deep(.ProseMirror-woot-style) {
  @apply min-h-[12.5rem];

  p {
    @apply text-base;
  }
}
</style>
