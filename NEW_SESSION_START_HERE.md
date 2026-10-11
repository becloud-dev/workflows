# New session start

## Status
2026-10-11T14:55-03:00: becloud-dev shared AI workflows, docs only. Section 4 Rounds 1-5
recorded; org issue fields read live. The user skips the UI pin check: the probe run shows it.

## Resume here (first command: `git log --oneline`)
1. The user reports pass/fail with exact error text: Anthropic question sent; public remotes
   created; sandbox repo; org secret and variables; sandbox labels, issue types, Actions
   setting.
2. Draft the probe (triage reusable workflow + consumer caller), shown before any write; the
   user commits and pushes. Needs the real repo, secret and variable names first.
3. Then the triage workflow draft (stage 1), shown before any write; then a haiku quality
   check on a small sample of real issues.

## Git state (2026-10-11T14:55-03:00)
- Branch `main`, clean (`git status -sb`), no stash (`git stash list`); no remote, no upstream,
  nothing pushed (`git remote -v`; `git log @{u}..HEAD` fails with no upstream).
- 38 commits (`git log --oneline | wc -l`) before this refresh, which adds one. No PRs (no
  remote). Org `becloud-dev` repo list not re-checked this session.

## Done and verified (section 5 of `docs/third-party-review.md`)
- Review #1-#21, monitoring, stage design, issue field and `type` write payloads (OpenAPI
  2026-03-10, raw).
- Live, via `gh api orgs/becloud-dev/issue-fields` with the user's login (not `GITHUB_TOKEN`):
  4 fields; Priority id `48149712`, single select, 4 default options Urgent, High, Medium, Low
  with `priority` rank 1-4; descriptions null; `visibility` organization_members_only.
- Round 5 items 1-9 in section 4 (commit `6f50511`); live result in section 5 (`082aa87`).

## Decisions (user)
- 2026-10-11: framework-agnostic, GitHub-native; English; Free plan; all repos public (probe
  repo too); MIT, holder Bento Machado. Native gates; owners-variable label gate; only the
  code owner starts runs.
- Subscription auth under that gate, Anthropic to confirm; Bedrock later; model per stage is a
  caller input, full IDs pinned; AI PRs under a custom App bot.
- Stage design: section 4 Rounds 3-4; triage: Round 5 (start by owner label `triage`, no App,
  read-only Claude step, `needs-info`, sub-issues via `--parent`).
- Priority keeps GitHub's defaults (Round 5 item 9): no `P1`-`P5`, no fallback labels.
- Priority pins to Task, Bug, Feature, "Issues without a type" and the option-count limit are
  not checked in the UI; the probe run shows whether the write lands.

## Open and unverified
- To send: question to Anthropic on subscription OAuth for a public project (drafted).
- `organization_members_only` effect on a public repo (not read).
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
