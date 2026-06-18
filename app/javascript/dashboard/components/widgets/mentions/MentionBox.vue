<script setup>
import { ref, watch, computed, nextTick } from 'vue';
import { useKeyboardNavigableList } from 'dashboard/composables/useKeyboardNavigableList';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  type: {
    type: String,
    default: 'canned',
  },
});

const emit = defineEmits(['mentionSelect']);

const { getPlainText } = useMessageFormatter();

const mentionsListContainerRef = ref(null);

const isHeader = item => item && item.type === 'header';

const firstSelectableIndex = items => {
  const idx = items.findIndex(item => !isHeader(item));
  return idx === -1 ? 0 : idx;
};

const selectedIndex = ref(firstSelectableIndex(props.items));
let previousIndex = selectedIndex.value;

// If the current selectedIndex points to a header, move to the next
// non-header item in the same direction the user was moving. Wraps
// around if needed. This keeps header rows visually present but
// non-navigable via keyboard/hover.
const skipHeaderIfNeeded = () => {
  const items = props.items;
  if (!items.length) return;
  if (!isHeader(items[selectedIndex.value])) {
    previousIndex = selectedIndex.value;
    return;
  }

  // Determine direction from the navigation step. The composable
  // moves by ±1 (with wrap-around), so the modular distance tells us
  // whether we just moved down (distance === 1) or up (distance === len - 1).
  const diff =
    (selectedIndex.value - previousIndex + items.length) % items.length;
  const movingDown = diff === 1 || diff === 0;
  const step = movingDown ? 1 : -1;

  let next = selectedIndex.value;
  for (let i = 0; i < items.length; i += 1) {
    next = (next + step + items.length) % items.length;
    if (!isHeader(items[next])) {
      selectedIndex.value = next;
      previousIndex = next;
      return;
    }
  }
  // All items are headers (should not happen in practice).
  previousIndex = selectedIndex.value;
};

const adjustScroll = () => {
  nextTick(() => {
    const container = mentionsListContainerRef.value;
    if (!container) return;
    const selectedElement = container.querySelector(
      `#mention-item-${selectedIndex.value}`
    );
    if (selectedElement) {
      selectedElement.scrollIntoView({ block: 'nearest', behavior: 'auto' });
    }
  });
};

const onSelect = () => {
  const item = props.items[selectedIndex.value];
  if (!item || isHeader(item)) return;
  emit('mentionSelect', item);
};

useKeyboardNavigableList({
  items: computed(() => props.items),
  onSelect,
  adjustScroll,
  selectedIndex,
});

watch(
  () => props.items,
  newItems => {
    if (
      newItems.length < selectedIndex.value + 1 ||
      isHeader(newItems[selectedIndex.value])
    ) {
      selectedIndex.value = firstSelectableIndex(newItems);
      previousIndex = selectedIndex.value;
    }
  }
);

watch(selectedIndex, () => {
  skipHeaderIfNeeded();
  adjustScroll();
});

const onHover = (index, item) => {
  if (isHeader(item)) return;
  selectedIndex.value = index;
};

const onListItemSelection = (index, item) => {
  if (isHeader(item)) return;
  selectedIndex.value = index;
  onSelect();
};

const variableKey = (item = {}) => {
  return props.type === 'variable' ? `{{${item.label}}}` : `/${item.label}`;
};
</script>

<template>
  <div
    ref="mentionsListContainerRef"
    class="bg-n-solid-1 p-1 rounded-xl overflow-auto absolute w-full z-20 shadow-md left-0 bottom-full max-h-[9.75rem] border border-solid border-n-strong mention--box"
  >
    <ul class="mb-0 vertical dropdown menu">
      <template v-for="(item, index) in items">
        <li
          v-if="item.type === 'header'"
          :id="`mention-item-${index}`"
          :key="`mention-header-${index}-${item.label}`"
          class="px-3 pt-2 pb-1 text-xs font-medium uppercase tracking-wide text-n-slate-10 select-none pointer-events-none"
          aria-hidden="true"
        >
          {{ item.label }}
        </li>
        <woot-dropdown-item
          v-else
          :id="`mention-item-${index}`"
          :key="item.key"
          class="!mb-1"
          @mouseover="onHover(index, item)"
        >
          <button
            class="flex rounded-lg group flex-col gap-0.5 overflow-hidden cursor-pointer items-start px-3 py-2 justify-center w-full h-full text-left hover:bg-n-alpha-black2"
            :class="{
              'bg-n-alpha-black2': index === selectedIndex,
            }"
            @click="onListItemSelection(index, item)"
          >
            <slot
              :item="item"
              :index="index"
              :selected="index === selectedIndex"
            >
              <p
                class="max-w-full min-w-0 mb-0 overflow-hidden text-sm font-medium text-n-slate-11 group-hover:text-n-slate-12 text-ellipsis whitespace-nowrap"
                :class="{
                  'text-n-slate-12': index === selectedIndex,
                }"
              >
                {{ getPlainText(item.description) }}
              </p>
              <p
                class="max-w-full min-w-0 mb-0 overflow-hidden text-xs text-n-slate-11 group-hover:text-n-slate-12 text-ellipsis whitespace-nowrap"
                :class="{
                  'text-n-slate-12': index === selectedIndex,
                }"
              >
                {{ variableKey(item) }}
              </p>
            </slot>
          </button>
        </woot-dropdown-item>
      </template>
    </ul>
  </div>
</template>

<style scoped lang="scss">
.mention--box {
  .dropdown-menu__item:last-child > button {
    @apply border-0;
  }
}

.canned-item__button :deep(.button__content) {
  @apply overflow-hidden text-ellipsis whitespace-nowrap;
}
</style>
