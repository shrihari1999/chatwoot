# TikTok Shop Channel Integration — Plan & Scaffold

**Status:** Scaffolding committed. All TikTok Shop API specifics resolved against
the official Partner Center docs. End-to-end testing still requires a TikTok Shop
Partner Center developer app + approval.
**Branch:** `vorflux/tiktok-shop-integration`

---

## 1. Why this exists

TikTok Shop messaging and TikTok Business Messaging are **distinct systems**. Buyer
messages to a shop appear in TikTok Seller Center and through any integrated
Customer Service API consumer (e.g. Freshchat) — they are not delivered to the
Business Messaging API that the existing `Channel::Tiktok` consumes. That is why
test DMs to `@TheRollingPinn`'s shop reach Freshchat but never Chatwoot.

Direct quote from TikTok's Business Messaging FAQ:

> "TikTok Business Messaging and TikTok Shop Messaging are distinct messaging
> systems. Integration with the TikTok Business Messaging API does not allow
> management of TikTok Shop Messages."

We therefore introduce `Channel::TiktokShop`, dedicated to the Shop Customer
Service API (v202309).

## 2. Reference architecture — modelled on Lazada with OAuth (Tiktok-style)

| Aspect | Lazada | TikTok Shop |
|---|---|---|
| Auth | Manual app_key/app_secret/access_token | OAuth 3-legged via `services.tiktokshop.com/open/authorize` |
| Token lifecycle | Static | Access token = 7 days, refresh handled by `TokenService` |
| Shop identifier | `shop_id` | `shop_id` + `shop_cipher` (cipher required in API calls; obtained via Get Authorized Shops after OAuth) |
| Webhook routing | `/webhooks/lazada/:shop_id` | `/webhooks/tiktok_shop` (single endpoint; shop disambiguated by payload `shop_id`) |

## 3. Confirmed API specs (resolved from official docs)

### OAuth flow

```
Step 1 — User redirected to:
   https://services.tiktokshop.com/open/authorize?service_id=<service_id>&state=<jwt>
   (US sellers: services.us.tiktokshop.com)
   Note: service_id is distinct from app_key — both come from Partner Center
   but service_id identifies the OAuth client, app_key identifies the API caller.

Step 2 — Redirect back to <Redirect URL>?code=<auth_code>&state=<jwt>
   auth_code valid for 30 minutes, single-use.

Step 3 — GET https://auth.tiktok-shops.com/api/v2/token/get
   ?app_key=...&app_secret=...&auth_code=...&grant_type=authorized_code
   → { access_token, refresh_token,
       access_token_expire_in,   # ABSOLUTE Unix timestamp, NOT a duration
       refresh_token_expire_in,
       open_id, seller_name, seller_base_region, user_type }
   Access token good for 7 days; refresh token determined by seller's grant duration.

Step 4 — GET /authorization/202309/shops with x-tts-access-token: <token>
   → { shops: [ { id, cipher, code, name, region, seller_type } ] }
   Required because token-exchange does NOT include shop_cipher.

Step 5 — Refresh as needed:
   GET https://auth.tiktok-shops.com/api/v2/token/refresh
   ?app_key=...&app_secret=...&refresh_token=...&grant_type=refresh_token
```

### Request signing (HMAC-SHA256)

Algorithm (per `Sign_your_API_request`):

```
1. Take query params except `sign` and `access_token`. Sort alphabetically.
2. Concatenate as "key1value1key2value2..."
3. Prepend the request path. e.g. "/customer_service/202309/conversations" + concat
4. If Content-Type != multipart/form-data, append raw body.
5. Wrap: app_secret + result + app_secret
6. HMAC-SHA256, key = app_secret. Hex-encoded lowercase.
```

Implementation: `Tiktok::Shop::SignatureService.generate(...)`.

### API request shape

- Base: `https://open-api.tiktokglobalshop.com`
- Always in query: `app_key`, `timestamp`, `sign`. Add `shop_cipher` for shop-scoped calls.
- Header: `x-tts-access-token: <token>` (NOT `Access-Token` or `Authorization`)
- Header: `Content-Type: application/json` (or `multipart/form-data` for image upload)

### Messaging endpoints (v202309)

| Method | Path | Use |
|---|---|---|
| `GET` | `/customer_service/202309/conversations` | List conversations |
| `GET` | `/customer_service/202309/conversations/{id}/messages` | List messages |
| `POST` | `/customer_service/202309/conversations/{id}/messages` | Send message |
| `POST` | `/customer_service/202309/conversations/{id}/messages/read` | Mark read |
| `POST` | `/customer_service/202309/images/upload` | Upload image (multipart) |
| `POST` | `/customer_service/202309/conversations` | Create conversation (with buyer) |

### Send Message body

```json
{ "type": "TEXT", "content": "{\"content\":\"hello\"}" }
```

The `content` field is itself a JSON-serialized string. Supported `type` enums:
`TEXT, IMAGE, VIDEO, PRODUCT_CARD, ORDER_CARD, RETURN_REFUND_CARD, COUPON_CARD, LOGISTICS_CARD`.

