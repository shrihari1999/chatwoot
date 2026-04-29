# User Preferences — shrihari1999

These are non-negotiable. The Vorflux harness enforced them and the user expects Claude Code to do the same.

## 1. Plan approval before action

> User explicitly wants a plan presented and approved before any code changes or DB actions are taken, even for multi-step tasks. Always present the approach and wait for explicit approval ("Yes please go ahead" or equivalent) before proceeding. This applies to new features too: read referenced documentation, outline the implementation approach (how it follows existing channel patterns, what files change, what tests will be written), and get confirmation before writing any code.

**How to comply:** For anything beyond a 1-3 line typo/config-value fix, write a short numbered plan in chat. Cover: files to change, why, edge cases considered, tests to write. Stop. Wait for the user to say "yes please go ahead" / "proceed" / equivalent. Then code.

The only fixes that skip planning: typos, hardcoded value bumps, comment edits, formatting-only changes — i.e. anything that cannot regress.

## 2. Automated verification expected

> When the user says "you can do tests yourself without me having to test in GUI", they mean: run Rails runner checks, curl endpoint checks, and any other non-browser verification possible before handing back. Don't just say "ready for you to test" — actually run the automated checks and report results.

**How to comply:** Before saying "done", do all that's automatable yourself:
- `bundle exec rspec <path>` — show the example count and pass/fail
- `bundle exec rails runner '<verification snippet>'` against the test or production DB
- `curl -sS -o /dev/null -w "%{http_code}\n" <endpoint>` for HTTP checks
- For frontend: grep the built bundle for the expected string

Report each check and its result.

## 3. Deploy after implementation

> After merging a PR, the agent must merge and deploy to production automatically without asking — do not hand this off to the user.

**Deploy commands** (see `30-deploy-and-verify.md` for full sequence):
- Backend-only changes: `git fetch origin production && git reset --hard origin/production && sudo systemctl restart chatwoot.target` (use `reset --hard`, not `git pull`, so a stale local commit on the VM cannot trigger a confusing merge)
- With gem changes: add `bundle install` before restart
- With migration: add `RAILS_ENV=production bundle exec rails db:migrate` before restart
- With frontend (JS/Vue/CSS): add `RAILS_ENV=production NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider" bundle exec rake assets:precompile` before restart
- After any frontend change: verify the new bundle contains expected content (grep an i18n key or unique string) before restarting. Vite-ruby silently skips rebuilds when the cache is stale.

## 4. Tool constraint transparency

> When a tool or platform restriction blocks a task (e.g. branch prefix guards, missing permissions), the user wants to understand *why* it's failing before seeing the workaround. Explain the constraint briefly, then provide the solution.

**How to comply:** When a tool fails, two-sentence format: "X failed because Y. Falling back to Z which uses a different auth path." Never silently swap tools.

## 5. Telemetry must be fully blocked

> User cares strongly about zero telemetry leakage to external servers. When disabling telemetry, implement all available layers (code stubs, env vars, network-level blocks) without being asked. Don't stop at just one layer.

**How to comply:** When the topic is telemetry, apply ALL of:
- Code-level stubs (e.g. `ChatwootHub.sync_with_hub` returning `nil` immediately)
- `.env` flags (`DISABLE_TELEMETRY=true`, `ENABLE_PUSH_RELAY_SERVER=false`)
- DNS-level block (`/etc/hosts` entries pointing the telemetry hostname to `0.0.0.0`)
- Network-level block (iptables `REJECT` on the resolved IPs, persisted via `/etc/network/if-up.d/`)
- Cron-level: drop telemetry-emitting jobs from `config/schedule.yml`

See `90-enterprise-unlock-recipe.md` for the full chatwoot-hub blocking recipe.

## 6. Debugging workflow — query APIs directly

> User prefers the agent to query APIs directly from the agent's machine (using API tokens) rather than asking the user to install debug builds and share logs. When possible, make test API calls to inspect data structures and save install/test round trips.

**How to comply:** If you have an API token, hit the API yourself. Don't ask the user to share output that you could fetch.

## 7. Build versioning in logs

> User wants a version identifier (e.g., `APP_VERSION`) embedded in all log lines so it's immediately clear which build is running. Include this when building debug or release versions.

**How to comply:** When adding logging, include a build version constant or env-driven identifier in the log prefix.

## 8. Contact name logic — leave alone

> User explicitly said to keep existing contact name logic as-is (using Lazada session `title` field), even though the field returns redacted names.

**How to comply:** Don't "improve" contact-name resolution for Lazada. The user has a reason.

## Verification checklist (run mentally before saying "done")

- [ ] Did I get plan approval before coding? (skip only for trivial fixes)
- [ ] Did I run automated verification myself, not ask the user to?
- [ ] If I deployed, did I run the post-deploy Rails-runner sanity check?
- [ ] If frontend, did I grep the bundle to confirm the change is in?
- [ ] If a tool failed, did I explain *why* before showing the workaround?
- [ ] If telemetry-related, did I block at all layers?
- [ ] Is my final reply terse — PR URL + 2-5 bullets + nothing else?
