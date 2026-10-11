# New session start

## Status
2026-10-11T15:18-03:00: becloud-dev shared AI workflows. Triage probe files committed locally;
sandbox repo and org secret exist. Blocked: the user's A4, A6b, A7, A3, then the first run.

## Resume here (first command: `git log --oneline`)
1. The user reports pass/fail with exact error text: A6b variables `OWNERS`,
   `PRIORITY_FIELD_ID=48149712` on the sandbox; A7 labels `triage`, `needs-info`, issue types,
   Actions setting; A3 Anthropic question; A4 public remote + push (the user's call).
2. R1 after A4: copy `docs/probe/consumer-triage.yml` to the sandbox
   `.github/workflows/triage.yml` on `main`. R2-R4: test issue, apply `triage`, report the
   run summary and step conclusions.
3. Record the run in section 5 (text shown first), correct what it contradicts; then the
   stage 1 workflow draft and a haiku quality check on real issues.

## Git state (2026-10-11T15:18-03:00)
- Branch `main`, clean (`git status -sb`), no stash (`git stash list`); no remote, no upstream,
  nothing pushed (`git remote -v`; `git log @{u}..HEAD` fails).
- 42 commits (`git log --oneline | wc -l`) before this refresh, which adds one. No PRs.
- `becloud-dev` has one repo, `triage-sandbox`, public (`gh repo list becloud-dev`).

## Done and verified (section 5 of `docs/third-party-review.md`)
- Review #1-#21, monitoring, stage design, write payloads; issue field list and Priority
  object read live (id `48149712`, options Urgent, High, Medium, Low, rank in `priority`).
- Round 5 items 1-10 in section 4 (commits `6f50511`, `7ac8757`).
- Sandbox repo created; org secret `CLAUDE_CODE_OAUTH_TOKEN`, visibility SELECTED, repo list
  `triage-sandbox` only (`gh secret list --org becloud-dev`); CLI token has `admin:org`.
- Probe files (commits `608936a`, `7aa3e72`): `.github/workflows/triage.yml`,
  `.github/actions/record-run/action.yml`, `prompts/triage.md`, `docs/probe/consumer-triage.yml`.
  YAML parses and the `jq` was run on sample JSON; `actionlint` not run, nothing run on GitHub.
- `GET issue-field-values` keys `issue_field_id`, `single_select_option.name` and issue
  `type.name` read raw (OpenAPI 1.1.4).

## Decisions (user)
- 2026-10-11: framework-agnostic, GitHub-native; English; Free plan; all repos public; MIT,
  holder Bento Machado. Native gates; owners-variable gate; only the code owner starts runs.
- Subscription OAuth auth (Round 5 item 10), Anthropic to confirm; Bedrock later; model per
  stage a caller input, full IDs pinned; AI PRs under a custom App bot.
- Stage design: section 4 Rounds 3-5. Priority keeps GitHub defaults, no `P1`-`P5`.
- UI pin checks skipped; the probe run shows whether the write lands.

## Open and unverified
- Not yet by the user: A3, A4, A6b (`gh variable list --repo becloud-dev/triage-sandbox` empty),
  A7 labels (`triage`, `needs-info` absent), issue types and Actions setting (unchecked).
- Live A: `GITHUB_TOKEN` writes type, Priority (names as value); Live B: `job.workflow_sha`
  cross-repo; `vars` via `with:`; `GH_TOKEN` reaching the Claude process; allowlist; composite
  at `@main`; OAuth cost fields; label removal; `concurrency`; secret read by a public repo.
- Not verified: `issue_fields` as a `permissions:` key; `suggest`; `vars` in a called
  workflow; Projects v2 writes; auto-merge; release PR checks with an App token; Pro limit;
  `$/` cross-repo; `organization_members_only` on a public repo.

## Pointers
- `docs/third-party-review.md`: flow, mapping, review list, decisions (4), findings (5).
  Probe: `.github/`, `prompts/`, `docs/probe/`. Inspiration: `bentoluizv/patagonia-trip`.

## Conventions in force
- Plan gate: exact text before any write; local commits per verified step; no push without a go.
- Docs: no personal pronouns; English; raw sources for design claims.
