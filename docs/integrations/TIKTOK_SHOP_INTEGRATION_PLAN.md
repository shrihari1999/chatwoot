# TikTok Shop Channel Integration — Plan & Scaffold

**Status:** Scaffolding committed, end-to-end testing blocked on TikTok Shop Partner approval.
**Author:** Claude (Sonnet 4.6) under instruction from @shrihari1999
**Branch:** `vorflux/tiktok-shop-integration`

---

## 1. Why this exists

TikTok Shop is a separate messaging system from TikTok Business Messaging API. Test messages sent to the @TheRollingPinn shop appear in TikTok Seller Center and in Freshchat (which uses the TikTok Shop Partner API) but never reach Chatwoot — because Chatwoot's existing TikTok channel uses the **Business Messaging API**, not the **Shop Partner API**. Direct quote from TikTok's own FAQ (`Access_to_Business_Messaging_API__1832184145137922.md`):

> "TikTok Business Messaging and TikTok Shop Messaging are distinct messaging systems. Integration with the TikTok Business Messaging API does not allow management of TikTok Shop Messages."

The bakery's actual customer messages are Shop messages, so we need a separate channel: `Channel::TiktokShop`.

## 2. Reference architecture — modelled on Lazada with three deltas

Lazada (`Channel::Lazada`) is the closest existing precedent: same vertical (e-commerce marketplace messaging), same flavour (text + image + product/order cards), similar minimal feature surface. We replicate that architecture with three meaningful differences:

| Aspect | Lazada | TikTok Shop |
|---|---|---|
| Auth | Manual credentials (shop_id + app_key + app_secret + access_token entered into the form) | OAuth 3-legged flow (modeled on existing `Tiktok::CallbacksController`); app_key + app_secret are global Super Admin config, access_token + refresh_token + shop_cipher come from TikTok |
| Token lifecycle | No refresh logic | Access token expires ~24h, refresh token expires longer; `TokenService` refreshes on demand (same pattern as existing `Tiktok::TokenService`) |
| Shop identifier | `shop_id` (provided by user) | `shop_cipher` (returned by TikTok OAuth, used in API calls) + `shop_id` (numeric, used in webhook routing) |

Everything else — webhook handler → events job → incoming service → conversation building → outgoing service → recall service → mark-as-read service → frontend Vue page → routes — mirrors Lazada one-to-one.

## 3. Feature parity matrix

Based on the @user's at-a-glance matrix plus what I could verify from the publicly-readable EcomPHP SDK for v202309. Items marked **UNVERIFIED** depend on TikTok Shop documentation pages that are JS-rendered SPAs and could not be extracted programmatically — they are marked with TODO comments in the code, to be confirmed once the user has Partner Center access.

| Feature | Status | Implementation |
|---|---|---|
| **Send text** | ✅ Implemented | `customer_service/202309/conversations/{id}/messages` with `type=TEXT` |
| **Send image** | ✅ Implemented | Upload via `customer_service/202309/images/upload`, then send with `type=IMAGE` |
| **Send product/order card** | ✅ Implemented | Same send endpoint with `type=PRODUCT_CARD` / `type=ORDER_CARD`. Field names TODO. |
| **Receive text** | ✅ Implemented | Webhook event handler routes to `Tiktok::Shop::IncomingMessageService` |
| **Receive image** | ✅ Implemented | Image URL or media_id parsed from webhook payload — TODO field names |
| **Receive product/order card** | ✅ Implemented | Card payload preserved in `content_attributes` |
| **Mark as read** (agent → buyer) | ✅ Implemented | `POST /customer_service/202309/conversations/{id}/messages/read` enqueued via `Tiktok::Shop::MarkAsReadJob` when agent views conversation |
| **Read receipts** (buyer → agent) | ⚠️ TODO | Webhook event name and payload schema unknown. Service stubbed; will route to `Conversations::UpdateMessageStatusJob` when wired. |
| **Reply / quote** | ❌ Not supported by API | Per the feature matrix: TikTok Shop has no documented `reply_to` field. Send service accepts the param but ignores it. |
| **Unsend / recall** (agent-initiated) | ⚠️ TODO | EcomPHP SDK does not expose a recall endpoint. Service file scaffolded but performs no-op with TODO. |
| **Unsend / recall** (buyer-initiated, webhook in) | ⚠️ TODO | Event name unknown. Handler stubbed. |
| **Bidirectional reactions** | ⚠️ TODO | EcomPHP SDK does not expose reaction endpoints. Scaffolded as no-op service. **User explicitly requested this — see Open Question #5.** |
| **Typing indicator** (outbound) | ⚠️ TODO | Unknown. No scaffold. |
| **Edit message** | ❌ Not supported | Consistent with every other social channel — businesses cannot API-edit sent messages. |
| **Token refresh** | ✅ Implemented | `Tiktok::Shop::TokenService` refreshes access token when within 5-minute expiry window |
| **Reauthorize UI** | ✅ Implemented | `Reauthorize.vue` page + `Reauthorizable` concern + admin email on auth failure |

