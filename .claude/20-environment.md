# 20 — Environments

Three environments matter: your **local dev machine**, the **local test DB** (used by rspec), and the **production VM** at chat.rollingpinn.com. This file tells you how to shell into each, run Rails, and run specs.

---

## Local dev (your laptop / VS Code machine)

The repo is checked out at wherever you cloned it. The user typically uses Docker Compose for the data stores so the host machine doesn't need a Postgres/Redis install.

### Prerequisites
- Ruby 3.4.4 (managed by `rbenv` or `rvm`; `.ruby-version` pins it)
- Node 20+, pnpm
- Docker + Docker Compose (for Postgres/Redis)
- `bundle install && pnpm install` once after clone

### Booting the data stores

The repo has a `docker-compose.override.yaml` (gitignored) that adds a Postgres password (upstream's compose file leaves it blank, which Postgres rejects on first boot). Make sure it exists locally:

```yaml
# docker-compose.override.yaml
services:
  postgres:
    environment:
      POSTGRES_PASSWORD: chatwoot_dev_password
```

Boot the stack:

```bash
docker compose -f docker-compose.production.yaml -f docker-compose.override.yaml up -d postgres redis
docker exec chatwoot-postgres-1 pg_isready -U postgres
```

Containers should look like this:
```
chatwoot-postgres-1   pgvector/pgvector:pg16   127.0.0.1:5432->5432/tcp
chatwoot-redis-1      redis:alpine             127.0.0.1:6379->6379/tcp
```

### Running the dev server

Use `overmind start -f Procfile.dev` or `pnpm dev`. Both bring up Rails + Vite + Sidekiq.

### Test database

For rspec, point Rails at the same Docker Postgres but a different DB:

```
# .env.test.local (gitignored)
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=chatwoot_dev_password
POSTGRES_DATABASE=chatwoot_test
```

Then once:
```bash
RAILS_ENV=test bundle exec rails db:create db:schema:load
```

For new migrations: `RAILS_ENV=test bundle exec rails db:migrate`.

### Running specs

```bash
bundle exec rspec spec/path/to/file_spec.rb              # one file
bundle exec rspec spec/path/to/file_spec.rb:LINE         # one example
bundle exec rspec spec/configs/ spec/lib/ spec/jobs/     # multiple paths
```

### Lint

```bash
pnpm eslint        # or pnpm eslint:fix
bundle exec rubocop -a
```

---

## Production VM (chat.rollingpinn.com)

> **Sensitive details masked:** the actual IP, SSH user, and key path are private to your machine. Replace `xxx.xxx.xxx.xxx`, `<USER>`, `<KEY_PATH>` with your real values everywhere below.

### Connection

```bash
ssh -i <KEY_PATH> -o StrictHostKeyChecking=no <USER>@xxx.xxx.xxx.xxx
```

### Layout on the VM

```
/home/chatwoot/
├── chatwoot/                 # the app — git checkout
│   ├── .env                  # production env (gitignored)
│   ├── .bundle/config        # BUNDLE_WITHOUT="development:test" (do NOT corrupt this)
│   ├── public/vite/          # built frontend bundles
│   └── log/                  # (sparse — most logs go to journalctl)
├── install.sh                # the upstream installer (don't re-run)
└── nginx_chatwoot.conf
```

### Ruby / RVM

RVM is **system-wide** at `/usr/local/rvm/`, NOT per-user. To run any Ruby command:

```bash
source /usr/local/rvm/scripts/rvm
rvm use 3.4.4
```

This is required before every `bundle exec`. SSH'd one-liner:

```bash
ssh -i <KEY_PATH> <USER>@xxx.xxx.xxx.xxx \
  'source /usr/local/rvm/scripts/rvm; rvm use 3.4.4; cd /home/chatwoot/chatwoot && RAILS_ENV=production bundle exec rails runner "puts Account.count"'
```

### Services

| Service | Purpose |
|---|---|
| `chatwoot-web.1.service` | Rails / Puma |
| `chatwoot-worker.1.service` | Sidekiq |
| `chatwoot.target` | Combined target — restart this to bounce both at once |

```bash
sudo systemctl status chatwoot-web.1.service
sudo systemctl restart chatwoot.target
journalctl -u chatwoot-worker.1.service -n 200 --no-pager
```

### Nginx access logs

`/var/log/nginx/chatwoot_access_443.log` — useful for confirming Meta webhooks actually reach the box (look for `POST /bot`).

### Running rspec on the VM

The bundle config has `BUNDLE_WITHOUT: "development:test"` and `BUNDLE_DEPLOYMENT: "true"`. To run specs you must temporarily relax both:

```bash
cd /home/chatwoot/chatwoot
bundle config set --local deployment false
bundle config set --local without ''
bundle install
RAILS_ENV=test bundle exec rails db:create db:schema:load   # first time only
bundle exec rspec spec/...

# RESTORE before next deploy — wrong config causes 502
bundle config set --local deployment true
bundle config set --local without 'development:test'
```

If you forget to restore, `rack-timeout` won't load and Rails fails to boot. See `60-chatwoot-knowledge.md` for the exact symptom + recovery.

### Postgres on the VM — port quirk

If the install script saw port 5432 already taken (e.g. by a Docker container), the system Postgres silently binds to **5433**, but `.env` has no `POSTGRES_PORT` setting, so Rails connects to 5432 and fails auth. Fix: append `POSTGRES_PORT=5433` to `/home/chatwoot/chatwoot/.env`.

### Getting an admin API token (one-liner)

```bash
ssh -i <KEY_PATH> <USER>@xxx.xxx.xxx.xxx \
  'source /usr/local/rvm/scripts/rvm; rvm use 3.4.4; cd /home/chatwoot/chatwoot && RAILS_ENV=production bundle exec rails runner "AccountUser.where(role: :administrator).each{|au| puts au.user.email + \"|\" + au.user.access_token.token.to_s}" 2>&1 | grep "@"'
```

Then use the token as `-H "api_access_token: TOKEN"` (NOT a query param — see `60-chatwoot-knowledge.md`).

### Running a Rails runner script from your laptop

Two-step:

```bash
# 1. Copy script to the VM
scp -i <KEY_PATH> /tmp/my_script.rb <USER>@xxx.xxx.xxx.xxx:/tmp/my_script.rb

# 2. Run it
ssh -i <KEY_PATH> <USER>@xxx.xxx.xxx.xxx \
  'source /usr/local/rvm/scripts/rvm; rvm use 3.4.4; cd /home/chatwoot/chatwoot && RAILS_ENV=production bundle exec rails runner /tmp/my_script.rb'
```

### Database — direct psql

```bash
ssh -i <KEY_PATH> <USER>@xxx.xxx.xxx.xxx \
  'sudo -u postgres psql chatwoot_production -c "SELECT count(*) FROM accounts"'
```

(or use port 5433 if the install script hit the port-collision case above)

---

## Local-only secrets file

Per the user's preference (mask sensitive details from the public repo), keep your real Azure host / SSH user / key path / API tokens in a **non-tracked** file:

```
# .claude.local/azure.md  (this directory is in .gitignore)
HOST=<your real IP>
USER=chatwoot
KEY=<absolute path to your local SSH key>
ADMIN_API_TOKEN=<token from the rails runner one-liner above>
```

Whenever a `.claude/` doc says `xxx.xxx.xxx.xxx`, `<USER>`, or `<KEY_PATH>`, substitute from that file. Add it to `.gitignore` to keep it out of commits.

---

## Cheat sheet — most-used commands

```bash
# Deploy after merging a backend-only PR
ssh -i <KEY_PATH> <USER>@xxx.xxx.xxx.xxx \
  'source /usr/local/rvm/scripts/rvm; rvm use 3.4.4; cd /home/chatwoot/chatwoot && \
   git fetch origin production && git reset --hard origin/production && \
   sudo systemctl restart chatwoot.target'

# Run a Rails runner one-liner on production
ssh -i <KEY_PATH> <USER>@xxx.xxx.xxx.xxx \
  'source /usr/local/rvm/scripts/rvm; rvm use 3.4.4; cd /home/chatwoot/chatwoot && RAILS_ENV=production bundle exec rails runner "<RUBY>"'

# Tail Sidekiq logs
ssh -i <KEY_PATH> <USER>@xxx.xxx.xxx.xxx 'journalctl -u chatwoot-worker.1.service -f'

# Tail Rails logs
ssh -i <KEY_PATH> <USER>@xxx.xxx.xxx.xxx 'journalctl -u chatwoot-web.1.service -f'
```
