# 60 — Chatwoot Backend Knowledge Base

Hard-won gotchas from prior debugging sessions on this fork. Read the section that matches the area you're working in. None of this is guesswork — every entry was paid for in a real bug.

Cross-references:
- Frontend gotchas → `70-frontend-knowledge.md`
- Meta webhook subscriptions → `80-meta-webhooks.md`
- Enterprise unlock → `90-enterprise-unlock-recipe.md`

---

## REST API

### `api_access_token` Must Be an HTTP Header, Not a Query Parameter

Despite many Chatwoot docs and examples showing `?api_access_token=TOKEN` as a query param, the production server in this deployment only accepts the token as an **HTTP header**:

```
-H "api_access_token: TOKEN"
```

Using `?api_access_token=TOKEN` as a query param returns **401** silently. The auth concern (`access_token_auth_helper.rb`) reads from `request.headers[:api_access_token]` only.

### `custom_attribute_definitions` Create: Params Must Be Nested + Key Is Required

`POST /api/v1/accounts/:id/custom_attribute_definitions` requires:
1. All fields nested under `custom_attribute_definition` key: `{"custom_attribute_definition": {...}}`
2. Field name is `attribute_display_name` (NOT `display_name` or `name`)
3. `attribute_key` must be provided explicitly — the model does NOT auto-generate it from the display name. Without it, you get a 422 "Attribute key can't be blank" error.

Generate keys from the source field names (e.g. strip `cf_` prefix, replace special chars with `_`).

### Freshchat → Chatwoot Field Type Mapping

| Freshchat type | Chatwoot `attribute_display_type` |
|---|---|
| 2 (dropdown) | 6 (list) |
| 5 (boolean/checkbox) | 7 (checkbox) |
| 8 (number/score) | 1 (number) |
| 17 (date) | 5 (date) |

For list type (6), pass `attribute_values: [...]` with the option strings.

### Getting an API Token via Rails Runner (Production Server)

The production Chatwoot server runs natively via RVM (not in Docker). To get an admin API token:

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx \
  'source /usr/local/rvm/scripts/rvm; rvm use 3.4.4; cd /home/chatwoot/chatwoot && RAILS_ENV=production bundle exec rails runner "AccountUser.where(role: :administrator).each{|au| puts au.user.email + \"|\" + au.user.access_token.token.to_s}" 2>&1 | grep "@"'
```

### `params[:action]` Is Reserved in Rails Controllers — Use a Different Param Name

In any Rails controller action, `params[:action]` returns the controller action name (e.g., `"create"`), not user-submitted data. If a client sends `reaction_action` as a JSON key, it must be read as `params[:reaction_action]`, not `params[:action]`. Similarly, any param named `controller` returns the controller name. Silent bug — no error, just wrong value.

---

## ActiveStorage / Attachments

### `find_signed!` Raises `InvalidSignature`, Not `RecordInvalid`

`ActiveStorage::Blob.find_signed!(signed_id)` raises `ActiveSupport::MessageVerifier::InvalidSignature` for stale or invalid blob IDs. This exception is NOT `ActiveRecord::RecordInvalid` and is NOT caught by `rescue_from ActiveRecord::RecordInvalid` in `RequestExceptionHandler`, causing an unhandled 500 even when wrapped in a transaction.

Fix: rescue it explicitly inside the map block and re-raise as `ActiveRecord::RecordInvalid`:
```ruby
blobs = file_blob_ids.map do |signed_id|
  ActiveStorage::Blob.find_signed!(signed_id)
rescue ActiveRecord::RecordNotFound, ActiveSupport::MessageVerifier::InvalidSignature
  @record.errors.add(:files, 'contains an invalid attachment reference')
  raise ActiveRecord::RecordInvalid, @record
