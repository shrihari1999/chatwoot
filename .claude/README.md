# Claude Code Worker — Onboarding Pack

This directory replaces the Vorflux harness for the **shrihari1999/chatwoot** fork. It encodes everything Vorflux learned about this repo, this user's deployment, and the user's working preferences so a single Claude Code worker in VS Code can operate at the same level without relearning anything.

## Read order (for the worker, on every new task)

1. **`00-operating-principles.md`** — How Vorflux thinks. Adopt this mindset before touching anything.
2. **`10-repo-overview.md`** — What this fork is, what's different from upstream, where things live.
3. **`20-environment.md`** — Local dev machine, test DB, production server (Azure), how to SSH and run Rails on each.
4. **`30-deploy-and-verify.md`** — The exact deploy sequence after a merge. This is non-negotiable: run it without asking.
5. **`40-quality-loop.md`** — How to simplify/review/test code changes when you only have one worker. (Vorflux had 3 parallel agents; you have to do all three roles serially.)
6. **`50-pr-workflow.md`** — Branch naming, commit style, PR description format, and the two known auth-permission gotchas (`pr-create` failures, branch-prefix guards).
7. **`60-chatwoot-knowledge.md`** — All known runtime gotchas: API quirks, Rails 7.1 raw-SQL traps, channel-specific landmines, ActiveStorage edge cases. Read once and remember.
8. **`70-frontend-knowledge.md`** — Vue 3 / Vite-specific gotchas. Read this before any frontend change.
9. **`80-meta-webhooks.md`** — The two-level Meta subscription model (Facebook/Instagram). Both layers must agree or webhooks silently drop.
10. **`90-enterprise-unlock-recipe.md`** — Full self-hosted enterprise unlock cookbook. The user's install at `chat.rollingpinn.com` runs on this.
11. **`USER_PREFERENCES.md`** — How the user wants to work: plan approval, automated verification, telemetry policy, deploy auto-pilot.

`CLAUDE.md` (at the repo root, alongside `AGENTS.md`) is the **single entry point**. It instructs Claude Code to read this directory's files in the order above.

## Why so many files?

Claude Code has a finite context window. Splitting by topic lets the worker pull in the file that matches the current task without burning context on irrelevant material. For a typical task, the worker reads `CLAUDE.md` + `00-operating-principles.md` + `USER_PREFERENCES.md`, then pulls topic-specific files only when relevant.

## Maintenance

Whenever you discover a new gotcha, add it to the matching file in `.claude/` and reference the file/line where it surfaced. Keep files terse — one sentence per gotcha plus a code-snippet example is the canonical format. The user can re-prime any worker session by pointing it at this directory.
