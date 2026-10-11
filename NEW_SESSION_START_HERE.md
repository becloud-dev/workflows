# New session start

## Status
2026-10-11T16:42-03:00: becloud-dev shared AI workflows. Stage 1 `needs_info` increment
is live-tested and pushed; a plan to move this handoff file out of the repo awaits approval.

## Resume here (first command: `cat ~/.claude/plans/vast-juggling-avalanche.md`)
1. Handoff relocation: the user approves, amends or reorders the plan (9 steps, local commits;
   deviation: the hook keeps its root-file check for claude-config). Not executed.
2. Findings write: subsection in section 5 for the `needs_info` test (runs 38167016110,
   38167018047), shown before any write.
3. Increment 2 (format fix), then 3 (split): each shown before its write, tested on a new
   sandbox issue.
4. A3: the user reports Anthropic's reply on subscription OAuth for a public project.
5. Haiku quality check on real issues (issue #3 hit the 5-question cap); when the org-level
   work ends: `gh auth refresh --remove-scopes admin:org` (effect on `read:org` untested).

## Git state (2026-10-11T16:42-03:00)
- `workflows`: `main` equals `origin/main` at `043fa60`; no stash, no PRs; 47 commits.
- Local branch `backup-pre-rewrite` keeps the pre-rewrite history with the personal address:
  never push it; delete it when no longer needed.
- Sibling clone `../triage-sandbox`: `main` equals `origin/main` at `0929a1b`; issues #1 to
  #4 open.

## Done and verified (evidence in section 5 unless noted)
- Remote public; sandbox variables, labels, issue types, org secret; first triage run
  `38164369843` and the concurrency test (issue #2) recorded in section 5.
- `needs_info` (`043fa60`): #3 got label `needs-info` and 5 numbered questions, no type or
  Priority; #4 got Bug and High; runs success (via `gh run view`, `gh issue view`, not in 5).
- Author identity is the GitHub noreply address (`729e24b` re-read via `git log -1`).

## Decisions (user, 2026-10-11)
- Framework-agnostic, GitHub-native; English; Free plan; public repos; MIT, holder Bento
  Machado; owners-variable gate; subscription OAuth for stage 1, Anthropic to confirm (A3).
- Stage 1 increments, approved by "Go": `needs_info` skips type and Priority writes; format
  fix only against the repo's issue template; split children get a type, no Priority, no
  `triage`, cap 5; a split is skipped if the parent has sub-issues; split wins over format fix.
- Push of the `needs_info` commit authorized on the user's behalf; later pushes need a go.
- Handoff location (goals: less commit noise, no public session notes): a separate local
  repo `~/workspace/handoffs/`, mirroring the project path; accepted by "Go" (round 3); the
  plan is not yet approved, so the file stays at this repo root until it is.

## Open and unverified
- Old head `a91d057` still readable by SHA (not purged, not requested).
- Not read: run records of #3 and #4, `job.workflow_sha` value, `costBasis: list` on OAuth,
  REST list of sub-issues (the split guard needs it), `gh` version on Ubuntu 26 (2026-10-19).
- Not exercised: three-event concurrency, format fix, split, `suggest`, Projects v2.
- The sandbox caller uses `@main`: a workflow change is live only after a push to main.
- `~/workspace/handoffs/` does not exist yet (verified via `ls`); a remote for it is open.

## Pointers
- `docs/third-party-review.md`: flow, review list, decisions (4), findings (5). Probe:
  `.github/`, `prompts/`, `docs/probe/`. Sandbox: `../triage-sandbox`.
- Plan file: `~/.claude/plans/vast-juggling-avalanche.md`.
- `git` and `grep` fail inside the Bash sandbox here (userns); `gh` works.

## Conventions in force
- Plan gate: exact text before any write; local commits per verified step; push only on a go.
- Docs: no personal pronouns; English; raw sources for design claims.
- A commit is denied by a hook while this file is over 60 lines: `wc -l` first.