### Webhook delivery

- HTTPS POST to the URL configured in Partner Center under app's "Developing" tab.
- `Authorization` header carries the HMAC-SHA256 signature, computed with the
  same algorithm as outgoing API requests (path = the webhook callback path,
  body = raw JSON payload, no query params).
- Must respond 200 or 401 within **3 seconds**. Retries: 2 min, 30 min, 3 h, 12 h.

### Webhook payload (event type 14 — "new message")

```json
{
  "type": 14,
  "tts_notification_id": "...",
  "shop_id": "7494049642642441621",
  "timestamp": 1644412885,
  "data": {
    "conversation_id": "...",
    "message_id": "...",
    "index": "...",
    "type": "TEXT",
    "content": "{\"content\":\"hi\"}",
    "create_time": 1681790246,
    "is_visible": true,
    "sender": { "im_user_id": "...", "role": "BUYER" }
  }
}
```

Event types in scope:
- `13` — new conversation (CS agent joined/left)
- `14` — new message (in CS conversation; main path)
- `33` — new message listener (creator → seller; out of scope for buyer support)

### Eligibility to send

Reply allowed only if at least one of:
1. Buyer messaged the shop in the last 30 days
2. Buyer placed an order in the last 60 days
3. Buyer has a return/refund history with the shop

The `conversations` list response carries `can_send_message` per conversation.

## 4. Feature parity matrix (verified)

Legend: ✅ supported. ❌ not in API.

| Feature | TikTok Shop API | Chatwoot wiring |
|---|---|---|
| Send text | ✅ | `Tiktok::Shop::Client#send_text` |
| Send image | ✅ (upload→send) | `Client#upload_image` + `#send_image` |
| Send video/product/order/coupon/logistics card | ✅ | `Client#send_message(type:, content_payload:)` |
| Receive text | ✅ webhook 14 | `Tiktok::Shop::IncomingMessageService` |
| Receive image / video | ✅ | Attachment built from `content.url` |
| Receive product/order/etc. cards | ✅ | Descriptive text + raw payload preserved in `content_attributes` |
| Mark as read | ✅ | `Tiktok::Shop::MarkAsReadJob` on conversation view |
| Read receipts (buyer→agent) | ❌ not exposed | — |
| Reply/quote | ❌ not in API | — |
| Unsend/recall (agent) | ❌ confirmed unsupported | `OutgoingRecallService` no-ops with log |
| Unsend/recall (buyer webhook) | ❌ no event type | — |
| Reactions (bidirectional) | ❌ confirmed unsupported | `*ReactionService` no-ops with log |
| Edit message | ❌ universal across channels | — |
| Token refresh | ✅ 7-day cycle | `Tiktok::Shop::TokenService` |
| Reauthorize UI | ✅ | `Reauthorize.vue` + `Reauthorizable` |

## 5. File inventory (post-fix)

### Backend
- `db/migrate/20260519102516_create_channel_tiktok_shop.rb`
- `app/models/channel/tiktok_shop.rb`
- `app/models/account.rb` — `has_many :tiktok_shop_channels`
- `app/services/tiktok/shop/auth_client.rb` — OAuth + Get Authorized Shops
- `app/services/tiktok/shop/signature_service.rb` — HMAC-SHA256 helper
- `app/services/tiktok/shop/client.rb` — per-channel signed HTTP client
- `app/services/tiktok/shop/token_service.rb` — refresh with Redis lock
- `app/services/tiktok/shop/incoming_message_service.rb` — webhook 14
- `app/services/tiktok/shop/incoming_conversation_service.rb` — webhook 13
- `app/services/tiktok/shop/mark_as_read_service.rb`
- `app/services/tiktok/shop/send_on_tiktok_shop_service.rb`
- `app/services/tiktok/shop/outgoing_recall_service.rb` — explicit no-op
- `app/services/tiktok/shop/incoming_reaction_service.rb` — explicit no-op
- `app/services/tiktok/shop/outgoing_reaction_service.rb` — explicit no-op
- `app/jobs/webhooks/tiktok_shop_events_job.rb`
- `app/jobs/tiktok/shop/mark_as_read_job.rb`
- `app/jobs/tiktok/shop/recall_job.rb`
- `app/controllers/tiktok/shop/callbacks_controller.rb`
- `app/controllers/api/v1/accounts/tiktok/shop/authorizations_controller.rb`
- `app/controllers/webhooks/tiktok_shop_controller.rb`
- `app/helpers/tiktok/shop/integration_helper.rb`

