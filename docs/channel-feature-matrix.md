# Messaging feature matrix — LINE · FB Messenger · Instagram · TikTok DM · TikTok Shop · Lazada

> **Point-in-time snapshot generated 2026-07-02** via a multi-agent cross-reference of each platform's primary API docs against this fork's code (base branch `production`), with an independent verification pass. Cells marked `[post-verify]` in the notes were hand-corrected after synthesis. Re-verify against code before relying on any cell — the fork changes over time.

Each cell shows **two states**: `platform-support / fork-implementation`.
Legend: ✅ yes · ⚠️ partial/conditional · ❌ no · ❔ unknown.
Direction: **◀ in** = inbound (customer→us, we receive) · **▶ out** = outbound (we send via the platform API).

## Delivery & status

| Feature | Dir | LINE | FB Msgr | Instagram | TikTok DM | TikTok Shop | Lazada |
|---|---|---|---|---|---|---|---|
| Text message | ◀ in | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ |
| Text message | ▶ out | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ |
| Sent/accepted status (platform ack) | ▶ out | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ |
| Delivered receipt on our outbound msgs | ◀ in | ⚠️/❌ | ✅/✅ | ❌/❌ | ❌/⚠️ | ❌/❌ | ❌/❌ |
| Read / seen receipt | ◀ in | ❌/❌ | ✅/✅ | ✅/✅ | ✅/✅ | ❌/❌ | ✅/✅ |
| Read / seen receipt | ▶ out | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ |
| Failed status + error reason | ◀ in | ✅/✅ | ⚠️/⚠️ | ⚠️/✅ | ⚠️/✅ | ⚠️/✅ | ⚠️/✅ |
| Retry / resend a failed send | ▶ out | ✅/✅ | ✅/✅ | ⚠️/✅ | ⚠️/✅ | ⚠️/✅ | ⚠️/✅ |
| Outbound echo (agent msg sent from platform app) | ◀ in | ❌/❌ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ |

## Operations

| Feature | Dir | LINE | FB Msgr | Instagram | TikTok DM | TikTok Shop | Lazada |
|---|---|---|---|---|---|---|---|
| Quote / reply-to a specific message | ◀ in | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ❌/❌ | ❌/❌ |
| Quote / reply-to a specific message | ▶ out | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ❌/❌ | ❌/❌ |
| Edit an already-sent message | ◀ in | ❌/❌ | ✅/✅ | ✅/✅ | ❌/❌ | ❌/❌ | ❌/❌ |
| Edit an already-sent message | ▶ out | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Unsend / recall / delete a message | ◀ in | ✅/✅ | ❌/❌ | ✅/✅ | ❌/❌ | ❌/❌ | ✅/✅ |
| Unsend / recall / delete a message | ▶ out | ❌/❌ | ❌/⚠️ | ❌/⚠️ | ❌/❌ | ❌/⚠️ | ✅/✅ |
| Reaction add (emoji) | ◀ in | ❌/❌ | ✅/✅ | ✅/✅ | ✅/✅ | ❌/❌ | ❌/❌ |
| Reaction add (emoji) | ▶ out | ❌/❌ | ✅/✅ | ✅/✅ | ❌/❌ | ❌/❌ | ❌/❌ |
| Reaction remove | ◀ in | ❌/❌ | ✅/✅ | ✅/✅ | ✅/✅ | ❌/❌ | ❌/❌ |
| Reaction remove | ▶ out | ❌/❌ | ✅/✅ | ✅/✅ | ❌/❌ | ❌/❌ | ❌/❌ |
| Forward a message | ◀ in | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Forward a message | ▶ out | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |

## Content / media

| Feature | Dir | LINE | FB Msgr | Instagram | TikTok DM | TikTok Shop | Lazada |
|---|---|---|---|---|---|---|---|
| Image | ◀ in | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ |
| Image | ▶ out | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ |
| Video | ◀ in | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ❌/❌ |
| Video | ▶ out | ✅/✅ | ✅/✅ | ✅/✅ | ❌/❌ | ✅/✅ | ✅/❌ |
| Audio / voice note | ◀ in | ✅/✅ | ✅/✅ | ✅/✅ | ❌/❌ | ❌/❌ | ❌/❌ |
| Audio / voice note | ▶ out | ✅/✅ | ✅/✅ | ✅/✅ | ❌/❌ | ❌/❌ | ❌/❌ |
| File / document | ◀ in | ✅/✅ | ✅/✅ | ⚠️/✅ | ❌/❌ | ❌/❌ | ❌/❌ |
| File / document | ▶ out | ❌/❌ | ✅/✅ | ⚠️/⚠️ | ❌/❌ | ❌/❌ | ❌/❌ |
| Sticker | ◀ in | ✅/✅ | ✅/⚠️ | ⚠️/❌ | ✅/❌ | ✅/❌ | ⚠️/⚠️ |
| Sticker | ▶ out | ✅/❌ | ❌/❌ | ⚠️/❌ | ❌/❌ | ❌/❌ | ⚠️/❌ |
| GIF / animated | ◀ in | ⚠️/❌ | ✅/⚠️ | ⚠️/⚠️ | ❌/❌ | ⚠️/❌ | ⚠️/⚠️ |
| GIF / animated | ▶ out | ❌/❌ | ✅/⚠️ | ❌/❌ | ❌/❌ | ❌/❌ | ⚠️/⚠️ |
| Location (static) | ◀ in | ✅/✅ | ⚠️/✅ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Location (static) | ▶ out | ✅/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Live location | ◀ in | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Contact card / vCard | ◀ in | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Contact card / vCard | ▶ out | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Link preview / URL unfurl | ◀ in | ❌/❌ | ⚠️/⚠️ | ⚠️/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Link preview / URL unfurl | ▶ out | ⚠️/❌ | ⚠️/❌ | ⚠️/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Multiple attachments in one message | ▶ out | ✅/✅ | ❌/✅ | ❌/✅ | ❌/❌ | ❌/✅ | ❌/✅ |
| Caption on media | ◀ in | ❌/❌ | ❌/⚠️ | ❌/✅ | ❌/❌ | ❌/❌ | ❌/❌ |
| Caption on media | ▶ out | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/⚠️ | ❌/⚠️ |
| Unsupported-type fallback handling | ◀ in | ❌/❌ | ✅/✅ | ✅/✅ | ⚠️/✅ | ✅/⚠️ | ⚠️/⚠️ |

## Rich / interactive

| Feature | Dir | LINE | FB Msgr | Instagram | TikTok DM | TikTok Shop | Lazada |
|---|---|---|---|---|---|---|---|
| Quick replies / suggested responses | ▶ out | ✅/⚠️ | ✅/✅ | ✅/❌ | ✅/❌ | ❌/❌ | ⚠️/❌ |
| Buttons (URL/postback/call) send + click | ◀ in | ✅/❌ | ✅/❌ | ✅/❌ | ⚠️/❌ | ❌/❌ | ⚠️/❌ |
| Buttons (URL/postback/call) send + click | ▶ out | ✅/⚠️ | ✅/❌ | ✅/❌ | ⚠️/❌ | ❌/❌ | ⚠️/❌ |
| List / menu message | ▶ out | ⚠️/❌ | ⚠️/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Carousel / generic template cards | ▶ out | ✅/❌ | ✅/❌ | ✅/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Product / catalog / commerce message | ◀ in | ❌/❌ | ❌/❌ | ⚠️/❌ | ❌/❌ | ✅/⚠️ | ✅/⚠️ |
| Product / catalog / commerce message | ▶ out | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ✅/❌ | ✅/❌ |
| In-thread payment / checkout | ◀ in | ❌/❌ | ⚠️/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| In-thread payment / checkout | ▶ out | ❌/❌ | ⚠️/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Forms / flows (multi-step) | ◀ in | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Forms / flows (multi-step) | ▶ out | ⚠️/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Persistent menu | ▶ out | ✅/❌ | ✅/❌ | ✅/❌ | ⚠️/❌ | ❌/❌ | ❌/❌ |
| Story mention | ◀ in | ❌/❌ | ❌/❌ | ✅/✅ | ❌/❌ | ❌/❌ | ❌/❌ |
| Story reply | ◀ in | ❌/❌ | ❌/❌ | ✅/✅ | ❌/❌ | ❌/❌ | ❌/❌ |
| Post/comment -> DM handoff | ◀ in | ❌/❌ | ✅/❌ | ✅/✅ | ⚠️/❌ | ❌/❌ | ❌/❌ |

## Presence & indicators

| Feature | Dir | LINE | FB Msgr | Instagram | TikTok DM | TikTok Shop | Lazada |
|---|---|---|---|---|---|---|---|
| Typing indicator | ◀ in | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Typing indicator | ▶ out | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ❌/❌ | ❌/❌ |
| Online / last-active presence | ◀ in | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |

## Formatting

| Feature | Dir | LINE | FB Msgr | Instagram | TikTok DM | TikTok Shop | Lazada |
|---|---|---|---|---|---|---|---|
| Rich text formatting (bold/italic/etc.) | ◀ in | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Rich text formatting (bold/italic/etc.) | ▶ out | ⚠️/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| @mentions | ◀ in | ✅/❌ | ❌/❌ | ⚠️/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| @mentions | ▶ out | ✅/❌ | ❌/❌ | ⚠️/❌ | ❌/❌ | ❌/❌ | ❌/❌ |
| Emoji (unicode) | ◀ in | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ |
| Emoji (unicode) | ▶ out | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ |

## Contact / profile

| Feature | Dir | LINE | FB Msgr | Instagram | TikTok DM | TikTok Shop | Lazada |
|---|---|---|---|---|---|---|---|
| Contact display name | ◀ in | ✅/✅ | ✅/✅ | ✅/✅ | ✅/⚠️ | ✅/✅ | ✅/❌ |
| Contact avatar / profile picture | ◀ in | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ |
| Extended profile (username/verified/followers/etc.) | ◀ in | ⚠️/❌ | ❌/❌ | ✅/✅ | ⚠️/⚠️ | ❌/❌ | ⚠️/⚠️ |

## Conversation & policy

| Feature | Dir | LINE | FB Msgr | Instagram | TikTok DM | TikTok Shop | Lazada |
|---|---|---|---|---|---|---|---|
| Messaging window (e.g. 24h) enforcement | ▶ out | ❌/❌ | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ |
| Message tags / out-of-window send | ▶ out | ❌/❌ | ⚠️/⚠️ | ⚠️/⚠️ | ❌/❌ | ⚠️/❌ | ⚠️/❌ |
| Template / pre-approved proactive message | ▶ out | ✅/⚠️ | ⚠️/❌ | ❌/❌ | ❌/❌ | ✅/❌ | ⚠️/❌ |
| Handover protocol (bot <-> agent) | ◀ in | ❌/❌ | ✅/❌ | ✅/⚠️ | ❌/❌ | ⚠️/⚠️ | ❌/❌ |
| Handover protocol (bot <-> agent) | ▶ out | ❌/❌ | ✅/❌ | ✅/❌ | ❌/❌ | ⚠️/❌ | ❌/❌ |
| Group vs 1:1 conversation support | ◀ in | ✅/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ | ❌/❌ |

## Verifier notes & corrections (cells the verify pass changed or flagged with a caveat)

| Feature | Dir | Platform | Note |
|---|---|---|---|
| Sent/accepted status (platform ack) | ▶ out | LINE | Impl treats the HTTP-200 send ack as 'delivered' status (a platform accept/sent ack, not a true delivery receipt). |
| Delivered receipt on our outbound msgs | ◀ in | TikTok DM | Kept partial: the 'delivered' state is a self-mark off the send ack, not a real platform delivered receipt (platform support is no). |
| Read / seen receipt | ◀ in | LINE | Support partial->no and impl yes->no: LINE emits no read event (confirmed against live docs). The dead `ReadStatusService` + read-event routing were subsequently removed in PR #130. |
| Read / seen receipt | ▶ out | LINE | Corrected support evidence: only /v2/bot/chat/markAsRead(token) exists; the draft's /v2/bot/message/markAsRead(userId) endpoint is not in the docs. |
| Read / seen receipt | ▶ out | Lazada | Doc marks last_read_message_id required=true but channel.read_session (lazada.rb:52-54) sends only session_id; read-sync may be a no-op if Lazada enforces the param [post-verify] read_session sends only session_id; doc marks last_read_message_id required, so read-sync may be a no-op. |
| Retry / resend a failed send | ▶ out | LINE | Impl re-pushes without an X-Line-Retry-Key, so retrying a send that only appeared to fail could duplicate the message. |
| Retry / resend a failed send | ▶ out | FB Msgr | Support changed no->yes: draft conflated lack of a dedicated retry/idempotency endpoint with inability to resend; re-POSTing is fully supported and the fork's retry path exercises it. |
| Retry / resend a failed send | ▶ out | Lazada | [post-verify] Resend possible via re-POST /im/message/send; no idempotency/retry key. |
| Quote / reply-to a specific message | ▶ out | Lazada | Changed draft partial->no: message.rb:353 ensure_in_reply_to only stores a generic in_reply_to in content_attributes locally and it is never sent to Lazada, so there is no functional quote-reply on this channel |
| Unsend / recall / delete a message | ▶ out | Lazada | outgoing_recall_service header note: multi-fragment sends only recall the last message_id |
| Reaction add (emoji) | ▶ out | TikTok DM | Changed draft 'partial'->'no': local apply_reaction! is a Chatwoot-internal UI record, not an outbound platform action, and the platform offers no reaction send. |
| Reaction remove | ▶ out | TikTok DM | Changed draft 'partial'->'no': same reasoning as reaction_add out (no outbound platform reaction path). |
| File / document | ▶ out | Instagram | [post-verify] Generic passthrough: attachment_type maps unknown -> 'file'; IG DM file support itself limited. |
| Sticker | ◀ in | Lazada | Changed draft no->partial: draft claimed 'no sticker template_id handled' but parse_content case 4 explicitly handles it, ingesting the sticker as its code text (degraded, no image) rather than dropping it |
| GIF / animated | ◀ in | LINE | A GIF delivered typed as an image would flow through the generic image attach_files path, but there is no GIF-aware handling. |
| Location (static) | ◀ in | Instagram | Changed impl from draft partial to no: the :location branch is inherited dead code — location_params is undefined in the Instagram builder chain, so a location attachment would raise and never persist |
| Multiple attachments in one message | ▶ out | Instagram | Caveat: impl sends each attachment as a separate message rather than bundling multiple into one message [post-verify] Meta send API = one attachment/message; fork fans out one send per attachment (base_send_service loop). Aligned with FB. |
| Multiple attachments in one message | ▶ out | Lazada | impl fans out into separate IM sends and only image attachments are included (non-image skipped) |
| Caption on media | ◀ in | FB Msgr | Impl changed yes->partial: platform delivers no caption on media, so the combined-message structure is structural-only, not an exercised caption feature. |
| Caption on media | ◀ in | Instagram | Caveat: only yields a caption when the webhook bundles text+media on one message (story replies); plain DM media/text arrive separately |
| Caption on media | ▶ out | Instagram | Changed impl from draft partial to no: attachments and content go out as separate messages, so no caption is produced |
| Quick replies / suggested responses | ▶ out | LINE | Implemented via a Flex bubble with message-action buttons, not LINE's native quickReply field. [post-verify] Emulated via Flex bubble with message-action buttons, not LINE native quickReply (same path as buttons). |
| Buttons (URL/postback/call) send + click | ◀ in | LINE | Taps on the impl's message-action buttons return as ordinary text messages (which are handled), but genuine postback events are not. |
| List / menu message | ▶ out | FB Msgr | Support evidence corrected: draft said List Template is 'documented'; it is now absent from Meta's current template catalog (deprecated). State kept partial since generic template covers card lists. |
| Rich text formatting (bold/italic/etc.) | ▶ out | LINE | A LineRenderer artifact exists but produces literal asterisks/underscores, not styled text, since LINE plain-text messages have no markdown. |
| Emoji (unicode) | ◀ in | Lazada | Fixed draft evidence: unicode emoji ride template_id 1 normal text (not template_id 4, which is the bracketed sticker set); state unchanged (yes) |
| Emoji (unicode) | ▶ out | LINE | Only unicode emoji pass through; LINE's proprietary emojis (emojis array with productId/emojiId) are not used. |
| Contact display name | ◀ in | TikTok DM | Fork uses the username as the contact name; TikTok's display_name/nickname (available via content/list participants) is not ingested (ContactProfileJob leaves the name as-is). [post-verify] Name set from webhook username; platform display_name/nickname not ingested (ContactProfileJob leaves name as-is). |
| Contact display name | ◀ in | Lazada | Changed draft partial->no: no platform display name is actually populated (name = numeric buyer id; masked title intentionally discarded per contact_profile_job comment) |
| Extended profile (username/verified/followers/etc.) | ◀ in | Lazada | Changed draft no->partial to align with support and the code: site_id (country) + account_id are stored, though no rich profile fields exist |
| Message tags / out-of-window send | ▶ out | Instagram | [post-verify] Only HUMAN_AGENT tag implemented (merge_human_agent_tag), same as FB; not arbitrary message tags. |
| Template / pre-approved proactive message | ▶ out | LINE | Changed draft impl no->partial: push is proactive-capable and implemented, though no template concept exists. |
| Handover protocol (bot <-> agent) | ◀ in | LINE | [post-verify] No Meta-style per-message handover protocol; only account-level OA Manager Chat mode toggle. |
| Handover protocol (bot <-> agent) | ◀ in | Instagram | Impl only consumes the standby array as ordinary messages; there is no thread-control state machine or messaging_handovers handling |
| Handover protocol (bot <-> agent) | ▶ out | LINE | [post-verify] No Meta-style handover protocol API on LINE. |

