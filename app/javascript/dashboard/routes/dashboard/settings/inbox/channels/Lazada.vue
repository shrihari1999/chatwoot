<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import router from '../../../../index';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    PageHeader,
    NextButton,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      channelName: '',
      shopId: '',
      appKey: '',
      appSecret: '',
      accessToken: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
  },
  validations: {
    channelName: { required },
    shopId: { required },
    appKey: { required },
    appSecret: { required },
    accessToken: { required },
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const lazadaChannel = await this.$store.dispatch(
          'inboxes/createChannel',
          {
            name: this.channelName?.trim(),
            channel: {
              type: 'lazada',
              shop_id: this.shopId,
              app_key: this.appKey,
              app_secret: this.appSecret,
              access_token: this.accessToken,
            },
          }
        );

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: lazadaChannel.id,
          },
        });
      } catch (error) {
        useAlert(
          this.$t('INBOX_MGMT.ADD.LAZADA_CHANNEL.API.ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.LAZADA_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.LAZADA_CHANNEL.DESC')"
    />
    <form
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createChannel()"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.channelName.$error }">
          {{ $t('INBOX_MGMT.ADD.LAZADA_CHANNEL.CHANNEL_NAME.LABEL') }}
          <input
            v-model="channelName"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.LAZADA_CHANNEL.CHANNEL_NAME.PLACEHOLDER')
            "
            @blur="v$.channelName.$touch"
          />
          <span v-if="v$.channelName.$error" class="message">{{
            $t('INBOX_MGMT.ADD.LAZADA_CHANNEL.CHANNEL_NAME.ERROR')
          }}</span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.shopId.$error }">
          {{ $t('INBOX_MGMT.ADD.LAZADA_CHANNEL.SHOP_ID.LABEL') }}
          <input
            v-model="shopId"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.LAZADA_CHANNEL.SHOP_ID.PLACEHOLDER')
            "
            @blur="v$.shopId.$touch"
          />
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.appKey.$error }">
          {{ $t('INBOX_MGMT.ADD.LAZADA_CHANNEL.APP_KEY.LABEL') }}
          <input
            v-model="appKey"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.LAZADA_CHANNEL.APP_KEY.PLACEHOLDER')
            "
            @blur="v$.appKey.$touch"
          />
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.appSecret.$error }">
          {{ $t('INBOX_MGMT.ADD.LAZADA_CHANNEL.APP_SECRET.LABEL') }}
          <input
            v-model="appSecret"
            type="password"
            :placeholder="
              $t('INBOX_MGMT.ADD.LAZADA_CHANNEL.APP_SECRET.PLACEHOLDER')
            "
            @blur="v$.appSecret.$touch"
          />
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.accessToken.$error }">
          {{ $t('INBOX_MGMT.ADD.LAZADA_CHANNEL.ACCESS_TOKEN.LABEL') }}
          <input
            v-model="accessToken"
            type="password"
            :placeholder="
              $t('INBOX_MGMT.ADD.LAZADA_CHANNEL.ACCESS_TOKEN.PLACEHOLDER')
            "
            @blur="v$.accessToken.$touch"
          />
        </label>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="uiFlags.isCreating"
          type="submit"
          solid
          blue
          :label="$t('INBOX_MGMT.ADD.LAZADA_CHANNEL.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