### Wiring
- `config/routes.rb` — `/tiktok/shop/callback`, `/webhooks/tiktok_shop`, namespaced authorization API
- `app/controllers/api/v1/accounts/conversations_controller.rb` — enqueue MarkAsRead
- `app/models/message.rb` — `trigger_tiktok_shop_recall`
- `app/models/inbox.rb` — `tiktok_shop?` predicate + webhook URL
- `app/builders/contact_inbox_builder.rb` — allow channel
- `app/jobs/send_reply_job.rb` — dispatch to `Tiktok::Shop::SendOnTiktokShopService`
- `app/helpers/api/v1/inboxes_helper.rb` — register `tiktok_shop` channel type
- `app/controllers/super_admin/app_configs_controller.rb` — config group `tiktok_shop`
  with `TIKTOK_SHOP_APP_KEY`, `TIKTOK_SHOP_APP_SECRET`, `TIKTOK_SHOP_SERVICE_ID`

### Frontend
- `app/javascript/dashboard/api/channel/tiktokShopClient.js`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/TiktokShop.vue`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/tiktok_shop/Reauthorize.vue`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/ChannelFactory.vue`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/ChannelList.vue` — gated on `chatwootConfig.tiktokShopAppKey`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue` — reauthorize banner
- `app/javascript/dashboard/helper/inbox.js` — `INBOX_TYPES.TIKTOK_SHOP`
- `app/javascript/dashboard/components-next/icon/provider.js`
- `app/javascript/dashboard/components/widgets/ChannelItem.vue`
- `app/javascript/dashboard/constants/editor.js`
- `app/javascript/dashboard/featureFlags.js` — `CHANNEL_TIKTOK_SHOP`
- `app/javascript/shared/mixins/inboxMixin.js` — `isATiktokShopChannel`
- `app/javascript/dashboard/i18n/locale/en/inboxMgmt.json`
- `app/views/layouts/vueapp.html.erb` — expose `TIKTOK_SHOP_APP_KEY` as `tiktokShopAppKey`

### Config & DB
- `config/features.yml` — `channel_tiktok_shop` flag
- `app/helpers/super_admin/features.yml` — Super Admin `tiktok_shop` entry
- `app/controllers/dashboard_controller.rb` — expose `TIKTOK_SHOP_APP_KEY` to frontend

### Test scaffolding
- `spec/factories/channel/channel_tiktok_shop.rb` — minimal factory; no further tests scaffolded until live API verifies behavior.

## 6. Verification path (post-deploy)

1. Register a developer app in Partner Center.
2. Configure:
   - Redirect URL = `https://chat.rollingpinn.com/tiktok/shop/callback`
   - Webhook URL = `https://chat.rollingpinn.com/webhooks/tiktok_shop`
   - Subscribe to event types **13** and **14**.
   - Enable the `customer_service` access scope.
3. Set Super Admin → AppConfig → TikTok Shop → `TIKTOK_SHOP_APP_KEY`, `TIKTOK_SHOP_APP_SECRET`, `TIKTOK_SHOP_SERVICE_ID`.
4. From Chatwoot inbox setup, click "Connect TikTok Shop" → complete OAuth.
5. Verify the resulting channel has `access_token`, `refresh_token`, `shop_cipher`, expiry timestamps populated.
6. Send a test DM from a buyer test account → verify nginx `chatwoot_access_443.log` shows a 200 POST to `/webhooks/tiktok_shop` → verify message lands in inbox.
7. Reply from Chatwoot → confirm visible in Seller Center.

## 7. Non-goals (deliberately out of scope)

- Order / product / fulfillment / affiliate APIs — Chatwoot is the messaging surface only.
- Multi-shop-per-inbox UX — one shop = one Chatwoot inbox; multi-shop sellers get multiple inboxes.
- The "creator messaging" (event 33) path — different relationship type, outside buyer support.

## 8. What changed between the initial scaffold and the fix-up commit

| Area | Before (TODO scaffold) | After (verified) |
|---|---|---|
| Auth URL host | Guess based on Business Messaging | `services.tiktokshop.com/open/authorize?service_id=...` |
| Token endpoint | POST (Business-Messaging style) | **GET** `auth.tiktok-shops.com/api/v2/token/{get,refresh}` |
| OAuth identifier | `app_key` | `service_id` (separate Partner Center field) |
| Token expiry | `Time.current + seconds_until_expiry` | `Time.zone.at(<unix_ts>)` — absolute Unix timestamps |
| shop_cipher source | Expected from token response | Fetched via `/authorization/202309/shops` |
| Access-token header | `Access-Token` | `x-tts-access-token` |
| `sign` placement | Header | Query parameter |
| Signing input | Modeled on EcomPHP SDK guess | Confirmed against official Go/Java/Node/Python samples |
| Webhook signature header | `X-TTS-Signature` guess | `Authorization` |
| Webhook event names | String placeholders (`MESSAGE_NEW`) | Numeric integers (`13`, `14`) |
| `content` field shape | JSON object | JSON-serialized **string** within the message body |
| Recall/reactions | "TODO verify" | Confirmed unsupported by TikTok Shop API; explicit no-ops |

## 9. Bottom line

Every gating unknown has been answered against official docs. The remaining
prerequisites are operational (Partner Center developer app, webhook subscription
configured) rather than architectural.
