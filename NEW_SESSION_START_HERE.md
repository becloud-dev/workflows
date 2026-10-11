# New session start

## Status
2026-10-11T14:18-03:00: becloud-dev shared AI workflow flow, documentation only. Review #1-#21,
monitoring and stage design (section 4 Round 3) recorded; #22 (Bedrock) deferred; live
confirmation postponed.

## Resume here
Next round on the stage design, questions with a recommendation each: what planner 2a/2b write,
label and field names, stage 4 consumer contract (plan file, check script, test command), where
a called workflow finds the shared prompt files. Then a triage workflow draft shown before any
write. Follow the research-iterations rule. First command: `git log --oneline`.

## Git state (2026-10-11T14:18-03:00)
- Branch `main`, clean tree, no stash (verified via `git status -sb`, `git stash list`).
- No remote, no upstream: nothing is pushed (`git log @{u}..HEAD` fails with no upstream).
- 30 commits including this refresh (29 via `git log --oneline | wc -l`, plus this one).
- The org `becloud-dev` has no repositories (verified via `gh repo list becloud-dev`).

## Done and verified (section 5 of `docs/third-party-review.md`)
- Hard blockers, data model, App permission keys, Claude Code Action, models and billing.
- #1-#3 reusable workflows, events, syntax; #16 templates and #17 issue forms (tested live);
  #20 `gh` flags; #21 release-please.
- Public repository plan features and subscription terms; AI output and copyright (US guidance).
- Monitoring: result and `ModelUsage` fields, log sanitizer, OTel, run timing, summary and
  artifact limits; billing endpoints answer for the Free org; `$/path` resolves to the file's repo.
- Stage design inputs: patagonia-trip files, issue fields, permissions, prices (section 5, last).

## Decisions (user, 2026-10-11)
- Framework-agnostic, GitHub-native only; English; Free plan; all repos public; MIT, holder
  Bento Machado (github.com/bentoluizv).
- Native gates (CODEOWNERS with protected branch or ruleset, environment reviewers); label gate
  is workflow logic against an owners variable. Only the code owner starts AI runs.
- Subscription auth (`claude_code_oauth_token`) under that gate, Anthropic to confirm in writing;
  Bedrock later. Provider and model per stage are caller inputs, full IDs pinned.
- AI PRs are opened under a custom GitHub App bot so the owner can approve them.
- Monitoring record (section 5): job summary plus 90-day JSON artifact, one composite action,
  failed runs recorded, totals by hand.
- Stage design (section 4 Round 3): Actions engine, issue-field Priority, owner-label start,
  on-demand planner, haiku DEV, App-token PR step, 2-lap check loop, owner merges.

## Open and unverified
- To send: the question to Anthropic on subscription OAuth for a public project (drafted).
- Needs the user: org Settings > Planning > Issue fields present (Priority field vs P1-P5 labels).
- Postponed by the user: live probe (user creates the private repo and secret; workflow first).
- Not verified: ruleset rule types on Free public repos; `vars` in `with:` and in a called
  workflow; Projects v2 writes; `GITHUB_TOKEN` approval vs code-owner rule; native auto-merge on
  Free public; release PR checks with an App token; commit types that create a release PR;
  behaviour at the Pro limit; OAuth run fills cost fields; billing rows for a public repo;
  `$/` cross-repo; Bedrock fine-tuning for 5.5. Not read: #22, Brazilian copyright law.

## Pointers
- `docs/third-party-review.md`: flow, mapping, review list, decisions (4), findings (5).
- `LICENSE`: MIT. Inspiration: `bentoluizv/patagonia-trip` (read through `gh api`). Flow image:
  `/home/bento/Documents/flow.png` (outside the repo).

## Conventions in force
- Plan-review gate: exact text shown before any write; one step at a time.
- Commit locally after each verified increment; no push without an explicit go.
- Docs have no personal pronouns; English; raw sources for claims the design rests on.