## 4. File-by-file inventory

### Database
- `db/migrate/<timestamp>_create_channel_tiktok_shop.rb` — `channel_tiktok_shop` table

### Models
- `app/models/channel/tiktok_shop.rb` — channel model, encrypts secrets, contains API helpers + Reauthorizable concern
- `app/models/account.rb` — adds `has_many :tiktok_shop_channels`

### Services
- `app/services/tiktok/shop/auth_client.rb` — global static class wrapping OAuth + token exchange (parallels `Tiktok::AuthClient`)
- `app/services/tiktok/shop/client.rb` — per-channel HTTP client with signing logic
- `app/services/tiktok/shop/token_service.rb` — refreshes access token on demand
- `app/services/tiktok/shop/incoming_message_service.rb` — webhook → conversation + message
- `app/services/tiktok/shop/incoming_recall_service.rb` — TODO: handle buyer-initiated recall webhook
- `app/services/tiktok/shop/incoming_reaction_service.rb` — TODO: handle buyer reaction webhook
- `app/services/tiktok/shop/send_on_tiktok_shop_service.rb` — outgoing message dispatcher
- `app/services/tiktok/shop/outgoing_recall_service.rb` — TODO: agent-initiated recall
- `app/services/tiktok/shop/outgoing_reaction_service.rb` — TODO: agent-initiated reaction
- `app/services/tiktok/shop/mark_as_read_service.rb` — agent viewed conversation
- `app/services/tiktok/shop/messaging_helpers.rb` — shared helpers (signing, parsing)

### Jobs
- `app/jobs/webhooks/tiktok_shop_events_job.rb` — dispatches webhook events to services
- `app/jobs/tiktok/shop/mark_as_read_job.rb` — async wrapper for MarkAsReadService
- `app/jobs/tiktok/shop/recall_job.rb` — async wrapper for OutgoingRecallService

### Controllers
- `app/controllers/tiktok/shop/callbacks_controller.rb` — OAuth callback handler
- `app/controllers/api/v1/accounts/tiktok/shop/authorizations_controller.rb` — generates OAuth init URL
- `app/controllers/webhooks/tiktok_shop_controller.rb` — webhook receiver with signature verify

### Routes
- `config/routes.rb`:
  - `get '/tiktok/shop/callback'` → CallbacksController#show
  - `post 'webhooks/tiktok_shop'` → tiktok_shop_controller#events
  - `post 'tiktok/shop/authorization'` (namespaced API) → AuthorizationsController#create
  - `get 'tiktok/shop/reauthorize'` (API) → AuthorizationsController#reauthorize (TODO if reusing create)

### Inbox / channel wiring
- `app/helpers/api/v1/inboxes_helper.rb` — register `'tiktok_shop' => Current.account.tiktok_shop_channels`
- `app/controllers/api/v1/accounts/inboxes_controller.rb` — `allowed_channel_types` += `'tiktok_shop'`; map type
- `app/models/inbox.rb` — add `tiktok_shop?` predicate + `/webhooks/tiktok_shop` in `webhook_url`
- `app/builders/contact_inbox_builder.rb` — allow TikTok Shop channel
- `app/jobs/send_reply_job.rb` — map `Channel::TiktokShop => ::Tiktok::Shop::SendOnTiktokShopService`
- `app/models/message.rb` — wire `trigger_tiktok_shop_recall` (mirrors `trigger_lazada_recall`)
- `app/controllers/api/v1/accounts/conversations_controller.rb` — enqueue MarkAsReadJob on view
- `app/controllers/super_admin/app_configs_controller.rb` — add `tiktok_shop` config group for global `TIKTOK_SHOP_APP_KEY` + `TIKTOK_SHOP_APP_SECRET`

