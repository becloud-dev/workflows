# New session start

## Status
2026-10-11T15:51-03:00: becloud-dev shared AI workflows. First live triage run and the
concurrency test passed on the sandbox; findings in section 5, committed locally, not pushed.

## Resume here (first command: `git log --oneline @{u}..HEAD`)
1. A3: the user reports Anthropic's reply on subscription OAuth for a public project.
2. Stage 1 draft (split, needs-info, format fix) shown before any write; then a haiku quality
   check on a small sample of real issues.
3. When the org-level work ends: `gh auth refresh --remove-scopes admin:org` (the effect on
   `read:org` is untested).

## Git state (2026-10-11T15:51-03:00)
- `workflows`: `main`, 1 ahead of `origin/main` (`ac3d11f`, unpushed), no stash, no PRs.
  46 commits including this refresh.
- Local branch `backup-pre-rewrite` keeps the pre-rewrite history with the personal address:
  never push it; delete it when no longer needed.
- Sibling clone `../triage-sandbox`: `main` equals `origin/main` at `0929a1b`; issues #1, #2 open.

## Done and verified (section 5 of `docs/third-party-review.md`)
- Remote `becloud-dev/workflows`, public, pushed; head equals local after the rewrite
  (verified via `gh api .../commits`, SHAs compared).
- Sandbox: variables `OWNERS`, `PRIORITY_FIELD_ID=48149712`; labels `triage`, `needs-info`; issue
  types Task, Bug, Feature enabled; Actions allowed; org secret selected (read back with `gh`).
- Run `38164369843` (issue #1): all steps success, type Bug, Priority Urgent, one comment,
  `triage` label removed, `permission_denials_count` 0, `total_cost_usd` 0.00467535, OAuth
  (verified via `gh run view`, `gh issue view`, `issue-field-values`, record artifact).
- Concurrency (issue #2): 3 adds, 2 runs; B pending until A ended, both success, 2 comments
  (verified via `gh run list`, `gh run view`, `gh issue view`).
- Author identity in both repos: `53844142+bentoluizv@users.noreply.github.com`; the 43 pushed
  commits were rewritten and force-pushed (all author and committer emails read back).

## Decisions (user, 2026-10-11, this session)
- Framework-agnostic, GitHub-native; English; Free plan; all repos public; MIT, holder Bento
  Machado; native gates; owners-variable gate; only the code owner starts runs.
- Subscription OAuth for stage 1 (Round 5 item 10), Anthropic to confirm; model per stage a
  caller input, full IDs pinned; AI PRs under a custom App bot; Priority keeps GitHub defaults.
- Noreply address on all commits; the Gmail-to-noreply swap by rewrite and force-push, old
  objects left to age out. The sandbox clone moved from `~/.claude` to `~/workspace/becloud-dev`.

## Open and unverified
- The old head `a91d057` is still readable by SHA on GitHub (verified via `gh api`); a full
  purge needs delete and recreate, or GitHub Support. Not requested.
- Not read: `job.workflow_sha` value (job summary not in the API); `costBasis: list` meaning on
  OAuth; `licenseInfo` null on the first repo view (LICENSE file is present).
- Not exercised: three-event case, `needs-info`, format fix, split; `issue_fields` as a
  `permissions:` key; `suggest`; `vars` in a called workflow; Projects v2; auto-merge.
- `ubuntu-latest` moves to Ubuntu 26 on 2026-10-19 (notice only).

## Pointers
- `docs/third-party-review.md`: flow, mapping, review list, decisions (4), findings (5).
  Probe: `.github/`, `prompts/`, `docs/probe/`. Sandbox: `../triage-sandbox`.
- `git` fails inside the Bash sandbox here (userns); `gh` works. Inspiration:
  `bentoluizv/patagonia-trip`.

## Conventions in force
- Plan gate: exact text before any write; local commits per verified step; no push without a go.
- Docs: no personal pronouns; English; raw sources for design claims.
- A commit is denied by a hook while this file is over 60 lines: `wc -l` first.
