<script setup>
import { ref } from 'vue';
import InboxReconnectionRequired from '../../components/InboxReconnectionRequired.vue';

import tiktokShopClient from 'dashboard/api/channel/tiktokShopClient';

import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();

const isRequestingAuthorization = ref(false);

async function requestAuthorization() {
  try {
    isRequestingAuthorization.value = true;
    const response = await tiktokShopClient.generateAuthorization();

    const {
      data: { url },
    } = response;

    window.location.href = url;
  } catch (error) {
    useAlert(t('INBOX_MGMT.ADD.TIKTOK_SHOP.ERROR_AUTH'));
  } finally {
    isRequestingAuthorization.value = false;
  }
}
</script>

<template>
  <InboxReconnectionRequired class="mx-6" @reauthorize="requestAuthorization" />
</template>