### Frontend
- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/TiktokShop.vue` — connect button (initiates OAuth)
- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/tiktok_shop/Reauthorize.vue` — re-authorize component
- `app/javascript/dashboard/api/channel/tiktokShopClient.js` — API client for OAuth init
- `app/javascript/dashboard/routes/dashboard/settings/inbox/ChannelFactory.vue` — register channel
- `app/javascript/dashboard/routes/dashboard/settings/inbox/ChannelList.vue` — list TikTok Shop option
- `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue` — handle reauthorize state
- `app/javascript/dashboard/helper/inbox.js` — `INBOX_TYPES.TIKTOK_SHOP = 'Channel::TiktokShop'` + icon/brand helpers
- `app/javascript/dashboard/components-next/icon/provider.js` — icon mapping
- `app/javascript/dashboard/components/widgets/ChannelItem.vue` — channel icon support
- `app/javascript/dashboard/constants/editor.js` — editor config (minimal, like Lazada)
- `app/javascript/dashboard/i18n/locale/en/inboxMgmt.json` — strings under `INBOX_MGMT.ADD.TIKTOK_SHOP_CHANNEL`

### Configuration
- `config/features.yml` — add `channel_tiktok_shop` feature flag
- `app/helpers/super_admin/features.yml` — registry of the flag
- `app/javascript/dashboard/featureFlags.js` — frontend feature flag enum

### Specs (scaffold-only — minimal)
- `spec/factories/channel/channel_tiktok_shop.rb` — FactoryBot factory
- Test files for each service are NOT scaffolded in this branch — they should be written once the live API behaviour is verified, otherwise they encode our guesses rather than real behaviour.

## 5. OAuth flow (designed)

```
1. User clicks "Connect TikTok Shop" in Chatwoot
   → POST /api/v1/accounts/:id/tiktok/shop/authorization
   → Backend generates state JWT, redirects to:
     https://services.tiktokshop.com/open/authorize?app_key=<key>&state=<jwt>

2. User authorizes on TikTok, redirected to:
   https://chat.rollingpinn.com/tiktok/shop/callback?code=<auth_code>&state=<jwt>

3. CallbacksController exchanges code:
   POST https://auth.tiktok-shops.com/api/v2/token/get
   body: { app_key, app_secret, auth_code, grant_type: "authorized_code" }
   → returns: { access_token, refresh_token, access_token_expire_in, refresh_token_expire_in,
                open_id, seller_name, seller_base_region, shop_id_list, shop_cipher_list }

4. For each shop_id+shop_cipher returned, create one Channel::TiktokShop record.
   (If multiple shops, pick the first — UX iteration: let user choose.)

5. After channel save, enqueue Avatar::AvatarFromUrlJob (mirrors existing Tiktok callback).
   Redirect user back to inbox setup → agents page.
```

## 6. Webhook flow (designed)

```
TikTok Shop → POST https://chat.rollingpinn.com/webhooks/tiktok_shop
  Headers:
    X-TTS-Signature: <hex HMAC-SHA256 of timestamp + body, key = app_secret>   ← TODO: verify header name
    X-TTS-Timestamp: <unix seconds>                                              ← TODO: verify header name
  Body:
    {
      "tts_notification_id": "...",
      "shop_id": "<numeric shop id>",
      "timestamp": <unix seconds>,
      "type": "MESSAGE_NEW"          ← TODO: confirm exact event name
      "data": { ... event-specific payload ... }
    }

→ Webhooks::TiktokShopController.events
  → verify_signature! (constant-time HMAC compare + 5s timestamp tolerance)
  → enqueue Webhooks::TiktokShopEventsJob

→ Webhooks::TiktokShopEventsJob
  → look up Channel::TiktokShop by shop_id
  → dispatch on payload['type']:
       MESSAGE_NEW         → Tiktok::Shop::IncomingMessageService
       MESSAGE_READ        → Tiktok::Shop::SessionUpdateService (TODO: verify name)
       MESSAGE_RECALLED    → Tiktok::Shop::IncomingRecallService (TODO: verify name)
       MESSAGE_REACTION    → Tiktok::Shop::IncomingReactionService (TODO: verify name)
```

