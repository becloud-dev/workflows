# New session start

## Status
2026-10-11: drafting the shared AI-oriented workflow flow for the becloud-dev GitHub org.
Documentation-only; no workflow YAML exists yet. Local commits only, no remote.

## Resume here
Read the review table in `docs/third-party-review.md` (section 3, review order item 3), then read
the AI-execution group: #18 claude-code-action, #19 model IDs, #15 Actions billing. Report at
each checkpoint and wait. First command: `git log --oneline`.

## Git state (2026-10-11T11:07-03:00)
- Branch `main`, clean tree (verified via `git status -sb`).
- No remote, no upstream (verified via `git log @{u}..HEAD`: "no upstream configured").
- 6 commits, newest first: d26cdc0 (permission keys), e40d633 (this file), 43711e8, b3bd6ae,
  8ea870b, eef7c93 (verified via `git log --oneline`).
- No open PRs: no remote exists.

## Done and verified
- Patagonia-trip process read through `gh api` (CONTRIBUTING, CLAUDE.md, release and Claude
  review workflows, templates, hooks, DESIGN.md sections 4/6/8/9).
- Flow diagram (`/home/bento/Documents/flow.png`) transcribed into section 1 of the doc.
- 24 candidate doc URLs returned HTTP 200 (verified via curl; existence only).
- Hard-blocker docs #4, #5, #8, #11-#14 and data-model docs #6, #7, #9, #10 read via WebFetch;
  findings in section 5 of the doc.
- GitHub App permission keys (#5, #8) read raw; findings in section 5 of the doc
  (`organization_projects` for Projects v2; table of keys and action inputs).
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
  rulesets plan wording came via search, not the raw doc page; the org "Issue Types" and
  "Variables" App permissions are listed in the docs but have no key in the token schema or
  action input (design does not depend on them; minting was not tested).
- Not yet read: #1-#3, #15-#21 (except the pieces noted above).

## Pointers
- `docs/third-party-review.md`: flow, mapping, 21-item review list, findings, decisions.
- Source inspiration: `bentoluizv/patagonia-trip` (private), read via `gh api`.
- Flow image: `/home/bento/Documents/flow.png` (outside the repo).

## Conventions in force
- Plan-review gate: no file written before the plan is reviewed; one step at a time.
- Commit locally after each verified increment; no push without an explicit go.
- Docs have no personal pronouns; English; verify third-party behaviour against current docs.
