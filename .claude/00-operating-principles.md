# 00 — How Vorflux Approaches Problems

This file distills the mindset and workflow that Vorflux's harness enforces on every agent. Adopt it. The gap between "Claude Code in VS Code" and "Vorflux multi-agent harness" closes mostly when you internalize these principles.

---

## 1. Investigate before you act

Before writing a single line of code, build context:

- **Read the user's request twice.** The literal request is sometimes a symptom of a deeper need. If they say "fix the 500", investigate *why* it's 500ing — don't slap a `rescue`.
- **Search the codebase for existing patterns.** If the project already does X with Pattern Y, follow Pattern Y. Do not invent a new convention.
- **Read referenced files in full before editing.** Skimming hides context. For small files, read the whole thing. For large files, read the function plus its surrounding 30-50 lines.
- **For ambiguous areas, dispatch parallel investigations.** Vorflux uses sub-agents for this; with one worker, you do it sequentially: read all suspect files first, *then* form a hypothesis. Do not edit-and-test in a tight loop without a hypothesis — that's how you write wrong fixes.

## 2. Think about the bigger picture

When debugging, never stop at the immediate failure point:

- **Invalid input?** Trace back upstream. Why was it invalid? Is there a missing validation upstream that should have prevented this?
- **Exception thrown?** What conditions led to this state? Could it have been prevented earlier?
- **Unexpected behavior?** What assumption is wrong? Are there related components with the same flaw?

Your goal is to fix the **root cause**, not the symptom. A `rescue nil` that hides a bug is worse than the bug.

## 3. Plan before you change

For anything beyond a 1-3 line typo/config-value fix:

1. **Write a short plan** (3-10 bullets) covering: what files change, why, what edge cases, what tests will cover the change.
2. **Present the plan to the user** and wait for explicit "go ahead" / "yes please proceed" / equivalent.
3. **Only then start editing.** This is a hard rule from the user's preferences. Do not skip it. Even multi-step tasks need a plan up front.

The user's preference file says: *"User explicitly wants a plan presented and approved before any code changes or DB actions are taken, even for multi-step tasks."*

## 4. Make small, testable, incremental changes

- Edit one file at a time when possible.
- After each meaningful change, run the relevant test or curl check yourself before moving on.
- Don't pile up 10 unrelated edits and run tests at the end. If anything fails, you'll spend 10x debugging.
- **Do not refactor surrounding code "while you're there".** Stay scoped to the request. Cleanup goes in a separate PR.

## 5. Don't add speculative defenses

- No `begin/rescue` for exceptions that cannot occur in the current code path.
- No fallbacks for hypothetical future requirements.
- No abstractions ("just in case we need to swap this out") for one-time logic.
- Three repeated lines beat a premature abstraction.

The exception: always validate genuinely user-supplied input and sanitize external data per project standards. That's not speculation, that's hygiene.

## 6. Self-quality-loop (one worker doing three roles)

Vorflux dispatches `simplify`, `review`, and `testing` agents in parallel after every change. With one worker, you do them serially. After implementing a change, before opening a PR, run **all three passes yourself**:

### Pass 1 — Simplify (you wear the simplifier hat)
- Is there dead code I introduced or left behind?
- Is there duplication that begs to be a single function?
- Did I add a comment that just restates the code?
- Did I add a defensive check that's impossible to trigger?
- **Are there orphaned files?** (e.g. dropped a cron entry — is the job's `.rb` still around?)

### Pass 2 — Review (you wear the senior-reviewer hat)
- Does this introduce a regression? Trace every callsite of changed methods.
- Are there race conditions, N+1 queries, or unbounded loops?
- For migrations: is `down` reversible or explicitly marked irreversible?
- For data migrations on production: what's the blast radius? Verify on the live DB read-only first.
- Does this match an existing convention in the repo, or am I inventing a new one?

### Pass 3 — Testing (you wear the tester hat)
- For new functions/methods: write unit tests that exercise them. **This is mandatory.** "Existing tests pass" does not mean new code is tested.
- Run them and confirm pass/fail before claiming completion.
- Cover at least: the happy path, one boundary, one error case.

See `40-quality-loop.md` for the exact procedure.

## 7. Verify automatically — never hand work back unverified

The user's preference file says: *"When the user says 'you can do tests yourself without me having to test in GUI', they mean: run Rails runner checks, curl endpoint checks, and any other non-browser verification possible before handing back."*

Before saying "done":

- **Run the test suite** for affected files (rspec spec/path/...).
- **Run a Rails runner sanity check** that exercises the actual code path with realistic data, ideally against a live DB or production read-only.
- **Curl the endpoint** if it's an HTTP change. Confirm status code AND response body shape.
- **Grep the bundle** if it's a frontend change (vite cache lies — see `70-frontend-knowledge.md`).
- **For deploys, check the post-deploy state** via Rails runner SSH'd into the server.

Report each check + its result in your final reply. Don't say "tests pass" — show the count and the duration.

## 8. Be transparent when a tool fails

The user's preference file says: *"When a tool or platform restriction blocks a task, the user wants to understand why it's failing before seeing the workaround."*

Format:
> The `pr-create` tool returned `Resource not accessible by integration (createPullRequest)` — that's a permission gap on the integration's GitHub App scope. Falling back to `gh pr create` (separate auth path) succeeds.

Not:
> Used a different tool, here's the PR.

## 9. Don't fabricate evidence

- Never paste "example output" of a command you didn't actually run.
- Never invent numbers, log lines, or test results.
- If you couldn't run something, say so and explain why.

## 10. Be concise

- One-sentence acknowledgments are noise. The user already saw the emoji reaction.
- Final summaries: 2-5 bullets max. PR URL + what changed + what's deployed. That's it.
- Don't re-narrate what you just did. The user can see the diffs.
- Use plain text or terse bullets. Avoid headers in chat replies unless the answer is genuinely structured.

## 11. Patience with long-running operations

Some commands take 10+ minutes (full test suites, asset precompiles, db:migrate on large tables). Don't kill them. Watch for output, but let them finish.

## 12. Trust the data, not your assumptions

If `git log` says the production branch already has the code, trust git. If `Rails.env.production? && Account.first.feature_enabled?(:sla)` returns `true`, trust the runtime. Verify before assuming.

## 13. Reference file paths the way humans navigate

When citing code in chat or PR descriptions, use `path/to/file.rb:line_number`. The user can click that in VS Code to jump straight to the line.

## 14. Search for the convention before inventing one

Before adding a new pattern (a new directory layout, a new test helper, a new YAML key), grep for similar patterns already in the codebase. If one exists, follow it. The user's repo has lots of conventions; respecting them keeps the codebase coherent.

## 15. Memory hygiene

Maintain `.claude/` as you go. When you discover a new gotcha that future-you would benefit from knowing, write it down here in the matching file with a one-line description plus the relevant snippet. Keep entries terse — one sentence + 5 lines of code is the format. Don't write essays.
