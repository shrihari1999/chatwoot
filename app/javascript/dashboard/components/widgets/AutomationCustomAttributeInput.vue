<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  modelValue: {
    type: [Array, Object, String, Number],
    default: null,
  },
  attributes: {
    type: Array,
    default: () => [],
  },
  dropdownMaxHeight: {
    type: String,
    default: 'max-h-80',
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const TEXT_TYPES = ['text', 'link'];

const normalizedValue = computed(() => {
  const raw = props.modelValue;
  if (Array.isArray(raw)) return raw[0] || {};
  if (raw && typeof raw === 'object') return raw;
  return {};
});

const selectedAttribute = computed(() =>
  props.attributes.find(attr => attr.id === normalizedValue.value.attribute_key)
);

const attributeSelectModel = computed({
  get() {
    if (!selectedAttribute.value) return null;
    return {
      id: selectedAttribute.value.id,
      name: selectedAttribute.value.name,
    };
  },
  set(option) {
    emit('update:modelValue', {
      attribute_key: option?.id || null,
      value: null,
    });
  },
});

const booleanOptions = computed(() => [
  { id: true, name: t('AUTOMATION.ACTION.BOOLEAN_TRUE') },
  { id: false, name: t('AUTOMATION.ACTION.BOOLEAN_FALSE') },
]);

const listOptions = computed(() => {
  if (!selectedAttribute.value) return [];
  return (selectedAttribute.value.values || []).map(v => ({ id: v, name: v }));
});

const valueOptions = computed(() => {
  if (!selectedAttribute.value) return [];
  if (selectedAttribute.value.type === 'checkbox') return booleanOptions.value;
  if (selectedAttribute.value.type === 'list') return listOptions.value;
  return [];
});

const valueSelectModel = computed({
  get() {
    const v = normalizedValue.value.value;
    if (v === null || v === undefined) return null;
    return valueOptions.value.find(option => option.id === v) || null;
  },
  set(option) {
    emit('update:modelValue', {
      attribute_key: normalizedValue.value.attribute_key,
      value: option ? option.id : null,
    });
  },
});

const textValue = computed({
  get() {
    return normalizedValue.value.value ?? '';
  },
  set(newValue) {
    emit('update:modelValue', {
      attribute_key: normalizedValue.value.attribute_key,
      value: newValue,
    });
  },
});

const isTextType = computed(
  () =>
    selectedAttribute.value && TEXT_TYPES.includes(selectedAttribute.value.type)
);
const isSelectType = computed(
  () =>
    selectedAttribute.value &&
    ['checkbox', 'list'].includes(selectedAttribute.value.type)
);
</script>

<template>
  <SingleSelect
    v-model="attributeSelectModel"
    :options="attributes"
    :dropdown-max-height="dropdownMaxHeight"
    :placeholder="$t('AUTOMATION.ACTION.CUSTOM_ATTRIBUTE_PLACEHOLDER')"
    disable-deselect
    class="flex-shrink-0"
  />
  <SingleSelect
    v-if="isSelectType"
    v-model="valueSelectModel"
    :options="valueOptions"
    :dropdown-max-height="dropdownMaxHeight"
    :placeholder="
      $t('AUTOMATION.ACTION.CUSTOM_ATTRIBUTE_VALUE_SELECT_PLACEHOLDER')
    "
    disable-deselect
    class="flex-shrink-0"
  />
  <NextInput
    v-else-if="isTextType"
    v-model="textValue"
    type="text"
    size="sm"
    :placeholder="$t('AUTOMATION.ACTION.CUSTOM_ATTRIBUTE_VALUE_PLACEHOLDER')"
  />
</template>