end
```

### Direct Upload Endpoint Blocked by CSRF/WAF

`POST /rails/active_storage/direct_uploads` cannot be called from outside a browser session — it requires a CSRF token and the server WAF rejects external requests with "Request rejected" (HTML 403). To create blobs programmatically, use a Rails runner on the server:

```ruby
blob = ActiveStorage::Blob.create_and_upload!(
  io: File.open(filepath, 'rb'),
  filename: File.basename(filepath),
  content_type: content_type
  # NOTE: do NOT pass checksum: — not supported in Rails 7.1 on this server
)
```

Then attach: `record.files.attach(blob)`.

---

## CannedResponse

### CannedResponse Has No `name` Column

The `canned_responses` table only has `short_code` (string) and `content` (text) as user-facing fields. There is no `name` column. Passing `name:` to `.new()` raises `ActiveModel::UnknownAttributeError`.

### Creating Image-Only CannedResponses via Rails Runner

When `content` is nil, the `content_or_files_present` validator rejects the record. At save time, `files.attached?` is false even if you've called `.attach` — the attach hasn't persisted yet. The only working pattern is:

```ruby
cr = account.canned_responses.new(short_code: short_code, content: nil)
cr.category = category
cr.save!(validate: false)   # skip validation — files not attached yet
cr.files.attach(blob)        # now attach
```

Do NOT rely on `pending_file_ids` in Rails runner context — that mechanism only works through the API controller which sets the attribute before save.

---

## LINE Channel

### Conversation Lookup Must Mirror `IncomingMessageService#set_conversation`

When writing any service that looks up a LINE conversation by `source_id`, do NOT use a plain `find_by(contact_inboxes: { source_id: ... })` — this returns an arbitrary (often oldest) matching conversation and breaks inboxes where `lock_to_single_conversation` is false (the default), causing events to update old resolved threads instead of the active one.

Always mirror `IncomingMessageService#set_conversation`:
```ruby
contact_inbox = inbox.contact_inboxes.find_by(source_id: user_id)
return if contact_inbox.blank?

if inbox.lock_to_single_conversation
  contact_inbox.conversations.last
else
  contact_inbox.conversations.where.not(status: :resolved).last ||
    contact_inbox.conversations.last
end
```

### `markAsReadToken` Is Single-Use — Must Be Consumed After Use

LINE's `markAsReadToken` (stored in `message.additional_attributes['mark_as_read_token']`) is a single-use token. After successfully calling `POST /v2/bot/chat/markAsRead`, clear the token immediately:
```ruby
updated = message.additional_attributes.except('mark_as_read_token')
message.update_columns(additional_attributes: updated)
```
Failure to consume the token causes every subsequent agent open (with no new inbound message) to replay a stale token, resulting in rejected LINE API calls.

### `line-bot-api` Gem: Low-Level HTTP Client Signature

The gem's client (`channel.client`) exposes a low-level `post` method for endpoints not wrapped by the gem:
```ruby
channel.client.post(
  channel.client.endpoint,          # "https://api.line.me/v2"
  '/bot/chat/markAsRead',           # path
  { markAsReadToken: token }.to_json,
  channel.client.credentials        # {"Authorization" => "Bearer #{channel_token}"}
)
```
This works for any LINE Messaging API endpoint not yet wrapped by the gem (e.g., `markAsRead` is absent from gem v1.28.0).

### Outbound Messages: Persist `sentMessages` Metadata for Quote Round-Trip

After a successful `push_message` call, LINE returns `sentMessages[0].id` (the LINE-assigned message ID) and `sentMessages[0].quoteToken`. Without persisting these, the round-trip is broken:
- Customers cannot quote agent messages (no `source_id` to match against `quotedMessageId`)
- Agents cannot quote previously sent LINE messages (no stored `quote_token`)

In `perform_reply`, on `response.code == '200'`, extract and persist before calling `StatusUpdateService`:
```ruby
first_sent = parsed_json['sentMessages']&.first
if first_sent.present?
  updates = {}
  updates[:source_id] = first_sent['id'] if first_sent['id'].present? && message.source_id.blank?
  if first_sent['quoteToken'].present?
    updates[:additional_attributes] = (message.additional_attributes || {}).merge('quote_token' => first_sent['quoteToken'])
  end
  message.update!(updates) if updates.any?
end
```

### Quote/Reply: Delegate `in_reply_to` Resolution to the Message Model

When processing `quotedMessageId` in `IncomingMessageService`, do NOT look up the Chatwoot message manually and set both `in_reply_to` and `in_reply_to_external_id`. Instead, only set `in_reply_to_external_id` — the `Message` model has a `before_save :ensure_in_reply_to` callback (`Messages::InReplyToMessageBuilder`) that resolves `in_reply_to` automatically from the external ID. This is the canonical pattern used by Facebook, Instagram, WhatsApp, and TikTok channels.

---

## Inbound Recall Services

### Guard Against `after_update_commit` Feedback Loop

When writing an inbound recall/delete service (e.g., marking a message deleted in response to a webhook), always guard against the channel's outbound recall callback firing spuriously.

