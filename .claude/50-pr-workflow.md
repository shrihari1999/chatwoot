# 50 — PR Workflow

End goal of every code change: a merged PR on `production` followed by a deploy. This file covers the mechanics. For the deploy itself, see `30-deploy-and-verify.md`.

---

## Branch naming

- Always branch from up-to-date `origin/production`:
  ```bash
  git fetch origin production
  git checkout -B vorflux/<short-description> origin/production
  ```
- Use the `vorflux/` prefix. The Vorflux `git_push` tool enforced it; even though Claude Code uses raw `git push`, keep the convention so the history stays consistent and so any push helpers that still expect the prefix work.
- Branch name: lowercase, kebab-case, ≤ 5 words. Examples: `vorflux/pricing-plan-quantity-cast`, `vorflux/enterprise-hardening`, `vorflux/claude-code-onboarding`.

If you need a non-`vorflux/` name (rare — e.g. a `feature/foo` workflow shared with another tool), see "Pushing a non-vorflux branch" at the bottom.

---

## Commit style

Conventional Commits: `type(scope): subject`. Lowercase subject, no trailing period, ≤ 72 chars.

| Type | When |
|---|---|
| `feat` | User-facing new capability |
| `fix` | Bug fix |
| `chore` | Tooling, schedule, dependencies, no behavior change |
| `refactor` | Restructure with no behavior change |
| `docs` | Docs/comments only |

Examples from this repo:
- `fix(super_admin): cast pricing_plan_quantity to integer`
- `chore(schedule): drop internal_check_new_versions_job to keep self-hosted plan stable`
- `feat(features): backfill premium feature flags for existing self-hosted enterprise accounts`

Do **not** reference Claude (or any AI tool) in commit messages or PR descriptions.

---

## PR description format

(Mirrors the upstream `AGENTS.md` template; do not deviate.)

1. **Lead paragraph** — short, user-facing description of the product change. Plain English, no jargon.
2. **`Closes`** — link to the issue/Linear/Jira reference if there is one. Skip if internal-only.
3. **`How to test`** — for feature PRs, a UX-level repro from a user's perspective. Skip the agent-internal commands.
4. **`How to reproduce`** — for bugfix PRs, the original symptom (so the reviewer can sanity-check the fix solves it).
5. **`What changed`** *(optional)* — implementation highlights, files of interest. Use bullet points.

Do **not** add a `How this was tested` block listing rspec commands. The test results live in the agent chat / commit description, not the PR body.

---

## Opening the PR

The Vorflux `pr-create` and `pr-edit` tools fail on this repo with `GraphQL: Resource not accessible by integration` — that's a known integration auth bug specific to `shrihari1999/chatwoot`. The `gh` CLI (or the `gh` function tool when running inside Vorflux) uses a different auth path and works. From a Claude Code shell:

```bash
# This repo's default branch is `production` (not `main`/`develop`).
# Confirm with: gh repo view --json defaultBranchRef --jq .defaultBranchRef.name
gh pr create \
  --base production \
  --head vorflux/<branch> \
  --title "fix(scope): subject" \
  --body-file /var/tmp/pr_body.md
```

If the fork is ever rebased onto upstream Chatwoot where the default is `develop`, update `--base` accordingly — the value is repo-specific, not universal.

To update an existing PR:

```bash
gh pr edit <PR_NUMBER> --body-file /var/tmp/pr_body.md --title "new title"
```

Always check whether a PR already exists for the branch before creating a new one:
```bash
gh pr list --head vorflux/<branch> --json number,title,url
```

---

## Updating an existing PR (preserve metadata)

Before editing the body, fetch the current one — Vorflux/CI sometimes appends a "Session Details" or "Attached Images" section, and overwriting it strips that metadata:

```bash
gh pr view <PR_NUMBER> --json body --jq .body > /var/tmp/current_body.md
# edit the top portion only, preserving any Session Details / Attached Images / Post-Merge Notes
```

For Claude Code (no Vorflux), this is rarely an issue — but the rule still applies if you collaborate with a teammate who left a comment block in the description.

---

## Merge mechanics

Always squash-merge to keep `production` linear:

```bash
gh pr merge <PR_NUMBER> --squash --admin --delete-branch
```

- `--admin` bypasses branch protection. It only works for repo admins (the user is). If a non-admin teammate ever runs Claude Code on this repo, drop `--admin` and the PR will sit in "ready" state pending checks/review.
- `--delete-branch` removes the `vorflux/...` ref on origin after merge so the branch list stays clean.

If GitHub returns a merge conflict, do not attempt a manual merge from the agent. Resolve locally, push the rebased branch, then re-run the merge command.

---

## After merge — deploy

Per `USER_PREFERENCES.md` §3, deploy automatically. Don't ask. See `30-deploy-and-verify.md` for the exact sequence by change type.

---

## Bulk branch cleanup

The repo accumulates `vorflux/*` branches on origin from prior agent sessions. To delete them in bulk:

```bash
gh api -X DELETE /repos/shrihari1999/chatwoot/git/refs/heads/vorflux/<branch-name>
# HTTP 204 = deleted
# HTTP 422 "Reference does not exist" = already gone (treat as success)
```

The default branch (`production`) cannot be deleted (HTTP 422 "Cannot delete the default branch"). If you ever genuinely need to retire `production`, change the default first via `PATCH /repos/{owner}/{repo}` with `{"default_branch": "..."}`, then delete.

---

## Pushing a non-`vorflux/` branch (rare, Vorflux-specific)

Plain `git push` from Claude Code has no branch-prefix guard, so this workaround is unnecessary in normal use. It's only relevant if the user later returns to a Vorflux session (where the `git_push` tool enforces `vorflux/*`) and needs to land a branch with a different name. Steps:

1. Rename locally: `git branch -m feature/foo vorflux/feature-foo`
2. Push: `git push -u origin vorflux/feature-foo`
3. Rename on GitHub: `gh api /repos/shrihari1999/chatwoot/branches/vorflux/feature-foo/rename --method POST -f new_name=feature/foo`
4. Rename back locally: `git branch -m vorflux/feature-foo feature/foo`

Note: creating a ref via `gh api /repos/.../git/refs --method POST` requires the commit to already exist on GitHub — the API returns HTTP 422 "Object does not exist" if the commit hasn't been uploaded. Always push first, then create/rename refs.

---

## Quick checklist before opening a PR

- [ ] Branch is from latest `origin/production`
- [ ] Quality loop ran (simplify → review → test) per `40-quality-loop.md`
- [ ] All specs pass; new code has new specs
- [ ] PR description follows the format above (no Claude references)
- [ ] PR is opened against `production`, not `develop` or `main`
- [ ] User has approved the plan (per `USER_PREFERENCES.md` §1) — skip only for trivial fixes
