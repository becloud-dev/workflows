# New session start

## Status
2026-10-11T14:06-03:00: becloud-dev shared AI workflow flow, documentation only. Review #1-#21
and the monitoring stage are recorded; #22 (Bedrock) deferred; live confirmation postponed.

## Resume here
Section 4 of `docs/third-party-review.md`: bring the frontier of questions with a recommendation
each (engine, state model, planner trigger, which patagonia pieces to keep, DEV (haiku)
executing the plan, whether the AI merges). Follow the research-iterations rule. First command:
`git log --oneline`.

## Git state (2026-10-11T14:06-03:00)
- Branch `main`, clean tree (verified via `git status -sb`); no stash.
- No remote, no upstream: nothing is pushed (verified via `git log @{u}..HEAD`).
- 27 commits including this refresh (verified via `git log --oneline | wc -l`).
- The org `becloud-dev` has no repositories (verified via `gh repo list becloud-dev`).

## Done and verified (section 5 of `docs/third-party-review.md`)
- Hard blockers, data model, App permission keys, Claude Code Action, models and billing.
- #1-#3 reusable workflows, events, syntax; #16 org default templates and #17 issue forms (both
  tested live); #20 `gh` flags; #21 release-please.
- Public repository plan features and subscription terms; AI output and copyright (US guidance).
- Monitoring sources: result and `ModelUsage` fields (SDK 0.3.296 types), log sanitizer, OTel,
  run timing, summary and artifact limits; both billing endpoints answer for the Free org.
- Composite action from a reusable workflow: `./` resolves against the caller's workspace;
  `$/path` resolves to the file's own repo (raw `workflow-syntax.md`).

## Decisions (user, 2026-10-11)
- Framework-agnostic, GitHub-native only; English; Free plan.
- All repos under becloud-dev are public; MIT; holder Bento Machado (github.com/bentoluizv).
- Native gates (CODEOWNERS with protected branch or ruleset, environment reviewers); the label
  gate stays workflow logic against an owners variable. Only the code owner starts AI runs.
- Subscription auth (`claude_code_oauth_token`) under that gate; Anthropic to confirm in writing;
  Bedrock is the later target. Provider and model per stage are caller inputs, full IDs pinned.
- AI pull requests are opened under a custom GitHub App bot so the owner can approve them.
- Monitoring record (approved in chat, recorded in section 5): job summary plus a 90-day JSON
  artifact; one composite action; failed runs record; cross-run totals by hand.

## Open and unverified
- To send: the question to Anthropic on subscription OAuth for a public project (drafted).
- Postponed by the user: live probe (user creates the private repo and secret; workflow shown first).
- Not decided: engine, state model, planner trigger, which patagonia pieces to keep (section 4);
  DEV (haiku) executing the plan; whether the AI merges.
- Not verified: ruleset rule types on Free public repos; `vars` in `with:`; `gh pr create` in
  automation mode; Projects v2 writes from a Claude step; App-token checks on release PRs; which
  commit types alone create a release PR; behaviour at the Pro limit; OAuth run fills
  `total_cost_usd` and `modelUsage` values; billing rows for a public repo; `$/` cross-repo
  (date and runner 2.336.0 from a search result); fine-tuning on Bedrock for the 5.5 models.
- Not read: #22; Brazilian copyright law.

## Pointers
- `docs/third-party-review.md`: flow, mapping, review list, findings, decisions.
- `LICENSE`: MIT. Source inspiration: `bentoluizv/patagonia-trip` (read through `gh api`).
- Flow image: `/home/bento/Documents/flow.png` (outside the repo).

## Conventions in force
- Plan-review gate: exact text shown before any write; one step at a time.
- Commit locally after each verified increment; no push without an explicit go.
- Docs have no personal pronouns; English; raw sources for claims the design rests on.