**The problem:** If `Message` has an `after_update_commit` callback that enqueues an outbound recall job when an outgoing message transitions to `deleted: true`, and the inbound service uses `inbox.messages.find_by(source_id: ...)` without filtering on `message_type`, a source_id collision causes the service to mark the *outgoing* message deleted — which fires the callback and makes a redundant API recall call.

**Fix:** In the inbound recall service, add `return unless message_to_delete.incoming?` immediately after the blank guard:
```ruby
message_to_delete = inbox.messages.find_by(source_id: data[:message_id].to_s)
return if message_to_delete.blank?
return unless message_to_delete.incoming?   # prevent outbound callback feedback loop
```

This pattern applies to any channel that has both an inbound recall webhook handler and an outbound recall job triggered by `after_update_commit`.

---

## Facebook / Instagram (Meta)

### `Channel::FacebookPage` Is Also Used for Instagram DM Inboxes — Distinguish by `instagram_id`

In this Chatwoot installation, Instagram Direct Message inboxes are backed by `Channel::FacebookPage` records (not `Channel::Instagram`). The only reliable way to distinguish them at runtime is `channel.instagram_id.present?`:
- `instagram_id` present → Instagram DM inbox → use Instagram Graph API
- `instagram_id` blank → regular Messenger inbox → use Facebook Messenger Send API

`Channel::FacebookPage` does NOT define `access_token`. Use `channel.page_access_token` for the token. `Channel::Instagram` uses `channel.access_token` (which auto-refreshes OAuth token).

`additional_attributes['type'] == 'instagram_direct_message'` on `Conversation` is NOT a reliable check — that field is empty on all production conversations.

### `graph.instagram.com` Rejects Page Access Tokens With Error 190

`POST https://graph.instagram.com/v22.0/<instagram_id>/messages` with a `page_access_token` returns HTTP 200 with body `{"error": {"code": 190, "message": "Invalid OAuth access token"}}`. This endpoint requires an Instagram OAuth token, NOT a page access token.

For `Channel::FacebookPage` inboxes (including Instagram DM inboxes), always use `graph.facebook.com/me/messages` (via `Facebook::Messenger::Bot.deliver`) with the `page_access_token`. This endpoint correctly handles both Messenger and Instagram DM messages for Page-backed channels.

### Both Messenger and Instagram Support `sender_action=react`

Both Messenger and Instagram support sending reactions on behalf of a page/bot via the same endpoint pattern:
```
POST https://graph.facebook.com/<VERSION>/PAGE-ID/messages?access_token=<PAGE_ACCESS_TOKEN>
Body: { recipient: {id: <PSID_or_IGSID>}, sender_action: "react", payload: {message_id: <MID>, reaction: <emoji>} }
```
For Instagram Graph API, use `https://graph.instagram.com/<VERSION>/<IG_ID>/messages` instead. Use `unreact` (without `reaction` key in payload) to remove. The `sender_action` enum also accepts `MARK_SEEN`, `TYPING_ON`, `TYPING_OFF`.

### `Channel::FacebookPage#subscribe` Must Explicitly List `message_reactions`

Meta only delivers `message_reactions` webhook callbacks when the subscribed page explicitly subscribes to the `message_reactions` field via `POST /{page-id}/subscribed_apps`. The `Channel::FacebookPage#subscribe` method builds a `subscribed_fields` string — if `message_reactions` is absent from that list, no reaction webhooks are ever delivered, even if the bot handler code is correct. Adding the field requires page re-authorization to take effect on already-connected pages.

See also `80-meta-webhooks.md` for the App-level subscription requirement.

### `Channel::FacebookPage` Factory Triggers Real HTTP on Create — Stub Required in Specs

`Channel::FacebookPage` has an `after_create_commit :subscribe` callback that calls `Facebook::Messenger::Subscriptions.subscribe` via HTTParty. In test environments with WebMock enabled, creating any `FacebookPage` record will raise `WebMock::NetConnectNotAllowedError` unless the request is stubbed:

```ruby
stub_request(:post, /graph\.facebook\.com/).to_return(status: 200, body: '', headers: {})
create(:channel_facebook_page, account: account)
```

### `Facebook::Messenger::Incoming::Common#to_json` Wraps Payload Under `"messaging"` Key

