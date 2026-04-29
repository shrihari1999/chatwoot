# 90 — Enterprise Unlock Recipe

Self-hosted Chatwoot ships with all premium features gated behind a `pricing_plan == 'enterprise'` check that talks to `hub.2.chatwoot.com`. This fork unlocks them locally and blocks the telemetry that would otherwise revert the unlock.

This file is the canonical recipe. Most of it is **already applied** to this repo (see PR #29, PR #30, and prior history). Use this as both a reference and a regression check — if any layer is missing, the unlock will degrade silently.

The user feels strongly about telemetry blocking (`USER_PREFERENCES.md` §5). Apply ALL layers, every time, without being asked.

---

## Why a single DB flag isn't enough

Setting `INSTALLATION_PRICING_PLAN=enterprise` in the DB is insufficient. A background job (`internal_check_new_versions_job` → `Internal::TriggerDailyScheduledItemsJob` → `sync_with_hub`) runs daily, phones home to `hub.2.chatwoot.com`, and overwrites the DB value back to `'community'`. A complete unlock requires code patches, cron changes, frontend route changes, feature-flag flips, and network-level telemetry blocks.

---

## Layer 1 — Code patches

### `lib/chatwoot_hub.rb`
- `pricing_plan` returns `'enterprise'` unconditionally (not just as a fallback) — the DB row likely already exists as `'community'`, so a fallback change has no effect.
- `pricing_plan_quantity` returns `9_999_999` unconditionally. **Always cast to `.to_i` at any read site** (this is what PR #29 fixed: `InstallationConfig#value` is JSON-serialized and may return a String). See `60-chatwoot-knowledge.md`.
- Stub `sync_with_hub`, `register_instance`, `send_push`, `emit_event` to return `nil` immediately.

### `lib/chatwoot_app.rb`
`self_hosted_enterprise?` should be:
```ruby
def self.self_hosted_enterprise?
  enterprise? && !chatwoot_cloud?
end
```
Drop any `GlobalConfig.get_value('INSTALLATION_PRICING_PLAN') == 'enterprise'` guard — that introduces a dependency on the same DB row the hub job tries to overwrite. PR #30 cleaned this up.

### `enterprise/app/controllers/enterprise/api/v1/accounts_controller.rb`
Remove `:limits` from the `before_action :check_cloud_env` guard. The `/limits` endpoint must work on self-hosted enterprise; without it, SLA and other features return 404. PR #30 fixed this.

### `config/schedule.yml`
Drop `internal_check_new_versions_job`. PR #30 dropped it. Side effect: `LATEST_CHATWOOT_VERSION` and `CHATWOOT_SUPPORT_*` no longer auto-refresh; the manual super-admin "Refresh from hub" button still works (and is also blocked by the network layer below, so the unlock holds).

The orphaned `app/jobs/internal/trigger_daily_scheduled_items_job.rb` and its spec were also deleted in PR #30.

### `config/features.yml`
All premium features set to `enabled: true`. PR #30 flipped these 10:
`sla`, `audit_logs`, `custom_tools`, `captain_integration`, `captain_integration_v2`, `custom_roles`, `disable_branding`, `help_center_embedding_search`, `channel_voice`, `advanced_search`.

If you ever add a new premium feature in `features.yml`, set it to `true` for self-hosted and write a backfill migration (see Layer 2).

### Frontend routes
Add `INSTALLATION_TYPES.COMMUNITY` to `installationTypes` arrays in route guards:
- captain routes
- companies routes
- auditlogs routes
- customRoles routes
- security routes
- sla routes

Without this, the routes 404 even if the plan is set correctly.

---

## Layer 2 — Data migration (backfill existing accounts)

Editing `config/features.yml` does NOT retroactively update existing installs (see `60-chatwoot-knowledge.md`). PR #30's migration `db/migrate/20260429111600_enable_premium_features_for_self_hosted_enterprise.rb` covers the 10 features above:

1. Short-circuit on `ChatwootApp.chatwoot_cloud?` (cloud is unaffected).
2. `flip_account_level_feature_defaults` — updates `ACCOUNT_LEVEL_FEATURE_DEFAULTS` `InstallationConfig` row so future accounts inherit the new state.
3. `backfill_existing_accounts` — `Account.find_in_batches(batch_size: 100)`, calls `account.enable_features!(*PREMIUM_FEATURES)`.
4. `GlobalConfig.clear_cache`.
5. `def down` raises `ActiveRecord::IrreversibleMigration` (intentional — flipping back would break the live install).

Pattern to follow if you ever add a new premium feature: copy this migration shape, adjust the `PREMIUM_FEATURES` constant.

---

## Layer 3 — DB setup (Rails runner, run once on the live VM)

```ruby
# Pricing plan + quantity (these survive across deploys)
InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN').tap { |c|
  c.value = 'enterprise'; c.locked = true; c.save!
}
InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').tap { |c|
  c.value = 9_999_999; c.locked = true; c.save!
}

# Cloud-plan feature manifest the frontend reads to decide which menu items to render
InstallationConfig.find_or_initialize_by(name: 'CHATWOOT_CLOUD_PLAN_FEATURES').tap { |c|
  c.value = { 'enterprise' => ['sla', 'audit_log', 'custom_roles', 'saml',
                               'advanced_search', 'captain', 'companies',
                               'voice_channel'] }
  c.locked = true; c.save!
}

# Per-account flag the UI checks for `account.subscribed_features`
Account.find_each do |acc|
  acc.custom_attributes ||= {}
  acc.custom_attributes['plan_name'] = 'enterprise'   # required for subscribed_features UI check
  acc.save!
end
```

`account.subscribed_features` is NOT derived from `pricing_plan` — it requires both `account.custom_attributes['plan_name'] = 'enterprise'` AND the `CHATWOOT_CLOUD_PLAN_FEATURES` row above. Omitting either causes enterprise menu items to be invisible in the UI even when all other checks pass.

Note: an older copy of this recipe used `acc.enable_features!(...)` directly here, but for the 10 features in PR #30 the migration handles backfill. `enable_features!` is still valid for ad-hoc per-account flips.

---

## Layer 4 — Telemetry blocking (network)

Belt and suspenders. Each layer alone is bypassable; together they are not.

### `.env` flags
```
DISABLE_TELEMETRY=true
ENABLE_PUSH_RELAY_SERVER=false
```

### `/etc/hosts` (DNS-level block)
```
0.0.0.0 hub.2.chatwoot.com
```
DNS-level is more reliable than iptables-only because the hub IPs rotate via ELB.

### iptables (network-level block on resolved IPs)
```bash
# Resolve current IPs (CNAME-aware)
dig +short hub.2.chatwoot.com | grep -E '^[0-9]+'

# Block each
sudo iptables -A OUTPUT -d <resolved_ip> -j REJECT
```

Persist via `/etc/network/if-up.d/chatwoot-firewall` so the rules survive a reboot. The script should re-resolve and re-add (since IPs rotate).

### Cron-level (already covered in Layer 1)
`config/schedule.yml` no longer schedules `internal_check_new_versions_job`. No code path on this fork emits telemetry.

---

## Post-unlock verification

Run these on the live VM after any deploy that touches enterprise/billing/feature code:

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx '
  source /usr/local/rvm/scripts/rvm; rvm use 3.4.4
  cd /home/chatwoot/chatwoot
  RAILS_ENV=production bundle exec rails runner "
    puts \"self_hosted_enterprise? = #{ChatwootApp.self_hosted_enterprise?}\"
    puts \"pricing_plan = #{ChatwootHub.pricing_plan}\"
    puts \"pricing_plan_quantity = #{ChatwootHub.pricing_plan_quantity.inspect}\"
    puts \"User.count > pricing_plan_quantity = #{User.count > ChatwootHub.pricing_plan_quantity}\"
    Account.find_each do |a|
      missing = %w[sla audit_logs custom_tools captain_integration captain_integration_v2 custom_roles disable_branding help_center_embedding_search channel_voice advanced_search].reject { |f| a.feature_enabled?(f) }
      puts \"account #{a.id} missing: #{missing.inspect}\" if missing.any?
    end
  "
'
```

Expected output:
- `self_hosted_enterprise? = true`
- `pricing_plan = enterprise`
- `pricing_plan_quantity = 9999999` (Integer — not String)
- `User.count > pricing_plan_quantity = false`
- No "account N missing" lines.

Then HTTP-check the admin endpoints that previously 500'd:
```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://chat.rollingpinn.com/super_admin/settings
# expected: 302 (auth redirect — proves no 500)
```

And confirm the schedule no longer phones home:
```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx '
  source /usr/local/rvm/scripts/rvm; rvm use 3.4.4
  cd /home/chatwoot/chatwoot
  RAILS_ENV=production bundle exec rails runner "
    Sidekiq::Cron::Job.all.each { |j| puts j.name + \" -> \" + j.cron }
  " | grep -i version
'
# expected: no output (no internal_check_new_versions_job entry)
```

---

## When you change anything in this list

Treat all six layers as a single system. If a future change re-introduces:
- A read of `INSTALLATION_PRICING_PLAN` from `chatwoot_hub.rb` → unlock breaks
- A `before_action :check_cloud_env` on a non-cloud endpoint → that endpoint 404s
- A new premium feature in `features.yml` without a backfill migration → existing accounts won't see it
- A cron job that calls `sync_with_hub` → DB plan flips back to community overnight
- A new HTTP call to a `*.chatwoot.com` host → telemetry leaks (DNS block catches `hub.2.chatwoot.com`, but a new hostname slips through)

…re-apply the missing layer in the same PR. Don't ship a half-unlock.
