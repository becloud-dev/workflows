# New session start

## Status
2026-10-11T14:44-03:00: becloud-dev shared AI workflows, docs only. Review #1-#21,
monitoring, stage design (section 4 Rounds 3-4), live list and write payloads recorded.
Blocked: the user runs the live checks.

## Resume here (first command: `git log --oneline`)
1. The user brings back pass/fail, with exact error text, for: org issue fields (Priority,
   P1-P5, pins), `gh api orgs/becloud-dev/issue-fields` id, org secret on a public repo,
   Anthropic question sent, public remotes created.
2. Show the exact section 4 "Round 5" text (triage answers below); record on a go.
3. Draft the probe (triage reusable workflow + consumer caller), shown before any write.

## Git state (2026-10-11T14:44-03:00)
- Branch `main`, clean tree, no stash (`git status -sb`, `git stash list`); no remote, no
  upstream, nothing pushed (`git log @{u}..HEAD` fails with no upstream).
- 36 commits including this refresh (35 via `git log --oneline | wc -l`, plus this one); org
  `becloud-dev` has no repositories (`gh repo list becloud-dev` printed nothing).

## Done and verified (section 5 of `docs/third-party-review.md`)
- Review #1-#21: blockers, data model, App keys, Claude Code Action, models and billing,
  reusable workflows, templates and issue forms (tested live), `gh` flags, release-please.
- Public repo plan features, subscription terms, AI output copyright (US guidance).
- Monitoring; stage design and round 4 inputs; live confirmations before triage (A/B);
  issue field and `type` write payloads (OpenAPI 2026-03-10, raw).

## Decisions (user)
- 2026-10-11: framework-agnostic, GitHub-native; English; Free plan; all repos public (probe
  repo too); MIT, holder Bento Machado. Native gates; owners-variable label gate; only the
  code owner starts runs.
- Subscription auth under that gate, Anthropic to confirm; Bedrock later; model per stage is a
  caller input, full IDs pinned; AI PRs under a custom App bot.
- Stage design: section 4 Round 3; routing, labels, stage 4 contract, prompt lookup: Round 4.
- Triage, "Go" on 8 recommendations (not yet in section 4): start only by the owner applying
  `triage` (no run on `opened`); Priority field id from a variable `PRIORITY_FIELD_ID` via
  caller `with:`, no App for stage 1; Claude step read-only, returns a JSON verdict, a workflow
  step writes with `GITHUB_TOKEN`; type applied directly with the rationale in the comment;
  missing information = numbered comment + new label `needs-info`, `triage` removed, owner
  re-applies; format fix edits the body + one-line comment; split = sub-issues with
  `--parent`, owner applies `triage` to each; one run, one haiku call for both diagram steps.

## Open and unverified
- To send: question to Anthropic on subscription OAuth for a public project (drafted).
- Needs the user: org Settings > Planning > Issue fields present (not answered yet).
- Live A: `GITHUB_TOKEN` writes type, Priority, sub-issues. Live B: `job.workflow_sha`
  cross-repo; `vars` via `with:`; haiku ID, allowlist; result fields; label removal,
  `concurrency`; org secret on a public repo. Probe needs a remote for `workflows` + sandbox.
- Not verified: `--json-schema` in `claude_args` gives `structured_output`; `issue_fields` as
  a workflow `permissions:` key; what a `suggest` type looks like; `vars` inside a called
  workflow; Projects v2 writes; code-owner approval by `GITHUB_TOKEN`; native auto-merge;
  release PR checks with an App token; Pro limit; OAuth cost fields; `$/` cross-repo.

## Pointers
- `docs/third-party-review.md`: flow, mapping, review list, decisions (4), findings (5).
  Inspiration: `bentoluizv/patagonia-trip`. Flow image outside the repo.

## Conventions in force
- Plan gate: exact text before any write; local commits per verified step; no push without a go.
- Docs: no personal pronouns; English; raw sources for design claims.
