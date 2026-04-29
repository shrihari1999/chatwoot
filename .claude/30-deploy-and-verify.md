# 30 — Deploy and Verify

After a PR is merged into `production`, deploy to the live VM **automatically** without asking. The user explicitly wants this — see `USER_PREFERENCES.md` §3.

---

## Decision tree: which deploy sequence?

| Change type | Sequence |
|---|---|
| Backend-only (no Gemfile change, no JS/Vue change) | **Sequence A** (fast) |
| Migration added | **Sequence B** (Sequence A + migrate) |
| Gem added/changed (Gemfile.lock changed) | **Sequence C** (full) |
| Frontend (JS/Vue/CSS) change | **Sequence C** (full) |
| Frontend + backend | **Sequence C** (full) |

When in doubt, use Sequence C — it's slower but always correct.

---

## Sequence A — Backend-only fast deploy

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx '
  source /usr/local/rvm/scripts/rvm
  rvm use 3.4.4
  cd /home/chatwoot/chatwoot
  git fetch origin production
  git reset --hard origin/production
  sudo systemctl restart chatwoot.target
'
```

Then verify (see "Post-deploy verification" below).

## Sequence B — Backend + migration

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx '
  source /usr/local/rvm/scripts/rvm
  rvm use 3.4.4
  cd /home/chatwoot/chatwoot
  git fetch origin production
  git reset --hard origin/production
  RAILS_ENV=production bundle exec rails db:migrate
  RAILS_ENV=production bundle exec rails db:migrate:status | tail -5    # confirm migrated state
  sudo systemctl restart chatwoot.target
'
```

## Sequence C — Full deploy (gem or frontend changed)

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx '
  source /usr/local/rvm/scripts/rvm
  rvm use 3.4.4
  cd /home/chatwoot/chatwoot
  git fetch origin production
  git reset --hard origin/production
  bundle install
  RAILS_ENV=production bundle exec rails db:migrate
  RAILS_ENV=production NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider" \
    bundle exec rake assets:precompile
  sudo systemctl restart chatwoot.target
'
```

### `assets:precompile` may silently no-op

If you see `"Skipping vite build. Watched files have not changed"` after a real frontend change, vite-ruby's file-change cache is stale. Force a rebuild:

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx '
  rm -rf /home/chatwoot/chatwoot/public/vite/.vite
  source /usr/local/rvm/scripts/rvm; rvm use 3.4.4
  cd /home/chatwoot/chatwoot
  RAILS_ENV=production NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider" \
    bundle exec rake assets:precompile
'
```

---

## Post-deploy verification (always run these)

### 1. Services are up

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx \
  'sudo systemctl is-active chatwoot-web.1.service chatwoot-worker.1.service'
# expected: active / active
```

### 2. HTTP health

```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://chat.rollingpinn.com/
# expected: 200

curl -sS -o /dev/null -w "%{http_code}\n" https://chat.rollingpinn.com/super_admin/settings
# expected: 302 (auth redirect — proves the controller didn't 500)
```

### 3. Migration (if any) actually applied

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx '
  source /usr/local/rvm/scripts/rvm; rvm use 3.4.4
  cd /home/chatwoot/chatwoot
  RAILS_ENV=production bundle exec rails db:migrate:status | tail -5
'
# expected: every migration listed as `up`
```

### 4. Frontend bundle contains expected change

If the change touched JS/Vue, grep the built bundle for a unique string from your change. **Look across all chunks** — the Vuex store often lands in a separate `DashboardIcon-*.js` or similar chunk:

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx \
  'grep -lR "MY_UNIQUE_MARKER" /home/chatwoot/chatwoot/public/vite/assets/ | head'
```

A negative result against just `dashboard-*.js` is misleading. If grep finds nothing across all chunks, the rebuild was skipped — wipe `.vite/` and re-run `assets:precompile`.

### 5. Behavioral smoke check via Rails runner

For functional changes, run a runner one-liner that exercises the new code path:

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx '
  source /usr/local/rvm/scripts/rvm; rvm use 3.4.4
  cd /home/chatwoot/chatwoot
  RAILS_ENV=production bundle exec rails runner "
    puts ChatwootApp.self_hosted_enterprise?
    puts ChatwootHub.pricing_plan
    puts Account.first.feature_enabled?(:sla)
  "
'
```

### 6. Sidekiq cron jobs

If you added/removed a `config/schedule.yml` entry, verify the cron registry matches:

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx '
  source /usr/local/rvm/scripts/rvm; rvm use 3.4.4
  cd /home/chatwoot/chatwoot
  RAILS_ENV=production bundle exec rails runner "
    Sidekiq::Cron::Job.all.each { |j| puts j.name + \" -> \" + j.cron }
  "
'
```

---

## Failure modes and recovery

### 502 Bad Gateway after deploy

Most common cause: `BUNDLE_WITHOUT` got corrupted. Check:

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx 'cat /home/chatwoot/chatwoot/.bundle/config'
# must contain: BUNDLE_WITHOUT: "development:test"
```

Fix:
```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx '
  source /usr/local/rvm/scripts/rvm; rvm use 3.4.4
  cd /home/chatwoot/chatwoot
  bundle config set --local without "development:test"
  bundle install
  sudo systemctl restart chatwoot.target
'
```

If `rack-timeout` was missing in the boot log, this was the problem.

### Migration failed mid-way

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx '
  source /usr/local/rvm/scripts/rvm; rvm use 3.4.4
  cd /home/chatwoot/chatwoot
  RAILS_ENV=production bundle exec rails db:migrate:status
'
```

A `down` row for a migration you expected to be `up` is the smoking gun. Investigate the migration file, fix forward (DON'T `db:rollback` on production), and redeploy.

### Service won't start

```bash
ssh -i <KEY> <USER>@xxx.xxx.xxx.xxx 'journalctl -u chatwoot-web.1.service -n 100 --no-pager'
```

Read the actual stack trace — common causes: missing env var, missing gem, syntax error from a bad cherry-pick.

---

## Don't deploy these directly

- Anything in `vorflux/*` branches — these are PR sources. Always merge to `production` first, then deploy.
- Local working-copy state — always `git fetch && git reset --hard origin/production` on the VM. Never `git pull` (a stale local commit on the VM can cause a confusing merge).
