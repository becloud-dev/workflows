# New session start

## Status
2026-10-11T11:51-03:00: shared AI-oriented workflow flow for the becloud-dev org, documentation
only. Third-party review read through #1-#3; #16, #17, #20, #21 remain; #22 deferred.

## Resume here
Read `docs/third-party-review.md` sections 3 and 5, then review #16 (org default templates),
#17 (issue forms), #20 (`gh` flags), #21 (release-please). Follow the research-iterations rule:
raw sources over summarizer, close reachable gaps, show the exact findings text, wait for the
go, write, commit locally. First command: `git log --oneline`.

## Git state (2026-10-11T11:51-03:00)
- Branch `main`, clean tree (verified via `git status -sb`).
- No remote, no upstream, no stash (verified via `git log @{u}..HEAD` and `git stash list`).
- 10 commits, HEAD 447d4b9 (verified via `git log --oneline`).
- No PRs: no remote exists.

## Done and verified
- Hard blockers #4, #5, #8, #11-#14 and data model #6, #7, #9, #10 (section 5).
- GitHub App permission keys: `organization_projects` for Projects v2 (section 5).
- AI execution #18 claude-code-action, #19 model IDs, #15 Actions billing (section 5).
- #1-#3 reusable workflows, events, syntax, with the gaps closed from raw `github/docs`.
- Review list now has item #22 (Bedrock path) and review-order item 5.

## Decisions
- Framework-agnostic, GitHub-native only; English; Free plan, all repos private; human gates
  by workflow logic, code owner is the control (user, 2026-10-11).
- A failed gate sets a failing check plus a blocking comment; the owner merges by hand; a
  workflow removes `RELEASE` / `READY TO LIVE` when the actor is not in the owners variable.
- Auth through the Claude subscription (`claude_code_oauth_token`), Pro now, Max 5x later if
  needed; usage credits stay off; credit-billed use means Bedrock (user, 2026-10-11).
- Bedrock is the later target for fine-tuning and usage tuning (user, 2026-10-11).
- Provider and model per stage are caller inputs; full model IDs pinned, no aliases; Fable not
  used (user accepted, 2026-10-11).
- Findings are written to the doc every iteration (rule `research-iterations`).

## Open and unverified
- Not answered: engine, state in labels + milestones + Projects, planner trigger, which
  patagonia pieces to keep, release mechanism (section 4, rounds 1 and 2).
- Diagram ambiguities: DEV (haiku) executing the plan; whether the AI merges.
- Not verified: Access setting selectable on a Free org (needs the repo to exist); `vars` in
  `with:` (docs prose and table disagree) and inside a called workflow; `actions: write` for
  dispatch; Issue Types and Variables App permissions have no token key or action input.
- Not verified: `gh pr create` in automation mode; Projects v2 writes from a Claude step;
  behaviour at the Pro limit; OAuth token after a plan change; real tokens and minutes per run;
  fine-tuning on Bedrock for the 5.5 models.
- Not read: #16, #17, #20, #21, #22; `docs/usage.md` and `docs/faq.md` of the action; the last
  16497 characters of the model-config page.

## Pointers
- `docs/third-party-review.md`: flow, mapping, 22-item review list, findings, decisions.
- Source inspiration: `bentoluizv/patagonia-trip` (private), read through `gh api`.
- Flow image: `/home/bento/Documents/flow.png` (outside the repo).
- Config repo `~/.claude` has the rule `rules/research-iterations.md`, commit af06cb6, one
  commit ahead of its remote (verified via `git log @{u}..HEAD`).

## Conventions in force
- Plan-review gate: exact text shown before any write; one step at a time.
- Commit locally after each verified increment; no push without an explicit go.
- Docs have no personal pronouns; English; raw sources for claims the design rests on.
