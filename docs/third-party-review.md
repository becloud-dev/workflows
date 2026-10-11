# Shared workflows: flow and third-party review

Status: draft, 2026-10-11. Items read so far are recorded in section 5; the others were only
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
| 22 | Bedrock path (later) | https://code.claude.com/docs/en/github-actions-cloud-providers and the Amazon Bedrock fine-tuning docs | OIDC setup, custom App fit, model IDs, whether fine-tuning is offered for the 5.5 models and what it needs | 1-5 |

Review order:

1. Hard blockers for the design: #4, #5, #8, #11-#14 (decide whether human gates and
   Projects-driven state work on the Free plan).
2. Core data model: #6, #7, #9, #10.
3. AI execution: #18, #19, #15.
4. Packaging and consumer contract: #1-#3, #16, #17, #20, #21.
5. Bedrock path, after the subscription flow works: #22.

## 4. Open decisions

Round 1 (recommended answer first, none confirmed):

1. Repo shape: `becloud-dev/workflows` with reusable workflows, prompts and label/template
   definitions; thin caller workflows per project; templates in the org `.github` repo.
   Tested 2026-10-11: a private `.github` repo supplies no default templates (section 5, #16);
   templates are synced per repo.
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

Diagram ambiguities: both settled in Round 3 below.

Round 3 (user, 2026-10-11; recommended answers accepted by "Proceed"):

1. Engine: GitHub Actions with `claude-code-action@v1`, one reusable workflow per stage,
   prompts as files in the shared repo, org-level secret.
2. State: issue types for the kind of work; an org-level issue field Priority with options
   P1 to P5; labels only for routing (`RELEASE`, `UX/UI`, `READY TO LIVE`, `release-blocker`);
   one milestone per release; Projects v2 not written by automation. Fallback when issue fields
   are absent on the Free org: labels `P1` to `P5`. Pending the org settings check.
3. Start signal: an owner-applied label starts the issue stages (sender checked against the
   owners variable, label removed at the end); an owner comment starts the PR stages.
4. Planner: 2a and 2b run only by `workflow_dispatch` from the owner; no cron, no chain after
   triage. Backlog order is a saved query over Priority. Replaces Round 1 item 4.
5. Kept from patagonia-trip: Conventional Commits and release-please, `pr-title` check, "Bug
   class" section, `Decision:` options gate for cross-layer issues, plan-before-code triggers,
   `release-blocker` gating, Blocking/Suggestion taxonomy with a 5-nit cap, release range via
   `git describe`, per-issue `concurrency`, `timeout-minutes`, tight tool allowlists, sub-issues
   via `--parent`. Dropped: D1 backup, migrations and deploy, biome, vitest, playwright, pt-BR,
   stack-specific review rules.
6. DEV executes with haiku, model a caller input with the full ID pinned; the monitoring record
   compares it against sonnet on the same plan.
7. The PR is opened by a workflow step with the App token after the Claude step; Claude only
   commits to a branch.
8. Check loop: sonnet check, at most 2 haiku re-executions, then stop with a comment for the
   owner.
9. The AI does not merge: the check posts its result and the owner approves and merges.
   Native auto-merge enabled by the bot stays an unverified alternative.

Round 4 (user, 2026-10-11; recommended answers accepted by "Go"):

1. Planner 2a writes only a report (job summary and monitoring artifact), no issue writes.
2. Planner 2b creates milestones (title = version, `due_on` = ETA) and assigns issues. The owner
   approves by applying `RELEASE` or `UX/UI` per issue, which is also the start signal for
   stage 3 or 4.
3. Names: labels `RELEASE`, `UX/UI`, `READY TO LIVE`, `release-blocker`; transient start label
   `triage`; Priority options `P1` to `P5` with a criticality description each, defined in the
   triage prompt; fallback labels `P1` to `P5`.
4. `RELEASE` and `UX/UI` persist as state and start a run on `labeled`; only `triage` is removed
   at the end. A re-run is remove and re-add. Amends Round 3 item 3.
5. `READY TO LIVE` is set by the owner on the release PR after approving the Opus review (the
   review starts by an owner comment). Merge gate: label present and zero open `release-blocker`.
6. Stage 4 plan is an issue comment with a marker line, not a repo file; the owner's approving
   comment starts the haiku execution.
7. Stage 4 consumer contract: optional string inputs `setup_command`, `check_command`,
   `test_command`, filled from repo `vars` in the caller, no defaults, nothing stack-specific in
   the shared repo; each command is also the `Bash(...)` allowlist entry. Project conventions
   stay in the consumer's `AGENTS.md` or `CLAUDE.md`.
8. Prompt lookup: second checkout into `.ai-workflows/` (sparse `prompts/`, no persisted
   credentials) at `job.workflow_repository` and `job.workflow_sha`; the prompt says to read
   `.ai-workflows/prompts/<stage>.md`. No consumer override.

Round 5 (user, 2026-10-11; recommended answers accepted by "Go"), stage 1 triage:

1. Start: only the owner applying the `triage` label starts a run; no run on `opened`. The
   sender is checked against the owners variable.
2. Priority field: its id comes from the variable `PRIORITY_FIELD_ID`, passed through the
   caller's `with:`. Stage 1 uses no App; writes use `GITHUB_TOKEN`.
3. Claude step: read-only tool allowlist; returns a JSON verdict. A workflow step performs the
   writes with `GITHUB_TOKEN`.
4. Type: applied directly, with the rationale in the comment. No `suggest`.
5. Missing information: a numbered comment and the new label `needs-info`; `triage` is removed
   and the owner re-applies it after the answer.
6. Format fix: the issue body is edited and a one-line comment says what changed.
7. Split: sub-issues are created with `--parent`; the owner applies `triage` to each.
8. One run makes one haiku call covering both diagram steps (classification and split check).
9. Priority options: the org field keeps GitHub's defaults, Urgent, High, Medium, Low (rank by
   option `priority` 1 to 4). Amends Round 3 item 2 and Round 4 item 3: no `P1` to `P5`, no
   fallback labels. The criticality description per option is defined in the triage prompt.
10. Authentication for the first run: the subscription OAuth token (`claude_code_oauth_token`,
    secret `CLAUDE_CODE_OAUTH_TOKEN`, organization secret limited to the sandbox repository),
    not an API key. Amends the fallback in "Live confirmations before triage" item 3. Anthropic's
    answer (A3) is still open and decides whether the arrangement is kept for a public project.

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

