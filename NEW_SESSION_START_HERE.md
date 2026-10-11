# New session start

## Status
2026-10-11T13:41-03:00: shared AI-oriented workflow flow for the becloud-dev org, documentation
only. Third-party review items #1-#21 are read and recorded; #22 (Bedrock) is deferred.

## Resume here
Section 5 of `docs/third-party-review.md` is the record. Next: a monitoring and metrics stage
(cost per run, per stage, per model), then the open items below, then the stage design (section 4
rounds 1 and 2 are partly answered). Follow the research-iterations rule: raw sources, close
reachable gaps, show the exact text, wait for the go, write, commit locally. First command:
`git log --oneline`.

## Git state (2026-10-11T13:41-03:00)
- Branch `main`, clean tree (verified via `git status -sb`).
- No remote, no upstream: nothing is pushed.
- 22 commits including this refresh (verified via `git log --oneline`).
- Probe repos deleted 2026-10-11; the org `becloud-dev` has no repositories yet (verified via
  `gh repo list becloud-dev`).

## Done and verified (section 5)
- Hard blockers, data model, App permission keys, Claude Code Action, models and billing.
- #1-#3 reusable workflows, events, syntax; #16 org default templates and #17 issue forms (both
  tested live); #20 `gh` flags; #21 release-please.
- Public repository plan features and subscription terms; AI output and copyright (US guidance).

## Decisions (user, 2026-10-11)
- Framework-agnostic, GitHub-native only; English; Free plan.
- All repos under becloud-dev are public; MIT; holder Bento Machado (github.com/bentoluizv).
- Option C replaced by native gates (CODEOWNERS with protected branch or ruleset, environment
  reviewers); the label gate stays workflow logic against an owners variable.
- Only the code owner starts AI runs (label or comment that needs write access).
- Subscription auth (`claude_code_oauth_token`) under that gate; Anthropic to confirm in writing;
  Bedrock is the later target. Provider and model per stage are caller inputs, full IDs pinned.
- AI pull requests are opened under a custom GitHub App bot so the owner can approve them.

## Open and unverified
- To send: the question to Anthropic on subscription OAuth for a public project (drafted).
- Not decided: monitoring and metrics stage; engine, state model, planner trigger, which
  patagonia pieces to keep (section 4); DEV (haiku) executing the plan; whether the AI merges.
- Not verified: ruleset rule types on Free public repos; `vars` in `with:`; `gh pr create` in
  automation mode; Projects v2 writes from a Claude step; App-token checks on release PRs; which
  commit types alone create a release PR; behaviour at the Pro limit; tokens and minutes per run;
  fine-tuning on Bedrock for the 5.5 models.
- Not read: #22; `docs/usage.md` and `docs/faq.md` of the action; Brazilian copyright law.

## Pointers
- `docs/third-party-review.md`: flow, mapping, 22-item review list, findings, decisions.
- `LICENSE`: MIT. Source inspiration: `bentoluizv/patagonia-trip` (read through `gh api`).
- Flow image: `/home/bento/Documents/flow.png` (outside the repo).

## Conventions in force
- Plan-review gate: exact text shown before any write; one step at a time.
- Commit locally after each verified increment; no push without an explicit go.
- Docs have no personal pronouns; English; raw sources for claims the design rests on.
