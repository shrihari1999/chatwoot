# 10 — Repo Overview

## What this fork is

`shrihari1999/chatwoot` is a private fork of [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot) running production at `https://chat.rollingpinn.com`. The base is upstream Chatwoot (Rails 7.1, Ruby 3.4.4, Vue 3 + Vite). The fork's value-add lives in:

- **Self-hosted enterprise unlock** — the install runs as `enterprise` plan with all premium features on. See `90-enterprise-unlock-recipe.md`.
- **Channel extensions** — Lazada, LINE, Facebook Messenger, and Instagram have fork-specific behaviour (read receipts, recall, edited labels, quote/reply, reactions).
- **Hardening fixes** — bug fixes layered on production that haven't been upstreamed.

## Repo layout (as it matters here)

```
.
├── app/
│   ├── controllers/                  REST API + super_admin
│   ├── jobs/                         Sidekiq workers
│   ├── models/                       AR models
│   ├── services/                     Domain services (incoming/outgoing message handling per channel)
│   ├── javascript/
│   │   ├── dashboard/                Vue 3 SPA (the agent UI)
│   │   ├── shared/                   Cross-cutting Vue/JS
│   │   └── widget/                   The customer-facing chat widget
│   └── views/super_admin/            Server-rendered admin UI
├── config/
│   ├── features.yml                  Account-level feature flag DEFAULTS (NOT retroactive — see 60)
│   ├── schedule.yml                  Sidekiq-cron job definitions
│   └── routes.rb
├── enterprise/
│   ├── app/                          Enterprise overlay (controllers, jobs, models, services)
│   └── ...                           Extends OSS via prepend_mod_with — see AGENTS.md
├── lib/
│   ├── chatwoot_app.rb               Edition detection (community/enterprise/cloud)
│   ├── chatwoot_hub.rb               Telemetry — patched in this fork (see 90)
│   └── config_loader.rb              Boots InstallationConfig rows from features.yml
├── db/migrate/                       Migrations
├── spec/                             RSpec — mirrors app/ and enterprise/ layout
└── .claude/                          THIS DIRECTORY — onboarding pack for Claude Code
```

## Enterprise overlay rules (from upstream `AGENTS.md`)

> Chatwoot has an Enterprise overlay under `enterprise/` that extends/overrides OSS code. When you add or modify core functionality, always check for corresponding files in `enterprise/` and keep behavior compatible.

- Search both trees before editing: `rg -n "FooService|ControllerName|ModelName" app enterprise`
- For Enterprise-only behavior on existing OSS features, **add an Enterprise module** via `prepend_mod_with` / `include_mod_with`. Don't fork the OSS file.
- For Enterprise-exclusive features, place code directly under `enterprise/`.
- Tests live under `spec/enterprise/` mirroring OSS layout.

## Branch model

- **`production`** — the deployed branch on `chat.rollingpinn.com`. This is the **base branch for all PRs**. (Yes, this fork uses `production`, not `master` or `develop`.)
- **`vorflux/<short-name>`** — feature branches. The Vorflux push tool requires this prefix; for Claude Code you can use any prefix you like, but `vorflux/` is the historical convention so existing tooling/scripts may reference it.

## Production state quick-reference

- Public URL: `https://chat.rollingpinn.com`
- Server: Azure VM, IP `xxx.xxx.xxx.xxx` (replace locally), user `chatwoot`, SSH key path is local to your machine
- Ruby: 3.4.4 via system-wide RVM at `/usr/local/rvm/`
- Web service: `chatwoot-web.1.service`
- Worker service: `chatwoot-worker.1.service`
- Combined target: `chatwoot.target` — restart this to bounce both
- Postgres: native install on the VM (see `20-environment.md` for port quirk)
- Redis: native install
- Plan: `enterprise` (per `InstallationConfig`); see `90-enterprise-unlock-recipe.md`

## Key models / services worth knowing

| Concept | File(s) |
|---|---|
| Inbox / Channel polymorphism | `app/models/inbox.rb`, `app/models/channel/*.rb` |
| Conversation lookup (lock_to_single_conversation) | `app/services/concerns/incoming_message_service.rb` |
| Message creation pipeline | `app/services/messages/message_builder.rb`, `app/services/messages/in_reply_to_message_builder.rb` |
| Featurable concern (account feature flags) | `app/models/concerns/featurable.rb` |
| Installation config (global key-value) | `app/models/installation_config.rb`, `lib/global_config.rb` |
| ChatwootHub (telemetry — patched) | `lib/chatwoot_hub.rb` |
| Chatwoot::App (edition detection) | `lib/chatwoot_app.rb` |
| Internal jobs | `app/jobs/internal/*.rb`, `enterprise/app/jobs/enterprise/internal/*.rb` |
| Super admin (admin UI) | `app/controllers/super_admin/*.rb`, `app/views/super_admin/*` |

## Channel-specific service files (incoming + outgoing pipelines)

| Channel | Incoming | Outgoing |
|---|---|---|
| Facebook Messenger | `app/services/facebook/incoming_message_service.rb` | `app/services/facebook/send_on_facebook_service.rb` |
| Instagram (DM via FB Page) | `app/services/instagram/messenger/...` | `app/services/instagram/messenger/send_on_instagram_messenger_service.rb` |
| Instagram (standalone) | `app/services/instagram/...` (Channel::Instagram) | `app/services/instagram/send_on_instagram_service.rb` |
| LINE | `app/services/line/incoming_message_service.rb` | `app/services/line/send_on_line_service.rb` |
| Lazada | `app/services/lazada/...` |  |
| WhatsApp | `app/services/whatsapp/...` |  |
| Twilio | `app/services/twilio/...` |  |

When adding a new feature to a channel, find the analogous code in another channel that already has it (`Facebook` is usually the most-featured reference) and mirror the pattern.