Superseded 2026-10-11 for public repositories: all repositories are now public (see "Decisions:
visibility and license"). On public repositories under Free, GitHub enforces CODEOWNERS with a
protected branch or ruleset, and environment reviewers (see "Public repositories: plan features
and subscription terms"). The premise above held for private repositories only. Gates move to
native enforcement where one exists; workflow logic stays for what GitHub cannot gate (labels).

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

Amended 2026-10-11: with public repositories, a called workflow in a public repo is accessible
to any caller (a `private` caller reaches `private` and `public`; a `public` caller reaches
`public` only), so the Access setting above is not needed. The organization policy for allowed
actions and reusable workflows still applies. Source: `reusing-workflow-configurations.md`.

### Gate decisions (2026-10-11)

- A failed gate sets a failing check and a blocking comment; the code owner merges by hand. No
  automatic reverts or closes.
- Gating labels (`RELEASE`, `READY TO LIVE`): a workflow removes the label and comments when the
  actor is not in an owners list kept as a repo variable.

Amended 2026-10-11 (public repositories):

- Merge to the default branch: a protected branch or ruleset that requires a pull request and
  review from code owners, with CODEOWNERS naming the code owner.
- "Pull request authors cannot approve their own pull requests", and "Repository owners and
  administrators can merge a pull request even if it hasn't received an approving review".
  Inference: a PR opened by an App bot can be approved by the owner; a PR the owner opens cannot
  be self-approved, and the owner's override is the escape hatch.
- Labels (`RELEASE`, `READY TO LIVE`): the workflow check above stays; no native control over
  who applies a label was found in the files read.
- Deploy jobs: an environment with the code owner as required reviewer. A job that calls a
  reusable workflow cannot use `environment` (#1), so it sits on a job inside the called
  workflow.
- AI runs start only from the code owner (decision, "Decisions: visibility and license").
- A failed gate still sets a failing check and a blocking comment; no automatic reverts or
  closes.

Unverified: which rule types a ruleset offers on a Free public repo; how admin bypass behaves in
a ruleset against classic branch protection; the label permission model.

### Token and data model (#4, #6, #7, #8, #9, #10), read 2026-10-11

| # | Finding | Gap left open |
|---|---|---|
| 4 | "The token's permissions are limited to the repository that contains your workflow." Events it creates do not start new runs, except `workflow_dispatch` and `repository_dispatch`; `pull_request` runs it creates wait in an approval-required state | Workflow syntax lists 16 scopes (issues, pull-requests, contents, ...); none covers projects or sub-issues. The page text was read to character 100000 of 230295 |
| 8 | "`GITHUB_TOKEN` is scoped to the repository level and cannot access projects." The docs use a GitHub App token (recommended for organization projects) or a classic PAT with `project` and `repo` scopes. Example trigger: `pull_request` `ready_for_review` | The App permission key names for projects are not on this page |
| 6 | Up to 25 custom issue types per organization; defaults are in every organization. The REST create/update issue endpoints accept `type`; "Only users with push access can set the type", silently dropped otherwise | Plan requirement and private-repo availability not stated; who manages types not stated |
| 7 | Sub-issue endpoints: POST/GET/DELETE `/repos/{owner}/{repo}/issues/{n}/sub_issues`, GET `.../parent`, PATCH `.../sub_issues/priority`. The sub-issue must belong to the same repository owner as the parent. Creating content too fast can hit secondary rate limits | Depth and per-parent limits and fine-grained permissions are not documented |
| 9 | Milestone endpoints under `/repos/{owner}/{repo}/milestones`; fields `due_on`, `state`, `open_issues`, `closed_issues` | Per-repo scope is an inference from the paths; permissions not stated |
| 10 | Per-issue label endpoints (add, set, remove one, remove all) and repo label CRUD. Archived labels cannot be added | No org-level label mechanism on the page; permissions not stated |

Implications (inference):

- A GitHub App token is required for any Projects v2 write; `GITHUB_TOKEN` cannot reach projects.
- A token that only has `GITHUB_TOKEN` cannot trigger a follow-up workflow, so stage hand-offs
  must use an App token, `workflow_dispatch` or `repository_dispatch`, or run in one workflow.
- Milestones are per repo, so an org-wide roadmap needs Projects v2, not milestones alone.
- Labels are per repo and must be created in each project repo by a sync step.
- Setting an issue type needs push access; a workflow token without it would silently skip it.

### GitHub App permission keys (#5, #8), read 2026-10-11

Sources: `actions/create-github-app-token` `action.yml` (raw), `github/rest-api-description`
`app-permissions` schema (raw), `github/docs` `server-to-server-permissions.json` (raw).

| Need | Token API key | Action input | Levels |
|---|---|---|---|
| Projects v2 (organization) | `organization_projects` | `permission-organization-projects` | read, write, admin |
| Projects (repository, classic) | `repository_projects` | `permission-repository-projects` | read, write, admin |
| Issues, sub-issues, labels, milestones | `issues` | `permission-issues` | read, write |
| Pull requests | `pull_requests` | `permission-pull-requests` | read, write |
| Contents | `contents` | `permission-contents` | read, write |
| Metadata | `metadata` | `permission-metadata` | read |

- Input name rule: `permission-` plus the key with `_` replaced by `-`.
- A requested permission must already be granted to the installation, or token creation fails.
  Permissions added to an App need administrator approval on the installation first.
- Minimum set for the design: `issues: write`, `pull_requests: write`, `contents: read`,
  `organization_projects: write`, `metadata: read`. Not verified against a working workflow.

Unverified: the docs permission data lists an organization "Issue Types" permission and
"Variables" permissions (repository and organization) as usable by installation tokens, but the
`app-permissions` schema and `action.yml` expose no key or input for either. Minting a token
that carries them was not tested. The design does not depend on them: setting an issue type is
done through `issues: write` (section 5, #6), and the owners variable is read through the `vars`
context with no API call.

### Claude Code Action (#18), read 2026-10-11

Sources: `anthropics/claude-code-action` `action.yml`, `docs/setup.md`, `docs/security.md` (raw,
through a page summarizer) and `code.claude.com/docs/en/github-actions`.

| Topic | Finding |
|---|---|
| Mode | `mode` is not an input in v1. No `prompt`: interactive, waits for `@claude`, answers in a comment. With `prompt`: automation, runs on any event, output in the run log unless the prompt and tools post elsewhere |
| `track_progress` | Current. Default `"false"`; forces tag mode with tracking comments for PR `opened`, `synchronize`, `ready_for_review`, `reopened`, `labeled` and issue `opened`, `edited`, `labeled`, `assigned` |
| Tools | No `allowed_tools` input. `--allowedTools` (alias `--allowed-tools`) goes in `claude_args`. With a plain-text prompt there is no shell or GitHub API access until tools are granted by `--allowedTools` or `permissions.allow` in `settings` |
| Model | No `model` input; `--model` in `claude_args`, else the Claude Code default |
| Auth | `anthropic_api_key`, `claude_code_oauth_token` (tied to the subscription of the person who ran `claude setup-token`; docs recommend an API key for a shared org secret) or workload identity federation (`id-token: write`) |
| Org rollout | Install the App once, org-level secret, job defined once as a reusable workflow |
| Triggers | Write access required on issue and PR events (skipped for events no user authors, e.g. `schedule`). Bot actors rejected unless in `allowed_bots`; allowed bots are not checked for repository permissions |
| App | The official Claude App has a fixed permission set that cannot be accepted in part. A custom App needs Contents, Issues, Pull requests (read and write) and is passed as `github_token` from `actions/create-github-app-token` |
| Pull requests | "Claude does not create pull requests automatically"; it commits to a branch and links to the creation page. Merge and approval are not addressed |
| CI on bot commits | Commits made with `GITHUB_TOKEN` do not start workflows; use the Claude App or a custom App token |
| Injection | Hidden markdown and invisible characters are stripped, "new bypasses may appear"; config files are restored from the base branch on PRs |

Implications (inference):

- An App-token hand-off between stages needs the App bot in `allowed_bots`; the login is
  probably `<app-slug>[bot]`, not verified.
- Whether `gh pr create` works in automation mode under an allowed `Bash(gh pr create:*)` tool
  is not stated. Stage 4 as drawn (DEV opens the PR) depends on it.
- The owners variable stays the real gate, since `allowed_bots` skips permission checks.
- Issue bodies are untrusted input to triage; tool lists per stage should be minimal.

Unverified: how a Claude step writes to Projects v2 with the App token; whether a custom App
path needs `id-token: write`; the current major of `create-github-app-token` (the setup page
pins `@v1`); model IDs in the docs examples are inconsistent (`claude-opus-5-5`,
`claude-sonnet-5`), settled in #19. `docs/usage.md` and `docs/faq.md` read in the monitoring subsection below: no cost content, and nothing on `gh pr create` in automation mode.

### Model choice and billing (#19, #15), read 2026-10-11

Sources: `platform.claude.com/docs/en/about-claude/models/overview`,
`code.claude.com/docs/en/model-config` (first 100000 of 116497 characters),
`code.claude.com/docs/en/costs`, and GitHub billing pages for Actions (through a page
summarizer). Plan limits for Pro also came from third-party guides, second-hand.

| Tier | Claude API ID | Bedrock ID | Retirement, not sooner than |
|---|---|---|---|
| Haiku 5.5 | `claude-haiku-5-5` | `anthropic.claude-haiku-5-5` | 2027-10-07 |
| Sonnet 5.5 | `claude-sonnet-5-5` | `anthropic.claude-sonnet-5-5` | 2027-09-28 |
| Opus 5.5 | `claude-opus-5-5` | `anthropic.claude-opus-5-5` | 2027-09-22 |
| Fable 5.1 | `claude-fable-5-1` | `anthropic.claude-fable-5-1` | 2027-09-01 |

- Every ID is a pinned snapshot. The Action docs example `--model claude-sonnet-5` is a legacy ID.
- Aliases differ by provider: on Bedrock `sonnet` maps to Sonnet 4.5 and `haiku` to Haiku 4.5,
  against 5.5 on the Anthropic API. Full IDs are pinned, aliases are not used.
- Thinking cannot be turned off on the three 5.5 models; `--effort` sets low to max.
- Fable is never a default and can bill to usage credits.
- Pro: rolling five-hour window plus weekly window, shared with claude.ai (third-party guides,
  numbers not published). A run at the limit is not documented for the Action.
- CI usage does not appear in `/usage`, which reads local session history.
- GitHub Actions on a Free org, private repos: 2,000 minutes per month, rounded up to the whole
  minute per job, blocked at quota when no payment method is on file. Linux 2-core x64 is
  $0.006 per minute above quota. Minutes are charged to the repository owner.

### Decisions: runtime and provider (2026-10-11)

- Authentication through the Claude subscription (`claude_code_oauth_token`, Pro now, Max 5x
  later if needed). The user reports Opus, Sonnet and Haiku 5.5 are available on that plan.
- Usage credits stay off. The Pro allowance is the hard ceiling for CI. If credit-billed or API
  usage is needed, the move is to Bedrock, not turning credits on.
- Fable is not used while it needs credits.
- Bedrock is the later target, for fine-tuning and usage tuning. Whether fine-tuning is offered
  for the 5.5 models is not verified (#22).
- The shared workflows take the provider and the model per stage as caller inputs, with the
  subscription as default. Nothing provider-specific is hardcoded in the shared repo.
- No jobs that exist only to check a label: fold gate checks and triage into one job where
  possible, since each job rounds up to a minute.

Unverified: behaviour of a run at the Pro limit; whether an existing OAuth token keeps working
after a plan change; real tokens and minutes per run (needs a measured run); the last 16497
characters of the model-config page; reusable-workflow billing across repos (not stated, same
org so one owner).

### Reusable workflows, events and syntax (#1, #2, #3), read 2026-10-11

Sources: docs.github.com pages for #1 to #3 (through a page summarizer), then raw `github/docs`
markdown (`workflow-syntax.md`, `events-that-trigger-workflows.md`, `contexts.md`,
`reusing-workflow-configurations.md`, concurrency reusables) to close the gaps.

| Topic | Finding |
|---|---|
| Call | Job level only: `{owner}/{repo}/.github/workflows/{file}@{ref}`; ref is a SHA, tag or branch (SHA safest). No expressions in `uses`; no subdirectories of `workflows` |
| Access | Private called repo: its Access policy must allow caller repos. Caller repo: Actions permissions must allow actions and reusable workflows |
| Inputs | Typed `boolean`, `number`, `string`; an undeclared input is an error. `with` values: the context table allows `github, needs, strategy, matrix, inputs, vars`; the prose on the same page lists only `github` and `needs` (table taken as authoritative, untested) |
| Secrets | By name or `inherit` (org, repository and environment secrets, same org or enterprise); only to the directly called workflow; a missing environment secret resolves to an empty string unless `required: true` |
| Outputs, env | Outputs map to job outputs; `env` does not propagate in either direction |
| Permissions | `GITHUB_TOKEN` permissions can only be downgraded down the chain |
| Limits | Ten levels, no loops; 50 unique reusable workflows per workflow file; caller job cannot use `environment` |
| `github.workflow` | In a called workflow it is the caller's name; the same concurrency group in both layers cancels the caller |
| Concurrency | One running run per group; default `queue: single` keeps one pending and a newer pending cancels the older; `queue: max` keeps up to 100, cannot combine with `cancel-in-progress: true`, FIFO order "not guaranteed". Group expressions: `github`, `inputs`, `vars` (job level adds `needs`, `strategy`, `matrix`). `queue` sits behind the docs flag `actions-nga` (`fpt` and `ghec`) |
| Timeout | `jobs.<id>.timeout-minutes` default 360 |
| `permissions` scopes | `actions`, `artifact-metadata`, `attestations`, `checks`, `code-quality`, `contents`, `deployments`, `discussions`, `id-token`, `issues`, `packages`, `pages`, `pull-requests`, `security-events`, `statuses`, `vulnerability-alerts`; once one is named the rest are `none`; no projects scope |
| Events | `issues` types include `typed`, `untyped`, `field_added`, `field_removed`, `milestoned`; issue events run the default-branch workflow file; `issue_comment` covers PRs (`github.event.issue.pull_request`); `label` is label CRUD, not applying a label; `workflow_dispatch` up to 25 inputs; `repository_dispatch` `client_payload` up to 10 properties; `workflow_run` chains deeper than three do not run; `schedule` minimum 5 minutes, default branch only |
| `projects_v2_item` | Absent from the raw events list: no documented Actions trigger for Projects item changes |
| `GITHUB_TOKEN` events | Do not start runs, except `workflow_dispatch` and `repository_dispatch` |

Implications (inference):

- The consumer's caller file names the shared repo ref, so a moving tag rolls an update and a SHA
  pins it.
- Planner runs cannot follow Projects field edits; use `workflow_dispatch` or labels.
- Per-issue serialization: a group per issue number at the caller, with `queue: max` if no event
  may be dropped; name the group explicitly, not from `github.workflow`.
- Set `timeout-minutes` explicitly; 360 would spend 18% of the Free quota in one stuck job.
- The owners value is passed as an input from `vars` in the caller.

Unverified: whether `vars` resolve inside a called workflow without being passed; whether
dispatching a workflow with `GITHUB_TOKEN` needs `actions: write`; that `fpt` in docs versioning
means Free, Pro and Team (docs convention, not stated in the files read); the `with` context
contradiction above, untested.

### Org default templates (#16), read and tested 2026-10-11

Sources: raw `github/docs` markdown (`creating-a-default-community-health-file.md`,
`about-issue-and-pull-request-templates.md`, `configuring-issue-templates-for-your-repository.md`,
`creating-a-pull-request-template-for-your-repository.md`, `reusing-workflow-configurations.md`,
`create-workflow-templates.md`, reusables `default-issue-templates` and `valid-community-issues`,
feature file `actions-nga.yml`), its commit history, and a live test in the `becloud-dev` org.
The visibility statements were cross-checked on the rendered docs.github.com pages.

| Topic | Finding |
|---|---|
| Host repo | Default files live in a repo named `.github`. It "must be public"; "A repository for default files cannot be private." Raw and rendered text agree. No reason or mechanism is stated |
| History | The passage was edited deliberately in 2025-11, 2026-03 and 2026-08 (public or internal; templates need public on GHEC; EMU orgs use internal). Earlier wording: "Private `.github` repositories are not supported" |
| Reach | Defaults are used for any repo of the owner "regardless of the destination repository's visibility" that has no file of its own of that type. `github/docs` PR #6941 (2021) changed the docs to match behavior: private repos do inherit |
| Issue templates | Stored in `.github/ISSUE_TEMPLATE` with `config.yml`. A repo that defines valid issue templates or template configuration in its own folder gets none of the default folder: override is per folder, not per file |
| PR templates | Precedence per file type: repo `.github` folder, repo root, `docs`, then the `.github` repo. A `PULL_REQUEST_TEMPLATE/` subdirectory holds several templates, chosen by the `template` query parameter |
| Labels | "If an issue template sets a label, that label must be created in your `.github` repository and any repositories where the template will be used" |
| Not shareable | A default license file |
| Starter workflows | `workflow-templates/` in `.github`, each with a `<name>.properties.json`; `$default-branch` placeholder. Under the docs flag `actions-nga` (`fpt`, `ghec`) the repo need not be public: a private `.github` serves only private repos, and users or teams need Read access to it. Not tested |

Live test (Free org, 2026-10-11): private `becloud-dev/.github` holding
`.github/ISSUE_TEMPLATE/probe.yml` (an issue form named "Probe form"), and a private target
`becloud-dev/tmp-template-probe` with no templates of its own.

| `.github` visibility | `/issues/new/choose` on the target |
|---|---|
| private | plain blank issue form, no chooser (screenshot 12:24:04, -03:00) |
| public | chooser with "Probe form" and "Blank issue" (screenshot 12:25:05, -03:00) |

- The GraphQL field `Repository.issueTemplates` returned `[]` in every state, including with
  the `.github` repo public and the chooser showing the form. The field does not report
  inherited defaults and is not usable as a check; only the UI was.
- One run, one org, one plan, one file type (issue form). The form appeared within about a
  minute of the visibility change, so propagation lag does not explain the private result.

Implications (inference):

- A private `.github` repo in a Free org supplies no default issue forms, even to private repos.
  The all-private decision therefore rules out the org `.github` repo for templates.
- Templates and labels reach each project repo by a sync step from `workflows`, in the same step
  as the #10 label sync. A repo with any file of its own in `.github/ISSUE_TEMPLATE` shows only
  its own.
- Starter workflows from a private `.github` repo are untested; the caller files can be copied
  by the same sync step instead.

Unverified: whether PR templates and `config.yml` behave like issue forms (same folder rule,
not tested); whether `actions-nga` starter workflows from a private `.github` work on a Free
org (`fpt` is the docs convention for Free, Pro and Team, not stated in the files read); what
happens when a template names a label that does not exist in the repo (#17).

### Decisions: visibility and license (2026-10-11)

- All repositories under `becloud-dev` are public (user, 2026-10-11), reversing the all-private
  decision recorded earlier the same day. Purpose: a study project open to the developer
  community, to show that AI can automate the process and to measure the real cost; the cheapest
  setup is the goal (Free plan, public repositories).
- License: MIT for code and docs, one `LICENSE` per repository. Copyright holder: Bento Machado
  (https://github.com/bentoluizv), year 2026 (user, 2026-10-11; the full legal name is longer,
  and the short form with the personal page was chosen).
- Accepted consequence: others may use, sell and host the work commercially.
- Contributions arrive under the repository license (GitHub Terms of Service, "Contributions
  Under Repository License", "inbound=outbound"); no CLA.
- Who may start an AI run: only the code owner, through a label or comment that needs write
  access (user, 2026-10-11). The community creates issues and reviews the AI's work in the open.
- Subscription auth stays (`claude_code_oauth_token`) under that gate, and Anthropic is asked to
  confirm in writing that it fits the terms (user, 2026-10-11). Until the answer arrives the
  question stays open. A fallback is an API key or Bedrock.
- AI pull requests are opened under a custom GitHub App bot identity, so the code owner can
  approve them under the native gate (user, 2026-10-11). How the bot opens the PR is open: the
  Action "does not create pull requests automatically" (#18).
- Option C was replaced by native gates on public repositories (see "Decision: option C").
- Not decided: a monitoring and metrics stage.

### AI-generated output and copyright (read 2026-10-11)

Source: US Copyright Office, "Copyright and Artificial Intelligence, Part 2: Copyrightability"
(January 2025), raw PDF, executive summary conclusions.

- "Copyright does not extend to purely AI-generated material, or material where there is
  insufficient human control over the expressive elements."
- "The use of AI tools to assist rather than stand in for human creativity does not affect the
  availability of copyright protection for the output."
- "Based on the functioning of current generally available technology, prompts do not alone
  provide sufficient control."
- Human authors keep copyright in perceptible contributions and in "creative selection,
  coordination, or arrangement … or creative modifications of the outputs". Case by case.

Implications (inference): files written by AI with little human edit may carry no copyright, so
the MIT notice covers the human-authored parts and may not cover raw AI output. The effect on a
permissive license is small; it weakens any claim over pure AI output.

Unverified: US guidance only, not binding on courts; Brazilian law not read; whether human
review in the workflow counts as a creative modification.

### Public repositories: plan features and subscription terms (read 2026-10-11)

Sources: raw `github/docs` markdown (`billing/concepts/product-billing/github-actions.md`,
`deployments-and-environments.md`, `about-rulesets.md`, `about-protected-branches.md`, reusables
`gated-features/repo-rules`, `protected-branches`, `code-owners`) and raw markdown of
`code.claude.com/docs/en/legal-and-compliance` and `github-actions`.

| Topic | Finding |
|---|---|
| Actions minutes | "The use of standard GitHub-hosted runners is free: in public repositories". Larger runners are always charged |
| Rulesets | "Rulesets are available in public repositories with GitHub Free and GitHub Free for organizations, and in public and private repositories with GitHub Pro, GitHub Team, and GitHub Enterprise Cloud" (reusable). The `about-rulesets` page words it as "for customers on GitHub Team and GitHub Enterprise plans"; the reusable is read as the plan matrix |
| Protected branches | Public repositories with Free and Free for organizations; private only on Pro, Team, Enterprise |
| CODEOWNERS | Can be defined in public repositories with Free and Free for organizations; "require review from code owners" is a protected-branch option |
| Environments | On Free, Pro and Team, required reviewers, wait timers, environment secrets, administrator bypass and custom protection rules are public-repository only |
| Issue forms | `required` is enforced for public repositories only (#17) |
| `.github` repo | Default templates need a public `.github` repo (tested, #16) |
| Subscription auth | OAuth is "intended exclusively for purchasers of … subscription plans" for "ordinary use". "Anthropic does not permit third-party developers to … route requests through Free, Pro, or Max plan credentials on behalf of their users." The Action docs: an OAuth token "is tied to the subscription of the person who ran `claude setup-token`", API key recommended for a shared secret |
| Who can trigger | Write access is required on issue and PR events (#18) |

Corrections to earlier records:

- The rulesets matrix in "Hard blockers" was second-hand; the raw reusable above replaces it. The
  claim there that a ruleset on a private Free repo "can be created but is not enforced" is not
  in the raw source and stays unverified.
- #13 "Free private not addressed directly": environments are public-only on Free, so private
  Free repos have none of these features.

Implications (inference):

- The premise of "Decision: option C" (GitHub cannot enforce gates on Free) holds for private
  repos only. Public repos can use CODEOWNERS with a protected branch or ruleset, and
  environment reviewers for deploy jobs. Whether to replace option C is open.
- Cost reduces to AI usage; Actions minutes are free for standard runners.
- A public repo with community-triggered AI runs on a personal subscription is the grey case
  of the auth terms. An owner-gated trigger (label or comment needing write access) keeps runs
  initiated by the owner. Not a legal opinion.
- Issue and PR text from strangers is untrusted prompt input (#18).

Unverified: which ruleset rule types exist on Free public repositories; whether owner-gated
runs on a public repo count as "ordinary use"; Anthropic's position (a question to Anthropic
is open).

### Issue forms (#17), read 2026-10-11

Sources: raw `github/docs` markdown (`syntax-for-issue-forms.md`, `syntax-for-githubs-form-schema.md`,
`common-validation-errors-when-creating-issue-forms.md`, reusables `form-schema/*`,
`community/issue-forms-beta`, `community/issue-forms-sample`). The `required` note was
cross-checked on the rendered docs.github.com page.

| Topic | Finding |
|---|---|
| Top-level keys | Required: `name` (unique, longer than 3 characters), `description`, `body`. Optional: `assignees`, `labels`, `title`, `type`, `projects` |
| `labels` | "If a label does not already exist in the repository, it will not be automatically added to the issue": a missing label is dropped, no error documented. Closes the #16 gap |
| `type` | "The issue type that will be automatically added … defined at the organization level". Behavior when the type does not exist is not stated |
| `projects` | `PROJECT-OWNER/PROJECT-NUMBER`. The person opening the issue needs write permission on the project; otherwise the docs point to the project's auto-add workflow |
| Elements | `markdown` (displayed, not submitted), `textarea`, `input`, `dropdown`, `checkboxes`, `upload` (docs flag `issue-form-upload`, present on the rendered page; size limits 10 to 100 MB by type) |
| `required` | "Prevents form submission until element is completed. Only for public repositories." Same text on every element type that has it; `min_length` carries no such note |
| Output | Responses are "converted to markdown and added to the body of an issue". No structured data. `id` is the key for URL query prefill |
| Validation | Body needs one non-markdown field; unique `id`s and labels (also across checkbox options); labels that normalize alike clash; YAML boolean words (`yes`, `no`, `on`, `off`, ...) are forbidden as keys; dropdown options distinct and not `none` |
| Status, scope | Issue forms and the form schema are public preview, "subject to change". Not supported for pull requests |

Implications (inference, for public repositories):

- `required` is enforced in the form. Issues created through the API or `gh` skip the form, so
  the triage workflow still checks the body.
- Triage reads a markdown body in which each field is a `### <label>` heading followed by the
  value (tested for `textarea`); form labels stay stable because they become the headings.
- Labels named by a form must exist in each repo (sync step) or they are dropped without error.
- Public preview: forms are pinned in `workflows` and re-checked at each release.

Live test (public repo `becloud-dev/tmp-template-probe`, Free org, 2026-10-11): a form with
`required: true` on a textarea, `labels: ["no-such-label"]` and `type: NoSuchType`.

| Case | Result |
|---|---|
| Submit with the required field empty | Blocked in the form: "Field can not be empty" under the field; no issue created |
| Submit with `hello` | Issue #1 created; body exactly `### What\n\nhello` (field label as an H3 heading, blank line, value) |
| Missing label `no-such-label` | Not applied and not created (the repo has only GitHub's default labels), no error shown |
| Missing type `NoSuchType` | Not applied (`type` is `null`), no error shown |

One run, one field type (`textarea`). A new repo in the org starts with ten default labels:
`accessibility, bug, documentation, duplicate, enhancement, good first issue, help wanted,
invalid, question, wontfix`.

Unverified: body layout of `input`, `dropdown`, `checkboxes` and `upload`, and of an empty
optional field; behavior of `type` and `labels` for an issue created through the API instead of
the form; the forbidden-word list for labels; any limit on body size or element count (none
stated in the files read).

### `gh` CLI flags (#20), read 2026-10-11

Sources: raw `cli/cli` source at release v2.102.0 (2026-09-30), the same version as the local
`gh`: `pkg/cmd/issue/create/create.go`, `edit/edit.go`, `pkg/cmd/issue/shared/lookup.go`,
`api/queries_issue.go`, `pkg/cmd/pr/create/create.go`, `pkg/cmd/root/help_topic.go`; release
notes of v2.94.0.

| Topic | Finding |
|---|---|
| `gh issue create` | `--title`, `--body`, `--body-file`, `--editor`, `--web`, `--assignee`, `--label`, `--project` (by title), `--milestone`, `--template`, `--recover`, `--type` (name), `--parent` (number or URL), `--blocked-by`, `--blocking` |
| Since | `--type`, `--parent` and relationships: v2.94.0 (2026-06-10). Release notes: "available on GitHub.com and GHES 3.17+; relationships require GHES 3.19+" |
| `gh issue edit` | `--add-label`/`--remove-label`, `--add-assignee`/`--remove-assignee`, `--add-project`/`--remove-project`, `--milestone`/`--remove-milestone`, `--type`/`--remove-type`, `--parent`/`--remove-parent`, `--add-sub-issue`/`--remove-sub-issue`, `--add-blocked-by`/`--remove-blocked-by`, `--add-blocking`/`--remove-blocking` |
| Order | `create` calls `IssueCreate`, then applies type, parent and relationships as separate mutations (`DeferredUpdateIssue`), run concurrently |
| Failure mode | A follow-up error (for example `type "X" not found; available types: …`) returns before the issue URL is printed, after the issue exists |
| Type match | Case-insensitive by name against the repository's available types |
| `gh pr create` | `--title`, `--body`, `--body-file`, `--base`, `--head`, `--fill`, `--fill-first`, `--fill-verbose`, `--draft`, `--reviewer`, `--assignee`, `--label`, `--project`, `--milestone`, `--template` (file), `--dry-run` ("May still push git changes"), `--no-maintainer-edit`, `--recover`, `--editor`, `--web`. No `--type` or `--parent` |
| Auth, prompts | `GH_TOKEN`, `GITHUB_TOKEN` (in that order of precedence); `GH_PROMPT_DISABLED` disables interactive prompts |
| Stability | No per-flag stability marker found in the files read; every flag above exists in the current release |

Implications (inference):

- An automated create is two steps in effect: check the type name first (or create, then
  `gh issue edit --type`), and carry an idempotency marker in the title or body so a retry
  searches before creating.
- Sub-issues still need the same repository owner (#7); Projects v2 writes still need an App
  token (#8).
- `--parent` and `--type` on creation are convenience only; setting them with `gh issue edit`
  is the same mutation and can be retried on its own.

Unverified: behavior of `--type` when the organization has no types; prompts without a TTY when
`--title` or `--body` is missing (the logic is at `create.go:135`, not run); `--project` with an
App token; the repository setting "Allow GitHub Actions to create and approve pull requests"
for `gh pr create` under `GITHUB_TOKEN` (not read).

### Release tooling (#21), read 2026-10-11

Sources: raw `googleapis/release-please` (README, `src/strategies/simple.ts`,
`src/strategies/base.ts`, `src/versioning-strategies/default.ts`, `src/commit.ts`; release
v17.11.2, 2026-08-24), raw `googleapis/release-please-action` README (v5.0.0, 2026-04-22), raw
`conventional-commits/conventionalcommits.org` spec v1.0.0.

| Topic | Finding |
|---|---|
| Scope | Parses Conventional Commits, keeps a Release PR up to date; on merge it updates the changelog, tags and creates a GitHub Release. "It does not handle publication to package managers" |
| Language | Release types include `simple` ("a version.txt and a CHANGELOG.md"); language-specific ones need their own files |
| Without a manifest | The action takes `release-type` inline; "allows for no further customization". `release-please-config.json` and `.release-please-manifest.json` are the advanced path |
| `simple` source | `CHANGELOG.md` is created if missing; `version.txt` is updated with `createIfMissing: false`, so the file must exist |
| Versioning | Breaking: major (minor pre-1.0 with `bumpMinorPreMajor`); `feat`: minor; anything else: patch. `Release-As: x.y.z` in a commit body forces the version. Squash-merge is "highly" recommended |
| Release PR trigger | README: releasable units are `feat`, `fix`, `deps`; `chore` and `build` are not |
| Labels | `autorelease: pending`, `tagged`, `snapshot`, `published` (the last is a convention, not set automatically) |
| Token | Default `GITHUB_TOKEN`: PR, tag and release it creates "will not trigger future GitHub actions workflows"; a PAT is documented for CI on release PRs |
| Permissions | `contents: write`, `issues: write`, `pull-requests: write`; "Allow GitHub Actions to create and approve pull requests" may be needed |
| Spec | Only `feat` and `fix` are defined; other types MAY be used; breaking is `!` before the colon or footer `BREAKING CHANGE:`; footers case-insensitive except `BREAKING CHANGE` |

Implications (inference):

- The release PR must be created with an App token (same identity as #5), not `GITHUB_TOKEN`, so
  checks run on it and the code owner can approve it under the native gate.
- A docs-only repo needs a committed `version.txt`; the release PR then edits `version.txt` and
  `CHANGELOG.md`.
- The git-workflow rule's "`perf`, `refactor`, `revert`: patch" may not produce a release PR on
  its own, if the README's releasable-unit list is accurate. Test before relying on it.

Unverified: which commit types alone create a release PR (`postProcessCommits` and the
manifest commit filter not read); behavior of an App token for release PR checks (documented
for a PAT only); that the action major `@v5` is the current one for new setups (latest release
tag, not the setup text).

### Monitoring and metrics, read 2026-10-11

Sources: `anthropics/claude-code-action` at commit `1d6de8c` (`action.yml`,
`base-action/src/run-claude-sdk.ts`, `base-action/src/execution-file.ts`,
`src/entrypoints/run.ts`, `src/entrypoints/update-comment-link.ts`,
`src/entrypoints/format-turns.ts`; `docs/usage.md` and `docs/faq.md` now read, no cost content);
`code.claude.com/docs/en/{costs,monitoring-usage,analytics,headless,github-actions}.md` and
`.../agent-sdk/cost-tracking.md` (raw markdown); `github/rest-api-description` OpenAPI
(`api.github.com.json`); `github/docs` raw `content/` files for billing, workflow commands,
limits and Projects.

| Topic | Finding |
|---|---|
| Action outputs | `conclusion`, `execution_file`, `branch_name`, `github_token`, `structured_output`, `session_id`. No cost or token output |
| Execution file | `claude-execution-output.json` in `RUNNER_TEMP`: the full SDK message array, last element is the `result` message. Contains tool results, so not uploaded raw |
| Default log | Sanitized: `duration_ms`, `num_turns`, `total_cost_usd`, `permission_denials_count`, and `modelUsage` reduced to `contextWindow` and `maxOutputTokens` (token usage and cost per model are hidden on purpose). `show_full_output: true` prints everything and is unsafe on public logs |
| Step summary | `display_report` default `"false"`; when on, `format-turns.ts` renders per-turn token usage and `Cost` and `Duration` |
| Tracking comment | `update-comment-link.ts` reads `total_cost_usd`, `duration_ms`, `duration_api_ms` from the last element of the execution file |
| Cost meaning | `total_cost_usd` and `costUSD` are client-side estimates from a bundled price table, "not authoritative billing data"; `-p` JSON output carries the same; a resumed session reports the conversation total |
| Subscription | Docs: the `/usage` session cost "isn't relevant for billing" for Pro and Max, and is computed locally at list price. Nothing states that an OAuth run omits it |
| OpenTelemetry | `CLAUDE_CODE_ENABLE_TELEMETRY=1`; metrics `claude_code.cost.usage` (USD) and `claude_code.token.usage` (by `type`, `model`); exporters `otlp`, `prometheus`, `console`, `none`; `console` writes to stderr under `-p`. Needs a collector to be useful |
| Analytics | Teams and Enterprise dashboards, the Console dashboard and the Analytics API do not cover an individual Pro or Max subscription |
| Run and job timing | `GET /repos/{o}/{r}/actions/runs/{id}/jobs` and `.../jobs/{id}` return `started_at`, `completed_at`, per-step times, `runner_name`, `labels`, `run_attempt` |
| Billable minutes | `GET .../runs/{id}/timing` (`billable.UBUNTU.total_ms`, `run_duration_ms`) is marked "closing down" in the OpenAPI text; "billable minutes only apply to private repositories". Org usage report `GET /organizations/{org}/settings/billing/usage` needs the enhanced billing platform and an org admin; summary endpoint is public preview |
| Public repos | Actions usage is free for public repositories on standard hosted runners (`billing/concepts/product-billing/github-actions.md`); minutes are time, not money, for this org |
| Job summary | `GITHUB_STEP_SUMMARY`, 1 MiB per step, at most 20 summaries per job, secrets masked; survives as long as the run |
| Artifacts | `retention-days` 1 to 90, default per repo or org setting; share an allowance with Packages on private repos |
| Projects v2 | Number and text fields exist; `updateProjectV2ItemFieldValue` takes `{ text }` or `{ number }` and needs an item added first (`addProjectV2ItemById`); token needs `project` scope or an App with Projects permission |

Implications (inference):

- The caller workflow, not the Action, must collect metrics: one `jq` step on `execution_file`
  that keeps only the `result` message fields (`total_cost_usd`, `duration_ms`, `duration_api_ms`,
  `num_turns`, `is_error`, `modelUsage`) and drops everything else. `modelUsage` is the field
  the SDK types name for token and cost accounting; `usage` is the main loop only.
- Minimal GitHub-native design: that record goes to the job summary (always), and to an artifact
  or a number field only if cross-run totals are wanted. Stage and model come from the caller
  inputs already decided, so the record carries `stage`, `model`, `run_id`, `issue`.
- For this study, `total_cost_usd` is a list-price equivalent, which is the useful comparison
  against Bedrock later; it is not what the subscription charges (nothing per token).

Read 2026-10-11 (SDK types, `@anthropic-ai/claude-agent-sdk@0.3.296`, the version range the
Action pins): `ModelUsage` carries `inputTokens`, `outputTokens`, `thinkingTokens?`,
`cacheReadInputTokens`, `cacheCreationInputTokens`, `webSearchRequests`, `costUSD`,
`canonicalModel?`, `provider?` and `costBasis?` (`list`, `managed`, `unknown`). Both billing
usage endpoints answer `200` with `usageItems: []` for `becloud-dev` (Free plan, no repos).

Unverified (needs a live run): whether an OAuth run fills `total_cost_usd` and `modelUsage`
with values; whether the billing usage endpoints return rows for a public repo on the Free
plan; Projects v2 writes with an App token from a workflow step; whether `display_report`
output fits the 1 MiB step limit on long runs.

#### Decisions: monitoring record (user, 2026-10-11)

- Fields per record: `ts`, `repo`, `workflow`, `stage`, `issue_or_pr`, `run_id`, `run_attempt`,
  `model` (pinned ID passed by the caller), `auth` (`oauth`, `api_key`, `bedrock`), `is_error`,
  `num_turns`, `duration_ms`, `duration_api_ms`, `total_cost_usd`, and per model `inputTokens`,
  `outputTokens`, `thinkingTokens`, `cacheReadInputTokens`, `cacheCreationInputTokens`,
  `costUSD`, `costBasis`. No prompt, result text or tool output.
- Storage: job summary always, plus a JSON artifact with `retention-days: 90`. No issue comment
  and no metrics branch for now; revisit once real data shows what is worth keeping.
- Producer: one composite action in the shared repo, called after the Claude step by each
  stage workflow, so the `jq` logic exists once.
- Failed and cancelled runs record too (`if: always()`); a run killed before any result message
  records zeros and the job conclusion only.
- Cross-run totals: a documented `gh run download` and `jq` command, run by hand; no
  aggregation workflow until data exists. (Round 2, default accepted if no change.)

Composite action reference (read raw, `workflow-syntax.md`): `./path` resolves against the
caller's workspace, so it fails from a reusable workflow called cross-repo. `$/path/to/action`
resolves to the repository of the file it appears in, at the running commit, with no checkout
and no `@ref`; not on GHES. Fallback: `becloud-dev/workflows/.github/actions/<name>@<ref>`.
Unverified: `$/` from a reusable workflow called cross-repo on a hosted runner; the release
date and minimum runner version (2.336.0) came from a search result, not read raw.

### Stage design inputs, read 2026-10-11

Sources: `bentoluizv/patagonia-trip` through `gh api` (`CONTRIBUTING.md`,
`.github/pull_request_template.md`, `.github/workflows/{claude-issue-review,claude-pr-review,
release,pr-title}.yml`, `.github/claude/{issue-review,pr-review}.md`); raw `github/docs`
(`about-issue-fields.md`, `managing-issue-fields-in-your-organization.md`,
`adding-and-managing-issue-fields.md`, `events-that-trigger-workflows.md`,
reusable `actions-do-not-trigger-workflows.md`, `about-code-owners.md`,
`managing-github-actions-settings-for-a-repository.md`, `adding-items-automatically.md`,
`src/github-apps/data/fpt-2026-03-10/server-to-server-permissions.json`); raw
`platform.claude.com` model overview and pricing.

| Topic | Finding |
|---|---|
| Patagonia engine | Issue review: `issues` `opened` and `labeled` (label `claude`, removed at the end), skipped when `sender.type == 'Bot'`, `concurrency` per issue number, `timeout-minutes: 15`, `claude-code-action@v1` with `claude_code_oauth_token`, `track_progress: true`, `--model` and `--allowedTools`/`--disallowedTools` in `claude_args`. The prompt only says "read and follow `.github/claude/issue-review.md`" |
| Patagonia PR review | `issue_comment` beginning `@claude review`, `timeout-minutes: 25`, opus. A release PR (head `release-please--*`) is reviewed over `git describe --tags --abbrev=0 HEAD...HEAD`. Normal PRs are not reviewed by Claude unless the owner asks |
| Patagonia gates | A cross-layer issue gets an Options section and code starts after the owner's `Decisão:` comment; a plan the owner approves comes before code for a new entry point, a migration, 3 or more hand-written files, or any change under `.github/workflows/`. Both are prose and local Plan Mode, not workflow logic. A `release-blocker` issue open makes the deploy job fail |
| Patagonia has no | Planner, UX/UI research or DEV workflow. Implementation runs in a local Claude Code session; stage 4 of section 1 has no source to port |
| Patagonia release | `release-please-action@v4` on push to `main`; merging the release PR tags and deploys; `pr-title` uses `amannn/action-semantic-pull-request@v6` with the same type list |
| Issue fields | Org-level, up to 25; types single-select, text, number, date; defaults Priority (Urgent, High, Medium, Low), Effort, Start date, Target date, all editable. Settable from the sidebar, projects, the API or Actions; not from templates or URL prefill; issues only, not pull requests. Docs feature flag `issue-fields` is `fpt: '*'` |
| Issue field events | `issues` types `field_added` (set or changed) and `field_removed` (cleared) start workflows |
| Issue field API | `PUT`/`POST`/`DELETE /repos/{o}/{r}/issues/{n}/issue-field-values`, `GET` the same; `GET`/`POST`/`PATCH`/`DELETE /orgs/{org}/issue-fields`. Values need `issues: write` (and `pull_requests: write` is also listed); the endpoint rows carry `additional-permissions: true`, meaning not read. Field definitions have their own `issue_fields` permission, read or write |
| Other permissions | `POST .../dispatches` needs `actions: write`; merge a pull request needs `contents: write`; create a pull request and create a review need `pull_requests: write` |
| PR creation by token | The repository setting "Allow GitHub Actions to create and approve pull requests" governs whether `GITHUB_TOKEN` can create and approve; new organization repos inherit the organization setting |
| Code owners | "Individuals or teams", with write access; a user or team without it is not assigned |
| Projects on Free | Built-in auto-add workflows: 1 per project on the Free plan; 50 fields per project, issue fields included |
| Prices (API, per MTok) | Haiku 5.5: $0.10 input, $0.50 output up to a 100,000-token prompt; $0.50 and $2.50 above it. Sonnet 5.5: $2 and $10. Opus 5.5: $4 and $20. Fable 5.1: $10 and $50 |

Implications (inference):

- Priority can be an issue field instead of a Projects field: it is writable with the same
  token as labels, and a change to it can start a workflow. Section 2's mapping row "Priority,
  backlog / planned / in progress: Projects v2 single-select fields" is superseded for priority if
  the field exists on the Free org.
- Backlog order is a saved search over the Priority field; no AI run is needed to sort.
- A bot cannot satisfy a required code-owner review, since it cannot be listed as a code owner.
- Reusable stage workflows can be chained with `workflow_dispatch` using `actions: write`;
  other `GITHUB_TOKEN` events do not chain.
- Haiku's price advantage shrinks above 100,000 prompt tokens, which long agentic runs may reach.

Unverified: issue fields on a Free organization (docs convention `fpt`, needs the org settings
page); the meaning of `additional-permissions: true`; whether an approval by `GITHUB_TOKEN`
counts toward a code-owner requirement; whether native auto-merge works on a Free public repo;
`vars` inside a called workflow (the contexts page states nothing); how a called workflow locates
its own repository for a second checkout; Haiku 5.5 behaviour as executor (no measured run).

### Stage design, round 4 inputs, read 2026-10-11

Sources: `bentoluizv/patagonia-trip` through `gh api` (`labels`, `CONTRIBUTING.md`,
`pull_request_template.md`, 6 most recent issues); raw `github/docs`
(`reference/workflows-and-actions/contexts.md`, `how-tos/reuse-automations/reuse-workflows.md`,
`managing-issue-fields-in-your-organization.md`, `data/reusables/actions/workflow-ref-description.md`,
`src/github-apps/data/fpt-2026-03-10/server-to-server-permissions.json`).

| Topic | Finding |
|---|---|
| Called workflow finds its own repository | `job.workflow_repository` is the `owner/repo` of the repository containing the workflow file that defines the current job; `job.workflow_sha` is that file's commit SHA; `job.workflow_ref` "refers to the reusable workflow file" for a job defined in a reusable workflow. The contexts page gives an example reusable workflow that passes the first and second to `actions/checkout` (`repository`, `ref`) to read files co-located with the workflow. Marked unavailable only on GitHub Enterprise Server |
| Context availability | `job` is available in `jobs.<job_id>.steps.with` and `steps.run`. `vars` is available in `jobs.<job_id>.with.<with_id>` (the caller), in steps and in `jobs.<job_id>.if`. `github.workflow_ref` is "the ref path to the workflow"; the page does not say caller or called, and `job.workflow_ref` is described as equal to it for jobs defined directly in a workflow file |
| `vars` in a called workflow | Neither the reusable-workflows page nor the contexts page says whose variables a called workflow reads |
| Patagonia labels | 14 labels: GitHub defaults, `autorelease: pending` / `autorelease: tagged`, `claude` ("Run the Claude issue reviewer", removed when the review ends) and `release-blocker`. No priority, routing or stage labels. The 6 most recent issues have no issue type |
| Patagonia plan and checks | The plan is local Plan Mode, "isn't copied anywhere": the issue keeps the `Decisão:` and the PR body says what was done. No plan file. Checks are `npm run check` and `npm run e2e` |
| Issue field options | Up to 25 fields per org; default fields are editable (name, description, options) or deletable; single-select options carry a name, description and colour; a field is pinned to issue types and "Issues without a type" can be selected; an unpinned field with no value stays hidden. The page states no option-count limit |
| Milestone permissions | `list/get/create/update/delete-a-milestone` sit under the `issues` key (read, write), server-to-server true |

Implications (inference):

- A called workflow reads its prompt files with a second checkout at `job.workflow_repository` and
  `job.workflow_sha`; prompts and workflow file are then always the same commit, and the caller's
  `uses: ...@<ref>` picks both.
- Consumer values travel as `with:` inputs filled from `vars` in the caller, a documented path that
  does not depend on `vars` inside the called workflow.
- The Priority field needs pinning to the issue types in use and to "Issues without a type",
  otherwise it is hidden on typeless issues.
- Milestones and labels need the same `issues: write` as issue fields; no extra App permission for 2b.
- Patagonia has no routing labels, planner or plan file; items 1-3 are design, not a port.

Corrected: the last paragraph of "Stage design inputs" lists "how a called workflow locates its own
repository" as unverified; it is documented above. Still unverified: `job.workflow_sha` populated in
a called workflow on a Free public repo (docs state it; live probe postponed); org issue fields
present (needs the account); option-count limit of a single-select.

### Live confirmations before triage (2026-10-11)

Section A changes the triage design; section B is confirmed by the first triage run, with the
workflow written first. Settled by docs, no live check: the `workflow_call` event payload is "the
same event payload from the calling workflow", so `github.event.sender` and `label` are the
caller's; setting an issue type needs push access (#6); `gh issue edit --type/--parent` exist (#20).

A. Changes the design:

| # | Confirmation | Why triage depends on it | Needs |
|---|---|---|---|
| 1 | Org Settings > Planning > Issue fields present, Priority editable to P1-P5, pinned to Task, Bug, Feature and "Issues without a type" | Priority field versus `P1`-`P5` labels; triage writes it | The user's answer in the UI |
| 2 | `GITHUB_TOKEN` with `issues: write` can write issue type, Priority field value, sub-issues and labels from a called workflow | Decides whether stage 1 needs the App at all (the App is required for PRs and chaining). The `issue-field-values` rows carry `additional-permissions: true`, unread | One run in a sandbox repo with the field present |
| 3 | Anthropic's answer on subscription OAuth for a public project | Which secret the triage input carries (`claude_code_oauth_token` or `anthropic_api_key`); the first run uses an API key if there is no answer | The drafted question, unsent |

B. Confirmed by the first triage run:

| # | Confirmation | What a failure changes |
|---|---|---|
| 4 | `job.workflow_repository` and `job.workflow_sha` populated for a cross-repo called workflow on Free; sparse second checkout works | Prompt lookup falls back to a `ref` input |
| 5 | `vars` passed through caller `with:`; owner check on `github.event.sender.login` | The owners gate moves into the caller's `if:` |
| 6 | `claude-code-action@v1` with `--model claude-haiku-5-5` accepted; the `Bash(gh ...)` allowlist permits the writes; `permission_denials_count` is 0 | Allowlist shape |
| 7 | Result fields and `modelUsage` per model on API key and on OAuth; composite action called cross-repo with a fully qualified `uses:`; summary plus 90-day artifact | Monitoring record fields |
| 8 | `triage` label removed at the end; a second `labeled` while a run is active is cancelled or queued as intended (`concurrency`) | Loop and idempotency design |
| 9 | Org secret and variables visible to a public repo on Free | Where the token lives |

Not a confirmation: whether haiku classifies well is a measured quality question on a small sample
of issues. Closed by reading, not live: the REST payload for `issue-field-values` and `type` on
issue update, read in the next iteration. Probe: one public sandbox repo under `becloud-dev` and one
consumer workflow calling a `triage` reusable workflow in `becloud-dev/workflows`, which needs a
remote for `workflows`; everything the probe writes is public. Items 2 and 4-9 are covered by one run.

### Issue field and issue type write payloads, read 2026-10-11

Sources: `github/rest-api-description` `api.github.com.2026-03-10.json` (raw), `github/docs`
`data/reusables/rest-api/additional-permissions.md` and
`src/github-apps/data/fpt-2026-03-10/server-to-server-permissions.json`.

| Topic | Finding |
|---|---|
| Set a field value | `POST` (add) and `PUT` (replace all existing values) `/repos/{owner}/{repo}/issues/{n}/issue-field-values`, body `{"issue_field_values": [{"field_id": <integer>, "value": ...}]}`, at most 25 items. Single-select takes the option name as a string, which "must match an existing option name"; number takes a number; date an ISO 8601 string. `POST` with an empty array clears all values. Responses 200, 400, 403, 404, 422, 503. 403 without push access. "Creating content too quickly ... may result in secondary rate limiting"; the call triggers notifications |
| Field id | Writes take `field_id` (integer), not the name. `GET /orgs/{org}/issue-fields` returns `id`, `name`, `data_type`, `visibility` and `options` (each with `id`, `name`); its permission key is `issue_fields` (read), server-to-server true, no additional permissions |
| Issue update | `PATCH /repos/{o}/{r}/issues/{n}` accepts `issue_field_values` and `type` in the same body. `type` is a name or an object `{value, rationale, suggest, confidence}`; with `suggest: true` "the change is stored as a pending suggestion for human review rather than applied directly"; `confidence` is `low`, `medium` or `high`. Without push access "type changes are silently dropped" |
| Additional permissions column | "Some endpoints require more than one permission. Other endpoints work with any one permission from a set of permissions", marked with a checkmark; the endpoint page has the detail. Field-value `POST`, `PUT`, `DELETE` carry it and are listed under both `issues` and `pull_requests` |

Implications (inference):

- `GITHUB_TOKEN` is limited to the repository of the workflow and `issue_fields` is not a workflow
  `permissions:` key as far as section 5 recorded; resolving the Priority field id by name probably
  needs an App token with `issue_fields: read`. The id can instead come from a caller variable, set
  once from `gh api orgs/becloud-dev/issue-fields`.
- Triage writes values with `POST`, not `PUT`, so other fields are not replaced.
- The listing under both `issues` and `pull_requests` reads as "either permission suffices", since
  an issue number can be a pull request; not confirmed on the endpoint page.
- `suggest` gives a native review path for an AI-chosen type; its effect (what the owner sees and
  does) is unread.

Unverified: `GITHUB_TOKEN` writing field values (live item 2); whether `issue_fields` can be
requested in a workflow `permissions:` block; what a pending type suggestion looks like and how it
is accepted.

Corrected 2026-10-11: `GITHUB_TOKEN` wrote the field value and the issue type in the first triage
run (see "Live results: first triage run"). `issue_fields` as a `permissions:` key and the
pending-suggestion behaviour stay unverified.

### Live results: org issue fields (2026-10-11)

Source: two screenshots from the user, taken 14:49 and 14:50, and two terminal outputs pasted by
the user (`gh api` run with the user's own login, not `GITHUB_TOKEN`).

| Check | Result |
|---|---|
| Org Settings > Planning > Issue fields (`becloud-dev`) | 4 fields listed: Priority, Start date, Target date, Effort |
| `gh api orgs/becloud-dev/issue-fields --jq '.[] \| [.id,.name,.data_type]'` | Priority `48149712` single_select; Start date `48149713` date; Target date `48149714` date; Effort `48149715` single_select |
| Priority field object, same endpoint | 4 options, GitHub defaults: `84291383` Urgent (`priority` 1, pink), `84291384` High (2, red), `84291385` Medium (3, yellow), `84291386` Low (4, green); every option `description` null; `visibility` `organization_members_only`; `created_at` 2026-10-08. Returned in name order |

Implications (inference):

- `PRIORITY_FIELD_ID` is `48149712`. The list endpoint answers on a Free org, so issue fields
  are present there.
- The user keeps the four default options; no `P1` to `P5`. Values are written by option name,
  so the verdict schema and the prompt use Urgent, High, Medium, Low as returned.
- Rank is in each option's `priority` key (1 to 4); response order is alphabetical.
- The API object carries no pin data; pins to issue types are checked in the UI.
- The criticality description per option lives only in the triage prompt, because the field's
  descriptions are null.

Corrected: "Stage design, round 4 inputs" lists "org issue fields present (needs the account)"
as unverified; the field list above shows them present. The "Live confirmations before triage"
table, item 1, asks for editing to P1-P5; superseded by Round 5 item 9.

Still open: pinning to Task, Bug, Feature and "Issues without a type" (UI); option-count limit
(not tested, no option added); meaning of `organization_members_only` on a public repo.

### Live results: sandbox repo and org secret (2026-10-11)

Source: two screenshots from the user (15:11, 15:13) and read-only `gh` metadata calls (names,
visibility and repository list; no secret value read).

| Check | Result |
|---|---|
| A5 `gh repo create becloud-dev/triage-sandbox --public --description "Consumer of the becloud-dev triage workflow" --clone` | Printed `https://github.com/becloud-dev/triage-sandbox`; no error |
| A6a `gh secret set CLAUDE_CODE_OAUTH_TOKEN --org becloud-dev --repos triage-sandbox`, first attempt | `failed to fetch public key: HTTP 403: You must be an org admin or have the actions secrets fine-grained permission.` and `This API operation needs the "admin:org" scope`; CLI scopes were `delete_repo`, `gist`, `read:org`, `repo`, `workflow` |
| A6a same command after the user's `gh auth refresh -h github.com -s admin:org` | `Set Actions secret CLAUDE_CODE_OAUTH_TOKEN for becloud-dev`; `gh secret list --org becloud-dev` shows `SELECTED`, updated `2026-10-11T18:13:43Z`; the repositories endpoint lists `becloud-dev/triage-sandbox` only |

Implications (inference):

- Writing an organization secret from the CLI needs `admin:org` (or the fine-grained secrets
  permission); a repository secret needs only `repo`.
- The Free plan accepts a public repository in an organization secret's selected list. Whether a
  run in that repository reads it is live item 14, confirmed by the first run.
- The CLI token now carries `admin:org`; removal is `gh auth refresh --remove-scopes admin:org`
  (flag from the `gh` help; the effect on `read:org` is untested).

Still open: A3, A4, A6b, A7 (labels, issue types, Actions setting); item 14 by run.

Corrected 2026-10-11: A4, A6b and A7 are done and item 14 held by outcome; see "Live results:
first triage run". A3 stays open.

### Live results: first triage run (2026-10-11)

Source: `gh` read-only calls with the user's login on `becloud-dev/triage-sandbox` and
`becloud-dev/workflows`; run `38164369843` (event `issues`, `labeled`, started 18:34:16Z), issue
#1; the run-record artifact `run-record-38164369843-1`. The job summary text is not exposed by
the API and was not read.

| Step | Result |
|---|---|
| A6b | Variables `OWNERS` (`bentoluizv`) and `PRIORITY_FIELD_ID` (`48149712`) set by the user; read back |
| A7a | Labels `triage`, `needs-info` created by the user; read back with descriptions |
| A7b | `GET /orgs/becloud-dev/issue-types`: Task `897472419`, Bug `897472420`, Feature `897472421`, all `is_enabled: true` |
| A7c | `GET .../actions/permissions`: `enabled: true`, `allowed_actions: all`, `sha_pinning_required: false` |
| A4 | `gh repo create becloud-dev/workflows --public` printed the URL; main pushed; `gh api .../commits` head equals the local `HEAD` |
| R1 | Caller workflow committed as the first commit of `triage-sandbox` (`0929a1b`) and pushed; `gh workflow list` shows `triage`, active |
| R2-R4 | Issue #1 created, label `triage` applied: run started, 9 steps and post steps `success`, job 35 s |
| Issue after run | Type `Bug`; field `48149712` value `Urgent` (`GET issue-field-values`); one comment with a two-sentence rationale citing the issue text; label `triage` removed |
| Run record | `is_error` false, `num_turns` 4, `duration_ms` 4972, `permission_denials_count` 0, model `claude-haiku-5-5`, `auth` oauth, `total_cost_usd` 0.00467535; `modelUsage` has one model: 1220 input, 699 output, 36945 cache read, 19172 cache creation tokens, `provider` firstParty, `costBasis` list |
| Annotation | `ubuntu-latest` migrates to Ubuntu 26 on 2026-10-19 (notice only) |

Interpretation (inference):

- `GITHUB_TOKEN` with `issues: write` wrote the issue type (`PATCH ... -f type=<name>`) and a
  Priority option name (`POST issue-field-values`, body `{field_id, value}`) in a called
  workflow, and the read-back step, which fails the job on a mismatch, passed. Live item 2 is
  confirmed.
- The prompt checkout, the owner gate, `vars` through `with:`, `--model claude-haiku-5-5`, the
  `Bash(gh ...)` allowlist, `structured_output`, the composite action at `@main` and the
  artifact upload each ran without error; items 4-9 are confirmed by outcome, not by reading the
  value of `job.workflow_sha` (summary not read).
- The Classify step ran with the organization secret in a public repository on Free; item 14
  holds by outcome.
- `total_cost_usd` on OAuth is populated; `costBasis: list` suggests a list-price figure, not a
  charge. What the subscription is charged is unverified.
- One triage costs about half a cent at list price, mostly cache tokens.

Unverified or not exercised: `needs-info`, the format fix and the split; the haiku verdict
quality on real issues; A3 (the Anthropic reply); the "Workflow identity" block of the job
summary. Concurrency is covered in the next subsection.

### Live results: concurrency (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after one sandbox write sequence on
the user's go: issue #2 created; label `triage` added at 18:47:21Z, added again at about
18:47:28Z, removed and re-added by 18:47:33Z. Runs `38165283016` (A) and `38165294100` (B). This
settles item 8 of section B in "Live confirmations before triage"; the earlier citation "Round 5
item 13" does not exist (Round 5 has items 1 to 10) and is corrected.

| Observation | Value |
|---|---|
| Add events sent / runs created for issue #2 | 3 / 2 |
| Run A | created 18:47:25Z, job 18:47:28Z to 18:48:16Z, all steps `success` |
| Run B | created 18:47:35Z, `pending` while A was `in_progress`; job 18:48:19Z to 18:48:51Z, all steps `success` |
| Issue after both runs | type `Bug`, Priority `High`, labels none, 2 comments (18:48:10Z, 18:48:46Z) |

Interpretation (inference):

- Job-level `concurrency` (group `triage-<issue>`, `cancel-in-progress: false`) on a job that
  calls a reusable workflow serializes runs: B waited `pending` and started 3 s after A ended;
  nothing was cancelled. The docs do not mention this case; the live run does.
- Adding a label already present fired no `labeled` event: 3 adds produced 2 runs.
- B's "Remove the start label" step succeeded although A had most likely removed the label
  already (label state at that instant not read), so `gh issue edit --remove-label` on an absent
  label does not fail the step.
- A queued run is a full second run: B repeated the classification and posted a second comment
  with the same type and priority and different wording. Two quick applications cost two haiku
  calls and two comments.

Unverified or not exercised: three events in a row (the docs say the middle pending run is
cancelled); which docs variant (`queue: single|max`, flag `actions-nga`) applies on Free; whether
a duplicate comment matters to the owner (a design question, not a defect found).