## Cross-platform synthesis

### Highlights
- Systemic 'fork-ahead-of-platform' on reliability rows: failed_status[in] and retry_resend[out] are F=yes while P=partial on IG/TikTok DM/TikTok Shop (and Lazada retry is F=yes vs P=no). The fork synthesizes status from local API acks/errors, not a real platform signal - every such cell is local synthesis, not platform-backed.
- Meta parity is uneven across FB vs IG despite one shared Graph/Messenger API: comment_to_dm[in] FB F=no vs IG F=yes; handover_protocol[in] FB F=no vs IG F=partial. Fork richness diverges between the two Meta channels with no platform reason. (read_receipt[out] was FB-only; closed for IG in PR #135.)
- Structured/interactive outbound is the biggest systematic fork lag: buttons, carousel, list_menu, persistent_menu, forms_flows are broadly P=yes/partial but F=no everywhere; LINE only fakes quick_replies/buttons via Flex; no channel implements native templated UI.
- multi_attachment[out] shows F=yes on FB/IG/TikTok Shop/Lazada but always via client-side fan-out (separate messages), and Lazada silently drops non-image attachments - 'yes' overstates a degraded behavior.
- Send-window/tagging governance is unimplemented fork-wide: messaging_window[out], message_tags[out], template_proactive[out] are P=yes/partial on FB/IG/TikTok/Lazada but F=no/partial across the board - a latent deliverability/24h-window risk.
- First-class inbound/outbound media types are silently unhandled: LINE sticker/mentions + location-out (P=yes F=no), TikTok DM sticker in (P=yes F=no) - real platform message types the fork can neither emit nor fully ingest. (Video *in* for TikTok DM was closed in PR #137; LINE location *in* in PR #138 — location *out* stays ❌ fork-wide because Chatwoot can't compose an outgoing location. Lazada video *in* was mistakenly added in #137 from an unreliable PDF and reverted in #141 — Lazada IM doesn't support inbound video.)

### Per-platform summary
- **LINE** — Solid text/media/receipts/typing + inbound location (PR #138); interactive (buttons/carousel/quick-replies) faked via Flex or absent; sticker/mentions/groups + location-out unhandled; dubious handover P=partial. (The dead inbound `ReadStatusService` was removed in PR #130.)
- **Facebook Messenger** — Most complete parity channel (receipts, reactions, edit, echo verified in code); fork lags on all templated/interactive UI, messaging window, handover, comment-to-DM; unsend[in] P=no looks understated vs IG.
- **Instagram** — Rich DM set incl. story/comment-to-DM/reactions/edit + outbound read/seen receipt (mark_seen, PR #135); several F>P overstatements (file_document, message_tags, caption[in], multi_attachment P); handover still lags FB despite shared API.
- **TikTok DM (Business Messaging)** — Text/reactions/typing/receipts + inbound video (PR #137) wired; status rows synthesized locally (F>P); display_name not actually ingested despite F=yes; no sticker inbound, no interactive UI.
- **TikTok Shop** — Text/image/video + partial product catalog + outbound echo (SHOP/CS/ROBOT sends mirrored, PR #132); local status synthesis (F>P); no typing; interactive/templates/window/tags all unimplemented.
- **Lazada IM** — Text/image/unsend(recall)/read + outbound echo (seller-app sends mirrored, PR #133) wired; heavy fan-out for multi-attachment (image-only); status synthesized with retry P=no/F=yes contradiction; display name discarded; no video (in or out — the PDF's template_id=6 video is not delivered in practice, see appendix)/product/interactive gaps.

### Inconsistencies noted
- TikTok DM display_name[in] P=yes F=yes contradicts its own annotation and the code: Tiktok::ContactProfileJob comments 'contact name is intentionally left as-is' and only backfills avatar; platform display_name/nickname is never ingested (name = username). Should be F=partial/no.
- IG multi_attachment[out] P=yes vs FB multi_attachment[out] P=no - same Meta send API (one attachment per message), and IG base_send_service loops one send per attachment so it cannot bundle either. IG P=yes is inconsistent with FB P=no.
- IG caption[in] F=yes vs FB caption[in] F=partial - both described as the same 'text+media bundled in one webhook' mechanism; labeling one yes and the other partial is inconsistent, and both being F>P (P=no) is odd for a caption claim.
- IG message_tags[out] P=partial F=yes vs FB message_tags[out] P=partial F=partial - identical Meta message-tag system; IG claiming full while FB is partial is contradictory.
- Lazada retry_resend[out] P=no F=yes - resend is a generic re-POST (every other channel is P=yes/partial); marking platform 'no' while the fork does it is internally contradictory.
- Lazada read_receipt[out] — RESOLVED (PR #136): read_session now sends the doc-required last_read_message_id (last inbound message's source_id) alongside session_id, so the read-sync is a real call, not a no-op. F=yes.
- LINE quick_replies[out] F=yes but the impl is a Flex bubble with message-action buttons (not native quickReply), while LINE buttons[out] is only F=partial for the same Flex-button code path - yes vs partial for one mechanism is inconsistent.
- LINE rich_formatting[out] F=no while a LineRenderer artifact exists (emits literal markdown) - either F=partial (artifact present) or the P=partial is itself dubious since LINE plain text has no markdown.
- IG file_document in/out P=partial F=yes - fork has only a generic 'file' passthrough (base_send_service maps unknown types to 'file'); claiming full F over a partial platform for a type IG DM barely supports is implausible.
- TikTok Shop outbound_echo[in] — RESOLVED (PR #132): Shop now mirrors SHOP/CUSTOMER_SERVICE/ROBOT sends from webhook 14 as outgoing echoes (dedup by source_id vs our own API sends), matching TikTok DM F=yes.
- LINE read_receipt[in] no/no — RESOLVED: confirmed LINE emits no read event, so `Line::ReadStatusService` was dead code; the service + read-event routing were removed in PR #130.

### Cells flagged as still uncertain
- TikTok DM display_name[in] F=yes - ContactProfileJob leaves name as-is and never ingests platform display_name; should be no/partial.
- Instagram multi_attachment[out] P=yes - Meta send API is one-attachment-per-message and fork loops per attachment; should be P=no like FB.
- Instagram message_tags[out] F=yes - same Meta tag system as FB (F=partial); F=yes overstates.
- Instagram caption[in] F=yes - only structural via bundled story-reply webhook; inconsistent with FB partial, likely partial.
- Instagram file_document[out] P=partial F=yes - generic 'file' passthrough over a type IG DM barely supports; F likely partial.
- Lazada retry_resend[out] P=no - resend via re-POST is generically possible everywhere else; P=no implausible.
- Lazada read_receipt[out] — RESOLVED (PR #136): read_session now includes the doc-required last_read_message_id; no longer a no-op.
- LINE quick_replies[out] F=yes - Flex-button emulation not native quickReply; inconsistent with buttons F=partial, likely partial.
- Facebook Messenger unsend[in] P=no - Messenger emits message-deletion/unsend events (IG on same platform family is P=yes); likely understated.
- LINE handover_protocol[in]/[out] P=partial - LINE Messaging API has no app-to-app handover protocol like Meta's; likely should be no.
- TikTok Shop outbound_echo[in] — RESOLVED (PR #132): confirmed webhook 14 fires for shop-side sends; fork now ingests them as outgoing echoes (F=yes).
- LINE read_receipt[in] no/no - RESOLVED: confirmed LINE emits no read event; dead `ReadStatusService` removed in PR #130.

## Appendix — full evidence per cell

### LINE

| Feature | Dir | Support | Support evidence | Impl | Impl evidence |
|---|---|---|---|---|---|
| Text message | ◀ in | ✅ yes | Webhook message event delivers TextMessageContent with a `text` field (receiving-messages / reference). | ✅ yes | incoming_message_service.rb:96-99 message_content case 'text' -> event.dig('message','text'); content_type 'text' (line 116-119). |
| Text message | ▶ out | ✅ yes | TextMessage / TextMessage (v2) sendable via /v2/bot/message/reply\|push (sending-messages). | ✅ yes | send_on_line_service.rb:99-101 text_message {type:'text',text:outgoing_content} pushed via push_message (line 9). |
| Sent/accepted status (platform ack) | ▶ out | ✅ yes | reply/push return sentMessages[{id,quoteToken}] + x-line-request-id header on HTTP 200 ack (send-push-message-response). | ✅ yes | send_on_line_service.rb:15-23 HTTP 200 -> Messages::StatusUpdateService(message,'delivered'); persists sentMessages id/quoteToken. |
| Delivered receipt on our outbound msgs | ◀ in | ⚠️ partial | No delivered webhook for standard bots; only PnP delivery-completion event for LINE Notification Messages (partner) + aggregate insight counts. | ❌ no | send_on_line_service.rb:23 'delivered' is set from the push-API 200, not from any inbound receipt; no delivery webhook handled in parse_events. |
| Read / seen receipt | ◀ in | ❌ no | mark-as-read doc explicitly states no webhook notifies the bot when a user reads its messages; reference event list has no 'read' event. Only aggregate broadcast insight open-counts exist (not per-conversation receipts). | ❌ no | LINE emits no 'read' webhook event; the former `Line::ReadStatusService` + read-event routing were dead code, removed in PR #130. No inbound read path exists. |
| Read / seen receipt | ▶ out | ✅ yes | POST /v2/bot/chat/markAsRead with markAsReadToken (carried in the message event); requires Chat turned on; token has no expiry (mark-as-read doc). | ✅ yes | conversations_controller.rb:126 update_last_seen enqueues Line::MarkAsReadJob -> MarkAsReadService POSTs /bot/chat/markAsRead with markAsReadToken captured at incoming_message_service.rb:72. |
| Failed status + error reason | ◀ in | ✅ yes | Send API returns synchronous HTTP 4xx/5xx ErrorResponse{message,details[]}; no async failure webhook. | ✅ yes | send_on_line_service.rb:24-26,153-163 non-200 -> StatusUpdateService 'failed' with external_error(message + details). |
| Retry / resend a failed send | ▶ out | ✅ yes | Resend allowed; X-Line-Retry-Key (UUID) gives idempotency on push/multicast/narrowcast/broadcast, 409 on dup, valid 24h (retrying-api-request doc). | ✅ yes | messages_controller.rb:28-34 retry -> SendReplyJob -> Line::SendOnLineService (send_reply_job.rb:8). |
| Outbound echo (agent msg sent from platform app) | ◀ in | ❌ no | No echo/send webhook event; messages sent by operators via LINE OA Manager are not delivered to the bot webhook. | ❌ no | parse_events handles only unsend/message events (incoming_message_service.rb); no echo path. |
| Quote / reply-to a specific message | ◀ in | ✅ yes | Message event carries quotedMessageId + quoteToken when a user quotes a message (receiving-messages). | ✅ yes | incoming_message_service.rb:60-68 quotedMessageId -> in_reply_to_external_id (resolved by Message before_save); quote_token stored at line 73. |
| Quote / reply-to a specific message | ▶ out | ✅ yes | quoteToken usable to reply-quote on reply/push for Text, Text(v2) and Sticker messages (sending-messages). | ✅ yes | send_on_line_service.rb:100,107-112 quoteToken pulled from the quoted message's stored additional_attributes and attached to the outgoing text. |
| Edit an already-sent message | ◀ in | ❌ no | No edit/message-edit webhook event in the reference. | ❌ no | No edit event handled in parse_events (incoming_message_service.rb:18-43). |
| Edit an already-sent message | ▶ out | ❌ no | No message-edit endpoint in the Messaging API. | ❌ no | No edit API call; messages_controller update mutates only local status. |
| Unsend / recall / delete a message | ◀ in | ✅ yes | UnsendEvent{unsend.messageId} fired when a user recalls one of their messages (reference #unsend-event). | ✅ yes | incoming_message_service.rb:84-93 handle_unsend_event marks the matching source_id message deleted. |
| Unsend / recall / delete a message | ▶ out | ❌ no | No unsend/recall endpoint for bot-sent messages (sending-messages confirms none). | ❌ no | destroy soft-deletes locally only; no LINE recall call in send_on_line_service. |
| Reaction add (emoji) | ◀ in | ❌ no | No reaction/message-reaction webhook event in the reference event list. | ❌ no | No reaction handling in LINE code (grep of app/services/line empty). |
| Reaction add (emoji) | ▶ out | ❌ no | No reaction endpoint in the Messaging API. | ❌ no | No reaction payload in send_on_line_service. |
| Reaction remove | ◀ in | ❌ no | No reaction webhook event in the reference. | ❌ no | No reaction handling in incoming_message_service. |
| Reaction remove | ▶ out | ❌ no | No reaction endpoint in the Messaging API. | ❌ no | No reaction send path in send_on_line_service. |
| Forward a message | ◀ in | ❌ no | No forward flag/type on message content; forwarded messages arrive as normal messages. | ❌ no | No forward handling in incoming_message_service. |
| Forward a message | ▶ out | ❌ no | No forward endpoint/message type in the Messaging API. | ❌ no | No forward payload in send_on_line_service. |
| Image | ◀ in | ✅ yes | ImageMessageContent{contentProvider,imageSet}; binary via GET message content (reference). | ✅ yes | incoming_message_service.rb:122-164 attach_files handles MessageType::Image via get_message_content. |
| Image | ▶ out | ✅ yes | ImageMessage{originalContentUrl,previewImageUrl} JPEG/PNG (sending-messages). | ✅ yes | send_on_line_service.rb:68-84 image attachment -> {type:'image',originalContentUrl,previewImageUrl}. |
| Video | ◀ in | ✅ yes | VideoMessageContent{contentProvider,duration} (reference). | ✅ yes | incoming_message_service.rb:159 attach_files handles MessageType::Video. |
| Video | ▶ out | ✅ yes | VideoMessage{originalContentUrl,previewImageUrl} (sending-messages). | ✅ yes | send_on_line_service.rb:82-83 video attachment -> {type:'video',originalContentUrl,previewImageUrl}. |
| Audio / voice note | ◀ in | ✅ yes | AudioMessageContent{contentProvider,duration}; covers user voice messages (reference). | ✅ yes | incoming_message_service.rb:160 attach_files handles MessageType::Audio. |
| Audio / voice note | ▶ out | ✅ yes | AudioMessage{originalContentUrl,duration} (m4a) (sending-messages). | ✅ yes | send_on_line_service.rb:76-80 audio -> {type:'audio',originalContentUrl,duration} (duration derived from blob). |
| File / document | ◀ in | ✅ yes | FileMessageContent{fileName,fileSize} (reference). | ✅ yes | incoming_message_service.rb:128,162 attach_files handles MessageType::File, preserving fileName. |
| File / document | ▶ out | ❌ no | No sendable File/document message type (sending-messages lists none). | ❌ no | send_on_line_service.rb:70 attachment filter keeps only image/video/audio; 'file' type skipped. |
| Sticker | ◀ in | ✅ yes | StickerMessageContent{packageId,stickerId,keywords,text,stickerResourceType} (reference). | ✅ yes | incoming_message_service.rb:100-117 sticker -> markdown image URL from sticker CDN, content_type 'sticker'. |
| Sticker | ▶ out | ✅ yes | StickerMessage{packageId,stickerId} (sending-messages). | ❌ no | No sticker payload branch in build_payload; attachments only image/video/audio (grep for sticker in send_on_line_service empty). |
| GIF / animated | ◀ in | ⚠️ partial | No dedicated GIF/animated content type; GIFs arrive as ImageMessageContent. | ❌ no | No GIF-specific handling; message_content covers only text/sticker. |
| GIF / animated | ▶ out | ❌ no | ImageMessage supports JPEG/PNG only; no animated/APNG send. | ❌ no | No GIF/animated payload in send_on_line_service. |
| Location (static) | ◀ in | ✅ yes | LocationMessageContent{latitude,longitude,title,address} (reference). | ✅ yes | attach_location builds a file_type: :location attachment from the event (coordinates_lat/long, fallback_title = title||address, external_url = Google Maps link); mirrors Facebook location ingest (PR #138). Outbound stays ❌ — Chatwoot has no way to compose an outgoing location (MessageBuilder only accepts file uploads). |
| Location (static) | ▶ out | ✅ yes | LocationMessage{title,address,latitude,longitude} (sending-messages). | ❌ no | No location payload branch in build_payload/send_on_line_service. |
| Live location | ◀ in | ❌ no | Only static LocationMessageContent; no live/continuous location type. | ❌ no | No live-location handling in incoming_message_service. |
| Contact card / vCard | ◀ in | ❌ no | No contact/vCard content type in the webhook reference. | ❌ no | No vCard/contact handling in incoming_message_service. |
| Contact card / vCard | ▶ out | ❌ no | No contact/vCard message type in the Messaging API. | ❌ no | No contact-card payload in send_on_line_service. |
| Link preview / URL unfurl | ◀ in | ❌ no | URLs arrive as plain text within TextMessageContent; no unfurl metadata delivered. | ❌ no | Inbound text stored verbatim; no URL-unfurl parsing (incoming_message_service.rb:99). |
| Link preview / URL unfurl | ▶ out | ⚠️ partial | LINE client auto-previews URLs in text; no API field to set/customize/disable the preview. | ❌ no | text_message sends plain text; no preview control/payload (send_on_line_service.rb:99-101). |
| Multiple attachments in one message | ▶ out | ✅ yes | Up to 5 message objects per reply/push request (sending-messages). | ✅ yes | send_on_line_service.rb:59-66 builds [text_message,*attachments] pushed in a single push_message. |
| Caption on media | ◀ in | ❌ no | No caption/text field on image/video/audio message content. | ❌ no | attach_files sets no content on media (incoming_message_service.rb:122-143). |
| Caption on media | ▶ out | ❌ no | No caption field on ImageMessage/VideoMessage; text must be a separate object. | ❌ no | Media payloads carry no text field; text sent as a separate bubble (send_on_line_service.rb:59-66,83). |
| Unsupported-type fallback handling | ◀ in | ❌ no | No 'unsupported' content type in the webhook reference. | ❌ no | Unknown types -> nil content, no is_unsupported/fallback flag (incoming_message_service.rb:95-104). |
| Quick replies / suggested responses | ▶ out | ✅ yes | quickReply (up to 13 items) attachable to any message (using-quick-reply). | ⚠️ partial | send_on_line_service.rb:51,115-149 input_select content rendered as a Flex bubble of tappable buttons that send back the option value. |
| Buttons (URL/postback/call) send + click | ◀ in | ✅ yes | PostbackEvent on postback action taps; message-action taps arrive as message events (reference). | ❌ no | No postback event handled in parse_events (incoming_message_service.rb handles only unsend/message). |
| Buttons (URL/postback/call) send + click | ▶ out | ✅ yes | Buttons template / Flex with postback, uri (incl. tel:) and message actions (sending-messages, actions). | ⚠️ partial | send_on_line_service.rb:137-149 Flex buttons use action type 'message' only; no uri/postback/tel actions. |
| List / menu message | ▶ out | ⚠️ partial | No dedicated list message type; approximated via Flex Message or carousel template. | ❌ no | Only a single Flex bubble for input_select (send_on_line_service.rb:115-135); no list/menu construct. |
| Carousel / generic template cards | ▶ out | ✅ yes | Carousel template, image carousel template, and Flex carousel supported (sending-messages). | ❌ no | No carousel/template payload in send_on_line_service. |
| Product / catalog / commerce message | ◀ in | ❌ no | No product/catalog/commerce message type in the API surface. | ❌ no | No product/commerce handling in incoming_message_service. |
| Product / catalog / commerce message | ▶ out | ❌ no | No product/catalog message type in the Messaging API. | ❌ no | No catalog/commerce payload in send_on_line_service. |
| In-thread payment / checkout | ◀ in | ❌ no | No in-thread payment/checkout in the Messaging API; LINE Pay is a separate API. | ❌ no | No payment/checkout handling in incoming_message_service. |
| In-thread payment / checkout | ▶ out | ❌ no | No native payment/checkout message type; only external LINE Pay via URI action. | ❌ no | No payment/checkout payload in send_on_line_service. |
| Forms / flows (multi-step) | ◀ in | ❌ no | No native form-submission webhook; inputs return as postback (datetimepicker) or via LIFF. | ❌ no | No multi-step form/flow handling in incoming_message_service. |
| Forms / flows (multi-step) | ▶ out | ⚠️ partial | No native form message; LIFF web apps (uri action) + datetimepicker action provide multi-step input. | ❌ no | No forms/flows payload in send_on_line_service. |
| Persistent menu | ▶ out | ✅ yes | Rich menu API under /v2/bot/richmenu (default + per-user) provides a persistent bottom menu (reference). | ❌ no | No rich-menu code anywhere in LINE model/services/jobs (grep for richmenu/persistent returns none). |
| Story mention | ◀ in | ❌ no | LINE has no stories; no story-mention event in the webhook reference. | ❌ no | No story handling in incoming_message_service. |
| Story reply | ◀ in | ❌ no | No story concept/event in the webhook reference. | ❌ no | No story-reply handling in incoming_message_service. |
| Post/comment -> DM handoff | ◀ in | ❌ no | No post/comment-to-DM handoff in the Messaging API (VOOM not exposed via webhook). | ❌ no | No post/comment->DM handoff in the LINE code path. |
| Typing indicator | ◀ in | ❌ no | No user-typing webhook event in the reference. | ❌ no | parse_events has no typing event (incoming_message_service.rb:18-43). |
| Typing indicator | ▶ out | ✅ yes | POST /v2/bot/chat/loading/start shows a loading animation; 1:1 chats only, loadingSeconds a multiple of 5 in 5-60 (use-loading-indicator). | ✅ yes | channel_typing_relay.rb:41-42 -> Line::TypingStatusJob -> TypingStatusService POSTs /bot/chat/loading/start (start-only; 'off' treated as no-op, LOADING_SECONDS=20). |
| Online / last-active presence | ◀ in | ❌ no | No online/last-active presence field or API in the surface. | ❌ no | No presence/last-active handling in incoming_message_service. |
| Rich text formatting (bold/italic/etc.) | ◀ in | ❌ no | TextMessageContent is plain text; no bold/italic markup received. | ❌ no | Inbound text stored as plain text; no formatting parsing (incoming_message_service.rb:99). |
| Rich text formatting (bold/italic/etc.) | ▶ out | ⚠️ partial | Plain text has no bold/italic; only Flex Message text supports weight/style/decoration. | ❌ no | render_line (markdown_renderer_service.rb:79-87) uses LineRenderer, but that renderer only wraps bold in ' * ' and italic in ' _ ' as literal characters; LINE displays them literally (not styled), so no real formatting is achieved. |
| @mentions | ◀ in | ✅ yes | TextMessageContent.mention.mentionees[] (with isSelf when the bot is @mentioned) (reference). | ❌ no | Incoming service stores only raw text (incoming_message_service.rb:99); the mention object is not parsed. |
| @mentions | ▶ out | ✅ yes | TextMessage (v2) substitution / mention object lets a bot @mention a user (sending-messages, textV2). | ❌ no | Send path builds plain text only; no mention object construction. |
| Emoji (unicode) | ◀ in | ✅ yes | Unicode emoji arrive within TextMessageContent.text. | ✅ yes | Inbound text stored verbatim (incoming_message_service.rb:99), so unicode emoji pass through. |
| Emoji (unicode) | ▶ out | ✅ yes | Unicode emoji in text; plus LINE proprietary emojis via TextMessage.emojis array. | ✅ yes | Outgoing text sent verbatim in text_message (send_on_line_service.rb:100), so unicode emoji pass through. |
| Contact display name | ◀ in | ✅ yes | GET /v2/bot/profile/{userId} returns displayName (reference). | ✅ yes | incoming_message_service.rb:171,208 get_profile displayName -> contact name. |
| Contact avatar / profile picture | ◀ in | ✅ yes | GET /v2/bot/profile/{userId} returns pictureUrl (reference). | ✅ yes | incoming_message_service.rb:209 get_profile pictureUrl -> contact avatar_url. |
| Extended profile (username/verified/followers/etc.) | ◀ in | ⚠️ partial | Get profile returns statusMessage + language in addition to name/avatar; no username/verified/follower fields. | ❌ no | Only name/avatar_url + social_line_user_id stored; statusMessage/language from get_profile dropped (incoming_message_service.rb:206-217). |
| Messaging window (e.g. 24h) enforcement | ▶ out | ❌ no | No time-based messaging window; push allowed anytime (subject to monthly quota/pricing). | ❌ no | push_message sent unconditionally; no 24h window check in send_on_line_service. |
| Message tags / out-of-window send | ▶ out | ❌ no | No message-tag/out-of-window concept (no window exists to bypass). | ❌ no | No message-tag/out-of-window param in the LINE push payload. |
| Template / pre-approved proactive message | ▶ out | ✅ yes | push/multicast/broadcast are proactive to friends with no approval; LINE Notification Messages uses templates for non-friends (partner). | ⚠️ partial | All outbound uses push_message (send_on_line_service.rb:9), which is inherently proactive, so proactively messaging an existing LINE contact works; but there is no template / pre-approval machinery (LINE needs none for friends). |
| Handover protocol (bot <-> agent) | ◀ in | ❌ no | Module channels emit Activated/Deactivated (control acquired/released) events; partner-gated. | ❌ no | No handover/module-channel event handling in the LINE code (Meta-specific handover is separate). |
| Handover protocol (bot <-> agent) | ▶ out | ❌ no | Module channel acquire/detach control endpoints; partner-gated; no standard handover protocol. | ❌ no | No handover-protocol send path for LINE. |
| Group vs 1:1 conversation support | ◀ in | ✅ yes | source type group/room plus Join/Leave/MemberJoined/MemberLeft events in the webhook reference. | ❌ no | get_line_contact_info uses source.userId + get_profile only (incoming_message_service.rb:171); group/room source and join/leave/member events are not handled (grep for groupId/roomId/join returns none). |

### FB Msgr

| Feature | Dir | Support | Support evidence | Impl | Impl evidence |
|---|---|---|---|---|---|
| Text message | ◀ in | ✅ yes | messages webhook: message.text field | ✅ yes | MessageParser#content (message_parser.rb:21-23) -> Facebook::MessageBuilder message_params content:response.content; app/builders/messages/facebook/message_builder.rb:126 |
| Text message | ▶ out | ✅ yes | Send API text message to /PAGE-ID/messages | ✅ yes | SendOnFacebookService#fb_text_message_payload {text: outgoing_content}; send_on_facebook_service.rb:9,56-62 |
| Sent/accepted status (platform ack) | ▶ out | ✅ yes | Send API 200 returns message_id + recipient_id (platform ack) | ✅ yes | outgoing msg defaults status:sent (message.rb:103 enum default sent), source_id set from parsed_result['message_id'] on success; send_on_facebook_service.rb:31 |
| Delivered receipt on our outbound msgs | ◀ in | ✅ yes | message_deliveries webhook (delivery watermark on our outbound) | ✅ yes | Bot.on :delivery -> FacebookDeliveryJob -> DeliveryStatus#process_delivery_status -> UpdateMessageStatusJob :delivered; delivery_status.rb:16-19 |
| Read / seen receipt | ◀ in | ✅ yes | message_reads webhook (read watermark) | ✅ yes | Bot.on :read -> FacebookDeliveryJob -> DeliveryStatus#process_read_status; delivery_status.rb:21-24 |
| Read / seen receipt | ▶ out | ✅ yes | Send API sender_action: mark_seen (sender-actions doc) | ✅ yes | MarkAsReadService sender_action=mark_seen (mark_as_read_service.rb:38-45); dispatched via Facebook::MarkAsReadJob in conversations_controller.rb:130-132 |
| Failed status + error reason | ◀ in | ⚠️ partial | Send API returns synchronous error code/message; no async per-message delivery-failure webhook for standard messaging | ⚠️ partial | failed status + external_error derived from the synchronous send response/timeout, not an inbound webhook; send_on_facebook_service.rb:19,27,38,42 |
| Retry / resend a failed send | ▶ out | ✅ yes | resending a failed message is a normal Send API call (re-POST to /PAGE-ID/messages); no idempotency key but no platform barrier to resending | ✅ yes | messages_controller#retry resets status to sent, clears content_attributes, re-enqueues SendReplyJob -> SendOnFacebookService; messages_controller.rb:28-34 |
| Outbound echo (agent msg sent from platform app) | ◀ in | ✅ yes | message_echoes webhook (is_echo=true; incl. Page Inbox/other-app sends) | ✅ yes | Bot.on :message_echo -> FacebookEventsJob -> MessageCreator#agent_message_via_echo -> Facebook::MessageBuilder outgoing_echo:true; message_creator.rb:24-36, message_builder.rb:119,125 |
| Quote / reply-to a specific message | ◀ in | ✅ yes | reply_to.mid in messages/echo webhook | ✅ yes | MessageParser#in_reply_to_external_id (message_parser.rb:67) stored in content_attributes[:in_reply_to_external_id]; message_builder.rb:117 |
| Quote / reply-to a specific message | ▶ out | ✅ yes | Send API message.reply_to.mid replies to a specific past message | ✅ yes | reply_to_payload {reply_to:{mid:...}} merged into text and attachment params; send_on_facebook_service.rb:53,77-85,108 |
| Edit an already-sent message | ◀ in | ✅ yes | message_edits webhook exists (verified against Meta message-edits webhook reference) - user edits a previously sent message | ✅ yes | Bot.on :message_edit -> FacebookMessageEditJob -> UpdateMessageService updates content + edited:true; update_message_service.rb:13-17 |
| Edit an already-sent message | ▶ out | ❌ no | no Send API to edit a previously-sent message (only reactions are mutable) | ❌ no | no edit-send path; messages_controller#update only mutates status for API inboxes; no FB edit code |
| Unsend / recall / delete a message | ◀ in | ❌ no | no unsend/deletion webhook for Messenger (message-delete is Instagram-only) | ❌ no | message_deletions not in subscribed_fields (facebook_page.rb:53-55); no inbound delete handler |
| Unsend / recall / delete a message | ▶ out | ❌ no | no delete/unsend-message endpoint in Messenger API surface | ⚠️ partial | destroy marks content_attributes.deleted locally + destroys attachments (messages_controller.rb:21-26); recall callbacks exist only for Lazada/TikTok Shop (message.rb:140-141), none for FB |
| Reaction add (emoji) | ◀ in | ✅ yes | message_reactions webhook action=react (like/love/wow/sad/angry/smile/dislike/other + emoji + mid) | ✅ yes | Bot.on :message_reaction -> FacebookReactionJob -> MessageReactionService react -> Message#apply_reaction!; message_reaction_service.rb:6-10, message.rb:254-262 |
| Reaction add (emoji) | ▶ out | ✅ yes | Send API sender_action:react with payload {message_id, reaction:emoji} (verified: sender-actions doc 'React or unreact to a message') | ✅ yes | messages_reactions_controller -> Facebook::SendReactionService (react) via Messaging::ReactionPayloadBuilder; send_reaction_service.rb:19-27, reaction_payload_builder.rb:23-27 |
| Reaction remove | ◀ in | ✅ yes | message_reactions webhook action=unreact | ✅ yes | MessageReactionService unreact -> apply_reaction! strips sender from all emoji buckets (unreact carries no emoji); message.rb:263-269 |
| Reaction remove | ▶ out | ✅ yes | Send API sender_action:unreact with payload {message_id} (verified: sender-actions doc) | ✅ yes | SendReactionService (unreact) via ReactionPayloadBuilder omits reaction emoji for unreact action; reaction_payload_builder.rb:27 |
| Forward a message | ◀ in | ❌ no | no forward webhook/field in Messenger surface | ❌ no | no forward parsing/handling |
| Forward a message | ▶ out | ❌ no | no forward-message endpoint in Send API | ❌ no | no forward payload in send service |
| Image | ◀ in | ✅ yes | messages webhook attachment.type=image (payload.url) | ✅ yes | attachment_params file_type=image -> file_type_params downloads payload.url; messenger/message_builder.rb:41,52-65 |
| Image | ▶ out | ✅ yes | Send API attachment type=image (URL or uploaded id) | ✅ yes | fb_attachment_message_params attachment_type=image; send_on_facebook_service.rb:95-126 |
| Video | ◀ in | ✅ yes | attachment.type=video (reel is a separate type for FB reels) | ✅ yes | video in attachment file_type list (messenger/message_builder.rb:41); reel type mapped to ig_reel with webpage-URL handling (:114,123-131) |
| Video | ▶ out | ✅ yes | Send API attachment type=video | ✅ yes | attachment_type video; send_on_facebook_service.rb:122-123 |
| Audio / voice note | ◀ in | ✅ yes | attachment.type=audio (voice clips) | ✅ yes | audio file_type handled + re-broadcast on attach for audio bubble; messenger/message_builder.rb:34,41 |
| Audio / voice note | ▶ out | ✅ yes | Send API attachment type=audio | ✅ yes | attachment_type audio; send_on_facebook_service.rb:122-123 |
| File / document | ◀ in | ✅ yes | attachment.type=file | ✅ yes | file file_type in attachment_params list; messenger/message_builder.rb:41 |
| File / document | ▶ out | ✅ yes | Send API attachment type=file | ✅ yes | attachment_type defaults to file for non-image/audio/video; send_on_facebook_service.rb:122-126 |
| Sticker | ◀ in | ✅ yes | sticker arrives as attachment.type=image with sticker_id (incl. like sticker) | ⚠️ partial | no sticker file_type enum (attachment.rb:47-48); FB stickers handled as a generic image attachment, sticker semantics lost |
| Sticker | ▶ out | ❌ no | no sticker send type in Send API (send as image instead) | ❌ no | no sticker payload; send service only text + media attachment |
| GIF / animated | ◀ in | ✅ yes | GIF arrives as image / share (Giphy) attachment | ⚠️ partial | no gif type; handled as image (or :fallback for shares); no GIF semantics; messenger/message_builder.rb:41,52 |
| GIF / animated | ▶ out | ✅ yes | GIF can be sent as an image attachment by URL (or via media template) | ⚠️ partial | agent .gif goes through generic image attachment_type (FileTypeHelper -> :image); no GIF-specific API handling; send_on_facebook_service.rb:95-126 |
| Location (static) | ◀ in | ⚠️ partial | attachment.type=location (lat/long) historically; user location-sharing UI removed 2019 | ✅ yes | location_params parses payload.coordinates.lat/long into a :location attachment; message_builder.rb:81-90, messenger/message_builder.rb:43-44 |
| Location (static) | ▶ out | ❌ no | location quick reply removed Oct 29 2019; no location-send type | ❌ no | send service builds only text + file/media attachment payloads |
| Live location | ◀ in | ❌ no | no live-location attachment type in Messenger surface | ❌ no | no live_location parsing |
| Contact card / vCard | ◀ in | ❌ no | no contact/vCard attachment type in Messenger (WhatsApp-only) | ❌ no | no vCard parsing (enum :contact exists but never populated for FB) |
| Contact card / vCard | ▶ out | ❌ no | no contact-card message type in Send API | ❌ no | no contact payload in send service |
| Link preview / URL unfurl | ◀ in | ⚠️ partial | shared link arrives as attachment.type=fallback {url,title}; no structured preview object | ⚠️ partial | FB :share normalized to :fallback storing url+title only (message_builder.rb:92-105); no unfurl metadata |
| Link preview / URL unfurl | ▶ out | ⚠️ partial | URLs in text auto-generate a preview; no API field to control/disable | ❌ no | no unfurl handling; text sent as-is and FB auto-unfurls (platform behavior, no code) |
| Multiple attachments in one message | ▶ out | ❌ no | Send API carries one attachment (or text) per call; no single multi-attachment message | ✅ yes | perform_reply iterates message.attachments and sends each as a separate Send API call (delivers all, as separate bubbles); send_on_facebook_service.rb:11-15 |
| Caption on media | ◀ in | ❌ no | no caption field; media and text arrive as separate messages | ⚠️ partial | builder puts content(text)+attachments on one message (message_builder.rb:47-53,126) so a caption WOULD be stored together, but FB doesn't deliver captions on media so it is never exercised |
| Caption on media | ▶ out | ❌ no | no caption param on attachments; must send separate text message | ❌ no | content and each attachment sent as separate Send API calls, no combined caption; send_on_facebook_service.rb:9-15 |
| Unsupported-type fallback handling | ◀ in | ✅ yes | attachment.type=fallback with url/title for unsupported/shared content | ✅ yes | FB :share -> :fallback (message_builder.rb:101); unsupported_file_type? skips template/unsupported_type/ephemeral; messenger/message_builder.rb:134-136 |
| Quick replies / suggested responses | ▶ out | ✅ yes | message.quick_replies (up to 13; title+payload, content_type text/email/phone) | ✅ yes | content_type input_select -> quick_replies_payload (content_type:text); send_on_facebook_service.rb:57,64-75 |
| Buttons (URL/postback/call) send + click | ◀ in | ✅ yes | button click delivered via messaging_postbacks webhook (postback.payload) | ❌ no | messaging_postbacks NOT in subscribed_fields (facebook_page.rb:53-55); no Bot.on :postback handler; parser reads only message.text |
| Buttons (URL/postback/call) send + click | ▶ out | ✅ yes | button/generic template buttons: web_url, postback, phone_number(call) | ❌ no | no button/generic template payload in send service |
| List / menu message | ▶ out | ⚠️ partial | classic List Template deprecated/removed from Meta's current template catalog; list-of-cards only via generic (carousel) template | ❌ no | no list/menu template payload in send service |
| Carousel / generic template cards | ▶ out | ✅ yes | generic template = horizontally scrollable carousel (up to 10 elements) | ❌ no | no generic/carousel template payload in send service |
| Product / catalog / commerce message | ◀ in | ❌ no | no product/catalog message in FB Messenger (product template is Instagram-only) | ❌ no | no product/commerce parsing |
| Product / catalog / commerce message | ▶ out | ❌ no | no catalog/product message type in FB Messenger Send API | ❌ no | no product/commerce payload |
| In-thread payment / checkout | ◀ in | ⚠️ partial | Buy Button payment completion / messaging_pre_checkouts webhook exists but Beta + US-only/restricted | ❌ no | no payment webhook handling |
| In-thread payment / checkout | ▶ out | ⚠️ partial | Buy Button: template button type=payment + payment_summary; Beta, US-only/restricted | ❌ no | no payment/checkout payload |
| Forms / flows (multi-step) | ◀ in | ❌ no | no native multi-step forms/flows message type (WhatsApp Flows only) | ❌ no | no forms/flows handling |
| Forms / flows (multi-step) | ▶ out | ❌ no | no forms/flows send in Send API (only webview/Messenger Extensions, not native) | ❌ no | no forms/flows payload |
| Persistent menu | ▶ out | ✅ yes | Messenger Profile API persistent_menu (up to 3 top-level items) | ❌ no | no persistent_menu / messenger_profile API call (grep: none) |
| Story mention | ◀ in | ❌ no | story_mention is Instagram-only; not in FB Messenger webhook surface | ❌ no | FB builder doesn't override get_story_object (parent returns {}); story_mention file_type never set for FB; messenger/message_builder.rb:106-108 |
| Story reply | ◀ in | ❌ no | story_reply is Instagram-only; not in FB Messenger webhook surface | ❌ no | no story_reply parsing for FB Messenger |
| Post/comment -> DM handoff | ◀ in | ✅ yes | Private Replies POST /{comment-id}/private_replies + feed comment webhook + m.me referral | ❌ no | FB page not subscribed to feed/comments (facebook_page.rb:53-55); no private-reply path |
| Typing indicator | ◀ in | ❌ no | no inbound typing/composer webhook from the customer | ❌ no | no inbound typing handling |
| Typing indicator | ▶ out | ✅ yes | Send API sender_action: typing_on / typing_off | ✅ yes | ChannelTypingRelay -> Facebook::TypingStatusJob -> TypingStatusService typing_on/off; channel_typing_relay.rb:38, typing_status_service.rb:40-54 |
| Online / last-active presence | ◀ in | ❌ no | no presence/last-active webhook in Messenger surface | ❌ no | no presence handling |
| Rich text formatting (bold/italic/etc.) | ◀ in | ❌ no | Messenger text is plain; no rich-text formatting field | ❌ no | plain text passthrough only |
| Rich text formatting (bold/italic/etc.) | ▶ out | ❌ no | Send API text is plain; no markdown/bold/italic support | ❌ no | plain text sent; no formatting markup handling |
| @mentions | ◀ in | ❌ no | no @mention field in 1:1 Messenger API surface | ❌ no | no @mention parsing |
| @mentions | ▶ out | ❌ no | no @mention send in Send API | ❌ no | no @mention payload handling |
| Emoji (unicode) | ◀ in | ✅ yes | unicode emoji carried inline in message.text | ✅ yes | unicode carried in message text passthrough; message_parser.rb:21-23 |
| Emoji (unicode) | ▶ out | ✅ yes | unicode emoji sent inline in message.text | ✅ yes | unicode in outgoing_content text passthrough; send_on_facebook_service.rb:60 |
| Contact display name | ◀ in | ✅ yes | User Profile API: first_name, last_name | ✅ yes | contact_params via Koala get_object -> process_contact_params_result first_name/last_name; message_builder.rb:133-135,143-165 |
| Contact avatar / profile picture | ◀ in | ✅ yes | User Profile API: profile_pic | ✅ yes | avatar_url from result['profile_pic']; message_builder.rb:137 |
| Extended profile (username/verified/followers/etc.) | ◀ in | ❌ no | no username/verified/followers for FB users (those are Instagram-only fields) | ❌ no | only first_name/last_name/profile_pic fetched; message_builder.rb:135-137 |
| Messaging window (e.g. 24h) enforcement | ▶ out | ✅ yes | 24h standard messaging window (messaging_type=RESPONSE) | ❌ no | no 24h window computation/enforcement; always tags messaging_type=RESPONSE and relies on FB to reject out-of-window sends; send_on_facebook_service.rb:111-120 |
| Message tags / out-of-window send | ▶ out | ⚠️ partial | CONFIRMED_EVENT_UPDATE/ACCOUNT_UPDATE/POST_PURCHASE_UPDATE deprecated (hard error Apr 27 2026); effectively only HUMAN_AGENT remains (7-day window) | ⚠️ partial | HUMAN_AGENT tag only, gated by global ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT flag (applies to all messages, not per-message); send_on_facebook_service.rb:111-120 |
| Template / pre-approved proactive message | ▶ out | ⚠️ partial | proactive messaging via Marketing Messages API / Utility Templates, but access-restricted/gated | ❌ no | no pre-approved template send path |
| Handover protocol (bot <-> agent) | ◀ in | ✅ yes | messaging_handovers (pass/take/request thread control) + standby webhook | ❌ no | standby + messaging_handovers ARE in subscribed_fields (facebook_page.rb:53-55) but no Bot.on handler/service processes them |
| Handover protocol (bot <-> agent) | ▶ out | ✅ yes | pass_thread_control / take_thread_control / request_thread_control endpoints | ❌ no | no pass/take/request_thread_control API call (grep: none) |
| Group vs 1:1 conversation support | ◀ in | ❌ no | Messenger API is 1:1 only; no group-thread messaging in surface | ❌ no | 1:1 threads only; no group/multi-participant handling |

### Instagram

| Feature | Dir | Support | Support evidence | Impl | Impl evidence |
|---|---|---|---|---|---|
| Text message | ◀ in | ✅ yes | messages webhook delivers message.text (UTF-8) for inbound DMs | ✅ yes | base_message_builder.rb:82,103 message_content->create!; message_text.rb:82-86 create_message; instagram_events_job.rb:153-159 routes message->MessageText/MessageBuilder |
| Text message | ▶ out | ✅ yes | Send API /<IG_ID>/messages message.text, UTF-8, <=1000 bytes | ✅ yes | base_send_service.rb:29-38 message_params(text); send_on_instagram_service.rb:16-20 POST graph.instagram.com/<id>/messages |
| Sent/accepted status (platform ack) | ▶ out | ✅ yes | Send API 200 returns recipient_id + message_id (platform ack) | ✅ yes | base_send_service.rb:66-70 process_response stores parsed message_id into message.source_id |
| Delivered receipt on our outbound msgs | ◀ in | ❌ no | No message_deliveries event; IG has no delivered receipt (not in webhook examples) | ❌ no | channel/instagram.rb:51 subscribed_fields=[messages,message_reactions,messaging_seen,message_edit,comments]; SUPPORTED_EVENTS job:14 has no delivery key |
| Read / seen receipt | ◀ in | ✅ yes | messaging_seen webhook with read.mid (per-message) | ✅ yes | instagram_events_job.rb:161-163 read->ReadStatusService; read_status_service.rb:7 UpdateMessageStatusJob; subscribed messaging_seen |
| Read / seen receipt | ▶ out | ✅ yes | sender_action=mark_seen documented on IG-Login sender-actions page | ✅ yes | conversations_controller.rb update_last_seen enqueues Instagram::MarkAsReadJob for Channel::Instagram -> Instagram::MarkAsReadService POSTs graph.instagram.com sender_action=mark_seen with the IG access_token (PR #135). Mirrors Instagram::TypingStatusService; Channel::FacebookPage-backed IG DMs are excluded (graph.instagram.com rejects page tokens), same boundary as typing + Facebook::MarkAsReadService |
| Failed status + error reason | ◀ in | ⚠️ partial | Synchronous Send API error (code/subcode/message); no async delivery-failure webhook | ✅ yes | base_send_service.rb:66-76 process_response on error->Messages::StatusUpdateService('failed', external_error) with code-message reason |
| Retry / resend a failed send | ▶ out | ⚠️ partial | No retry/idempotency primitive; resend = re-POST /messages | ✅ yes | messages_controller.rb:28-37 retry: StatusUpdateService 'sent' + clear content_attributes + SendReplyJob (generic, routes to IG send) |
| Outbound echo (agent msg sent from platform app) | ◀ in | ✅ yes | messages webhook is_echo:true for app-user/agent-sent msgs | ✅ yes | base_message_text.rb:37-39 agent_message_via_echo?; base_message_builder.rb:27-29 outgoing type, :161 status delivered, :170 external_echo |
| Quote / reply-to a specific message | ◀ in | ✅ yes | messages webhook reply_to.mid (inline reply) | ✅ yes | base_message_builder.rb:90-91 message_reply_attributes(reply_to.mid)->:166 content_attributes.in_reply_to_external_id |
| Quote / reply-to a specific message | ▶ out | ✅ yes | Send API reply_to.mid to quote a past message | ✅ yes | base_send_service.rb:56-64 reply_to_payload {reply_to:{mid}} from in_reply_to_external_id |
| Edit an already-sent message | ◀ in | ✅ yes | message_edit webhook: message_edit{mid,text,num_edit} | ✅ yes | instagram_events_job.rb:170-172 message_edit->UpdateMessageService; update_message_service.rb:17 update content+edited:true; subscribed message_edit |
| Edit an already-sent message | ▶ out | ❌ no | No API to edit an already-sent message | ❌ no | No send path edits our own IG message; send services only POST new /messages |
| Unsend / recall / delete a message | ◀ in | ✅ yes | messages webhook is_deleted:true (customer unsend) | ✅ yes | base_message_text.rb:20,41-59 is_deleted->unsend_message destroys attachments + sets content=deleted,deleted:true |
| Unsend / recall / delete a message | ▶ out | ❌ no | No delete/unsend endpoint in Send API; is_deleted inbound-only | ⚠️ partial | messages_controller.rb:21-26 destroy marks deleted locally + attachments.destroy_all; no IG recall (message.rb:140-141 only lazada/tiktok recall callbacks) |
| Reaction add (emoji) | ◀ in | ✅ yes | message_reactions webhook action=react + emoji/mid | ✅ yes | instagram_events_job.rb:166-168 reaction->message_reaction_service.rb:9 apply_reaction!; subscribed message_reactions |
| Reaction add (emoji) | ▶ out | ✅ yes | sender_action=react, payload{message_id,reaction} | ✅ yes | messages_reactions_controller.rb:52-58->Instagram::SendReactionService; reaction_payload_builder.rb:23-27 react payload; send_reaction_service.rb:22-31 POST |
| Reaction remove | ◀ in | ✅ yes | message_reactions webhook action=unreact | ✅ yes | message_reaction_service.rb:29 action; message.rb:263-269 apply_reaction! unreact strips sender from buckets |
| Reaction remove | ▶ out | ✅ yes | sender_action=unreact, payload{message_id} | ✅ yes | reaction_payload_builder.rb:27 unreact payload{message_id}; send_reaction_service.rb + controller action='unreact' |
| Forward a message | ◀ in | ❌ no | No forward event/field in webhook surface | ❌ no | No forward handling in instagram_events_job or builders |
| Forward a message | ▶ out | ❌ no | No forward capability in Send API | ❌ no | No forward send path in Instagram send services |
| Image | ◀ in | ✅ yes | attachments type=image (payload.url) | ✅ yes | base_message_builder.rb:106-108 process_attachment->messenger/message_builder.rb:37-65 attachment_params :image; attach_file downloads |
| Image | ▶ out | ✅ yes | attachment type=image; up to 10; PNG/JPEG <=8MB | ✅ yes | base_send_service.rb:40-54 attachment_message_params + :91-95 attachment_type->'image' |
| Video | ◀ in | ✅ yes | attachments type=video | ✅ yes | messenger/message_builder.rb:41 :video handled; file_type_helper video_file? |
| Video | ▶ out | ✅ yes | attachment type=video; MP4/MOV/OGG/AVI/WEBM <=25MB | ✅ yes | base_send_service.rb:91-95 attachment_type->'video' |
| Audio / voice note | ◀ in | ✅ yes | attachments type=audio (voice clips) | ✅ yes | messenger/message_builder.rb:41 :audio; :34 attach_file re-fires update event for audio |
| Audio / voice note | ▶ out | ✅ yes | attachment type=audio; AAC/M4A/WAV/MP4 <=25MB | ✅ yes | base_send_service.rb:91-95 attachment_type->'audio' |
| File / document | ◀ in | ⚠️ partial | attachments type=file exists; IG app rarely lets users send docs | ✅ yes | file_type_helper.rb:3-9 :file fallback; messenger/message_builder.rb:41 :file processed |
| File / document | ▶ out | ⚠️ partial | attachment type=file = PDF only, <=25MB | ⚠️ partial | base_send_service.rb:91-95 attachment_type defaults to 'file' for non image/audio/video |
| Sticker | ◀ in | ⚠️ partial | No distinct sticker type; stickers arrive under image type; only heart 'like' distinct | ❌ no | No sticker/like_heart handling; attachment.rb:47-48 enum has no sticker/like_heart; a sticker-as-image is treated as generic image |
| Sticker | ▶ out | ⚠️ partial | Only heart sticker via attachment type=like_heart | ❌ no | No sticker/like_heart send path in Instagram send services |
| GIF / animated | ◀ in | ⚠️ partial | Inbound GIF arrives under image attachment type; no distinct GIF type | ⚠️ partial | No GIF-specific path; image/gif in file_type_helper.rb:17-27 image list->treated as :image |
| GIF / animated | ▶ out | ❌ no | Send images limited to PNG/JPEG; no GIF type | ❌ no | No GIF send path; only generic attachment types |
| Location (static) | ◀ in | ❌ no | No location attachment type in IG webhook | ❌ no | messenger/message_builder.rb:45 has inherited :location branch but location_params is defined only in Facebook::MessageBuilder (facebook/message_builder.rb:81), not in the IG chain |
| Location (static) | ▶ out | ❌ no | No location message type in Send API | ❌ no | No location send path in Instagram send services |
| Live location | ◀ in | ❌ no | No live-location support in API surface | ❌ no | No live-location handling in IG webhook/builder path |
| Contact card / vCard | ◀ in | ❌ no | No contact/vCard attachment type | ❌ no | No vCard/contact-card handling in builders |
| Contact card / vCard | ▶ out | ❌ no | No contact/vCard message type | ❌ no | No contact-card send path |
| Link preview / URL unfurl | ◀ in | ⚠️ partial | Link carried in message.text; no unfurl metadata field | ❌ no | No URL-unfurl parsing; text stored verbatim |
| Link preview / URL unfurl | ▶ out | ⚠️ partial | Text may contain a link; IG auto-previews but no unfurl control in API | ❌ no | No unfurl payload; text sent as-is |
| Multiple attachments in one message | ▶ out | ❌ no | Up to 10 image attachment objects per message | ✅ yes | base_send_service.rb:8-19 perform_reply loops message.attachments, each via separate send_message |
| Caption on media | ◀ in | ❌ no | No caption field; IG delivers text and media as separate messages | ✅ yes | base_message_builder.rb:103-108 creates message with content then attaches media to same message (e.g. story replies carry reply text + story attachment) |
| Caption on media | ▶ out | ❌ no | No caption field; text and attachment sent separately | ❌ no | base_send_service.rb:8-13 send_attachments then send_content as separate send_message calls; no caption bundled onto media |
| Unsupported-type fallback handling | ◀ in | ✅ yes | messages webhook is_unsupported:true | ✅ yes | base_message_builder.rb:39-41,101,171 is_unsupported flag + all_unsupported_files? skip; messenger/message_builder.rb:134-136 unsupported_file_type? |
| Quick replies / suggested responses | ▶ out | ✅ yes | quick_replies array <=13; content_type text/user_phone_number/user_email; tap returns via message.quick_reply | ❌ no | No quick_replies payload built in Instagram send services (only text/attachment/reply_to/human_agent_tag) |
| Buttons (URL/postback/call) send + click | ◀ in | ✅ yes | messaging_postbacks webhook: postback{mid,title,payload} on button/CTA/icebreaker click | ❌ no | No postback handling; channel/instagram.rb:51 subscribed_fields + SUPPORTED_EVENTS job:14 lack messaging_postbacks |
| Buttons (URL/postback/call) send + click | ▶ out | ✅ yes | Button/Generic Template (web_url, postback), 1-3 buttons | ❌ no | No button/template payload in send services |
| List / menu message | ▶ out | ❌ no | No list template for IG Login (only generic/button) | ❌ no | No list/menu payload in send services |
| Carousel / generic template cards | ▶ out | ✅ yes | Generic Template carousel, <=10 elements, 3 buttons each (postback/web_url) | ❌ no | No generic-template/carousel payload in send services |
| Product / catalog / commerce message | ◀ in | ⚠️ partial | Product/post share arrives as share/ig_post attachment; no structured product message | ❌ no | No structured product handling; ig_post shares handled as post attachments, not commerce products |
| Product / catalog / commerce message | ▶ out | ❌ no | No product/commerce template under IG Login | ❌ no | No catalog send path |
| In-thread payment / checkout | ◀ in | ❌ no | No in-thread payment/checkout in API surface | ❌ no | No payment/checkout handling in IG path |
| In-thread payment / checkout | ▶ out | ❌ no | No in-thread payment/checkout in API surface | ❌ no | No payment/checkout send path |
| Forms / flows (multi-step) | ◀ in | ❌ no | No forms/flows (Flows are WhatsApp-only) | ❌ no | No forms/flows handling in IG path |
| Forms / flows (multi-step) | ▶ out | ❌ no | No forms/flows message type | ❌ no | No forms/flows send path |
| Persistent menu | ▶ out | ✅ yes | Persistent Menu supported for IG Login (dedicated feature page) | ❌ no | No persistent-menu setup in Channel::Instagram or services |
| Story mention | ◀ in | ✅ yes | messages webhook attachment type=story_mention | ✅ yes | messenger/message_builder.rb:75-88 fetch_story_link; instagram message_builder.rb:8-19 get_story_object_from_source_id; attachment_params :story_mention |
| Story reply | ◀ in | ✅ yes | messages webhook reply_to.story{id,url} | ✅ yes | base_message_builder.rb:86-88,111-134 story_reply_attributes->save_story_info + create_story_reply_attachment |
| Post/comment -> DM handoff | ◀ in | ✅ yes | comments webhook + Private Replies (comment->DM) supported | ✅ yes | instagram_events_job.rb:92-100 comments->CommentService->CommentMessageBuilder creates conversation message; subscribed comments |
| Typing indicator | ◀ in | ❌ no | No inbound typing webhook | ❌ no | No inbound typing event; not in subscribed_fields/SUPPORTED_EVENTS |
| Typing indicator | ▶ out | ✅ yes | sender_action=typing_on/typing_off (sender-actions page) | ✅ yes | channel_typing_relay.rb:39-40 Channel::Instagram->Instagram::TypingStatusJob->typing_status_service.rb sender_action typing_on/off |
| Online / last-active presence | ◀ in | ❌ no | No presence/last-active webhook | ❌ no | No presence/last-active handling in IG path |
| Rich text formatting (bold/italic/etc.) | ◀ in | ❌ no | Plain UTF-8 text; no bold/italic markup | ❌ no | Text stored as plaintext; no formatting parsing |
| Rich text formatting (bold/italic/etc.) | ▶ out | ❌ no | Plain UTF-8 text; no formatting markup | ❌ no | Outgoing text sent as plaintext; no formatting markup |
| @mentions | ◀ in | ⚠️ partial | @username arrives as plain text; no structured mention entity (story_mention is separate) | ❌ no | No @mention parsing; text stored plain |
| @mentions | ▶ out | ⚠️ partial | @username sent as plain text; no structured mention API | ❌ no | No @mention send handling |
| Emoji (unicode) | ◀ in | ✅ yes | UTF-8 text carries emoji | ✅ yes | base_message_builder.rb:82 message_content stores unicode text incl emoji |
| Emoji (unicode) | ▶ out | ✅ yes | UTF-8 text carries emoji; reactions accept UTF-8 emoji | ✅ yes | base_send_service.rb:33 message text carries unicode emoji |
| Contact display name | ◀ in | ✅ yes | User Profile API field: name | ✅ yes | message_text.rb:22-33 name fetched->find_or_create_contact->channel/instagram.rb:37-43 create_contact_inbox(id,name) |
| Contact avatar / profile picture | ◀ in | ✅ yes | User Profile API field: profile_pic (URL) | ✅ yes | message_text.rb profile_pic->webhooks_base_service.rb:26 Avatar::AvatarFromUrlJob |
| Extended profile (username/verified/followers/etc.) | ◀ in | ✅ yes | Fields: username, follower_count, is_verified_user, is_user_follow_business | ✅ yes | message_text.rb:10 fetches username/follower_count/is_verified_user/is_user_follow_business; webhooks_base_service.rb:36-58 stores social_instagram_* attrs |
| Messaging window (e.g. 24h) enforcement | ▶ out | ✅ yes | 24h standard messaging window enforced by Meta | ❌ no | No 24h window check in send path; Base::SendOnChannelService only checks outgoing/private/source_id/voice_call; send attempted regardless |
| Message tags / out-of-window send | ▶ out | ⚠️ partial | Only HUMAN_AGENT tag on IG (extends window to 7 days); other Messenger tags not available | ⚠️ partial | send_on_instagram_service.rb:25-33 ENABLE_INSTAGRAM_CHANNEL_HUMAN_AGENT->messaging_type=MESSAGE_TAG, tag=HUMAN_AGENT |
| Template / pre-approved proactive message | ▶ out | ❌ no | No pre-approved message templates on IG (WhatsApp-only) | ❌ no | No pre-approved template send for Instagram |
| Handover protocol (bot <-> agent) | ◀ in | ✅ yes | Handover Protocol supported on IG Login: standby channel + take_thread_control (secondary receiver) | ⚠️ partial | instagram_events_job.rb:174-176 messages() falls back to entry[:standby], processing standby msgs as normal inbound; no take/pass thread-control API |
| Handover protocol (bot <-> agent) | ▶ out | ✅ yes | pass_thread_control / request_thread_control supported on IG Login | ❌ no | No pass_thread_control/take_thread_control API call in Instagram path |
| Group vs 1:1 conversation support | ◀ in | ❌ no | Docs: group messaging not supported; one customer per conversation | ❌ no | 1:1 only; contact keyed by single sender IGSID; no group/participant modeling |

### TikTok DM

| Feature | Dir | Support | Support evidence | Impl | Impl evidence |
|---|---|---|---|---|---|
| Text message | ◀ in | ✅ yes | Webhook doc im_receive_msg: content type=text, text.body; EU senders arrive via im_receive_msg_eu with content stripped (only to/to_user/timestamp). | ✅ yes | tiktok_events_job.rb:6,61 im_receive_msg -> message_service.rb:120-122 text_message?, :143 content[:text][:body] set as message content. |
| Text message | ▶ out | ✅ yes | Send doc: message_type=TEXT with text.body (6000-char limit incl. spaces/emojis). | ✅ yes | SendReplyJob maps Channel::Tiktok->Tiktok::SendOnTiktokService (send_reply_job.rb); send_on_tiktok_service.rb:49 send_text_message -> client.rb:68,124-125 TEXT body. |
| Sent/accepted status (platform ack) | ▶ out | ✅ yes | Send doc response: code:0 + data.message.message_id is the platform ack for a successful send. | ✅ yes | send_on_tiktok_service.rb:13-16 captures returned message_id -> message.source_id set and status advanced (client.rb:131 returns message_id). |
| Delivered receipt on our outbound msgs | ◀ in | ❌ no | No delivered webhook exists; the only delivery-side event is im_mark_read_msg (read). Webhook doc event list has no delivered event. | ⚠️ partial | send_on_tiktok_service.rb:16 optimistically self-marks 'delivered' on the send-ack; there is no genuine platform delivered receipt ingested. |
| Read / seen receipt | ◀ in | ✅ yes | Webhook doc im_mark_read_msg with read.last_read_timestamp; fires only when a Personal Account marks read (Business-side marks send no notification). | ✅ yes | tiktok_events_job.rb:6,67 im_mark_read_msg -> read_status_service.rb:9 enqueues Conversations::UpdateMessageStatusJob with last_read_timestamp. |
| Read / seen receipt | ▶ out | ✅ yes | Send doc: message_type=SENDER_ACTION, sender_action=MARK_READ shows 'Seen' to the user. | ✅ yes | conversations_controller.rb:128 Tiktok::MarkAsReadJob -> mark_as_read_service.rb:34 -> client.rb:78-81 send_sender_action MARK_READ. |
| Failed status + error reason | ◀ in | ⚠️ partial | Return codes doc: synchronous send/ errors (40064 blocked, 40908 unsupported file, 40002 param, 40100 rate, 51065 system) carry a reason; there is no async delivery-failure webhook. | ✅ yes | send_on_tiktok_service.rb:17-19 rescue -> Messages::StatusUpdateService(message,'failed',e.message) stores failed status + external_error. |
| Retry / resend a failed send | ▶ out | ⚠️ partial | Return codes doc: 51065 'Retry the call'; retry means re-POSTing send/ (no idempotency key or dedicated resend endpoint). | ✅ yes | messages_controller.rb:28-37 retry sets status 'sent', clears content_attributes, re-enqueues SendReplyJob -> Tiktok::SendOnTiktokService. |
| Outbound echo (agent msg sent from platform app) | ◀ in | ✅ yes | Webhook doc im_send_msg fires for business sends including APP/WEB (message_tag.source APP/WEB/API/OTHERS). | ✅ yes | tiktok_events_job.rb:55-57 im_send_msg passes outgoing_echo:true; message_service.rb:9-12 dedups API echoes by source_id, :116 sets external_echo=true for app/web echoes. |
| Quote / reply-to a specific message | ◀ in | ✅ yes | Webhook doc: referenced_message_info.referenced_message_id on im_receive_msg/im_send_msg. | ✅ yes | message_service.rb:114,158-160 sets content_attributes[:in_reply_to_external_id] = referenced_message_info.referenced_message_id. |
| Quote / reply-to a specific message | ▶ out | ✅ yes | Send doc: referenced_message_info.referenced_message_id; only text replies supported (must set message_type=TEXT). | ✅ yes | message.rb:353 ensure_in_reply_to -> InReplyToMessageBuilder resolves referenced source_id; send_on_tiktok_service.rb:44,49 -> client.rb:118 referenced_message_info on TEXT sends only. |
| Edit an already-sent message | ◀ in | ❌ no | No edit/update event in the Business Messaging webhook surface (type enum: text/image/share_post/video/emoji/sticker/reaction/template). | ❌ no | tiktok_events_job.rb:6 SUPPORTED_EVENTS has no edit event; message_service handles no edit type. |
| Edit an already-sent message | ▶ out | ❌ no | Send doc has no edit parameter/endpoint; message_type enum has no edit option. | ❌ no | send_on_tiktok_service/client only create new sends; no edit path. |
| Unsend / recall / delete a message | ◀ in | ❌ no | No unsend/recall/delete event in webhook surface. | ❌ no | tiktok_events_job.rb:6 SUPPORTED_EVENTS has no delete/recall event. |
| Unsend / recall / delete a message | ▶ out | ❌ no | No unsend/recall/delete endpoint in Business Messaging API reference. | ❌ no | No Channel::Tiktok recall/delete path in client/send service (message.rb recall trigger is TiktokShop-only). |
| Reaction add (emoji) | ◀ in | ✅ yes | Webhook doc: type=reaction, reaction[].operation=ADD, type EMOJI/AI_EMOJI, emoji/ai_emoji_url, original_msg_id. | ✅ yes | message_service.rb:7 routes reaction to message_reaction_service.rb:42-43 apply_reaction! action 'react' (EMOJI only; AI_EMOJI skipped). |
| Reaction add (emoji) | ▶ out | ❌ no | Send doc message_type enum has no reaction option; no reaction-send capability. | ❌ no | messages_reactions_controller.rb:52-58 forwards only Channel::FacebookPage/Instagram to the platform; TikTok reaction is only apply_reaction! stored locally (never sent to the customer). |
| Reaction remove | ◀ in | ✅ yes | Webhook doc: reaction[].operation=REMOVE. | ✅ yes | message_reaction_service.rb:42-43 operation!=ADD -> apply_reaction! action 'unreact'. |
| Reaction remove | ▶ out | ❌ no | No reaction-send capability on send/. | ❌ no | messages_reactions_controller.rb:52-58 forwards only FB/IG; TikTok unreact is local-only. |
| Forward a message | ◀ in | ❌ no | No forward event/field in webhook surface. | ❌ no | No forward event or parser in message_service. |
| Forward a message | ▶ out | ❌ no | No forward parameter on send/. | ❌ no | No forward path in SendOnTiktokService/client. |
| Image | ◀ in | ✅ yes | Webhook doc type=image, image.media_id; media/download/ supports media_type=IMAGE. Region-gated (both parties in image-supporting markets). | ✅ yes | message_service.rb:82-96 image_message? -> fetch_attachment via client.rb:35 file_download_url -> attachment file_type image. |
| Image | ▶ out | ✅ yes | Upload doc: media/upload/ IMAGE (JPG/PNG, 3MB) -> send/ message_type=IMAGE; capabilities/get IMAGE_SEND, region-gated. | ✅ yes | send_on_tiktok_service.rb:31-35,47 validates JPG/PNG<3MB + image_send capability; client.rb:72-76 upload_media+IMAGE send. |
| Video | ◀ in | ✅ yes | Webhook doc type=video, video.media_id; media/download/ supports media_type=VIDEO. | ✅ yes | message_service.rb video_message? added to supported_message? + create_message_attachments; create_video_message_attachment downloads via fetch_attachment(..., 'VIDEO') (media_type threaded through file_download_url) and attaches file_type: :video (PR #137) |
| Video | ▶ out | ❌ no | Send doc message_type has no VIDEO; media/upload only supports IMAGE. | ❌ no | send_on_tiktok_service.rb:33 'Only image attachments are supported'; client send only TEXT/IMAGE. |
| Audio / voice note | ◀ in | ❌ no | No audio type in webhook type enum; would surface as content/list message_type=OTHER (no content). | ❌ no | message_service.rb:108-109 not in supported types -> unsupported. |
| Audio / voice note | ▶ out | ❌ no | No audio message_type on send/. | ❌ no | send_on_tiktok_service.rb:33 only image attachments; client TEXT/IMAGE only. |
| File / document | ◀ in | ❌ no | No file/document type in webhook type enum; surfaces as message_type=OTHER. | ❌ no | message_service.rb:108-109 not supported -> unsupported. |
| File / document | ▶ out | ❌ no | No file message_type on send/; media/upload IMAGE only. | ❌ no | send_on_tiktok_service.rb:33 image-only; client TEXT/IMAGE only. |
| Sticker | ◀ in | ✅ yes | Webhook doc type=sticker, sticker.url (30-day URL); content/list message_type=STICKER. | ❌ no | message_service.rb:128-130 sticker_message? defined but excluded from supported_message? (:108-109) -> is_unsupported, sticker.url not ingested. |
| Sticker | ▶ out | ❌ no | No STICKER message_type on send/. | ❌ no | client.rb send_message builds only TEXT/IMAGE. |
| GIF / animated | ◀ in | ❌ no | No gif type in webhook/content type enums (only emoji/sticker/etc.). | ❌ no | No gif type handled (message_service.rb:108-109). |
| GIF / animated | ▶ out | ❌ no | No gif message_type on send/. | ❌ no | No gif path in client/send service. |
| Location (static) | ◀ in | ❌ no | No location type in API/webhook surface. | ❌ no | No location type handled (message_service.rb:108-109). |
| Location (static) | ▶ out | ❌ no | No location message_type on send/. | ❌ no | No location path in client/send service. |
| Live location | ◀ in | ❌ no | Not present in API/webhook surface. | ❌ no | No code path. |
| Contact card / vCard | ◀ in | ❌ no | No vCard/contact type in API/webhook surface. | ❌ no | No code path. |
| Contact card / vCard | ▶ out | ❌ no | No contact message_type on send/. | ❌ no | No code path. |
| Link preview / URL unfurl | ◀ in | ❌ no | text.body is plain; no URL-unfurl object. share_post carries embed_url but is a shared TikTok post, not arbitrary link preview. | ❌ no | message_service.rb:98-106 share_post -> embed attachment of a TikTok post; no generic link unfurl. |
| Link preview / URL unfurl | ▶ out | ❌ no | No link-preview control on send/ (text sent as-is). | ❌ no | client.rb:125 sends raw text body; no unfurl handling. |
| Multiple attachments in one message | ▶ out | ❌ no | Send doc: one message_type per send; 'A message cannot consist of both text and image'. | ❌ no | send_on_tiktok_service.rb:26 raises 'multiple attachments in a single TikTok message is not supported'. |
| Caption on media | ◀ in | ❌ no | Media messages carry no text/caption field; text+image mutually exclusive. | ❌ no | message_service.rb:82-96 image parses media_id only, no caption. |
| Caption on media | ▶ out | ❌ no | Send doc forbids text+image in one message. | ❌ no | send_on_tiktok_service.rb:25 raises 'Sending attachments with text is not supported'. |
| Unsupported-type fallback handling | ◀ in | ⚠️ partial | content/list exposes message_type=OTHER (content not retrievable); webhook delivers typed events (video/emoji/sticker/template) without a dedicated OTHER type. | ✅ yes | message_service.rb:115 sets is_unsupported=true for any non text/image/share_post; the message is still created (create_message runs unconditionally). |
| Quick replies / suggested responses | ▶ out | ✅ yes | Send doc: message_type=TEMPLATE, QA_BUTTON_CARD/QA_LINK_CARD with REPLY buttons (clicking sends the button text back as the user). | ❌ no | client.rb send_message builds only TEXT/IMAGE payloads; no TEMPLATE support. |
| Buttons (URL/postback/call) send + click | ◀ in | ⚠️ partial | Webhook doc reply_source_payload.reply_source_unique_id identifies which QA-card button/link was clicked; REPLY type only (no URL/postback/call). | ❌ no | message_service does not parse reply_source_payload; a button click arrives as plain text and is stored as ordinary text, with no button metadata. |
| Buttons (URL/postback/call) send + click | ▶ out | ⚠️ partial | Send doc TEMPLATE buttons type enum is REPLY only; no URL/postback/call button types. | ❌ no | No TEMPLATE send in client (TEXT/IMAGE only). |
| List / menu message | ▶ out | ❌ no | No list/menu message_type on send/. | ❌ no | No code path (client TEXT/IMAGE only). |
| Carousel / generic template cards | ▶ out | ❌ no | Send/content docs: template elements 'only one card is supported within elements'. | ❌ no | No template/carousel send path. |
| Product / catalog / commerce message | ◀ in | ❌ no | No product/commerce message type in Business Messaging surface (commerce is TikTok Shop, separate). | ❌ no | No code path in Channel::Tiktok (commerce lives in separate Channel::TiktokShop). |
| Product / catalog / commerce message | ▶ out | ❌ no | No product/catalog message_type on send/. | ❌ no | No code path. |
| In-thread payment / checkout | ◀ in | ❌ no | Not present in Business Messaging surface. | ❌ no | No code path. |
| In-thread payment / checkout | ▶ out | ❌ no | Not present in Business Messaging surface. | ❌ no | No code path. |
| Forms / flows (multi-step) | ◀ in | ❌ no | No multi-step form/flow type; QA cards are single-step single-card. | ❌ no | No code path. |
| Forms / flows (multi-step) | ▶ out | ❌ no | No flow send; only single QA-card templates. | ❌ no | No code path. |
| Persistent menu | ▶ out | ⚠️ partial | Analog only: chat prompts (up to 6 interactive buttons above input box) + suggested questions, configured via auto_message API (guide docs). | ❌ no | No auto_message/chat-prompt management code in the fork. |
| Story mention | ◀ in | ❌ no | No story-mention event (TikTok has no stories in this surface). | ❌ no | No code path. |
| Story reply | ◀ in | ❌ no | No story-reply event in surface. | ❌ no | No code path. |
| Post/comment -> DM handoff | ◀ in | ⚠️ partial | Webhook im_receive_high_intent_comment + send/ direct_reply reply_type=COMMENT_REPLY; Comment-to-Message only for Business Accounts registered in Vietnam/Indonesia/Thailand. | ❌ no | im_receive_high_intent_comment not in SUPPORTED_EVENTS (tiktok_events_job.rb:6); no direct_reply send path. |
| Typing indicator | ◀ in | ❌ no | No customer-typing webhook event in surface. | ❌ no | No typing-receive event in SUPPORTED_EVENTS (tiktok_events_job.rb:6). |
| Typing indicator | ▶ out | ✅ yes | Send doc: message_type=SENDER_ACTION, sender_action=TYPING (auto-clears after ~5s; no stop action). | ✅ yes | channel_typing_relay.rb:15,44 (start-only) -> typing_status_job.rb -> typing_status_service.rb:27,39 -> client.rb:84-88 SENDER_ACTION TYPING. |
| Online / last-active presence | ◀ in | ❌ no | No presence/last-active field or event in surface. | ❌ no | No code path. |
| Rich text formatting (bold/italic/etc.) | ◀ in | ❌ no | text.body is plain text; no bold/italic markup in schema. | ❌ no | message_service.rb:143 stores plain body; no formatting parsed. |
| Rich text formatting (bold/italic/etc.) | ▶ out | ❌ no | text.body plain; no formatting markup parameter on send/. | ❌ no | client.rb:125 sends raw text; no markup handling. |
| @mentions | ◀ in | ❌ no | No @mention field in message schema. | ❌ no | No code path. |
| @mentions | ▶ out | ❌ no | No mention parameter on send/. | ❌ no | No code path. |
| Emoji (unicode) | ◀ in | ✅ yes | text.body carries unicode emoji (content/list example body '👍👍'). | ✅ yes | message_service.rb:143 stores text body verbatim; unicode passes through. |
| Emoji (unicode) | ▶ out | ✅ yes | Send doc: text.body length limit is 6000 chars 'including spaces and emojis'. | ✅ yes | client.rb:125 sends text body verbatim; unicode passes through. |
| Contact display name | ◀ in | ✅ yes | Webhook 'from' is the TikTok username; content/list participants[].display_name is the nickname. | ⚠️ partial | messaging_helpers.rb:12-16 sets contact name = webhook 'from'. |
| Contact avatar / profile picture | ◀ in | ✅ yes | content/list participants[].profile_image (temporary URL with x-expires); webhook carries no avatar. | ✅ yes | message_service.rb:63 ContactProfileJob -> contact_profile_job.rb:29 participants profile_image -> Avatar::AvatarFromUrlJob. |
| Extended profile (username/verified/followers/etc.) | ◀ in | ⚠️ partial | Available: username (from), unique_identifier, is_follower (content/list + webhooks). No verified badge or follower count. | ⚠️ partial | messaging_helpers.rb:19-27 stores username + social_tiktok_user_id/name + social_profiles; is_follower/verified/followers not stored. |
| Messaging window (e.g. 24h) enforcement | ▶ out | ✅ yes | Messaging-limits doc: 48h window (10 msgs after first inbound; unlimited within 48h of each user reply; 3 when inactive); over-limit sends blocked with 40064. | ❌ no | No window tracking/enforcement in SendOnTiktokService (only image_send capability checked); over-limit 40064 just surfaces as a failed send. |
| Message tags / out-of-window send | ▶ out | ❌ no | message_tag.source is a read-only inbound field; no out-of-window/tag send mechanism, and initiating outside the window is prohibited. | ❌ no | No tag/out-of-window logic in send service. |
| Template / pre-approved proactive message | ▶ out | ❌ no | Manage-DM guide: 'You are prohibited from initiating a conversation or messaging any TikTok user who has not started a conversation with you.' Welcome/auto messages are user-triggered only. | ❌ no | No proactive/template initiation code path. |
| Handover protocol (bot <-> agent) | ◀ in | ❌ no | No bot/agent handover protocol in Business Messaging surface. | ❌ no | No handover events for TikTok. |
| Handover protocol (bot <-> agent) | ▶ out | ❌ no | No handover protocol in surface. | ❌ no | No code path. |
| Group vs 1:1 conversation support | ◀ in | ❌ no | conversation/list conversation_type only STRANGER/SINGLE (1:1); no group type. | ❌ no | client.rb:50 conversation_type defaults 'SINGLE'; no group parsing/handling. |

### TikTok Shop

| Feature | Dir | Support | Support evidence | Impl | Impl evidence |
|---|---|---|---|---|---|
| Text message | ◀ in | ✅ yes | Webhook 14 type=TEXT, content {"content":...}; Get Conversation Messages TEXT type | ✅ yes | incoming_message_service.rb:22,148-149 TEXT_LIKE_TYPES→content_hash['content'] |
| Text message | ▶ out | ✅ yes | Send Message 202606 type=TEXT, content {content} max 2000 chars | ✅ yes | send_on_tiktok_shop_service.rb:31-33→client.send_text; SendReplyJob maps Channel::TiktokShop |
| Sent/accepted status (platform ack) | ▶ out | ✅ yes | Send Message returns code:0 + data.message_id (platform ack) | ✅ yes | handle_response captures message_id→source_id, sets 'delivered' (send svc:80-89); msg defaults 'sent' |
| Delivered receipt on our outbound msgs | ◀ in | ❌ no | No delivered-receipt webhook; message events are only 13/14/33 | ❌ no | No delivery webhook handled; 'delivered' is synthesized locally on send success (send svc:84-89) |
| Read / seen receipt | ◀ in | ❌ no | No buyer-read webhook; unread_count is CS-agent-side unread (Get Conversations) | ❌ no | No read event dispatched (events_job.rb:60-72 handles 7/13/14/33 only) |
| Read / seen receipt | ▶ out | ✅ yes | Read Message API POST /customer_service/202309/conversations/{id}/messages/read marks buyer msgs read | ✅ yes | MarkAsReadJob→MarkAsReadService→client.mark_conversation_read; enqueued conversations_controller.rb:129 |
| Failed status + error reason | ◀ in | ⚠️ partial | Synchronous Send error codes (45101006 sensitive, 45109001 conv rules, 45101002/45111017 card) but no async failed webhook | ✅ yes | handle_response sets 'failed'+error from sync response (send svc:90-94); StatusUpdateService |
| Retry / resend a failed send | ▶ out | ⚠️ partial | No idempotency/retry endpoint; re-POST Send; errors 45101001/36009003 advise 'try again' | ✅ yes | Generic messages_controller#retry resets to 'sent', clears content_attributes, re-enqueues SendReplyJob (messages_controller.rb:28-37) |
| Outbound echo (agent msg sent from platform app) | ◀ in | ✅ yes | Webhook 14 fires for any sender.role incl SHOP/CUSTOMER_SERVICE/SYSTEM/ROBOT | ✅ yes | SHOP/CUSTOMER_SERVICE/ROBOT roles ingested as outgoing echoes (external_echo, status delivered) attached to the existing conversation by tiktok_shop_conversation_id; deduped by source_id so our own API sends don't double-post; SYSTEM still dropped (incoming_message_service.rb:26-42, ECHO_ROLES) |
| Quote / reply-to a specific message | ◀ in | ❌ no | No reply_to/quoted field in webhook 14 or Get Conversation Messages message object | ❌ no | create_message sets no in_reply_to; no quoted parse (incoming_message_service.rb:132-146) |
| Quote / reply-to a specific message | ▶ out | ❌ no | Send Message body = type/content/sender_role only; no reply/quote parameter | ❌ no | client.send_message body has no reply-to field (client.rb:50-53) |
| Edit an already-sent message | ◀ in | ❌ no | No message-edited/updated webhook in catalog | ❌ no | No edit event dispatched (events_job.rb:60-72) |
| Edit an already-sent message | ▶ out | ❌ no | No edit-message endpoint in CS API (send/list/read/upload/create + end-session/agent-settings only) | ❌ no | No edit endpoint/service; client exposes no edit method (client.rb) |
| Unsend / recall / delete a message | ◀ in | ❌ no | No recall/unsend/delete-message webhook | ❌ no | No unsend event dispatched (events_job.rb:60-72) |
| Unsend / recall / delete a message | ▶ out | ❌ no | No recall/delete-message endpoint in CS API surface | ⚠️ partial | Recall wired (message.rb:515-526→RecallJob) but OutgoingRecallService is a no-op; deletes in Chatwoot only (outgoing_recall_service.rb:14-22) |
| Reaction add (emoji) | ◀ in | ❌ no | No reaction webhook/field; EMOTICONS is a message type, not a reaction | ❌ no | IncomingReactionService is a no-op & unwired (not called by events_job) (incoming_reaction_service.rb:13-15) |
| Reaction add (emoji) | ▶ out | ❌ no | No message-reaction endpoint in API surface | ❌ no | OutgoingReactionService is a no-op & has no callers (outgoing_reaction_service.rb:8-10) |
| Reaction remove | ◀ in | ❌ no | No reaction-remove webhook in catalog | ❌ no | Same no-op unwired IncomingReactionService (incoming_reaction_service.rb:13) |
| Reaction remove | ▶ out | ❌ no | No reaction endpoint in API surface | ❌ no | Same no-op unwired OutgoingReactionService (outgoing_reaction_service.rb:8) |
| Forward a message | ◀ in | ❌ no | No forwarded-message field/webhook | ❌ no | No forward code path |
| Forward a message | ▶ out | ❌ no | No forward-message endpoint | ❌ no | No forward code path |
| Image | ◀ in | ✅ yes | Webhook 14 type=IMAGE {url,width,height}; FAQ Image up to 10MB | ✅ yes | attach_image→download_and_attach(:image)→Down.download (incoming_message_service.rb:32,57,172,183-192) |
| Image | ▶ out | ✅ yes | Send Message type=IMAGE {url,width,height}; url via Upload Buyer Messages Image (jpg/gif/webp/png ≤10MB) | ✅ yes | send_image_attachment: client.upload_image→client.send_image (send svc:52-59) |
| Video | ◀ in | ✅ yes | Webhook 14 type=VIDEO {url,vid,cover,duration,...} | ✅ yes | attach_video→download_and_attach(:video) (incoming_message_service.rb:33,61,176,183) |
| Video | ▶ out | ✅ yes | Send Message type=VIDEO {vid}; FAQ Video up to 100MB (Large File Upload flow) | ✅ yes | VideoUploadService 3-step chunk upload→client.send_message type=VIDEO {vid} (send svc:61-71; video_upload_service.rb) |
| Audio / voice note | ◀ in | ❌ no | No AUDIO/VOICE type in webhook 14, Get Messages, or Message Types | ❌ no | No audio type handled; unhandled types fall to empty card_summary else (incoming_message_service.rb:53-63,155-170) |
| Audio / voice note | ▶ out | ❌ no | Not in Send Message type enum | ❌ no | SENDABLE_ATTACHMENT_TYPES=[image,video]; audio→mark_unsupported→failed (send svc:36,41-42,73-78) |
| File / document | ◀ in | ❌ no | FAQ: Attachments 'Not Supported'; no file type in webhook/Message Types | ❌ no | No file type handled (incoming_message_service.rb:53-63,155-170) |
| File / document | ▶ out | ❌ no | FAQ Attachments Not Supported; not in Send enum | ❌ no | Not in SENDABLE; rejected as unsupported→failed (send svc:36-42) |
| Sticker | ◀ in | ✅ yes | EMOTICONS type in webhook 14 & Get Messages (content {url,w,h}); FAQ emoji static/animation Yes | ❌ no | EMOTICONS not handled (not IMAGE/VIDEO/TEXT/OTHER/card)→card_summary else returns empty content (incoming_message_service.rb:53-63,148-170) |
| Sticker | ▶ out | ❌ no | EMOTICONS not in Send Message 202606 type enum | ❌ no | No sticker code path |
| GIF / animated | ◀ in | ⚠️ partial | FAQ 'emoji (animation): Yes' (animated EMOTICONS); no distinct GIF message type | ❌ no | No GIF/EMOTICONS handling (incoming_message_service.rb) |
| GIF / animated | ▶ out | ❌ no | No animated/GIF type in Send Message enum (image upload accepts gif format but sent as static IMAGE) | ❌ no | No GIF-specific path; only image/video SENDABLE (send svc:36) |
| Location (static) | ◀ in | ❌ no | No location message type in webhook/Message Types | ❌ no | No location code path |
| Location (static) | ▶ out | ❌ no | Not in Send Message enum | ❌ no | No location code path |
| Live location | ◀ in | ❌ no | No live-location type in API surface | ❌ no | No live-location code path |
| Contact card / vCard | ◀ in | ❌ no | No contact/vCard message type | ❌ no | No contact-card code path |
| Contact card / vCard | ▶ out | ❌ no | Not in Send Message enum | ❌ no | No contact-card code path |
| Link preview / URL unfurl | ◀ in | ❌ no | FAQ: Hyperlinks 'Not supported'; no unfurl metadata in message content | ❌ no | No unfurl parse; text stored as-is (incoming_message_service.rb:148-149) |
| Link preview / URL unfurl | ▶ out | ❌ no | FAQ: Hyperlinks 'Not supported' | ❌ no | Text sent raw; no unfurl control (send svc:31-33) |
| Multiple attachments in one message | ▶ out | ❌ no | Send Message is one type/content per call; Attachments 'Not Supported' as a batch | ✅ yes | send_attachments loops attachments.each{send_attachment} (each = separate API call), then optional text (send svc:38-46) |
| Caption on media | ◀ in | ❌ no | IMAGE/VIDEO content has url/dims only; no caption/text field | ❌ no | IMAGE/VIDEO content set to '' ; no caption ingested (incoming_message_service.rb:150) |
| Caption on media | ▶ out | ❌ no | Send IMAGE/VIDEO content has no caption field | ⚠️ partial | Accompanying text sent as separate TEXT after media, not attached to the media (send svc:44-45) |
| Unsupported-type fallback handling | ◀ in | ✅ yes | Get Messages returns OTHER type + unsupported_msg_tips guidance string + is_visible flag | ⚠️ partial | OTHER ingested as its text (TEXT_LIKE_TYPES); unknown types→empty card_summary else; unsupported_msg_tips/is_unsupported flag never used (incoming_message_service.rb:22,155-170) |
| Quick replies / suggested responses | ▶ out | ❌ no | No quick-reply type; FAQ system_button/select_order = No | ❌ no | No quick-reply code path |
| Buttons (URL/postback/call) send + click | ◀ in | ❌ no | No button/postback type; FAQ system_button = No | ❌ no | No button code path |
| Buttons (URL/postback/call) send + click | ▶ out | ❌ no | No button send type; FAQ card = No | ❌ no | No button code path |
| List / menu message | ▶ out | ❌ no | No list/menu type in Send enum; FAQ select_order = No | ❌ no | No list/menu code path |
| Carousel / generic template cards | ▶ out | ❌ no | No carousel/generic template; FAQ card = No | ❌ no | No carousel code path |
| Product / catalog / commerce message | ◀ in | ✅ yes | Webhook 14 receives PRODUCT_CARD/ORDER_CARD/COUPON_CARD/LOGISTICS_CARD & BUYER_ENTER_FROM_PRODUCT/ORDER | ⚠️ partial | Cards→text summary + raw payload stored in content_attributes.tiktok_shop_payload (incoming_message_service.rb:143,155-170) |
| Product / catalog / commerce message | ▶ out | ✅ yes | Send Message type=PRODUCT_CARD {product_id} (+ORDER/COUPON/LOGISTICS/RETURN_REFUND cards) | ❌ no | client.send_message supports card types but send svc dispatches only TEXT/IMAGE/VIDEO; no message→card path (send svc:20-71; client.rb:44-53) |
| In-thread payment / checkout | ◀ in | ❌ no | No in-thread payment/checkout message type | ❌ no | No payment code path |
| In-thread payment / checkout | ▶ out | ❌ no | No checkout send type; COUPON_CARD is promo only | ❌ no | No payment code path |
| Forms / flows (multi-step) | ◀ in | ❌ no | FAQ message_greeting_question(_answer) = No | ❌ no | No forms/flows code path |
| Forms / flows (multi-step) | ▶ out | ❌ no | No multi-step form/flow send type | ❌ no | No forms/flows code path |
| Persistent menu | ▶ out | ❌ no | No persistent-menu API in surface | ❌ no | No persistent-menu code path |
| Story mention | ◀ in | ❌ no | No stories in TikTok Shop CS; no such webhook/type | ❌ no | No story code path |
| Story reply | ◀ in | ❌ no | No story-reply type/webhook | ❌ no | No story code path |
| Post/comment -> DM handoff | ◀ in | ❌ no | No comment→DM handoff; BUYER_ENTER_FROM_PRODUCT/ORDER is chat entry-context only | ❌ no | Creator event 33 explicitly ignored; no comment→DM (events_job.rb:67-69) |
| Typing indicator | ◀ in | ❌ no | No typing webhook in catalog | ❌ no | No typing event dispatched (events_job.rb:60-72) |
| Typing indicator | ▶ out | ❌ no | No typing/sender_action endpoint in CS API | ❌ no | TiktokShop absent from ChannelTypingRelay dispatch (channel_typing_relay.rb:15,34-46) |
| Online / last-active presence | ◀ in | ❌ no | Buyer presence not exposed; can_accept_chat is the agent's own availability | ❌ no | No presence event/handling (events_job.rb:60-72) |
| Rich text formatting (bold/italic/etc.) | ◀ in | ❌ no | TEXT is plain content string; no bold/italic markup; hyperlinks unsupported | ❌ no | Text stored as plain content; no formatting parse (incoming_message_service.rb:148-149) |
| Rich text formatting (bold/italic/etc.) | ▶ out | ❌ no | Send TEXT is plain string; hyperlinks unsupported | ❌ no | send_text sends raw text (send svc:31-33) |
| @mentions | ◀ in | ❌ no | No @mention field in message content | ❌ no | No mention code path |
| @mentions | ▶ out | ❌ no | No @mention support in Send Message | ❌ no | No mention code path |
| Emoji (unicode) | ◀ in | ✅ yes | TEXT content is free-form UTF-8; FAQ 'emoji (static): Yes' | ✅ yes | Unicode carried transparently in text content (incoming_message_service.rb:148-149) |
| Emoji (unicode) | ▶ out | ✅ yes | Send TEXT is free-form UTF-8; emoji static supported | ✅ yes | Unicode carried in outgoing_content via send_text (send svc:31-33) |
| Contact display name | ◀ in | ✅ yes | Get Conversation/Messages sender.nickname = buyer's TikTok nickname | ✅ yes | sender.nickname placeholder + ContactProfileJob backfill from Get Conversation participants (incoming_message_service.rb:84; contact_profile_job.rb:35-53) |
| Contact avatar / profile picture | ◀ in | ✅ yes | Get Conversation/Messages sender.avatar URL (expiring CDN) | ✅ yes | ContactProfileJob fetches avatar→Avatar::AvatarFromUrlJob (contact_profile_job.rb:55-58) |
| Extended profile (username/verified/followers/etc.) | ◀ in | ❌ no | Only im_user_id/user_id/nickname/avatar/role/buyer_platform exposed; no username/verified/followers | ❌ no | Only nickname+avatar fetched (contact_profile_job.rb:38) |
| Messaging window (e.g. 24h) enforcement | ▶ out | ✅ yes | 6h buyer / 7-day CS auto-close; can_send_message eligibility (30d conv/60d order/return-refund); Send err 45109001 conversation-rule enforcement | ❌ no | No window/eligibility pre-check; comment states it relies on API eligibility error (send svc:6-12,20-29) |
| Message tags / out-of-window send | ▶ out | ⚠️ partial | No tag taxonomy (Tagging is Seller-Center-only per gaps table); out-of-window via Create Conversation reopen (eligibility) + Customer Engagement templates | ❌ no | No tag/out-of-window mechanism; send body has no tag; client.create_conversation unused (client.rb:50-53,66-68) |
| Template / pre-approved proactive message | ▶ out | ✅ yes | Customer Engagement API: Get Message Templates + Create Engagement Task + Send Engagement Message (to buyer_emails, 365d order req, 1/wk-per-shop) | ❌ no | No template/engagement send path; no customer_engagement client methods; create_conversation unused (client.rb) |
| Handover protocol (bot <-> agent) | ◀ in | ⚠️ partial | Session phase AUTO_REPLY/QUEUED/ASSIGNED (Get Conversations cur_session); ALLOCATED_SERVICE/BUYER_ENTER_FROM_TRANSFER msg types; webhook 13 on CS agent join/leave; ROBOT sender role | ⚠️ partial | Event 13→IncomingConversationService but log-only, nothing propagated; ALLOCATED_SERVICE/transfer msgs dropped (non-BUYER) (incoming_conversation_service.rb:12-25; incoming_message_service.rb:43-44) |
| Handover protocol (bot <-> agent) | ▶ out | ⚠️ partial | Update Agent Settings can_accept_chat; End Session API; Send Message sender_role CUSTOMER_SERVICE/SYSTEM/ROBOT | ❌ no | No end_session/agent-settings client methods or callers; sender_role hardcoded CUSTOMER_SERVICE (client.rb:51) |
| Group vs 1:1 conversation support | ◀ in | ❌ no | Always 1 buyer + shop + optional CS agent (participant_count 2-3); no multi-buyer groups | ❌ no | 1:1 buyer↔shop; one contact per im_user_id (incoming_message_service.rb:79-95) |

### Lazada

| Feature | Dir | Support | Support evidence | Impl | Impl evidence |
|---|---|---|---|---|---|
| Text message | ◀ in | ✅ yes | IM Message push (4.1) + /im/message/list return template_id=1 content {"txt":...}; from_account_type=1 (buyer) | ✅ yes | incoming_message_service.rb:114-116 parse_content template_id 1 -> content_json['txt']; create_message builds message_type: :incoming |
| Text message | ▶ out | ✅ yes | /im/message/send (2.2) template_id=1 with txt param | ✅ yes | send_on_lazada_service.rb:19-26 send_text template_id 1 txt via channel.send_im_message |
| Sent/accepted status (platform ack) | ▶ out | ✅ yes | send response (2.2) returns message_id + error_code/error_msg (synchronous platform ack) | ✅ yes | send_on_lazada_service.rb:56-61 on success stores source_id and Messages::StatusUpdateService(message,'sent') |
| Delivered receipt on our outbound msgs | ◀ in | ❌ no | message status field is only 0=normal/1=recalled; session exposes only read positions (to_position/self_position); no delivered concept | ❌ no | SessionUpdateService only marks read (UpdateMessageStatusJob default :read); no delivered path parsed |
| Read / seen receipt | ◀ in | ✅ yes | Session Update push (4.2) to_position = other party's read time (buyer read of seller msgs) | ✅ yes | lazada_events_job.rb:35-37 SESSION_UPDATE -> session_update_service.rb:40-43 to_position -> Conversations::UpdateMessageStatusJob marks non-incoming sent/delivered msgs read |
| Read / seen receipt | ▶ out | ✅ yes | /im/session/read (3.3) + best practices (Sec 7): synchronizes seller's read status to the buyer; requires session_id + last_read_message_id | ✅ yes | conversations_controller Lazada::MarkAsReadJob -> mark_as_read_service now sends both session_id and last_read_message_id (last inbound message's source_id) to channel.read_session (/im/session/read); skips when no inbound message exists (PR #136) |
| Failed status + error reason | ◀ in | ⚠️ partial | send response error_code/error_msg is synchronous only; inbound process_msg field flags security-intercepted 'not sent' (seller-only visible); no async failed-delivery webhook | ✅ yes | send_on_lazada_service.rb:62-66 API error -> Messages::StatusUpdateService(message,'failed',error_msg); status_update_service sets external_error on failed |
| Retry / resend a failed send | ▶ out | ⚠️ partial | no dedicated retry/resend or idempotent API; a resend is just a fresh /im/message/send with a new message_id; LPM 12x/30min retry is inbound webhook-delivery only (Open Platform.pdf) | ✅ yes | messages_controller.rb:28-37 retry resets status to 'sent', clears content_attributes, SendReplyJob.perform_later; send_reply_job.rb:7 maps Channel::Lazada -> Lazada::SendOnLazadaService |
| Outbound echo (agent msg sent from platform app) | ◀ in | ✅ yes | Message push + /im/message/list include from_account_type=2 (seller) messages; seller recalls also pushed (Sec: Message recall) | ✅ yes | seller messages (from_account_type==2) ingested as outgoing echoes (external_echo, status delivered) attached to the existing conversation by lazada_session_id; deduped by source_id so our own API sends don't double-post; source_id set so Base::SendOnChannelService won't re-send (incoming_message_service.rb ingest_echo). Recall of an echoed message is reflected too (PR #134): IncomingRecallService sets message.recall_from_platform so trigger_lazada_recall skips the outbound recall API (no loop) while still marking the echo deleted |
| Quote / reply-to a specific message | ◀ in | ❌ no | message schema (2.1/4.1) has no reply-to/quoted-message field | ❌ no | incoming_message_service parses no quoted/reply reference; no code path |
| Quote / reply-to a specific message | ▶ out | ❌ no | /im/message/send (2.2) has no reply-to/quote param | ❌ no | send_on_lazada_service.send_text sends only txt; no reply reference propagated |
| Edit an already-sent message | ◀ in | ❌ no | no edit event in push/list; only recall (status=1) | ❌ no | lazada_events_job handles only im_message/session_update; parse_content has no edit path |
| Edit an already-sent message | ▶ out | ❌ no | no edit endpoint; only /im/message/recall (2.3) | ❌ no | send service only sends new messages; no edit API call |
| Unsend / recall / delete a message | ◀ in | ✅ yes | recall pushes status=1 message + a system message when buyer OR seller recalls (Sec: Message recall) | ✅ yes | incoming_message_service.rb:12-15 status==1 -> Lazada::IncomingRecallService marks the matching message deleted (incoming, agent-sent, or seller echo) and sets recall_from_platform so no outbound recall API loop fires (PR #134) |
| Unsend / recall / delete a message | ▶ out | ✅ yes | /im/message/recall (2.3) within 2 minutes; system messages not recallable | ✅ yes | messages_controller#destroy -> message.rb:502-513 trigger_lazada_recall -> Lazada::RecallJob -> outgoing_recall_service.rb:22 channel.recall_im_message |
| Reaction add (emoji) | ◀ in | ❌ no | reactions not in IM API surface | ❌ no | no reaction webhook parsed in lazada_events_job; no code path |
| Reaction add (emoji) | ▶ out | ❌ no | reactions not in IM API surface | ❌ no | no reaction send in send service; no /im reaction API in channel/lazada.rb |
| Reaction remove | ◀ in | ❌ no | reactions not in IM API surface | ❌ no | no reaction webhook parsed; no code path |
| Reaction remove | ▶ out | ❌ no | reactions not in IM API surface | ❌ no | no reaction API/send; no code path |
| Forward a message | ◀ in | ❌ no | forward not in IM API surface | ❌ no | no forward handling in incoming service; no code path |
| Forward a message | ▶ out | ❌ no | forward not in IM API surface | ❌ no | no forward handling in send service; no code path |
| Image | ◀ in | ✅ yes | template_id=3 picture; content {imgUrl,osskey,width,height} (Sec 5) | ✅ yes | incoming_message_service.rb:22,132-147 template_id 3 -> attach_image Down.download(imgUrl) into storage (external_url fallback) |
| Image | ▶ out | ✅ yes | /im/message/send template_id=3 with img_url/width/height | ✅ yes | send_on_lazada_service.rb:28-51 send_attachments template_id 3 img_url + width/height from file metadata |
| Video | ◀ in | ❌ no | Per the product owner, Lazada IM does NOT deliver inbound video (buyers can't send video in chat). The IM Open API PDF documents a template_id=6 "video message" + /media/video/get, but that is not delivered in practice — treat the PDF as unreliable here; do NOT re-add based on it. | ❌ no | No template_id 6 handling. (An earlier PR #137 added it from the PDF; reverted in PR #141 as the platform doesn't support inbound video.) |
| Video | ▶ out | ✅ yes | /im/message/send template_id=6 video_id (uploaded via /media/video/block/create) | ❌ no | send_on_lazada_service.rb:30 'next unless attachment.file_type == image' skips video attachments |
| Audio / voice note | ◀ in | ❌ no | no audio/voice template_id | ❌ no | only template_id 3 image attached inbound; no audio path |
| Audio / voice note | ▶ out | ❌ no | no audio/voice template_id | ❌ no | send_on_lazada_service.rb:30 non-image attachments skipped |
| File / document | ◀ in | ❌ no | no file/document template_id | ❌ no | only image attachment inbound; no file path |
| File / document | ▶ out | ❌ no | no file/document template_id | ❌ no | send_on_lazada_service.rb:30 non-image attachments skipped |
| Sticker | ◀ in | ⚠️ partial | template_id=4 'emoji' = fixed Lazada image-based sticker set (imgUrl/smallImgUrl/txt) across 3 tabs (Sec 5); not custom stickers | ⚠️ partial | incoming_message_service.rb:120-121 template_id 4 IS handled -> content_json['txt']; message created showing the bracketed code (e.g. '[happy]'), but imgUrl/smallImgUrl not attached |
| Sticker | ▶ out | ⚠️ partial | send template_id=4 txt=[code] from the fixed Lazada emoji/sticker set only (example: template_id 4, txt:[confused]) | ❌ no | send service only emits template_id 1 (text) and 3 (image); no template_id 4 sticker send path |
| GIF / animated | ◀ in | ⚠️ partial | a subset of template_id=4 stickers are animated .gif assets (tab2: [thank you],[dance],[gift]...); no arbitrary GIF | ⚠️ partial | template_id 4 gif stickers handled as bracketed code text (incoming_message_service.rb:120-121); a gif delivered as a template_id 3 picture would download via attach_image (Down.download preserves content-type) |
| GIF / animated | ▶ out | ⚠️ partial | send template_id=4 sticker whose asset is .gif; no arbitrary GIF upload | ⚠️ partial | a .gif attachment maps to file_type :image (file_type_helper.rb image_file? includes image/gif) so it is sent via template_id 3 img_url; no dedicated GIF/animated support |
| Location (static) | ◀ in | ❌ no | location not in IM API surface | ❌ no | no location template_id in parse_content; no code path |
| Location (static) | ▶ out | ❌ no | location not in IM API surface | ❌ no | send service has no location payload; no code path |
| Live location | ◀ in | ❌ no | live location not in IM API surface | ❌ no | no live-location handling; no code path |
| Contact card / vCard | ◀ in | ❌ no | vCard/contact not in IM API surface | ❌ no | no contact-card parsing; no code path |
| Contact card / vCard | ▶ out | ❌ no | vCard/contact not in IM API surface | ❌ no | no contact-card send; no code path |
| Link preview / URL unfurl | ◀ in | ❌ no | text content is plain {"txt"}; no unfurl/preview object | ❌ no | URLs kept as plain txt; no unfurl handling; no code path |
| Link preview / URL unfurl | ▶ out | ❌ no | txt is a plain string; no unfurl/preview payload | ❌ no | text sent raw as txt; no preview payload; no code path |
| Multiple attachments in one message | ▶ out | ❌ no | one template/attachment per /im/message/send call; no native multi-attachment message | ✅ yes | send_on_lazada_service.rb:28-53 iterates all image attachments (one send each) + a trailing text send, fanning one Chatwoot message into multiple IM messages |
| Caption on media | ◀ in | ❌ no | picture content {imgUrl,osskey,width,height} has no caption slot; video txt is the filename | ❌ no | incoming_message_service.rb:119 template_id 3 returns '' content; no caption parsed |
| Caption on media | ▶ out | ❌ no | template_id=3 picture schema has no txt/caption field | ⚠️ partial | send_on_lazada_service.rb:53 sends the image (template_id 3) then send_text separately, so body text is delivered as a distinct trailing IM bubble, not a caption on the media |
| Unsupported-type fallback handling | ◀ in | ⚠️ partial | every message carries a content JSON string and template_id=2 system messages + process_msg prompts exist; no formal unsupported-type fallback object | ⚠️ partial | incoming_message_service.rb:127-129 else -> content_json['txt'] \|\| raw content (generic text fallback so unknown types are not dropped); no is_unsupported flag set |
| Quick replies / suggested responses | ▶ out | ⚠️ partial | template_id=10015 auto-reply defines action1..10 Txt/Code (quick-reply-style buttons) but it is an auto-reply type and /im/message/send exposes no action params, so it is not agent-sendable via the open API | ❌ no | no quick-reply/action payload in send service; no code path |
| Buttons (URL/postback/call) send + click | ◀ in | ⚠️ partial | received cards (10006 item, 10011 refund, 10015) carry actionUrl/actionCode buttons, but there is no click/postback webhook | ❌ no | parse_content summarizes 10006/10007 to text and ignores actionUrl; no button/postback parsing |
| Buttons (URL/postback/call) send + click | ▶ out | ⚠️ partial | commerce card templates (10006/10007/10008/10010) carry a built-in actionUrl; no arbitrary URL/postback/call buttons | ❌ no | send service only emits template_id 1/3; no card/button payload |
| List / menu message | ▶ out | ❌ no | list/menu not in IM API surface | ❌ no | no list/menu payload in send service; no code path |
| Carousel / generic template cards | ▶ out | ❌ no | single card per message; no carousel/generic template | ❌ no | no carousel/template-card send; no code path |
| Product / catalog / commerce message | ◀ in | ✅ yes | template_id=10006 item card, 10007 order card, 10011 refund card received via push/list (Sec 5) | ⚠️ partial | incoming_message_service.rb:123-126 template_id 10006/10007 -> 'Item: <id>'/'Order: <id>' text summary; 10008/10011 fall to else (raw txt/JSON); no rich card rendering |
| Product / catalog / commerce message | ▶ out | ✅ yes | /im/message/send template_id=10006 item / 10007 order / 10008 voucher (item_id/order_id/promotion_id params) | ❌ no | send service can only send template_id 1 (text) / 3 (image); cannot send item/order/voucher cards |
| In-thread payment / checkout | ◀ in | ❌ no | no in-thread payment/checkout message type | ❌ no | no payment message parsing; no code path |
| In-thread payment / checkout | ▶ out | ❌ no | no in-thread checkout; voucher(10008)/order(10007) are commerce links only | ❌ no | no payment/checkout send; no code path |
| Forms / flows (multi-step) | ◀ in | ❌ no | forms/flows not in IM API surface | ❌ no | no forms/flows handling; no code path |
| Forms / flows (multi-step) | ▶ out | ❌ no | forms/flows not in IM API surface | ❌ no | no forms/flows send; no code path |
| Persistent menu | ▶ out | ❌ no | persistent menu not in IM API surface | ❌ no | no persistent-menu API in Channel::Lazada; no code path |
| Story mention | ◀ in | ❌ no | Lazada IM has no stories | ❌ no | no story handling; no code path |
| Story reply | ◀ in | ❌ no | Lazada IM has no stories | ❌ no | no story handling; no code path |
| Post/comment -> DM handoff | ◀ in | ❌ no | no post/comment channel; IM is seller<->buyer only | ❌ no | no comment->DM handoff; no code path |
| Typing indicator | ◀ in | ❌ no | no typing event in push mechanism | ❌ no | lazada_events_job parses only im_message/session_update; no typing event |
| Typing indicator | ▶ out | ❌ no | no typing/sender-action API | ❌ no | channel_typing_relay.rb enqueue_job has no Channel::Lazada case; nothing enqueued |
| Online / last-active presence | ◀ in | ❌ no | no online/last-active field; self_position/to_position are read timestamps only | ❌ no | no presence/last-active handling; no code path |
| Rich text formatting (bold/italic/etc.) | ◀ in | ❌ no | content is plain {"txt"}; no markup | ❌ no | content stored as plain txt; no formatting parse |
| Rich text formatting (bold/italic/etc.) | ▶ out | ❌ no | txt is plain text; no bold/italic markup | ❌ no | outgoing_content sent raw as txt; no markup handling |
| @mentions | ◀ in | ❌ no | @mentions not in IM API surface | ❌ no | no @mention parsing; no code path |
| @mentions | ▶ out | ❌ no | @mentions not in IM API surface | ❌ no | no mention payload in send service; no code path |
| Emoji (unicode) | ◀ in | ✅ yes | template_id=1 content {"txt"} is a plain UTF-8 string that carries unicode emoji | ✅ yes | incoming_message_service.rb:114-116 template_id 1 -> content_json['txt'] stored verbatim (UTF-8), so unicode emoji pass through |
| Emoji (unicode) | ▶ out | ✅ yes | txt param is a plain UTF-8 string; unicode emoji pass through | ✅ yes | send_on_lazada_service.rb:19-24 emoji embedded in txt sent via template_id 1 |
| Contact display name | ◀ in | ✅ yes | /im/session/get and /im/session/list expose title = buyer nick name (Sec 3.1/3.2) | ❌ no | incoming_message_service.rb:42-48 sets contact name to the numeric user_id; contact_profile_job fetches only head_url and deliberately leaves the (Lazada-masked, e.g. 'T*****r') title unused |
| Contact avatar / profile picture | ◀ in | ✅ yes | /im/session/get and /im/session/list expose head_url = buyer head picture (Sec 3.1/3.2) | ✅ yes | contact_profile_job.rb:34-38 GetSessionDetail head_url -> Avatar::AvatarFromUrlJob (skips Lazada's default placeholder) |
| Extended profile (username/verified/followers/etc.) | ◀ in | ⚠️ partial | session exposes only site_id (country) and tags (e.g. ["official"]) plus buyer_id; no username/verified/followers/bio | ⚠️ partial | incoming_message_service.rb:49-52 persists lazada_account_id + lazada_site_id (country) into contact additional_attributes; no username/verified/followers captured |
| Messaging window (e.g. 24h) enforcement | ▶ out | ✅ yes | Sec 6 Session validity: seller can initiate only within 30d of a buyer order; max 5 messages/day if buyer has not replied, unlimited after a reply | ❌ no | send_on_lazada_service.perform_reply sends unconditionally; no 5-msg/window enforcement |
| Message tags / out-of-window send | ▶ out | ⚠️ partial | no message-tag/HSM system; limited out-of-window sending exists via session validity (/im/session/open for orders <30d + 5-msg pre-reply allowance); session tags are labels only | ❌ no | send_im_message has no tag/out-of-window param; code never calls /im/session/open (uses stored lazada_session_id) |
| Template / pre-approved proactive message | ▶ out | ⚠️ partial | templated commerce cards (10006-10010) + proactive send via /im/session/open within 30d order; no pre-approval/HSM template system | ❌ no | send template_id param is a Lazada content type (1/3), not a pre-approved proactive template; no /im/session/open call implemented |
| Handover protocol (bot <-> agent) | ◀ in | ❌ no | no bot<->agent handover protocol in IM API surface | ❌ no | no Lazada handover protocol; no code path |
| Handover protocol (bot <-> agent) | ▶ out | ❌ no | no bot<->agent handover protocol in IM API surface | ❌ no | no handover API in Channel::Lazada; no code path |
| Group vs 1:1 conversation support | ◀ in | ❌ no | session keyed to a single buyer_id; strictly 1:1 buyer<->seller | ❌ no | conversation/contact built per single buyer session_id; no group handling |
