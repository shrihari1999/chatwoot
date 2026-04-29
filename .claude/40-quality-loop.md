# 40 — Quality Loop (Single-Worker Adaptation)

The Vorflux harness ran simplify + review + testing sub-agents in parallel after every code change. With a single Claude Code worker in VS Code, do the same three passes serially, in the same order, against your own diff. Skip them only for trivial fixes (typos, hardcoded value bumps, comment edits, formatting-only).

The loop runs **after** you have written tests yourself and run them at least once. It is not a substitute for unit tests — it is a final QA gate before opening the PR.

---

## When to run the loop

| Change type | Run the loop? |
|---|---|
| Typo, comment edit, single hardcoded value bump | No |
| Anything that adds, modifies, or removes Ruby/JS logic | Yes |
| New migration | Yes |
| New spec file (no production code change) | No, unless it tests new behavior |

When in doubt, run it. Three passes on a 50-line diff take a few minutes and routinely catch mistakes.

---

## Pass 1 — Simplify hat

You are now the simplify reviewer. Read your diff with one question: **what can be deleted without changing behavior?**

Look for:
- Dead code paths (unreachable `if` branches, unused parameters, unused imports)
- Duplicated logic that should be one helper, OR a one-time helper that should be inlined (3 similar lines is better than a premature abstraction)
- Comments that restate what the code obviously does
- Defensive guards that cannot trigger in the current call sites (e.g. nil checks for params Rails always provides, exception handlers wrapping operations that cannot raise)
- Orphaned files (a deleted job whose spec file still exists, a renamed module whose old constant is still referenced in a comment)
- Backward-compat shims for code paths that don't exist anywhere in the repo

Ship the smallest correct diff. **Do not** introduce abstractions for hypothetical future requirements.

If you delete or change anything in this pass, re-run the relevant specs before moving on.

---

## Pass 2 — Review hat

Now you are a senior reviewer. Read the diff with the question: **what could go wrong?**

Categories to scan, in order of severity:

### Correctness regressions
- Does the change preserve existing behavior for the cases it doesn't intend to change?
- For Ruby — Rails 7.1 raw SQL guard (`Arel.sql()` required for `.where.not()` / `.pick()` strings). See `60-chatwoot-knowledge.md`.
- For Vue — is `validations` defined as a function so `requiredIf` is reactive? Both `INBOX_FEATURE_MAP` files updated together?
- For migrations — is `down` reversible, or does it explicitly `raise ActiveRecord::IrreversibleMigration`? Either is fine; **silently** non-reversible is not.

### Race conditions / concurrency
- New `after_update_commit` callback on `Message`? Will it cause a feedback loop with existing inbound recall services? See the inbound-recall guard pattern in `60-chatwoot-knowledge.md`.
- New Sidekiq job that mutates a record another job also mutates? Use `with_lock` or rely on `update_columns` for the specific column.

### Performance
- New N+1 introduced by adding an association access inside an existing loop? Add `.includes(...)` at the loader, not inside the iteration.
- Unbounded loop over a table that grows without limit (e.g. `Message.find_each` without an account scope)?

### Blast radius
- Touching `lib/chatwoot_hub.rb`, `lib/chatwoot_app.rb`, `enterprise/`, or any file referenced from `90-enterprise-unlock-recipe.md`? Re-verify the unlock still holds with `ChatwootApp.self_hosted_enterprise? && ChatwootHub.pricing_plan == 'enterprise'` after the change.
- Editing `config/features.yml`? Remember: existing accounts are NOT retroactively flipped — write a data migration. See the `config/features.yml` gotcha in `60-chatwoot-knowledge.md`.
- Adding a `before_action :check_cloud_env`? Will it block a self-hosted enterprise endpoint that should still work?

### Convention adherence
- Vue components PascalCase? Events camelCase? Tailwind classes only (no scoped CSS, no inline styles)?
- Ruby — module/class declared compact (no nested `module Foo; module Bar`)?
- I18n — no bare strings in templates? Backend strings in `en.yml`, frontend strings in `en.json`?
- Enterprise — if you modified OSS code for enterprise-only behavior, did you use `prepend_mod_with` / `include_mod_with` instead of editing the OSS file directly?

If you find anything in this pass, fix it and re-run pass 1 + relevant specs.

---

## Pass 3 — Testing hat

Mandatory check: **for every new function, method, controller action, or job, there must be a corresponding new spec example.** "All existing tests pass" is not enough.

Coverage rules:
- Happy path — the documented behavior with valid inputs.
- Boundary case — empty array, nil, zero, max length, end of date range.
- Error path — what happens when the dependency raises? When the API returns 4xx/5xx? When the record is missing?

Test runner reminders (this repo, native VM not Docker):
```bash
source /usr/local/rvm/scripts/rvm && rvm use ruby-3.4.4
bundle exec rspec spec/path/to/file_spec.rb
bundle exec rspec spec/path/to/file_spec.rb:42  # single example by line
```

If a spec needs `Channel::FacebookPage.create`, **always stub** the outbound webhook subscribe call:
```ruby
stub_request(:post, /graph\.facebook\.com/).to_return(status: 200, body: '', headers: {})
```
Otherwise WebMock raises `NetConnectNotAllowedError` and the factory blows up.

For test-DB setup, see `20-environment.md` (Docker `chatwoot-postgres-1` on port 5432, `.env.test.local` config).

Report results in the format the user expects:
> `bundle exec rspec spec/...` → 5 examples, 0 failures.

If any fail, fix and re-run before opening the PR.

---

## When the loop says "you missed something"

If pass 1 / 2 / 3 found a gap, fix it, then **start the loop over from pass 1**. Skipping passes after a fix is how regressions slip in.

For reference, PR #29 (`pricing_plan_quantity` cast) and PR #30 (enterprise hardening) both went through this loop and produced 37 examples / 0 failures combined — that is the bar.
