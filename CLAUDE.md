# Claude Code — shrihari1999/chatwoot

You are working on a fork of Chatwoot deployed at `https://chat.rollingpinn.com`. The full operating manual is in `.claude/`. **Read it.**

## Mandatory reading order at session start

1. `.claude/README.md` — index
2. `.claude/00-operating-principles.md` — how to approach problems
3. `.claude/USER_PREFERENCES.md` — how the user wants to work
4. `AGENTS.md` (project-level standards from upstream Chatwoot)

For any task that touches code, additionally read the topic-specific files in `.claude/` that match the area you're modifying (e.g. for a frontend change read `70-frontend-knowledge.md`; for a Meta-channel change read `80-meta-webhooks.md`; before deploying read `30-deploy-and-verify.md`).

## Non-negotiables

- **Plan first, code second.** For anything beyond a 1-3 line typo/config fix, present an explicit plan and wait for the user's "go ahead" before writing code. See `00-operating-principles.md` and `USER_PREFERENCES.md`.
- **Verify automatically.** When you say "I'm done", you must have already run the relevant rspec / curl / Rails runner check yourself. Don't ask the user to test in the GUI.
- **Deploy after merge, automatically.** Once a PR is merged, SSH to Azure and run the documented deploy sequence in `30-deploy-and-verify.md` without being asked.
- **Be transparent about constraints.** When a tool or platform restriction blocks a task, explain *why* it's failing before showing the workaround.
- **Telemetry stays fully blocked.** Multiple layers (code stubs + env vars + DNS + iptables) per `90-enterprise-unlock-recipe.md`.

## How to invoke the playbooks

When the user starts a task, the very first thing you do is decide which `.claude/` files to load:

| Task type | Files to read |
|---|---|
| Tiny config/typo fix | `00`, `USER_PREFERENCES` |
| Backend bug fix | `00`, `USER_PREFERENCES`, `60`, `30` (deploy) |
| Frontend change | `00`, `USER_PREFERENCES`, `70`, `30` (deploy) |
| Meta/Facebook/Instagram channel work | `00`, `USER_PREFERENCES`, `60`, `80`, `30` |
| LINE channel work | `00`, `USER_PREFERENCES`, `60`, `30` |
| Enterprise feature unlock / hardening | `00`, `USER_PREFERENCES`, `60`, `90`, `30` |
| Setting up a new test DB | `20`, `60` |
| Reviewing or rebasing a PR | `00`, `40`, `50` |

Always read `00-operating-principles.md` and `USER_PREFERENCES.md` first — they set the tone.
