# 70 — Frontend Knowledge Base

Vue 3 + Vite + Vuex on this fork. Read this whenever you touch `app/javascript/`.

Cross-references:
- Backend gotchas → `60-chatwoot-knowledge.md`
- Bundle/build verification on the live VM → `30-deploy-and-verify.md`

---

## Vuelidate v2: `requiredIf` Must Use Function Form of `validations()`

In Vuelidate v2 (Options API), if `validations` is defined as a plain **object** (not a function), `requiredIf(() => someData)` is evaluated once at component creation and never re-evaluated when reactive data changes. The result: a field can appear valid even when the condition has changed.

Fix: define `validations` as a **function** that returns the object:
```javascript
// Wrong — requiredIf callback is not reactive
validations: {
  content: { required: requiredIf(() => this.attachedFiles.length === 0) }
}

// Correct — re-evaluated on each render cycle
validations() {
  return {
    content: { required: requiredIf(() => this.attachedFiles.length === 0) }
  }
}
```

---

## CannedResponse.vue: MentionBox Default Slot

`CannedResponse.vue` uses `MentionBox` which exposes a default slot with `{ item, index, selected }` props. Override the slot to customize how each suggestion item renders. Do not destructure `index` in the slot template — it is unused and triggers an ESLint unused-vars error.

---

## `handleMentionClick` + `MessageMarkdownTransformer`

`handleMentionClick` in `CannedResponse.vue` calls `this.$emit('replace', item.description)`. If `item.description` is `null` or `undefined`, the `replace` handler calls `MessageMarkdownTransformer.parse(undefined)`, which throws. The exception is swallowed silently and the subsequent `attachFiles` emit never runs. Guard: only emit `replace` when `item.description` is truthy.

---

## Deleted Message UI Behavior

Messages with `content_attributes.deleted == true` are NOT hidden — they stay in the conversation timeline as a tombstone. The `content` field is replaced with the i18n string `"This message was deleted"` (`config/locales/en.yml` key: `conversations.messages.deleted`). Attachments are destroyed. The context menu options (Copy, Translate, Delete, Save as Canned Response) are all disabled for deleted messages. Read receipt / delivery status is also hidden. This applies to both agent-deleted and channel-recall-deleted messages.

---

## `INBOX_FEATURE_MAP` Is Duplicated — Both Files Must Be Updated Together

The `INBOX_FEATURE_MAP` (including the `REPLY_TO_OUTGOING` array) is defined in **two separate files**:
- `app/javascript/shared/mixins/inboxMixin.js` (legacy Options API mixin layer)
- `app/javascript/dashboard/composables/useInbox.js` (Composition API / `components-next` layer)

Both files must always be updated together when adding or removing inbox types from any feature flag array. Missing one causes the feature to appear broken in whichever UI layer uses the unpatched file. This is pre-existing tech debt with no single source of truth.

---

## Verifying a string made it into the built bundle — check ALL chunks

Vite chunk-splitting in Chatwoot puts the Vuex store and other shared modules in a separate chunk file whose name is derived from another entry (e.g. `public/vite/assets/DashboardIcon-<hash>.js`), not the main `dashboard-<hash>.js`. When grepping a deployed bundle to confirm a code change is live, search across all chunks:

```bash
grep -lR '<marker>' public/vite/assets/
```

A negative result against just `dashboard-*.js` is misleading — store/action/mutation code routinely lands in a different chunk.

---

## `pnpm build` is not a script — use `bundle exec bin/vite build`

Chatwoot's `package.json` only defines `build:sdk` (for the embedding SDK), not a generic `build` script. Running `pnpm build` fails with `ERR_PNPM_RECURSIVE_EXEC_FIRST_FAIL`. To rebuild dashboard assets on the server:

```bash
RAILS_ENV=production NODE_ENV=production bundle exec bin/vite build
# or the canonical
RAILS_ENV=production NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider" bundle exec rake assets:precompile
```

The `rake assets:precompile` path is preferred — it calls vite via vite_rails hooks and also writes the manifest correctly.

---

## `ContextMenu.vue` blur-before-click breaks real `<button>` children

`app/javascript/dashboard/components/ui/ContextMenu.vue` wraps the menu in a focusable `<div tabindex="0" @blur="handleClose">`. Children that are real `<button>` (or `<input>`/`<a href>`/`<select>`) elements take focus on `mousedown`. Sequence: mousedown → button focuses → wrapper blurs → `handleClose` emits `close` → menu unmounts → button removed before its `click` event can fire → handler never runs. Symptom: clicking the child does literally nothing (no API call, no error).

Other ContextMenu consumers that use only `<div role="button">` MenuItems (which don't take focus on mousedown) are unaffected, which makes the bug easy to misdiagnose as "only the reaction row is broken".

Robust fix on the wrapper:
1. `@mousedown` handler that calls `event.preventDefault()` when the target is a focusable descendant — keeps focus on the wrapper across browsers (Safari can deliver `blur.relatedTarget === null` for some non-form elements, so a `relatedTarget`-only guard is not sufficient).
2. `@blur` handler that returns early when `event.relatedTarget` is contained in the wrapper — fallback for keyboard focus shifts.
3. Skip preventDefault for `INPUT`/`TEXTAREA`/`SELECT`/`isContentEditable` so embedded inputs still receive caret placement.

---

## Emoji variation selector (U+FE0F) makes byte-level lookups miss

`❤` is `\u2764`; `❤️` is `\u2764\uFE0F`. Facebook can deliver either form for the same logical reaction, and Chatwoot stores reactions as a hash keyed by emoji string (`{ "<emoji>": ["<sender>", ...] }`). A naive `reactions[emoji]` lookup misses when the stored key has a different variation-selector form than the lookup key.

When comparing emoji keys (e.g. "did this user already react with this emoji?"), normalize both sides by stripping `\uFE0F`:
```js
const target = emoji.replace(/\uFE0F/g, '');
const matchedKey = Object.keys(reactions).find(
  key => key.replace(/\uFE0F/g, '') === target && reactions[key].includes(senderId)
);
```
Then send the original stored key (`matchedKey`) back to the API on toggle/unreact so the backend clears the same bucket it stored under.

---

## `INBOX_TYPES.FB` Covers Both Facebook Messenger AND Instagram DMs

`INBOX_TYPES.FB` = `'Channel::FacebookPage'` is the inbox type for both:
- Facebook Messenger conversations
- Instagram DM conversations on a Facebook Page inbox

The standalone Instagram channel is `INBOX_TYPES.INSTAGRAM` = `'Channel::Instagram'` and is a completely separate type. When adding a feature to Facebook Messenger inboxes, check whether the feature should also apply to Instagram DMs (they use the same channel class but different send services: `Facebook::SendOnFacebookService` delegates to `Instagram::BaseSendService` for DMs). The backend distinguishes them via `channel.instagram_id.present?` — see `60-chatwoot-knowledge.md` for the runtime check.

---

## Styling rules (recap from `AGENTS.md`)

- Tailwind utility classes only.
- No custom CSS. No scoped CSS. No inline styles.
- Refer to `tailwind.config.js` for the color palette — don't hardcode hex codes.
- Vue components are PascalCase (`MyComponent.vue`); events are camelCase (`@my-event`).

If you find yourself wanting to reach for `<style scoped>`, that is a signal to either lift the styling into Tailwind utility classes or extract a child component.