When registering a custom event with `Facebook::Messenger::Bot.on :some_event` and the handler calls `event.to_json`, the resulting JSON has the shape `{"messaging": {...raw_fields...}}`, NOT a flat object with the fields at the top level. Jobs that parse this JSON with `symbolize_names: true` and then do `messaging.dig(:recipient, :id)` will get `nil` — they must first extract the inner hash:

```ruby
parsed = JSON.parse(json, symbolize_names: true)
messaging = parsed[:messaging] || parsed
```

The existing `Facebook::UpdateMessageService` (message_edit pipeline) handles this — follow that pattern when adding new custom Messenger event types.

### `Instagram::SendReactionService#handle_response` Increments Redis Reauth Counter on Any Error 190

Any response containing `"code": 190` triggers `channel.authorization_error!`. This increments a Redis counter, and after `AUTHORIZATION_ERROR_THRESHOLD = 2` hits, Chatwoot sends a reconnect email and marks the channel as offline.

If you accidentally call this service with a wrong endpoint (e.g., `graph.instagram.com` with a page token), each failed attempt increments the counter. After the root cause is fixed, clear the counter: `channel.reauthorized!` — this resets the Redis counter and clears the disconnection state.

### `InstagramEventsJob` Reaction Webhook Payloads May Omit `sender`/`recipient`

Some Instagram reaction webhook payloads arrive without top-level `sender`/`recipient` fields in the messaging object. Code that calls `messaging[:recipient][:id]` directly will crash with `NoMethodError: undefined method '[]' for nil`. Always use `.dig(:recipient, :id)` with a fallback to the entry's `id` field (which is the Instagram account ID and matches `Channel::FacebookPage.instagram_id`):

```ruby
def instagram_id(messaging, entry_id = nil)
  if agent_message_via_echo?(messaging)
    messaging.dig(:sender, :id) || entry_id
  else
    messaging.dig(:recipient, :id) || entry_id
  end
end
# Call as: instagram_id(messaging, entry[:id])
```

---

## Rails 7.1 / Active Record

### Rejects Raw SQL in `.where.not()` and `.pick()` Without `Arel.sql()`

Any `.where.not("some_column->>'key' IS NULL")` or `.pick("jsonb_column->>'key'")` call using a plain string raises `ActiveRecord::UnknownAttributeReference: Dangerous query method called with non-attribute argument(s)` at runtime. Wrap all raw SQL fragments in `Arel.sql()`:

```ruby
# Wrong — raises ActiveRecord::UnknownAttributeReference
.where.not("additional_attributes->>'mark_as_read_token' IS NULL")
.pick("additional_attributes->>'mark_as_read_token'")

# Correct
.where.not(Arel.sql("additional_attributes->>'mark_as_read_token' IS NULL"))
.pick(Arel.sql("additional_attributes->>'mark_as_read_token'"))
```

This only surfaces at runtime (not syntax check), so tests pass locally but the job crashes in production the first time it runs.

---

## Test environment

### Running RSpec on the Native VM Server

The server's `.bundle/config` has `BUNDLE_WITHOUT: "development:test"` and `BUNDLE_DEPLOYMENT: "true"`. To run specs:

1. Override temporarily:
   ```bash
   bundle config set --local deployment false
   bundle config set --local without ''
   bundle install  # installs test/development gems
   ```
2. Create test DB (first time only):
   ```bash
   RAILS_ENV=test bundle exec rails db:create db:schema:load
   ```
3. Run specs normally with `bundle exec rspec ...`
4. **Restore before next deploy** (critical — wrong config causes 502):
   ```bash
   bundle config set --local deployment true
   bundle config set --local without 'development:test'
   ```

### Running RSpec in the Chatwoot Production Docker Container (legacy)

