# Shared workflows: flow and third-party review

Status: draft, 2026-10-11. Nothing in the review table has been read yet; the URLs were only
checked to resolve (HTTP 200).

Constraint: the shared workflows are framework-agnostic and rely on GitHub capabilities only. No
stack-specific command (npm, wrangler, biome, ...) lives in the shared repo; each consuming repo
supplies its own through a small contract.

Origin: the flow below is a port of the process in `bentoluizv/patagonia-trip` (CONTRIBUTING.md,
`.github/workflows/`, `.github/claude/`), used as inspiration only.

## 1. The flow

```
issue -> triage -> planning -> [ux/ui research] -> development -> release
```

| # | Stage | Actor (model) | What it does | Human gate |
|---|---|---|---|---|
| 0 | Issues | anyone | Feature requests, change requests, bug fixes, improvements | |
| 1 | Triage | TRIAGE (haiku) | Step 1: classify type, set priority P1-P5 by criticality, check the information is complete (if not, return the missing questions to the author), check the format (if wrong, edit the issue). Step 2: confirm priority, check atomicity (one change solves it, self-contained); if not atomic, split into atomic sub-issues that loop back into triage | |
| 2a | Planning: backlog | PLANNER (haiku) | Take open issues with no scope and no calendar, review categorization, order the backlog by priority | |
| 2b | Planning: roadmap | PLANNER (sonnet) | Group the backlog into epics = releases. Each release is a milestone with schedule and ETA, tracked in GitHub Projects. Error budget: when the bug-to-feature ratio is saturated, new features stop and bugs are fixed | Code owner approves the roadmap. Issues then get the `RELEASE` or `UX/UI` tag |
| 3 | UX/UI research (only `UX/UI` tag) | UX Research, UI Research (sonnet) | UX: user story, requirements, information hierarchy, screen elements. UI: design inside the design system, colours, navigation, layout, artifacts | Code owner confirms the design; the issue returns to the backlog or the release |
| 4 | Development (only `RELEASE` tag) | DEV (sonnet), DEV (haiku), DEV (sonnet) | Sonnet runs `/plan`: objective, steps, spec based on e2e tests, TDD red then green, acceptance criteria. Haiku executes the plan, runs the git flow, opens the PR. Sonnet checks the code against the criteria; on failure it suggests changes and loops; on success, merge | Code owner reviews the plan |
| 5 | Release (release PR tagged `READY TO LIVE`) | DEV (opus), DEV (sonnet) | Opus reviews the release as a whole: lists blocking issues, says which to fix now and which to defer; blocking issues are P1, the rest follow triage and planning. Sonnet creates the new issues | Code owner approves or rejects the Opus review; rejection loops back to Opus |

Release outcomes:

- A blocking issue exists: the new issues carry tags that skip triage and planning and go straight
  to development (loop back to stage 4).
- No blocking issue: the new issues go to triage and the release is approved.

## 2. GitHub-native mapping (unverified)

| Diagram concept | GitHub mechanism |
|---|---|
| Issue type | Org issue types (Task, Bug, Feature exist today) |
| Priority P1-P5, backlog / planned / in progress | Projects v2 single-select fields |
| Atomic split | Native sub-issues |
| Release = epic = milestone with ETA | Milestones with due date; Projects roadmap view |
| Error budget | Query over issue types and states per milestone, computed in a workflow |
| Routing (UX/UI, RELEASE, READY TO LIVE) | A few labels for state with no native field |
| Human gates | CODEOWNERS, required reviews, rulesets, environment approvals |
| Shared automation | Reusable workflows (`workflow_call`); org `.github` repo for templates |

Facts checked on the `becloud-dev` org (2026-10-11): Free plan, issue types enabled
(Task, Bug, Feature), no repositories yet.

## 3. Third-party review list

Stage numbers follow section 1.