## 7. Open questions (must answer before going live)

1. **Exact webhook event names and payload schemas** — extract from Partner Center docs (JS-rendered SPA, requires browser session). Currently using placeholder names in code with TODO markers.
2. **Exact API signing scheme for v202309** — the EcomPHP SDK source code shows the mechanics, but our implementation copies the convention without verification. First live request will confirm.
3. **Webhook signature header name** — guessed `X-TTS-Signature`. Lazada uses `Authorization`. TikTok Business uses `Tiktok-Signature`. TODO verify.
4. **Region routing for `auth.tiktok-shops.com` vs `auth.tiktok-shops.us.com`** — US shops use a different auth host. Channel stores `region` to disambiguate. TODO confirm hostnames.
5. **Reactions** — user explicitly asked about bidirectional reaction support. The EcomPHP SDK's `CustomerService.php` exposes no reaction endpoints. **Verdict: TikTok Shop API likely does not support reactions today.** Service stubbed as no-op pending Partner Center verification.
6. **TikTok Shop Partner approval** — accessing the messaging endpoints requires Partner Center registration + app approval. Without an approved app, every API call returns 401. **The bakery's existing TikTok Shop account (shop code `THLCQ2WL89`) is a separate prerequisite.**
7. **Token storage size** — `access_token` and `refresh_token` from TikTok Shop are JWT-like and can be ~1KB each. Migration uses `text` instead of `string`.
8. **Multiple shops per account** — TikTok Shop OAuth returns an array of `shop_id`/`shop_cipher` pairs. MVP picks the first. Future: per-shop inbox setup wizard.

## 8. Non-goals (deliberately scoped out)

- Order/product management endpoints — only customer service / messaging is in scope. Use the official Shopify-style admin for shop management.
- Affiliate, Logistics, Fulfillment APIs — out of scope.
- Webhook subscription management via API — TikTok Shop requires subscription in Partner Center UI, not via API. Documented in plan but not coded.
- Multi-shop per inbox — one channel = one shop; multi-shop accounts get multiple inboxes.

## 9. Verification path (post-merge, requires Partner approval)

1. Apply for TikTok Shop Partner Center developer account
2. Register an app, get app_key + app_secret, configure in Super Admin → AppConfig → TikTok Shop
3. Configure webhook URL `https://chat.rollingpinn.com/webhooks/tiktok_shop` in Partner Center
4. Click "Connect TikTok Shop" in Chatwoot inbox setup → complete OAuth
5. Verify channel record created with access_token, refresh_token, shop_cipher populated
6. Send a test DM from a buyer account to the shop → verify webhook hits `/webhooks/tiktok_shop` in nginx log → verify message appears in Chatwoot inbox
7. Reply from Chatwoot → verify it appears in TikTok Seller Center
8. Resolve all TODOs in code with verified field names

## 10. Risk register

| Risk | Mitigation |
|---|---|
| Webhook event names wrong → no messages ingested | Plan rolls out behind `channel_tiktok_shop` feature flag; first failed delivery in Partner Center event logs reveals correct names |
| Token refresh race condition under load | `TokenService` checks expiry per request, holds advisory lock via Redis if needed (TODO when traffic warrants) |
| Encryption key rotation | Tokens use Rails 7 `encrypts` macro; rotation handled by existing infra (matches Lazada) |
| Partner Center approval delayed | Code merges without affecting other channels (gated behind feature flag); deploy when approval lands |
| Region-routing mistakes (US vs others) | Region stored on channel; routed at API client construction time |

---

**Bottom line:** every architectural decision mirrors a proven pattern in this codebase (Lazada for the shop/messaging shape, existing `Tiktok::*` for the OAuth shape). The unknowns are confined to TikTok Shop's gated documentation — coded as TODOs, will be resolved in a follow-up PR once the user has Partner Center access.
