# New session start

## Status
2026-10-11T14:32-03:00: becloud-dev shared AI workflows, docs only. Review #1-#21,
monitoring, stage design (section 4 Round 3), round 4 inputs recorded; #22 deferred; live
confirmation postponed.

## Resume here (first command: `git log --oneline`)
1. Recorded, no go pending: section 4 Round 4; section 5 "Live confirmations before triage".
2. REST payloads for field values and `type` are recorded (section 5, last subsection).
3. Triage round: questions (start on `triage` label vs `opened`, missing-information
   handling, sub-issue loop-back), then the draft shown before any write.

## Git state (2026-10-11T14:32-03:00)
- Branch `main`, clean tree, no stash (`git status -sb`, `git stash list`); no remote, no
  upstream, nothing pushed (`git log @{u}..HEAD` fails with no upstream).
- 32 commits including this refresh (31 via `git log --oneline | wc -l`, plus this one); org
  `becloud-dev` has no repositories (`gh repo list becloud-dev` printed nothing).

## Done and verified (section 5 of `docs/third-party-review.md`)
- Review #1-#21: blockers, data model, App keys, Claude Code Action, models and billing,
  reusable workflows, templates and issue forms (tested live), `gh` flags, release-please.
- Public repo plan features, subscription terms, AI output copyright (US guidance).
- Monitoring fields, limits and billing endpoints; stage design and round 4 inputs
  (patagonia files and labels, issue fields, `job.workflow_*`, `vars`, milestone permission).

## Decisions (user)
- 2026-10-11: framework-agnostic, GitHub-native; English; Free plan; all repos public; MIT,
  holder Bento Machado. Native gates; owners-variable label gate; only the code owner starts runs.
- Subscription auth under that gate, Anthropic to confirm; Bedrock later; model per stage is a
  caller input, full IDs pinned; AI PRs under a custom App bot. Monitoring and stage design:
  section 5 and section 4 Round 3.
- Round 4, "Go" on 8 recommendations (section 4, Round 4): 2a writes only a report; 2b
  creates milestones and assigns issues, owner approves by applying `RELEASE`/`UX/UI`; labels
  `RELEASE`, `UX/UI`, `READY TO LIVE`, `release-blocker`, transient `triage`, Priority `P1`-`P5`
  (fallback labels); `RELEASE`/`UX/UI` persist (amends Round 3 item 3); `READY TO LIVE` set by
  the owner after the Opus review, gate = label + zero open `release-blocker`; stage 4 plan is
  an issue comment, owner's approving comment starts haiku; inputs `setup_command`,
  `check_command`, `test_command` from repo `vars`; prompts by second checkout at
  `job.workflow_repository`@`job.workflow_sha` into `.ai-workflows/`, no override.

## Open and unverified
- To send: question to Anthropic on subscription OAuth for a public project (drafted).
- Needs the user: org Settings > Planning > Issue fields present (not answered yet).
- Live A: issue fields; `GITHUB_TOKEN` writes type, Priority, sub-issues. Live B:
  `job.workflow_sha` cross-repo; `vars` via `with:`; haiku ID and allowlist; result fields;
  label removal and `concurrency`; org secret on a public repo. Probe needs a remote for
  `workflows` and a public sandbox repo (user, 2026-10-11: public, like all others).
- Not verified: ruleset rules on Free public; `vars` inside a called workflow; Projects v2
  writes; `GITHUB_TOKEN` approval vs code owners; native auto-merge; release PR checks with an
  App token; Pro limit behaviour; OAuth cost fields; billing rows for public; `$/` cross-repo.

## Pointers
- `docs/third-party-review.md`: flow, mapping, review list, decisions (4), findings (5).
  Inspiration: `bentoluizv/patagonia-trip`. Flow image outside the repo.

## Conventions in force
- Plan gate: exact text before any write; local commits per verified step; no push without a go.
- Docs: no personal pronouns; English; raw sources for design claims.