| # | Need | Doc to review | Question it must answer | Stages |
|---|---|---|---|---|
| 1 | Reusable workflows (`workflow_call`) | https://docs.github.com/en/actions/sharing-automations/reusing-workflows | Can a private consumer call a shared workflow across repos in the org? Nesting limits; how secrets and inputs pass | all |
| 2 | Triggers and events | https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows | Which events exist for `issues`, `projects_v2_item`, `pull_request`, `milestone`? Default-branch and fork caveats | all |
| 3 | Workflow syntax (concurrency, permissions, `if`) | https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax | How to serialize runs per issue and scope permissions per job | all |
| 4 | `GITHUB_TOKEN` scope | https://docs.github.com/en/actions/tutorials/authenticate-with-github_token | Can it write issue types, sub-issues, Projects v2 fields? Cross-repo limits; does it trigger further workflows | all |
| 5 | GitHub App token in Actions | https://github.com/actions/create-github-app-token | Permissions needed for issues, projects, org scope; rotation | 1, 2, 5 |
| 6 | Issue types | https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/managing-issue-types-in-an-organization and https://docs.github.com/en/rest/orgs/issue-types | Custom types beyond the defaults; set the type from an Action; plan requirement | 1 |
| 7 | Sub-issues | https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues and https://docs.github.com/en/rest/issues/sub-issues | Depth and count limits; create and attach via API; cross-repo | 1 |
| 8 | Projects v2 (Priority, Status, roadmap) | https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects | GraphQL-only updates? Token types; built-in automations that replace an Action | 1, 2 |
| 9 | Milestones | https://docs.github.com/en/rest/issues/milestones | Per-repo only; how a multi-repo release or org-wide roadmap works | 2, 5 |
| 10 | Labels | https://docs.github.com/en/rest/issues/labels | Org-wide sync or per repo; who may apply them | 2-5 |
| 11 | Rulesets and required reviews | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets | What works on the Free plan for private repos | 4, 5 |
| 12 | CODEOWNERS | https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners | Required review on a Free private repo; gating non-code files | 4, 5 |
| 13 | Environments with required reviewers | https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments | Can a workflow pause for approval on Free; which repos are eligible | 2-5 |
| 14 | Plan limits | https://docs.github.com/en/get-started/learning-about-github/githubs-plans | Feature matrix Free vs Team: rulesets, required reviewers, Projects | all |
| 15 | Actions minutes and billing | https://docs.github.com/en/billing/concepts/product-billing/github-actions | Minute allowances; cost of long AI jobs | all |
| 16 | Org default templates | https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file | Does the org `.github` repo give default issue templates and forms to all repos | 0, 1 |
| 17 | Issue forms | https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms | Can a form set type, labels, project | 0, 1 |
| 18 | AI runtime: Claude Code Action | https://github.com/anthropics/claude-code-action and https://code.claude.com/docs/en/github-actions | Modes, input and permission model; whether `track_progress` and `--allowedTools` are current | 1-5 |
| 19 | Model choice (haiku/sonnet/opus) | https://platform.claude.com/docs/en/about-claude/models/overview | Current model IDs, limits, cost per tier | 1-5 |
| 20 | `gh` CLI | https://cli.github.com/manual/gh_issue_create | Support for `--parent` and `--type`; which flags are stable | 1, 5 |
| 21 | Release tooling (consumer side, optional) | https://github.com/googleapis/release-please and https://www.conventionalcommits.org/en/v1.0.0/ | Language-agnostic? Setup without a manifest | 5 |

Review order:

1. Hard blockers for the design: #4, #5, #8, #11-#14 (decide whether human gates and
   Projects-driven state work on the Free plan).
2. Core data model: #6, #7, #9, #10.
3. AI execution: #18, #19, #15.
4. Packaging and consumer contract: #1-#3, #16, #17, #20, #21.

## 4. Open decisions

Round 1 (recommended answer first, none confirmed):

1. Repo shape: `becloud-dev/workflows` with reusable workflows, prompts and label/template
   definitions; thin caller workflows per project; templates in the org `.github` repo.
2. Engine: GitHub Actions with `claude-code-action`, org-level secrets.
3. State: labels + milestones + Projects, no external store.
4. Planner trigger: backlog on every triage completion; roadmap on demand; no cron.
5. Merge: the human code owner presses merge; the DEV sonnet check is advisory.
6. Prompt language: English as the default, with an output-language parameter per consuming
   repo. Confirmed 2026-10-11 (the source diagram is in pt-BR; the docs and prompts are not).
7. Kept from patagonia-trip, optional per repo: Conventional Commits and release-please, "Bug
   class" PR section, `Decisao:`/options design note, e2e flow rule, `release-blocker` deploy
   gate. Cloudflare/D1 backup and migrate steps stay out.
8. Pace: stage by stage, starting with triage.

Round 2:

1. Visibility: public, private or mixed (recommend public for the shared workflows repo).
2. Per-project contract: caller inputs + repo variables, conventions in `AGENTS.md`/`CLAUDE.md`.
3. Release mechanism: shared repo stops at a GitHub Release and tag; versioning is consumer-side.
4. Tokens: GitHub App on the org for cross-repo and Projects writes.
5. Verification: check the unverified items against current docs before designing on them.

Diagram ambiguities to confirm:

- DEV (haiku) executes the plan: intended, or should it be sonnet?
- After the "meets criteria?" check the arrow goes straight to MERGE with no human box.

## 5. Findings

### Hard blockers (#4, #5, #8, #11-#14), read 2026-10-11

Read through a page summarizer, so wording is as reported, not raw.

| # | Finding | Gap left open |
|---|---|---|
| 4 | `GITHUB_TOKEN` scopes are set with `permissions`. The docs say "If you need a token that requires permissions that aren't available in the `GITHUB_TOKEN`, create a GitHub App." | Scope list, cross-repo access, Projects v2 and whether token-created events trigger workflows are not on the page. Read the GITHUB_TOKEN concept page and the workflow syntax permissions section |
| 5 | The app-token action scopes to the current repo with no `owner`, the installation with `owner`, a list with `owner` + `repositories`. Token expires after 1 hour and is revoked in the post step, so it cannot cross jobs | `projects` / `organization-projects` permission keys are not documented on its page |
| 8 | Projects v2 updates are GraphQL only. Token is a classic PAT (`project` scope) or a GitHub App installation token. Adding and updating an item are two mutations | Fine-grained PATs and `GITHUB_TOKEN` are not mentioned. Read "Automating Projects using Actions" |
| 11 | Repo rulesets are described for Team and Enterprise customers. Org-level rulesets need Enterprise | Free not stated on the pages fetched; see plan matrix below |
| 12 | "Require review from Code Owners" is a branch-protection setting. Owners need write access | No plan or visibility stated on that page |
| 13 | Environment required reviewers and wait timers: "only available for public repositories" on Free, Pro and Team | Free private not addressed directly |
| 14 | Team lists protected branches, required reviewers and code owners for private repos. Free: 2,000 Actions minutes per month | Rulesets, environments, Projects not addressed per plan |

Plan matrix for rulesets (from search, second-hand; the exact docs page was not read raw):
"Rulesets are available in public repositories with GitHub Free and GitHub Free for
organizations, and in public and private repositories with GitHub Pro, GitHub Team, and GitHub
Enterprise Cloud." On a private repo in a Free organization, rulesets can be created but are not
enforced until the organization is upgraded to Team. Pro is a personal-account plan; that it
does not extend to organization-owned repos is an inference.

### Decision: option C (2026-10-11)

Project repos are private on the Free plan. GitHub will not enforce required reviews, CODEOWNERS,
rulesets or environment approvals there, so every human gate is enforced by workflow logic.

Consequences to design for:

- A workflow can fail a check, comment, or remove a label. It cannot stop the merge button.
  Gates are therefore visible and auditable, not preventive.
- Gate checks must read state through the API (reviews, label events, actor permission), which is
  unverified on private Free repos.
- A GitHub App token is still the only documented route to Projects v2 writes.
- Upgrading to Team later turns the same gates into native ones without changing the stages.

Confirmed 2026-10-11 after pricing was checked: stay on Free, all repositories private, the code
owner is the control, enforcement through workflow logic. Team is deferred until stricter
enforcement is needed. Price seen on the org upgrade screen: Team is $4 per user per month,
$48 per seat per year (same total either way). The billing-cycle docs did not state
cancellation or refund terms; that is unverified.

### Shared workflows repo, all private (checked 2026-10-11)

- A private repository can share its actions and reusable workflows with other private repos of
  the same organization through Settings > Actions > General > Access > "Accessible from
  repositories in the organization". Public repos cannot use this access. The docs state no plan
  requirement for the setting. Source: "Managing GitHub Actions settings for a repository".
- Cross-repo call syntax: `{owner}/{repo}/.github/workflows/{filename}@{ref}`.
- Nesting: at most ten levels of workflows, no loops, permissions can only be kept or reduced down
  the chain, and secrets pass only to the directly called workflow (`secrets: inherit` for the
  same organization).
- Not yet verified on a Free org: that the setting is actually selectable there (settings are
  visible only once the repo exists).
