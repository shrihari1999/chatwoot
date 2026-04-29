<script setup>
import {
  computed,
  onMounted,
  nextTick,
  onUnmounted,
  useTemplateRef,
  inject,
} from 'vue';
import { useWindowSize, useElementBounding, useScrollLock } from '@vueuse/core';

import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

const props = defineProps({
  x: { type: Number, default: 0 },
  y: { type: Number, default: 0 },
});

const emit = defineEmits(['close']);

const elementToLock = inject('contextMenuElementTarget', null);

const menuRef = useTemplateRef('menuRef');

const scrollLockElement = computed(() => {
  if (!elementToLock?.value) return null;
  return elementToLock.value?.$el;
});

const isLocked = useScrollLock(scrollLockElement);

const { width: windowWidth, height: windowHeight } = useWindowSize();
const { width: menuWidth, height: menuHeight } = useElementBounding(menuRef);

const calculatePosition = (x, y, menuW, menuH, windowW, windowH) => {
  const PADDING = 16;
  // Initial position
  let left = x;
  let top = y;
  // Boundary checks
  const isOverflowingRight = left + menuW > windowW - PADDING;
  const isOverflowingBottom = top + menuH > windowH - PADDING;
  // Adjust position if overflowing
  if (isOverflowingRight) left = windowW - menuW - PADDING;
  if (isOverflowingBottom) top = windowH - menuH - PADDING;
  return {
    left: Math.max(PADDING, left),
    top: Math.max(PADDING, top),
  };
};

const position = computed(() => {
  if (!menuRef.value) return { top: `${props.y}px`, left: `${props.x}px` };

  const { left, top } = calculatePosition(
    props.x,
    props.y,
    menuWidth.value,
    menuHeight.value,
    windowWidth.value,
    windowHeight.value
  );

  return {
    top: `${top}px`,
    left: `${left}px`,
  };
});

onMounted(() => {
  isLocked.value = true;
  nextTick(() => menuRef.value?.focus());
});

const handleClose = () => {
  isLocked.value = false;
  emit('close');
};

// Close on blur EXCEPT when focus is moving to a focusable descendant of
// the menu (e.g. a real <button> like the reaction emoji buttons). Without
// this guard, mousedown on a child button shifts focus off the wrapper,
// blur fires, the menu unmounts, and the button's @click never fires —
// see the reaction row in MessageContextMenu.vue.
//
// Note: `event.relatedTarget` can be null in Safari/older WebKit when
// clicking certain non-form elements, so we ALSO call preventDefault on
// the wrapper's mousedown (see template) to keep focus on the wrapper
// during clicks on descendants. The blur guard remains as a belt-and-
// suspenders fallback for keyboard focus shifts.
const handleBlur = event => {
  if (event.relatedTarget && menuRef.value?.contains(event.relatedTarget)) {
    return;
  }
  handleClose();
};

// Prevent mousedown on descendants from shifting focus off the wrapper.
// This is the primary defense against the blur-before-click bug; it works
// uniformly across browsers (including Safari) where `relatedTarget` may
// be null. We skip text inputs / contenteditable so callers can still
// embed inputs inside the menu and have caret placement work normally.
const handleMouseDown = event => {
  const target = event.target;
  if (!menuRef.value?.contains(target)) return;
  const tag = target.tagName;
  if (
    tag === 'INPUT' ||
    tag === 'TEXTAREA' ||
    tag === 'SELECT' ||
    target.isContentEditable
  ) {
    return;
  }
  event.preventDefault();
};

onUnmounted(() => {
  isLocked.value = false;
});
</script>

<template>
  <TeleportWithDirection to="body">
    <div
      ref="menuRef"
      class="fixed outline-none z-[9999] cursor-pointer"
      :style="position"
      tabindex="0"
      @mousedown="handleMouseDown"
      @blur="handleBlur"
    >
      <slot />
    </div>
  </TeleportWithDirection>
</template>
