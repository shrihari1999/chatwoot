# 80 — Meta (Facebook / Instagram) Webhook Subscriptions

For any work involving Messenger or Instagram DM webhooks, read this before touching code. The most common failure mode is a webhook that "should work" silently delivering nothing because the subscription is set at only one of the two required levels.

---

## TWO subscription levels must both include the field

Meta silently drops webhooks if EITHER level is missing the field — page subscribe returns 200 even when delivery is impossible. To deliver an event for fields like `message_reactions`, both levels must list it:

1. **App-level** — `POST /{app-id}/subscriptions` with `object=page`, `fields=...`. Set once per Meta App via App Dashboard or Graph API using an app access token (`<app_id>|<app_secret>`). Chatwoot has NO code path that sets this; if a new field (e.g. `message_reactions`) is added to the page-level subscriber, the App-level subscription must be updated manually too.
2. **Page-level** — `POST /me/subscribed_apps?subscribed_fields=...&access_token={page_access_token}`. Set per channel by `Channel::FacebookPage#subscribe`.

Verify both:
```bash
# App-level
curl "https://graph.facebook.com/<APP_ID>/subscriptions?access_token=<APP_ID>|<APP_SECRET>"

# Page-level (per channel)
curl "https://graph.facebook.com/me/subscribed_apps?access_token=<PAGE_ACCESS_TOKEN>"
```

When re-POSTing to `/{app-id}/subscriptions`, **omit the `verify_token` param** if your existing token is >64 chars (Meta limit); the existing callback URL/token persist.

---

## Verification methodology — simulations are not end-to-end tests

- Manually invoking `Facebook::MessageReactionService` only proves the service works.
- Manually invoking `Facebook::Messenger::Bot.receive(payload)` only proves the gem dispatch + downstream pipeline.
- Neither proves Meta actually DELIVERS the webhook.

To confirm end-to-end, perform the action in the real client (Messenger app or Instagram), then check:
- `/var/log/nginx/chatwoot_access_443.log` for `POST /bot`
- `journalctl -u chatwoot-worker.1.service -n 200 --no-pager` for the corresponding job

If the access log shows the POST but the worker shows nothing, the webhook arrived but failed dispatch — usually a custom event-type registration issue (see "facebook-messenger gem dispatch" below). If the access log shows nothing, the App-level subscription is missing the field.

---

## `message_reactions` webhook with `action: unreact` does NOT include an emoji

When a Messenger user removes a reaction, Meta's webhook payload contains `mid` + `action: "unreact"` only — no `emoji` and no `reaction` fields. A naive `apply_reaction!(emoji: payload[:emoji], action: 'unreact')` ends up with `emoji=nil`, creating a `data[nil] ||= []` bucket and leaving the original emoji entry untouched, so the customer's reaction pill never disappears from the agent UI even though the unreact webhook fired and the worker logs show `action="unreact" emoji=nil`.

Fix: on unreact with a blank emoji, strip `sender_id` from every emoji bucket and let the empty-bucket prune delete the original entry. Add a spec covering `apply_reaction!(emoji: nil, sender_id: ..., action: 'unreact')` — this is the exact shape the webhook delivers.

---

## facebook-messenger gem dispatch with custom event types

The gem (2.1.2) ships `'reaction' => MessageReaction` in `Facebook::Messenger::Incoming::EVENTS`. Chatwoot's `config/initializers/facebook_messenger.rb` adds a second entry `'message_reaction' => MessageReaction`. `Hash#invert` keeps the LAST key for duplicate values, so:

```ruby
EVENTS.invert[MessageReaction] == "message_reaction"
```

…and `Bot.receive` dispatches to `:message_reaction`. Register the hook as:

```ruby
Bot.on :message_reaction do |event|
  # handler
end
```

NOT `Bot.on :reaction` — it will silently never fire.

---

## Quick checklist when adding a new webhook field

- [ ] Added the field name to the `subscribed_fields` string in `Channel::FacebookPage#subscribe`?
- [ ] Updated the App-level subscription via Graph API or App Dashboard?
- [ ] If existing pages were already subscribed, re-subscribed each one (the field must be added before delivery starts)?
- [ ] Registered a `Bot.on :<event_name>` handler with the correct event symbol (the one returned by `EVENTS.invert[Klass]`, not the original gem name)?
- [ ] Stubbed `graph.facebook.com` in any spec that creates a `Channel::FacebookPage` (otherwise WebMock raises)?
- [ ] Verified end-to-end via real client action, not just `Bot.receive` simulation?