If you ever interact with a Docker-based deployment (this fork's Azure VM is native, not Docker — but the upstream Docker image is still relevant for reference):

The production `chatwoot/chatwoot:latest` image has `BUNDLE_WITHOUT: development:test` baked in. To run tests:

1. Override `BUNDLE_WITHOUT` by passing `-e BUNDLE_WITHOUT=""` to `docker exec`.
2. `docker exec -e BUNDLE_WITHOUT="" -w /app chatwoot-rails-1 bundle install` (once).
3. `docker exec -e BUNDLE_WITHOUT="" -e RAILS_ENV=test -w /app chatwoot-rails-1 bundle exec rspec ...`.

The image is Alpine-based and does NOT have `bash` — use `sh -c` in `docker exec` (`docker exec ... sh -c "..."`).

### Manual `Gemfile.lock` Editing When `bundle update` Fails Locally

`bundle update <gem>` may fail on local sandboxes for this repo due to C extension build failures (`bigdecimal` native extension). When a gem upgrade only changes the version number and not the dependency spec, it is safe to edit `Gemfile.lock` manually:

1. Update the gem version in the `GEM` specs section (e.g., `facebook-messenger (2.0.1)` → `(2.1.2)`)
2. Update the constraint in the `DEPENDENCIES` section (e.g., `facebook-messenger` → `facebook-messenger (~> 2.1)`)
3. Verify the runtime dependencies are unchanged (check via `curl -s "https://rubygems.org/api/v2/rubygems/<gem>/versions/<version>.json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d['dependencies']['runtime']))"`)
4. Confirm the lock file has NO `CHECKSUMS` section (this repo doesn't have one — no SHA updates needed)

The server's `bundle install` (with `BUNDLE_DEPLOYMENT: "true"`) will then correctly fetch and vendor the new version.

---

## Installation config / feature flags

### `InstallationConfig#value` Returns the Stored Type — Numeric Configs Need Explicit Cast

`InstallationConfig#value` is JSON-serialized via `serialize :value, JSON`. The returned type matches whatever was inserted: a row stored as `"9999999"` returns the **String** `"9999999"`, not Integer `9999999`. Any callsite that compares the value with `<`, `>`, etc. raises `ArgumentError: comparison of Integer with String failed` at runtime.

When reading an `InstallationConfig` row that semantically holds a number, always cast at the read site:

```ruby
(InstallationConfig.find_by(name: 'FOO_QUANTITY')&.value || 0).to_i
```

This is the same value the live admin UI writes via the form — it stores Strings even for numeric fields. PR #29 fixed this in `lib/chatwoot_hub.rb#pricing_plan_quantity`.

### `config/features.yml` Edits Do NOT Retroactively Update Existing Installs

Two layers of indirection prevent YAML feature-flag changes from taking effect on existing Chatwoot installs:

1. **`lib/config_loader.rb` runs in `reconcile_only_new: true` mode** by default (called from `lib/tasks/db_enhancements.rake`). It only inserts MISSING rows into the cached `ACCOUNT_LEVEL_FEATURE_DEFAULTS` `InstallationConfig` row — it does NOT update existing rows. So flipping `enabled: false` → `enabled: true` in `features.yml` is invisible to any install that already booted once.

2. **`Featurable#enable_default_features` runs in `before_create` only** (`app/models/concerns/featurable.rb`). Existing `Account` rows keep their `feature_flags` bitmask from when they were created — flipping the default doesn't touch them.

To actually flip a feature for an existing self-hosted install, write a data migration that does BOTH:

```ruby
# 1. Update the cached defaults row so future accounts inherit the new state
config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
features = config.value.map { |f| f['name'] == 'foo' ? f.merge('enabled' => true) : f }
config.update!(value: features)

# 2. Backfill existing accounts' feature_flags bits
Account.find_in_batches(batch_size: 100) do |batch|
  batch.each { |a| a.enable_features!('foo') }
end

GlobalConfig.clear_cache
```

Pattern: see `db/migrate/20260429111600_enable_premium_features_for_self_hosted_enterprise.rb` (PR #30) and the older `db/migrate/20250416182131_flip_chatwoot_v4_default_feature_flag_installation_config.rb`.

### `Internal::CheckNewVersionsJob` Enterprise Extension Overwrites Local Plan Config

On installs that ship `enterprise/`, the daily `internal_check_new_versions_job` (scheduled in `config/schedule.yml` at `0 0 * * *`) calls `ChatwootHub.sync_with_hub` → `https://hub.2.chatwoot.com/ping`. The enterprise extension at `enterprise/app/jobs/enterprise/internal/check_new_versions_job.rb` overrides the response handler to call `update_installation_config(key: 'INSTALLATION_PRICING_PLAN', value: @instance_info['plan'])` — silently overwriting locally-managed `INSTALLATION_PRICING_PLAN` and `INSTALLATION_PRICING_PLAN_QUANTITY` rows with whatever the hub returns.

For self-hosted enterprise installs that manage these values directly in `InstallationConfig`, this is a silent-regression hazard. PR #30 dropped the cron entry. See `90-enterprise-unlock-recipe.md` for the full unlock.
