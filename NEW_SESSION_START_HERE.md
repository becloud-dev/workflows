# New session start

## Status
2026-10-11: drafting the shared AI-oriented workflow flow for the becloud-dev GitHub org.
Documentation-only; no workflow YAML exists yet. 4 local commits, no remote.

## Resume here
Read the review table in `docs/third-party-review.md` (section 3, review order item 3), then read
the GitHub App permission-key pages and the AI-execution group: #18 claude-code-action, #19 model
IDs, #15 Actions billing. First command: `git log --oneline` (verified via it: HEAD is 43711e8
before this file was committed).

## Git state (2026-10-11T11:07-03:00)
- Branch `main`, clean tree (verified via `git status -sb`).
- No remote, no upstream (verified via `git log @{u}..HEAD`: "no upstream configured").
- 4 commits before this file: eef7c93, 8ea870b, b3bd6ae, 43711e8 (verified via `git log --oneline`).
- No open PRs: no remote exists.

## Done and verified
- Patagonia-trip process read through `gh api` (CONTRIBUTING, CLAUDE.md, release and Claude
  review workflows, templates, hooks, DESIGN.md sections 4/6/8/9).
- Flow diagram (`/home/bento/Documents/flow.png`) transcribed into section 1 of the doc.
- 24 candidate doc URLs returned HTTP 200 (verified via curl; existence only).
- Hard-blocker docs #4, #5, #8, #11-#14 and data-model docs #6, #7, #9, #10 read via WebFetch;
  findings in section 5 of the doc.
- Org `becloud-dev`: Free plan, issue types Task/Bug/Feature, 0 repos (verified via `gh api`).

## Decisions
- Framework-agnostic; GitHub-native capabilities only (user, 2026-10-11).
- English is the default language for prompts and docs (user, 2026-10-11).
- Stay on Free plan, all repos private; human gates enforced by workflow logic; the code owner
  is the control; move to Team ($48 per seat per year) only if stricter enforcement is needed
  (user, 2026-10-11).
- A failed gate sets a failing check plus a blocking comment; the owner merges by hand (user
  accepted recommendation).
- A workflow removes `RELEASE` / `READY TO LIVE` when the actor is not in an owners repo
  variable (user accepted recommendation).
- Shared repo is private and shared via Settings > Actions > General > Access (docs say private
  to private within the same org).

## Open and unverified
- Round 1 and 2 decisions never explicitly answered: engine (claude-code-action), state in
  labels + milestones + Projects, planner trigger, merge by the human, which patagonia pieces to
  keep, release mechanism, token approach (App recommended).
- Diagram ambiguities: DEV (haiku) executing the plan; whether the AI merges.
- Not verified: the Access setting being selectable on a Free org (needs the repo to exist);
  GitHub App permission key names for projects; rulesets plan wording came via search, not the
  raw doc page.
- Not yet read: #1-#3, #15-#21 (except the pieces noted above).

## Pointers
- `docs/third-party-review.md`: flow, mapping, 21-item review list, findings, decisions.
- Source inspiration: `bentoluizv/patagonia-trip` (private), read via `gh api`.
- Flow image: `/home/bento/Documents/flow.png` (outside the repo).

## Conventions in force
- Plan-review gate: no file written before the plan is reviewed; one step at a time.
- Commit locally after each verified increment; no push without an explicit go.
- Docs have no personal pronouns; English; verify third-party behaviour against current docs.
