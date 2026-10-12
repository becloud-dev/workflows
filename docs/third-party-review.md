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

### Release tooling, stage 5 read (2026-10-12)

Sources: raw `googleapis/release-please` v17.11.2 (`src/manifest.ts`, `src/commit.ts`,
`src/strategies/base.ts`, `src/versioning-strategies/default.ts`, README), raw
`googleapis/release-please-action` `main` (`action.yml`, README), raw `github/docs`
(`events-that-trigger-workflows.md`, the `pull_request` activity types reusable).

| Topic | Finding |
|---|---|
| Releasable units | README: "feat", "fix" and "deps". Code: no type filter on the path read; every parsed commit reaches the strategy, and a PR is skipped only at zero parsed commits (`base.ts:286`). Other types bump patch (`default.ts:104`) |
| Unparsed commits | Dropped with a debug log (`commit.ts:442`); a non-conventional squash title never counts |
| Tagging | Considers merged PRs carrying all of `autorelease: pending`; then swaps to `autorelease: tagged` (`manifest.ts:1155`, `1307`) |
| Token | `token` input is a string defaulting to `github.token`; `GITHUB_TOKEN` tags and PRs start no workflows (README); `pull_request` runs on a `GITHUB_TOKEN` PR need approval, and other events start no run except `workflow_dispatch` and `repository_dispatch` (events page) |
| Version | Latest `release-please-action` is `v5.0.0` (2026-04-22), tag `v5` exists, `node24`; Patagonia uses `v4` |
| Gate events | `pull_request`: `labeled`, `unlabeled`, `synchronize`; `issues`: `closed`, `reopened`, `labeled`, `unlabeled`; `issue_comment` covers PRs (`github.event.issue.pull_request`); no `pull_request` run on a PR with a merge conflict |

Correction: the "Implications" bullet above that says `perf`, `refactor` and `revert` may not
produce a release PR rests on the README list. The code read shows no such filter; the README
claim and the code disagree, and neither is run.

Implications (inference):

- A "zero open `release-blocker`" check on the release PR is not re-run when a blocker issue
  closes (an `issues` event, not `pull_request`). The gate is either evaluated at deploy time, or
  an `issues`-triggered job re-evaluates it and writes a status to the PR head.
- The release PR needs an App token (checks run, owner can approve); the action takes any token
  string.
- A workflow must not strip `autorelease: pending` from a release PR before merge.
- A consumer outside `becloud-dev` supplies its own credential through the caller's `secrets:`;
  the org secret is readable only by repositories in the organization it is scoped to.

Decision (user, 2026-10-12): the `release-blocker` gate is evaluated at deploy or merge time (a
job that fails while a `release-blocker` issue is open), not by an `issues`-triggered job that
writes a status to the release PR. Credential stays an org-level secret inside `becloud-dev`
(Round 3 item 1 unchanged).

Unverified: types that alone create a release PR (needs a run); an App installation token
starting runs for release PR events (documented for `GITHUB_TOKEN` only); whether the changelog
layer or a plugin drops types before this path (not read).

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

### Live results: needs_info (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after the user's sandbox writes:
issues #3 ("The app is broken") and #4 (accented search) created, label `triage` applied to
both. Runs `38167016110` (#3) and `38167018047` (#4), both `success`; run-record artifacts
`run-record-38167016110-1` and `run-record-38167018047-1` downloaded and read.

| Observation | #3 | #4 |
|---|---|---|
| Run start / end | 19:12:15Z / about 19:12:52Z | 19:12:16Z / about 19:12:54Z |
| Issue after run | label `needs-info`; type none; no Priority value; label `triage` removed | type `Bug`; Priority `High`; no labels |
| Comment | 5 numbered questions and a reason line | two-sentence rationale |
| Run record | `num_turns` 4, 937 output tokens, 19622 cache creation, `total_cost_usd` 0.00489 | `num_turns` 4, 659 output tokens, 5802 cache creation, `total_cost_usd` 0.00212 |
| Common | model `claude-haiku-5-5`, `auth` oauth, `is_error` false, `permission_denials_count` 0, `costBasis` list | same |

Interpretation (inference):

- The `needs_info` outcome skips the type and Priority writes and still removes the start
  label, as designed.
- Runs for different issues are not serialized: the two jobs overlapped.
- `costBasis: list` is present on OAuth in both records, so `total_cost_usd` is a list-price
  figure; what the subscription is charged is unverified. The 2.3x cost difference tracks
  cache-creation tokens; its cause was not read.
- #3 received exactly 5 questions, the cap, for a four-word issue.

Unverified or not exercised: the value of `job.workflow_sha` and the job summary text; the
haiku verdict quality on real issues; the format fix and the split; A3 (the Anthropic reply).

### Live results: format fix (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after the user's writes: template
`.github/ISSUE_TEMPLATE/bug.md` committed (`546c224`) and pushed together with `workflows`
`fc02671`; issue #5 ("Export button does nothing on the reports page", free-form body) created
and label `triage` applied. Run `38171318935`, `success`, every step `success`; run-record
artifact `run-record-38171318935-1` read; edit history read through GraphQL
`userContentEdits`.

| Observation | Value |
|---|---|
| Issue after run | type `Bug`; Priority `Urgent`; no labels (`triage` removed) |
| Body | reflowed under `## What happened`, `## Expected behaviour`, `## Steps to reproduce`; wording kept, one sentence moved |
| Comment | one comment: rationale, then `Format fix: <one line>` |
| Edit history | two entries at 20:14:32Z: the original body (editor `bentoluizv`) and the new one (editor `github-actions`) |
| Run record | `num_turns` 5, `total_cost_usd` 0.00569, `permission_denials_count` 0, model `claude-haiku-5-5`, `costBasis` list |

Interpretation (inference):

- The `Bash(ls .github/ISSUE_TEMPLATE:*)` allowlist entry matched and the relative path resolved
  in the caller checkout: the model listed and read the template (the extra turn).
- The read-back step passed, so the body read back equal after any GitHub normalization; the
  step summary line itself was not read.
- Edits made through the API are kept in the edit history, so the original body is
  recoverable. Visibility of that history to a viewer without write access is unverified.
- The model followed "reformat only": nothing was added or dropped.

Quality observations (one sample, recorded as open items, then acted on below):

- Priority `Urgent` rested on "no workaround is mentioned": absence of a mention was read as
  absence of a workaround.
- The rationale named evidence for the priority and left the type implicit, although the prompt
  asked for evidence on both.

Decision (user, 2026-10-11): priority is judged by operational impact on the business: a
business-critical flow stopped or corrupted (purchase, payment, sign-in, submission, core
transaction, data loss or exposure) is `Urgent`; a broken control outside a critical flow is
not, however visible. A stated workaround moves a stopped critical flow to `High`; silence about
a workaround moves nothing. The comment carries separate evidence for the type and the priority,
enforced by the prompt and by the workflow (a missing field aborts before any write).
Criticality is inferred from the issue text; an optional per-repo file naming the critical flows
is a later increment.

Unverified or not exercised: visibility of the edit history without write access; behaviour
with several templates or a `.yml` form; the split; three events in a row; the value of
`job.workflow_sha` and the job summary text; A3 (the Anthropic reply).

### Live results: priority by business impact (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after `workflows` `856e74e` was
pushed to `main`; issue #6 ("Print preview icon on the reports page does nothing", free-form
body, a stated workaround) created and label `triage` applied by the user's go. Run
`38172402379`, `success`; run-record artifact read; run log read (full tool output is hidden by
the action).

| Observation | Value |
|---|---|
| Issue after run | type `Bug`; Priority `Medium`; no labels (`triage` removed) |
| Comment | impact sentence, `Type: Bug. <evidence>`, `Priority: Medium. <evidence>`, `Format fix: <one line>` |
| Priority evidence | names the flow, states it is not a purchase, payment, sign-in, submission or data loss, cites the stated workaround |
| Body | text under `## What happened`; `## Expected behaviour` empty; the environment line under `## Steps to reproduce` |
| Run record | `num_turns` 7, `total_cost_usd` 0.00636, 2656 output tokens, `permission_denials_count` 1, model `claude-haiku-5-5` |

Interpretation (inference):

- A visible but non-critical broken control is not `Urgent`: the business-impact rule held on
  the case opposite to issue #5, and type and priority carry separate evidence.
- The enforcement path that aborts on a missing evidence field was exercised offline with `jq`
  (rc 4 on a missing or empty field), not yet by a live run.
- `priority_evidence` ran five sentences, arguing why `High` did not apply; the prompt asked
  for the flow, its criticality and the workaround.
- The template has no environment heading, so "closest heading" placed the environment line
  under `## Steps to reproduce`. Nothing was lost; the placement is slightly off.
- One permission denial occurred (earlier runs: 0), with 7 turns against 5. The denied call is
  not in the log. A guess (a command outside the allowlist) is unverified.

Decisions (user, 2026-10-11): leave the denied call open and watch the count on later runs
(`show_full_output` would print issue text in a public log); cap `priority_evidence` at two
sentences; keep "closest heading" for text that fits no template heading.

Unverified or not exercised: the denied tool call; the live abort path on a missing evidence
field; the `Urgent` case on a stopped critical flow with no stated workaround; the split; A3.

### Live results: urgent case (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after `workflows` `92bd555` was
pushed to `main`; issue #7 ("Checkout page rejects every payment with \"Something went
wrong\"", free-form body, no workaround) created and label `triage` applied by the user's go.
Run `38172779881`, `success`; run-record artifact read.

| Observation | Value |
|---|---|
| Issue after run | type `Bug`; Priority `Urgent`; no labels (`triage` removed) |
| Comment | impact sentence, `Type: Bug. <quote>`, `Priority: Urgent. <two sentences>`, `Format fix: <one line>` |
| Body | description under `### What happened`; empty `### Expected behaviour` and `### Steps to reproduce` appended |
| Run record | `num_turns` 6, `total_cost_usd` 0.00308, 1527 output tokens, `permission_denials_count` 0 |

Interpretation (inference):

- The business-impact rule holds at both ends: `Medium` for a non-critical control with a stated
  workaround (#6), `Urgent` for a stopped checkout with none (#7); silence about a workaround
  was reported as "No workaround is stated" and did not change the outcome.
- The two-sentence cap on `priority_evidence` held.
- The denial seen in run `38172402379` did not repeat; its cause stays unexplained.
- The template `bug.md` writes `##` headings; #5 and #6 got `##` and #7 got `###`, the level
  the prompt names only for `.yml` forms. One sample of a fidelity slip.
- The model appended the template's empty headings for sections the issue did not fill; no
  content was invented.

Decisions (user, 2026-10-11): the prompt requires each template heading exactly as written,
including its level; empty template headings are accepted as the template's format.

### Sub-issues REST API (read 2026-10-11)

Source: raw `github/rest-api-description` `api.github.com.json` (`main`) and `gh issue create
--help` (gh 2.102.0 locally).

| Topic | Finding |
|---|---|
| List | `GET /repos/{owner}/{repo}/issues/{issue_number}/sub_issues`; parameters `per_page` (max 100, default 30) and `page`; responses 200, 404, 410 |
| Add | `POST` the same path; body `sub_issue_id` (integer, required), `replace_parent` (boolean); "must belong to the same repository owner as the parent issue"; responses 201, 403, 404, 410, 422; "Creating content too quickly ... may result in secondary rate limiting" |
| Summary field | issue object carries `sub_issues_summary` (`total`, `completed`, `percent_completed`, all required); sandbox #1 returns `{"completed":0,"percent_completed":0,"total":0}` |
| `gh issue create` | `--parent <number or URL>` and `--type <name>` present in 2.102.0 |

Interpretation (inference): the split guard can read `sub_issues_summary.total` from
`GET .../issues/{n}` without paging, so it does not depend on the `gh` version on the runner.
Whether `GITHUB_TOKEN` with `issues: write` may add a sub-issue is unverified until a live run.

### Live results: split (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after `workflows` `98054ea`, then
`1e6362e`, were pushed to `main`; issues #8 and #12 created and label `triage` applied by the
user's go, and `triage` re-applied to #8. Runs `38174294323` (#8, `failure`), `38174522614`
(#8 again, `success`), `38174777474` (#12, `success`); run-record artifacts read; the failed
step's log read.

| Run | Parent after | Children | Run record |
|---|---|---|---|
| `38174294323` (#8, three changes) | `Feature`, `Medium`; comment ends `Split into: #9 #10 #11`; no format fix | #9 Feature, #10 Bug, #11 Task; parent #8, no labels, no Priority, bodies end `Split from #8` with a "Done when" line | `num_turns` 5, `total_cost_usd` 0.00590, 0 denials; "Apply the verdict" `failure` after the comment was posted |
| `38174522614` (#8 re-labelled) | one more comment, no `Split into` line | still #9 to #11, total 3 | `num_turns` 5, `total_cost_usd` 0.00248, 0 denials; `success` |
| `38174777474` (#12, two changes) | `Feature`, `Medium`; comment ends `Split into: #13 #14` | #13 and #14 Features; parent #12, no labels | `num_turns` 4, `total_cost_usd` 0.00240, 0 denials; `success` |

Interpretation (inference):

- `GITHUB_TOKEN` with `issues: write` created typed issues and set their parent; the runner's
  `gh` handled `--parent` and `--type`; 3 sequential creates showed no secondary rate limit.
- The first run failed at the final status check, after the three children and the comment
  existed: the immediate read-back of `sub_issues_summary.total` is the only remaining path to
  that failure. The count read 3 afterwards (REST and the list). The cause is most likely a lag
  in the derived count; the read value at that instant was not captured.
- With a bounded poll (5 reads, 2 s apart) run `38174777474` passed. This is consistent with the
  lag but does not prove it; the read count is in the step summary, which the API does not
  expose.
- The guard worked: with 3 sub-issues present, the re-applied label created no children and
  posted a second triage comment.
- The parent of a mixed issue was typed `Feature` while its evidence said the parent is mixed.

Unverified or not exercised: whether the poll needed more than one read; that the model returned
`children` again on the guard run (it was skipped either way); a partial-failure path of the
creation loop; a split on an issue with a `.yml` form or several templates; three events in a
row; A3 (the Anthropic reply).

### Third-party action pins (read 2026-10-11)

Source: `gh api` read-only calls on `repos/{owner}/{repo}/git/ref/tags/...`,
`git/matching-refs/tags/...` and `git/tags/{sha}` for the three actions; `triage.yml` and
`.github/actions/record-run/action.yml` at `workflows` `a07689a`; rule `build-and-maintenance`
line 17.

| Use in `triage.yml` | Tag | Numbered tag | Commit |
|---|---|---|---|
| `actions/checkout@v7` (lines 30, 35) | `v7` is a lightweight tag | `v7.0.1` | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/upload-artifact@v7` (line 195) | `v7` is a lightweight tag | `v7.0.2` | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` |
| `anthropics/claude-code-action@v1` (line 61) | `v1` is an annotated tag; tag object `3526ba01...` | `v1.0.248` (newest numbered tag; its commit equals the `v1` commit) | `1d6de8cb0c237e7c15e9e1bdf973826ebae490cc` |
| `becloud-dev/workflows/.github/actions/record-run@main` (line 185) | branch ref, first-party | not applicable | head of `main` at run time |

Interpretation (inference):

- A pin to the commit SHA of an annotated tag needs the dereferenced commit, not the tag-object
  SHA.
- `record-run` is bash and `jq` only, so it holds no third-party action to pin.
- Version skew: the prompts are read at `job.workflow_sha`, the composite at `main` head. A
  caller on an older workflow SHA runs the current `record-run`. Pinning the three actions does
  not change this. Candidate fix: add `.github/actions` to the sparse checkout and use a local
  path to the composite.

Unverified: that a local-path `uses:` into a sparse-checked-out second repository works with
`persist-credentials: false`; to be read in the GitHub docs before any edit. Not read: the
release notes between the pinned numbered tags and the previous floating resolution.

### Self-repository action reference (read 2026-10-11)

Source: raw `github/docs` `main`, `content/actions/reference/workflows-and-actions/workflow-syntax.md`
(section "Using an action in the same repository as the workflow at the running commit") and
`content/actions/how-tos/write-workflows/choose-what-workflows-do/find-and-customize-actions.md`;
last change to the first file 2026-10-01.

| Topic | Finding |
|---|---|
| Syntax | `uses: $/path/to/action`; "resolves to that repository at the running commit (the same SHA as the running workflow or action)"; no checkout needed |
| Ref | must not carry an `@{ref}` suffix; "the ref is always the commit the running workflow or action is using" |
| Called workflow | "`$/` always resolves against the repository of the file it appears in, not the repository that called it"; a reusable workflow called from another repository resolves to the called workflow's repository |
| `./path` | "resolves against the runner's workspace"; requires a checkout; docs: "For most cases, use the `$/` syntax" |
| Availability | "not available in GitHub Enterprise Server"; no preview or version note on the page |

Interpretation (inference): replacing `becloud-dev/workflows/.github/actions/record-run@main`
with `$/.github/actions/record-run` makes the composite come from the same commit as
`job.workflow_sha`, which removes the version skew recorded above. The sparse-checkout candidate
there is superseded: the `./` form resolves against the caller's workspace, and `$/` needs no
checkout.

Unverified: that `$/` resolves as documented inside a reusable workflow on a live run. An
unresolvable `uses` fails at job setup, before any step, so a failure would fail the whole job,
not only the record step. The first live run on the sandbox is the test; callers use `@main`, so
a push makes it live for every caller (only the sandbox today).

### Live results: pins and the self-repository reference (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after `workflows` `80ccb02` was
pushed to `main`; the `triage` label applied to #8 by the user's go; run `38175350506`
(`success`); run log and run-record artifact read.

| Check | Finding |
|---|---|
| Workflow commit | `Uses: becloud-dev/workflows/.github/workflows/triage.yml@refs/heads/main (80ccb02dbfa88c30febba91e0753bb2ab962ebef)` |
| Pinned actions | log shows `actions/checkout`, `anthropics/claude-code-action` and `actions/upload-artifact` downloaded at the pinned SHAs |
| `record-run` | `Run becloud-dev/workflows/.github/actions/record-run@80ccb02dbfa88c30febba91e0753bb2ab962ebef`; step `success` |
| Guard on #8 | `sub_issues_summary.total` stays 3; one more triage comment; start label removed |
| Run record | `claude-haiku-5-5`, `oauth`, `is_error` false, `num_turns` 5, `total_cost_usd` 0.0021553, 0 denials |

Interpretation (inference): `$/.github/actions/record-run` resolved to the same commit as the
called workflow, so the version skew recorded above is gone for this run. The pins did not
change behaviour.

Also read: the log downloads `oven-sh/setup-bun@0c5077e51419868618aeaa5fe8019c62421857d6`,
which is not in `triage.yml`; it is presumably pulled by `claude-code-action`. Its source was
not read. The parent of the mixed issue was typed `Task` here and `Feature` in earlier runs.

Unverified or not exercised: `$/` from a caller on a SHA other than `main` head; zizmor on the
workflow; a Dependabot config; the `setup-bun` pin inside `claude-code-action`.

### zizmor on the workflows (read and run 2026-10-11)

Source: raw `zizmorcore/zizmor` `docs/usage.md` and `docs/audits.md` (`main`); `zizmor` v1.30.1
(`gh api .../releases/latest`, published 2026-09-09) run through `uvx` with `--offline` on
`.github` at `workflows` `3b4ad1f`.

| Run | Result |
|---|---|
| Default persona (`regular`) | no findings, "3 suppressed" |
| `--persona=auditor` | 3 findings, all in `triage.yml`; `record-run/action.yml` has none |

| Audit | Severity | Location | Finding |
|---|---|---|---|
| `excessive-permissions` | medium (confidence Medium) | `triage.yml:1` | "default permissions used due to no permissions: block"; docs remedy: `permissions: {}` at workflow level |
| `undocumented-permissions` | low | `triage.yml:27` | `issues: write` has no explanatory comment |
| `anonymous-definition` | info | `triage.yml:21` | job `triage` has no `name:` |

Interpretation (inference):

- The 3 suppressed results are the 3 auditor-persona findings: the repo has no `zizmor: ignore`
  comment and no zizmor config file, and the docs say the default persona drops auditor-level
  results.
- The job sets `contents: read` and `issues: write`, so `excessive-permissions` is about the
  missing workflow-level default, not an over-grant today.

Unverified: `impostor-commit`, `known-vulnerable-actions` and `stale-action-refs` are marked
"not working offline" in `audits.md`, so they did not run; they need a token and online mode.
The `uvx` package was taken from PyPI at the pinned version; its provenance beyond the version
matching the GitHub release was not checked.

### Live results: default permissions and job name (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after `workflows` `d31ebc1` was
pushed to `main`; the `triage` label applied to #8 by the user's go; run `38175941033`
(`success`); run log read.

| Check | Finding |
|---|---|
| Workflow commit | `triage.yml@refs/heads/main (d31ebc161e0a32f6b614dc879bd9aac3b7bcbe59)` |
| Token | log "GITHUB_TOKEN Permissions": `Contents: read`, `Issues: write`, `Metadata: read` |
| Job | `triage / Triage`, all steps `success`; sub-issues on #8 stay 3, one more comment |

Interpretation (inference): the workflow-level `permissions: {}` did not reduce what the job
holds. The job check name changed from `triage / triage` to `triage / Triage`; a caller with
that name as a required check would need updating (not checked; only the sandbox calls the
workflow today).

Unverified: zizmor online audits; a caller with branch protection on the old check name.

### zizmor in CI: action and exit codes (read 2026-10-11)

Source: raw `zizmorcore/zizmor` `docs/integrations.md` and `docs/usage.md` (`main`); raw
`zizmorcore/zizmor-action` `action.yml`, `action.sh` and `support/versions` at
`cc914d7f3750a2d13d75c7f184a1060aa0e9d482` (`v0.6.4`, latest release); `gh api
.../git/ref/tags/v0.6.4`; `gh repo view becloud-dev/workflows`. A first read without a ref came
from the default branch head (4 commits ahead, unreleased) and was discarded.

| Topic | Finding |
|---|---|
| Recommended integration | `zizmorcore/zizmor-action`; the docs example pins `@cc914d7f...# v0.6.4`, a lightweight tag that resolves to the same commit |
| Install path at `v0.6.4` | `docker pull ghcr.io/zizmorcore/zizmor:<version>@sha256:<digest>` and `docker run` with the workspace mounted read-only; digests come from `support/versions` |
| Version | input `version` defaults to `latest`; `1.30.1` is in `support/versions` with digest `sha256:a2eb396d...`, equal to `latest`; an unlisted version fails with "Unknown version" |
| Online audits | input `online-audits` defaults `true`; `token` defaults to `github.token` |
| Result mode | `advanced-security` defaults `true` (SARIF through `upload-sarif`, needs `security-events: write`); `annotations` is mutually exclusive with it |
| Gate | SARIF mode exits 0 on findings; with both off the format is plain and the container's exit code is returned, 11 to 14 by highest severity (informational 11), which fails the job |
| Permissions | no special token permission for a public repo; `contents: read` for private repos; `security-events: write` only for SARIF |
| Repository | `becloud-dev/workflows` is `PUBLIC` |

Interpretation (inference): the action with `advanced-security: false` and no annotations is
the one form that fails a PR check on findings. Informational findings fail it too, so a
severity floor is a decision. The `upload-sarif` step is conditional and does not run in this
mode. The pinned release needs Docker on the runner and pulls from `ghcr.io`; unreleased `main`
drops Docker, so a later bump changes the install path.

Unverified: whether `--format=github` keeps exit codes 11 and above (the docs list only
`--format=sarif` and `--no-exit-codes` as removing them); that code scanning is enabled on the
repository; Docker and `ghcr.io` access on `ubuntu-latest` (not read; a live PR run tests it).

### Decision: stage 1 closed (user, 2026-10-11)

Stage 1 (triage) is closed on the sandbox at `workflows` `fe530b9`. Scope as designed in
Round 5 items 1 to 9, all implemented and observed live (runs listed in the "Live results"
sections above, plus `38175350506` and `38175941033` for the pins, `$/` record-run and default
permissions). Tests stay on `becloud-dev/triage-sandbox`; the full flow runs on a real project
later. Work continues on the next stages of section 1.

Gaps carried forward (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| Owner gate rejecting a non-owner never exercised live; only the `OWNERS` variable was read back (A6b) | security gate on who can start a run | a label applied by a second GitHub account or an allowed bot, then read the run (`if:` false, no job) |
| Partial failure of the child-creation loop | a split could leave some children and no read-back | force one `gh issue create` to fail in the sandbox |
| Three events in a row on one issue | concurrency and guard under bursts | apply, remove and re-apply `triage` quickly; read the runs |
| Issue form (`.yml`) or several templates | the format fix and template headings were tried on one markdown template only | a `.yml` form and a second template in the sandbox |
| Quality on real issues | verdicts were checked only on issues written for the test | run on a real project later, as decided |
| `suggest` (type) and Projects v2 | out of stage 1 by decision (Round 5 item 4) | needed only if the decision changes |
| A3: Anthropic reply on subscription OAuth for a public project | decides whether this authentication stays | the user reports the reply; then `gh auth refresh --remove-scopes admin:org`, whose effect on `read:org` is untested |
| Cause of the one permission denial in run `38172402379`; whether the poll needed more than one read; the job summary text; what OAuth is charged (`costBasis: list`); `gh` on the Ubuntu 26 runner (migration 2026-10-19) | unread facts, none blocks the flow | read when the source is reachable |

Not part of stage 1: issue #1 and PR #2 (zizmor in CI) are parked; the check ran green on the
branch (run `38176419903`) and nothing is merged.

### Live results: backlog planner, stage 2a (2026-10-11)

Files: `.github/workflows/planner-backlog.yml` (`9515b68`, fix `83628bb`),
`prompts/planner-backlog.md` (`0736640`); caller `triage-sandbox` `af45e53`. Trigger
`workflow_dispatch`; one haiku call; `Read` only; job `issues: read`; report in the job summary
and the artifact `planner-backlog-<run>-<attempt>`.

| Run | Result |
|---|---|
| `38177471382` | failed in 9s at "Build the backlog input", exit 3, before the model call. jq: `syntax error, unexpected '>', expecting '}'` at `truncated: (...) > 100`, an unparenthesised comparison as an object value. The runner image `ubuntu-24.04` has jq `1.7.1-3ubuntu0.24.04.2` (raw `actions/runner-images` `Ubuntu2404-Readme.md`); the local test had run jq 1.8.1, which accepted the line. The run record and artifact steps still ran, and `$/` resolved to `becloud-dev/workflows/.github/actions/record-run@0736640` |
| `38177571900` | success in 51s after `83628bb`. Input: `total` 13, `truncated` false, ranked `[1,5,7,2,4,6,8,12]`, unprioritised `[9,10,11,13,14]` (equal to the count computed from the baseline). Validate passed. Record: haiku, 3 turns, 24s, `total_cost_usd` 0.00715 (`costBasis: list`), `permission_denials_count` 0, `is_error` false |

Output of `38177571900`:

- Order, tiers kept: `#7, #1, #5` (Urgent), `#2, #4` (High), `#8, #12, #6` (Medium); inside Urgent
  the model moved `#7` ahead of the older `#1` and `#5`.
- `categorize`: empty. `gaps`: one, `#5` `duplicate` of `#2` (same title, same symptom).
- All 12 quoted strings in `order[].reason` and `gaps[].evidence` appear verbatim in the issue
  titles or bodies (script check).
- Issues #1 to #14 compared before and after on type, Priority, labels, milestone, comment count,
  `updated_at` and body length: identical.

Interpretation (inference):

- The path caller, reusable workflow, prompt checkout, `Read`, structured output, validation and
  artifact works end to end. It settles that `Read` opens `.planner/backlog.json`, that the owner
  gate passes under `workflow_dispatch` through `workflow_call`, and that `$/` resolves from a
  caller on `@main`.
- `#5` (Urgent) is a duplicate of `#2` (High) and the report did not say so; the prompt gave no
  place for it. The rule added after this run asks the model to state both priorities in the
  `duplicate` evidence.

Bug class: a check run on a different tool version than production (local jq 1.8.1, runner
1.7.1). The check that would have caught it is running the `run:` blocks with the runner
image's jq, or a CI step that pins the jq used by the local test.

Unverified: the `categorize` path (no miscategorized issue on the sandbox; the empty result
exercises nothing); the build step on jq 1.7.1 outside the runner; pagination past 100 issues
live; the abort of the validate step on a bad model `order` on the runner (tested only on jq);
`sub_issues` use by the model; order quality on real issues.

Retest after `65ad6c6` (the duplicate rule), run `38177887110`, `workflows` `7c4e9fb`: success;
4 turns, 25s, `total_cost_usd` 0.00389, `permission_denials_count` 0. Same input and same order
as `38177571900`. The `#5` gap evidence now reads: "Priorities differ: #2 is High and #5 is
Urgent; neither was changed." The two creation times cited match the input, and the 19 quoted
strings appear verbatim in the issue text. Issues #1 to #14 identical to the baseline. Not asked
for by the prompt: each `reason` begins with the tier name. One run: the rule fires, its
reliability is not measured. `categorize` is still empty.

### Decision: stage 2a closed (user, 2026-10-11)

Stage 2a is closed on the sandbox at `workflows` `7c4e9fb`, scope as in Round 4 item 1 and
the stage 2a decisions above. Tests stay on `becloud-dev/triage-sandbox`; the quality of the
order on real issues is checked when the full flow runs on a real project. Work continues with
stage 2b.

Gaps carried forward (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| `categorize` path never exercised | an empty result on this data proves nothing about type review | one deliberately miscategorized issue in the sandbox, then a dispatch |
| No age or `stale` rule | the model has no clock; an old issue is not flagged | `generated_at` in `backlog.json` and a threshold chosen by the user |
| Build step on jq 1.7.1 outside the runner | the one failure of this stage came from a jq version mismatch | run the `run:` blocks with jq 1.7.1, or accept the runner as the only test |
| Pagination past 100 issues and the cap, live | the cap and `--paginate --slurp` ran only on a fixture | a sandbox with more than 100 open issues, or a fixture-only acceptance |
| Validate abort on a bad model `order`, on the runner | the `jq` was tested locally only | a forced bad order in a sandbox run |
| `sub_issues` use by the model; order quality on real issues | verdicts were read on issues written for the test | run on a real project later, as decided |

### Stage 2b design inputs, read 2026-10-11

Sources: docs.github.com REST pages for repository tags, milestones and update an issue; raw
`github/docs` `workflow-syntax.md` (`on.workflow_call.inputs`, `on.workflow_dispatch.inputs`,
`jobs.<job_id>.with`); live read-only `gh api` on `becloud-dev/triage-sandbox`.

| Topic | Finding |
|---|---|
| Repository tags | `GET /repos/{o}/{r}/tags`: `per_page` max 100, default 30; sort order not stated |
| Milestones | create and update take `title`, `state` (`open`, `closed`), `description`, `due_on` (`YYYY-MM-DDTHH:MM:SSZ`); list takes `state` (`open`, `closed`, `all`), `per_page` max 100; the response carries `number` and `open_issues` |
| Issue milestone | `PATCH issues/{n}` `milestone` is an integer number, `null` clears it; the change needs push access and is silently dropped without it |
| Workflow inputs | `boolean`, `number`, `string` for `workflow_call` and `workflow_dispatch`; booleans stay Booleans in the `inputs` context; inputs passed with `jobs.<id>.with` must match the called workflow's input specifications |
| Sandbox, live | 14 open issues, 0 milestones, 0 tags; types: Bug 7 (#1, #2, #4, #5, #6, #7, #10), Feature 5 (#8, #9, #12, #13, #14), Task 1 (#11), none 1 (#3) |

Implications (inference):

- Tag order is unspecified, so the version scan paginates and sorts by version in jq.
- Open Bug share on the sandbox is 7/12 = 0.58, so the default `bug_budget` of 0.30 fires the
  hold on the first run; a no-hold test needs `bug_budget` of 0.7 or more.
- With 0 milestones and 0 tags only the `v0.1.0` fallback of the title rule runs live; the
  next-minor branch is fixture-only.
- The caller sets `release_days`, `max_issues`, `bug_budget` and `max_releases` as literals in
  `with:`; only `apply` comes from the dispatch input, so `vars` strings are not coerced.

Unverified: a dispatch boolean passed through `with:` to a called boolean input (the docs text
implies it; live probe planned); the local jq is 1.8.1, the runner's is 1.7.1.

### Decision: stage 2b design (user, 2026-10-11)

1. Input scope as stage 2a: open, no PR, no milestone, no `needs-info`, Priority set; cap 100 by
   tier; unprioritised issues are listed and never assigned.
2. Error budget: open `Bug` / (open `Bug` + open `Feature`), repo-wide, `Task` excluded,
   computed in shell. Above `bug_budget` only Bugs are planned and Features go to `held`; the
   shell enforces it in validate, the model does not judge saturation.
3. ETA: shell sets `due_on` to today 00:00:00Z plus k times `release_days` for the k-th new
   milestone; the model groups and gives a theme, it estimates no time.
4. Write gate: dispatch input `apply`, default false (report only); true creates milestones and
   assigns issues.
5. Title: next minor above the highest `vX.Y.Z` found by the shell, `v0.1.0` if none; the theme
   goes in the milestone description.
6. The model may assign issues into existing open milestones while `open_issues` is below
   `max_issues`; it never edits them.
7. Defaults: `release_days` 14, `max_issues` 8, `bug_budget` 0.30, `max_releases` 3.

### Local check: roadmap planner on jq 1.7.1 (2026-10-11)

Method: the `run:` blocks of `.github/workflows/planner-roadmap.yml` at `e5ff873` extracted and
run unchanged against fixtures, `gh` stubbed. jq: upstream `jq-linux-amd64` 1.7.1, SHA-256
matched the release `sha256sum.txt`. Fixtures: 10 issues (5 Bug, 3 Feature, 1 Task, 1 PR), one
open milestone with 5 open issues, tags `v0.2.0`, `v0.3.1`, `latest`. Scratchpad only, not kept.

| Step | Result |
|---|---|
| Build | 7 candidates, 6 ranked by tier then age, 1 unprioritised; `needs-info`, milestoned and PR items excluded; share 0.625; `next_minor` `[0,4,0]` from the tag `v0.3.1`; capacity 3 on the existing milestone |
| Validate | 2 valid plans pass; 10 rejected plans exit 1 (missing, duplicate and unknown issue, 4 new milestones, over capacity, target not open, held without hold, Feature planned, Feature unheld, non-Feature held) |
| Apply | new milestones titled `v0.4.0`, `v0.5.0`, ~~due today + 14 and + 28 days~~ (due dates unverified: the local `date` is uutils 0.10.0, not GNU; see "Live results: roadmap planner apply run"); existing target takes PATCH only; a dropped PATCH aborts on the read-back with exit 1 |
| Report | sections render from `plan.json` and the input |

Earlier run on `ce96acf`: the build failed on the label filter (`.name` read on mapped label
strings); fixed in `e5ff873`.

Inference: with `apply` true, the report step still runs after a failed validate or apply and its
header reads "applied". Not exercised on a failure path; the fix would key the header on the apply
step outcome.

Not covered: the runner's jq build (`1.7.1-3ubuntu0.24.04.2`) against upstream; real `gh`
behaviour for `-F milestone=N`, the milestone POST and `issue_field_values`; the model's output
against `--json-schema`; the dispatch boolean passed through `with:`.

### Live results: roadmap planner dry run (2026-10-11)

Run `38179661635` on `becloud-dev/triage-sandbox`, `workflow_dispatch` with `apply=false`,
caller `542a064`, reusable workflow at `workflows` `main` `82d3ec2`, model `claude-sonnet-5-5`,
literals `release_days` 14, `max_issues` 8, `max_releases` 3, `bug_budget` 0.30.

| Check | Result |
|---|---|
| Steps | build, plan, validate, report, record, upload success; apply skipped |
| Input | 14 open issues; 8 ranked (#1, #5, #7 Urgent; #2, #4 High; #6, #8, #12 Medium); 5 unprioritised (#9, #10, #11, #13, #14); #3 excluded by `needs-info`; Bug share 0.583, hold true; first version `v0.1.0` |
| Plan | new milestone 1: #1, #5, #2, #7 (Export button and checkout); new milestone 2: #4, #6 (accented search, print icon); held #8, #12; unplanned none; all three Urgent issues in milestone 1 |
| Validate | passed on the live plan |
| Quoted evidence | 7 of 7 quotes in the plan `reason` strings found in the issue titles and bodies |
| End state | issues #1 to #14 and milestones (0) identical to the baseline taken before the run |
| Run record | cost $0.0985 (sonnet $0.0984), 4 turns, 8.6 s, `permission_denials_count` 0 |

Confirmed live: the dispatch boolean passed through `with:` to the called boolean input reached
the job as `false` and skipped the apply step; a `--json-schema` `target` of `"new"` was accepted;
the shell-enforced hold held both Features.

Interpretation (inference): the three duplicate Export bugs (#1, #5, #2) were grouped and the
shared root cause was flagged in `summary`; the `held` reasons are a bare "error budget", which
adds nothing because the shell decides the hold. The run record lists a `claude-haiku-5-5` usage
entry (1,228 input tokens, $0.0001) although the caller sets only sonnet; the source is not
established.

Not covered: `apply=true` on real GitHub (`-F milestone=N`, the milestone POST, the read-back);
an integer `target` against an existing milestone; the hold test with a budget above the share;
the validate abort on a live bad plan.

### Live results: roadmap planner apply run (2026-10-11)

Run `38179936884` on `becloud-dev/triage-sandbox`, `apply=true`, caller `542a064`, workflows
`main` `82d3ec2`. Result: failure in the apply step.

| Check | Result |
|---|---|
| Plan, validate | success; plan as in the dry run in 2 new milestones, #8 and #12 held |
| Apply, milestone 1 | POST created `v0.1.0` (number 1) with `due_on` `2026-10-11T00:00:00Z`, expected `2026-10-25`; PATCH and read-back held for #1, #5, #2, #7 |
| Apply, milestone 2 | `date: invalid date 'today 00:00:00 + 28 days'`, exit 1; `v0.2.0` not created, #4 and #6 unassigned |
| Report | ran after the failure; header read "applied" |

Cause (verified in the log for milestone 2; milestone 1's stored value is not explained): the
GNU manual (Coreutils 9.12, "Time of day items") reads `+N` after a time of day as a time zone
correction with a 24-hour maximum, so `+ 28` is invalid and `+ 14` was read as a zone, not days.
The local fixture check ran on uutils `date` 0.10.0, which accepts the string and returned the
expected dates; it did not exercise the runner's `date`.

Fix `1c04177`: due dates from epoch arithmetic (`today_midnight + k * release_days * 86400`).
Unverified: that GNU date on the runner accepts `-d "@N"` (docs page fetch failed twice).

Bug class: implementation-specific parsing of a free-form string; the check that would have
caught it is running the block on the runner's `date`.

Confirmed live: `issues: write` through the caller, the milestone POST, `-F milestone=N` and
the read-back (4 of 4 held); a failed apply leaves milestones and assignments in place.

### Live results: roadmap planner apply run, second attempt (2026-10-11)

Run `38180319305` on `becloud-dev/triage-sandbox`, `apply=true`, workflows `main` `a455c07`
(fix `1c04177`), after a sandbox reset to the dry-run baseline. Result: success.

| Check | Result |
|---|---|
| Steps | plan, validate, apply, report, record success |
| Plan | milestone 1: #1, #5, #7, #2, #4; milestone 2: #6; held #8, #12; unplanned none (grouped differently from the dry run) |
| Apply | milestones number 2 `v0.1.0` and number 3 `v0.2.0`, descriptions from the themes; `-F milestone=N`, the milestone POST and the read-back held for 6 of 6; GNU `date -d "@N"` accepted on the runner |
| Quoted evidence | 7 of 7 quotes found in the issue titles and bodies |
| End state | against the pre-run baseline only the `milestone` field changed, on 6 issues |
| Run record | cost $0.0145, `permission_denials_count` 0 |
| Due dates | stored `2026-10-24` and `2026-11-07`, one day earlier than sent (`2026-10-25`, `2026-11-08` at `T00:00:00Z`) |

Probe (2 throwaway milestones created, read back and deleted; numbers 4 and 5):

| Sent `due_on` | Stored `due_on` |
|---|---|
| `2026-10-25T00:00:00Z` | `2026-10-24T00:00:00Z` |
| `2026-10-25T12:00:00Z` | `2026-10-25T00:00:00Z` |

Source: REST docs "Create a milestone" and "Update a milestone" (read 2026-10-11), which say only
that `due_on` is an ISO 8601 timestamp. Interpretation (inference from two data points): GitHub
stores the date as a calendar date in a zone west of UTC and not further west than UTC-12; the
exact zone is not established.

Fix `5a594e8`: due dates sent at noon UTC. Bug class: an API that normalises a timestamp to a
calendar date in a zone its docs do not state; the check that would have caught it is a live
read-back of `due_on` after the first create.

Open: the fix is untested live; the report header still reads "applied" after a failed apply
(seen in run `38179936884`); the hold test and the forced bad plan are not run.

### Live results: roadmap planner apply run, due dates (2026-10-11)

Run `38181204583` on `becloud-dev/triage-sandbox`, `apply=true`, workflows `main` `eded1ee`
(due date fix `5a594e8`), after a sandbox reset to the baseline. Result: success. Closes the
"fix untested live" item of the second apply run.

| Check | Result |
|---|---|
| Steps | plan, validate, apply, report, record success |
| Milestones | number 6 `v0.1.0` due `2026-10-25`, number 7 `v0.2.0` due `2026-11-08`, as expected from a send at `T12:00:00Z` |
| Plan | milestone 1: #7, #1, #5, #2; milestone 2: #4, #6; held #8, #12; unplanned none |
| Apply | the read-back held for 6 of 6 |
| Quoted evidence | 7 of 7; the quote for #4 contains an ellipsis, both fragments are verbatim in the issue body |
| End state | against the reset baseline only the `milestone` field changed, on 6 issues |
| Run record | cost $0.0139, `permission_denials_count` 0 |

Confirmed live: the milestone POST, `-F milestone=N`, the read-back, `due_on` after the noon send,
`issues: write` through the caller, and GNU `date -d "@N"` on the runner.

Open (stage 2b): the no-hold side of the error budget; the validate abort on a live bad plan; an
integer `target` into an open milestone with capacity (milestones 6 and 7 have room now); the
report header reads "applied" after a failed apply (seen in run `38179936884`).

### Live results: roadmap planner no-hold run and the due date collision (2026-10-11)

Run `38181470415` on `becloud-dev/triage-sandbox`, `apply=true`, workflows `main` `3635222`,
sandbox caller `85d313e` (`bug_budget` 0.70 as a test value). Result: success.

| Check | Result |
|---|---|
| Budget | `bug_share` 0.583 against 0.70, `hold_features` false; `held` empty, validate accepted |
| Plan | #8 and #12 each in a new milestone (`v0.3.0`, `v0.4.0`), although milestones 6 and 7 had capacity 4 and 6; unplanned none |
| Quoted evidence | 6 of 6 found in the issue text |
| End state | only the `milestone` field changed, on #8 and #12 |
| Run record | cost $0.0407, `permission_denials_count` 0 |
| Due dates | `v0.3.0` stored `2026-10-25` and `v0.4.0` `2026-11-08`, the same days as the existing `v0.1.0` and `v0.2.0` |

Finding: ~~ETA by `release_days`: due date is today plus k times `release_days` for the k-th new
milestone~~ ignored the due dates of existing open milestones, so a later release could be dated
no later than an earlier one. Amended rule, commit `1325e84`: the later of today and the latest
open `due_on`, plus k times `release_days` (sent at noon UTC, see the probe). Fixture check on
jq 1.7.1: future, past, null and empty due dates. Not yet run live.

Unverified: the report header on the runner (the job summary is not in the artifact).

Not exercised live: an integer `target` into an open milestone with capacity; the model opened
new milestones although existing ones had room. Covered by fixtures only.

### Decision: stage 2b closed (user, 2026-10-11)

Stage 2b is closed on the sandbox at `workflows` `967d0c1`: dry run, apply, error budget with and
without hold, due date probe and fix, report header fix, due date base fix. Tests stay on
`becloud-dev/triage-sandbox`; grouping quality on real issues is checked when the full flow runs
on a real project. Work continues with the issue type `Project` round, then stage 3.

Gaps carried forward (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| Integer `target` into an open milestone never exercised live | the model opened new milestones although two had room; the validate side ran on fixtures only | an issue that clearly belongs to an existing milestone, then a dispatch |
| Validate abort on a bad plan, on the runner | the 12 `jq` cases ran locally only; the workflow has no injection point | a forced bad plan, or a test-only input (changes the production workflow) |
| Due date base rule (`1325e84`) live | fixtures on jq 1.7.1 only; no run since with dated milestones and something to plan | one run on a sandbox with open issues to plan and dated milestones |
| Report header on the runner | the job summary is not in the artifact; `steps.apply.outcome` read from the docs | read the job summary of the next run in the browser |
| Grouping quality | the no-hold run made two single-issue milestones with room elsewhere | a run on a real project, as decided |
| No age rule; Urgent-first across milestones not enforced | carried from 2a and the 2b design | decisions for stage 3 |

### Queued after stage 2b

Issue type `Project` (org level; triage splits it into sub-issues), the issue form
`ISSUE_TEMPLATE/project.yml` and a sandbox test come after stage 2b and before stage 3, in their
own Plan Mode round. Stages 3, 4 and 5 follow, one per step.

### Issue type Project (2026-10-11)

Decisions (user, Plan Mode round): the type `Project` always splits; the parent keeps `Project` and
is still prioritised; only the author sets it, through the form, so the model `type` enum stays
`Task|Bug|Feature`; a Project that names fewer than two deliverables is `needs_info`; the child
cap stays 5; the org type is created by the agent on the user's go (the user was on a phone);
the form lives in `triage-sandbox` only.

Changes: `workflows` `5652f43` (prompt: three rules; `triage.yml`: step `Read the issue type`,
`Issue type:` in the prompt, `ISSUE_TYPE` in the apply step, Project branch, guard of at least two
children, type PATCH skipped for `Project`). `triage-sandbox` `0d5ba96`
(`.github/ISSUE_TEMPLATE/project.yml`). Both pushed.

Org type: `POST /orgs/becloud-dev/issue-types` with `name`, `is_enabled`, `description`, `color`
created `Project` (id `900748196`, purple). The token had `admin:org`. Body parameters were taken
from the REST docs page through a page summarizer (raw OpenAPI source unread); the call itself
returned the object with those fields.

Fixture check on jq 1.7.1 (SHA-256 `5942c9b0...c8ff5` matches the release `sha256sum.txt`), 9 cases:
Project with 0 or 1 children fails, with 3 passes and ignores a model `type`; Bug and an untyped
issue behave as before. Project/1 and Bug/1 fail in the existing range check, silently.

Sandbox runs (`gh api` read-back):

| Case | Issue | Run | Result |
|---|---|---|---|
| a. Project, 3 deliverables | #15 | `38182908746` | type `Project`, Priority `Medium`, 3 sub-issues #16-#18 typed `Feature`, no label, one comment with "Type: Project. Set by the author in the issue form." |
| b. Project, 1 deliverable | #19 | `38183021152` | type `Project`, label `needs-info`, no Priority, no sub-issues, one comment with 2 questions |
| c. Untyped Bug | #20 | `38183145951` | type `Bug`, Priority `High`, no sub-issues, one comment, as before |

Inference: the Project branch, the skipped PATCH and the always-split rule work on the runner. The
Priority write succeeded through the API with Priority not pinned to `Project`.

Gaps (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| Form `type: Project` applied on submit | only a missing type was observed; cases a and b were created with `gh issue create --type` | the user submits the form in the browser |
| Priority pinned to `Project` in the UI | the API write worked unpinned; the sidebar display is unread | look at #15 in the browser |
| Project with one child from the model | falls into the existing range check: silent fail, no comment | a run where the model returns one child instead of `needs_info` |
| Child cap 5 | a larger project needs a second pass | decision for a later round |
| Org-wide form distribution | the form exists in the sandbox only | the sync step, stage 5 or later |
| Re-run of a Project that has sub-issues | the idempotency reset applies after the guard; not run | a second `triage` label on #15 |
| Job summary of the three runs | only in the browser | read in the browser |

### Stage 3: UX and UI research (2026-10-11)

Decisions (user, Plan Mode round): one reusable `ux-ui.yml` with two Claude steps (UX, then UI
reading `.ux/ux.json`); two issue comments with marker lines `<!-- ux-research -->` and
`<!-- ui-research -->`, no files and no PR; optional caller input `design_system_path`, none means
no tokens; the gate is the owner swapping `UX/UI` for `RELEASE`; a thin issue gets questions and
`needs-info`; read-only tools (`gh issue view`, `Read`, `Grep`, `Glob`); an issue of type `Project`
is skipped with one comment; age rule and Urgent-first stay with the planner.

Changes: `workflows` `6bd173d` (prompts `ux-research.md`, `ui-research.md`; `ux-ui.yml`);
`triage-sandbox` `80e107a` (caller, `docs/design-system.md`); label `UX/UI` created on the sandbox.
Both pushed.

Details chosen inside the decisions: a re-run posts new comments and edits none; `record-run` writes
a fixed `run-record.json`, so the UX record is copied aside before the UI record is built; a
`design_system_path` that is absolute or contains `..` is refused; a UI result with
`design_system_used: false` and tokens is refused; triple backticks in model text are replaced
before a fenced block.

Fixture check on jq 1.7.1 (the real `run:` blocks extracted from the workflow, a stub `gh`): UX
and UI render and validate; `needs_info` with 0 questions, 1 requirement, and tokens without a
design system fail; a fence in the layout is escaped; the path guard accepts none and a relative
file, refuses `/etc/passwd`, `../x` and a missing file.

Sandbox runs (`gh api` read-back):

| Case | Issue | Run | Result |
|---|---|---|---|
| a. clear UI issue, design system given | #13 | `38183744281` | UX and UI comments, `UX/UI` stays; both run records in the artifact (5 and 4 turns, 0.098 and 0.105 USD, sonnet-5-5) |
| b. thin issue | #21 | `38183881071` | label `needs-info`, 5 questions, UI steps skipped |
| c. Project | #15 | `38184069206` | one skip comment, Claude steps skipped, sub-issues untouched |

Inference: the mechanics hold on the runner. In case a the UX is grounded in the issue text, and
every token cites a section of `docs/design-system.md` with matching values. Quality finding: the UI
step chose a one-row-per-invoice table because the design system defines a Table; the issue does
not say whether the button sits on a list or on one invoice, and the gaps list did not flag that.

Gaps (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| Unstated screen shape not flagged as a gap (closed on one run) | case a assumed a list from the available components | closed by `8f6d4b3`: re-run of #13, run `38184680888` (2026-10-11T23:33Z), `Gaps` item 1 names the list-or-single-item assumption; 8 further gaps listed, so the volume is higher; one run, not proof |
| `design_system_path` empty, live | fixture only; the model must design without colours | a caller with the input empty and a run |
| Job summary of the three runs | only in the browser | read in the browser |
| `needs-info` label in a fresh consumer repo | `gh issue edit --add-label` fails when it is missing | the label sync step (stage 5 or later) |
| Model text with `@` mentions goes into comments unfiltered | a mention notifies a person | a decision on filtering |
| Re-run duplicates comments | the latest marker comment is current, old ones stay | a decision: edit in place or keep history |
| The UI step reads the UX of the same run | an owner edit to the UX comment is not seen | a decision, with the gate design for stage 4 |
| Gate (`UX/UI` to `RELEASE`) not exercised | stage 4 does not exist yet | stage 4 |
| No age rule; Urgent-first across milestones | planner decisions carried from 2a and 2b | a planner round |

Re-run after `8f6d4b3` (inference, one run): the UI comment's `Gaps` now states that the page is
assumed to be a list with one button per row and that a single invoice would move the button to the
page header's actions area. The layout is unchanged. Nine gaps in total; unverified whether that
volume is useful or noisy across other issues.

### Stage 4a: development plan (2026-10-11)

Decisions (user, Plan Mode round): two reusable workflows, plan first (`dev-plan.yml`, then
`dev-execute.yml`); the owner's comment `/approve` starts the execution; `GITHUB_TOKEN` opens the PR
now and a GitHub App comes in a later round; a loop that still fails after 2 re-executions opens a
draft PR plus a findings comment. Defaults taken from the plan and not asked: the gate refuses a
`RELEASE` while `UX/UI` is on the issue; the plan reads the latest UX and UI comments as they are
at run time.

Changes: `workflows` `333d034` (`prompts/dev-plan.md`), `9ef164d` (`dev-plan.yml`), `2acb3ca`
(`record-run` keeps `permission_denials` with `tool_name` and `tool_input` cut to 300 characters);
`triage-sandbox` `750a808` (caller); label `RELEASE` created on the sandbox. All pushed.

Source read: `anthropics/claude-code-action` at `1d6de8c` (raw `src/modes/agent/index.ts`,
`src/github/operations/git-config.ts`, `docs/faq.md`, `docs/capabilities-and-limitations.md`) and
the Agent SDK TypeScript reference (`SDKPermissionDenial`). In agent mode the action checks that
the actor is human, replaces the checkout credential with its own token and sets a git user; it
creates no branch and no PR.

Fixture check on jq 1.7.1 (SHA-256 verified; real `run:` blocks, stub `gh`): gate output for a
plain issue, a Project and an issue with `UX/UI`; hold comment; planned post with and without
risks; planned with one step, no `risks` field, or no files fails; `needs_info` posts the
questions, with 0 questions fails. `record-run` with 0, 1 and 2 denials, a 500-character input
and a missing file. zizmor 1.30.1 offline, auditor persona: no findings on `dev-plan.yml` and
`record-run`.

Sandbox runs on #13 (`gh api` read-back):

| Case | Run | Result |
|---|---|---|
| a. `RELEASE` added while `UX/UI` is on | `38185526301` | hold comment `<!-- dev-plan-hold -->`; plan, record and upload steps skipped |
| b. `UX/UI` removed, `RELEASE` re-added | `38185565419` | `<!-- dev-plan -->` comment; sonnet-5-5, 5 turns, 0.127 USD, 19 s; `permission_denials_count` 1 |
| c. same, after `2acb3ca` | `38185834989` | success; 4 turns, 0.054 USD; `permission_denials_count` 0, list empty |

Inference: the mechanics hold on the runner (second checkout from `job.workflow_repository`, the
gate, the hold, the marker comment). In case b the plan cites the UX and UI comments in its
acceptance criteria, takes the tokens from the design system, and lists the list-or-single-item
assumption under Risks, so the stage 3 fix carries over. #13 has no application code, so the plan
invents a greenfield Node app (9 files, a hand-built PDF); that is a fixture limit, not a plan
defect, and slice 4b needs a small issue in a repository with code. One spec item,
"download click does not navigate away", cannot be checked by the stack the plan chose (no
browser); inferred from reading the plan, not run.

Gaps (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| Denied tool call in case b not identified | the log hides tool output and the first record kept only the count | the next occurrence, now named in the record; a prompt line only if it repeats |
| `permission_denials` shape on a live denial | fixture follows the SDK docs; the live array was only seen empty | one run with a denial |
| Plan items not testable on the chosen stack | the executor would write a test that cannot pass | a plan-prompt rule, decided with the first 4b run |
| Plan comment edited by a non-owner | the execution reads the comment as it is | a decision on checking the comment's last editor |
| Re-run duplicates plan comments | the latest `<!-- dev-plan -->` is current, older ones stay | the recorded stage 3 decision on edit in place |
| Hold when `RELEASE` is added before `UX/UI` is removed | the owner must re-add `RELEASE`; order is by design, not exercised in a mixed event order | stays as documented behaviour |
| `ux-ui.yml:160` zizmor `template-injection` (info, low confidence) | pre-existing; `record_path` is a runner temp path | passing it through `env:`, its own change |
| Gate `UX/UI` to `RELEASE` with a real UI change end to end | exercised on #13 only as a plan | slice 4b on a UI issue, later |

### Stage 4b: development execution (2026-10-12)

Decisions (user, 2026-10-12): branch type from the issue type (`Bug` gives `fix`, `Feature`
`feat`, else `chore`); push by an explicit token URL step; a first line other than `/approve`
fails the run; an existing branch stops the run with a comment; a PR opens only with commits ahead
of the base and a last outcome `done` (`fail` gives a draft); `blocked` or `failed` posts a
comment only; PR body is `Closes #N`, the plan link and the verdict. Strictening: a plan is made
and executed only for issues written by an `OWNERS` login or `github-actions[bot]`; the plan reads
a file with the comments of those authors only and has no `gh` tool; `triage` and `ux-ui` stay as
they are because they must read external issues. The user turned on "Allow GitHub Actions to
create and approve pull requests" at the organisation and the repository; it is to be turned off
after the live runs.

Source read (raw, `github/docs`): `data/reusables/actions/actions-do-not-trigger-workflows.md`,
`data/features/actions-github-token-pull-request-approval.yml`,
`events-that-trigger-workflows.md` (`issue_comment`),
`managing-github-actions-settings-for-a-repository.md`, `github-terms-of-service.md` (accounts);
`claude-code-action` at `1d6de8c` (`src/entrypoints/prepare.ts`, `permissions.ts`, `actor.ts`);
`gh pr create --help` 2.102.0.

Corrections: (1) pushes with `GITHUB_TOKEN` start no run, but a `pull_request` `opened`,
`synchronize` or `reopened` from a PR a `GITHUB_TOKEN` workflow creates makes runs in an
approval-required state; this narrows the "known limit" in the stage 4 plan. Unverified live: the
sandbox has no PR workflow. (2) Agent mode also runs `checkWritePermissions` for issue events
(`prepare.ts`), not only `checkHumanActor`; seen in the log as "Permission level retrieved: admin".

Changes: `workflows` `0bc04ef` (execute prompt), `3bbd734` (check prompt), `9115dfc` and `25d08c3`
(`dev-round` composite; unmet criteria named), `6d64c57` (`record-run` names the file by stage),
`14633a0` (`dev-execute.yml`), `2d8d29c` (author gate, filtered comments), `dba3e62` (prompt
wording: `Read` tool, one command at a time); `triage-sandbox` `c0ba872` (greet fixture, vars
`CHECK_COMMAND`, `TEST_COMMAND`), `85c8e70` (caller). Fixture checks on jq 1.7.1 (SHA-256
verified): composite 32 cases, `record-run` 10, `dev-execute` 37, `dev-plan` gate 14; mutations
fail as expected; zizmor 1.30.1 offline: no new findings.

Live runs (`gh` read-back):

| Case | Run | Result |
|---|---|---|
| a. #22, plan approved | `38243213387` | PR #23, 1 commit, pass in round 1; haiku 12 turns 0.008 USD, sonnet 7 turns 0.103 USD; denials 2 and 1 |
| b. #24, plan edited by the owner to a contradictory criterion | `38245576046` | executor `blocked` with the reason; findings comment; no push, no PR |
| c. #24, criterion removed, after `dba3e62` | `38246001793` | PR #25, pass in round 1; haiku 15 turns 0.0054 USD, sonnet 7 turns 0.042 USD; denials 0 and 0 |

Inference: the mechanics hold (gate, branch, composite outputs through `continue-on-error`,
`$/` inside a composite, push and `gh pr create` with `GITHUB_TOKEN`, blocked path, owner edit
honoured). The `Read` of files in the runner temp directory worked (inferred from the checker's
verdict). The wording fix removed the shell-form denials in one sample per case.

Gaps (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| `red_seen` is self-reported | no run evidence that the new tests failed first | the workflow running the tests against the base, its own change |
| `fail` with a draft PR and round 2 `findings_file` not seen live | an honest executor blocks instead of failing | the first real failing round |
| Non-owner trigger not run live | the guard is read from the expression and the action source | a second human account comments `/approve` |
| Approval-required PR runs | the sandbox has no PR workflow | a PR workflow in a consumer |
| Bot-authored issues are trusted | an external issue split by an owner-triggered triage reaches the plan | the owner's `triage` label is the control; recorded |
| One sample per model | cost and quality variance unknown | more runs |
| Non-owner writer edits the plan comment | the execution reads it as it is | a check of the comment's last editor |
| Organisation setting on | any workflow in the organisation can open PRs | turn it off after 4b, or the GitHub App round |

### Stage 5: release (2026-10-12)

Decisions (user, 2026-10-12): a GitHub App `becloud-dev-release`, owned by the organisation, for
the release PR; installed on all repositories of `becloud-dev` because the workflows are to run
organisation-wide (chosen over "Only select repositories"); scope is the review only, the
`release-blocker` merge or deploy gate job, the label sync and the form sync stay later; the stage
is split in 5a (release PR and live checks) and 5b (review); the review and the issues use
`GITHUB_TOKEN`, the App token exists only in the release-please job; the automation applies no
start label, the owner adds `RELEASE` to a blocking issue (skips triage) and `triage` to the
others; the review lives in a PR comment, started by `/review`, answered by `/reject` (reason on
the following lines) or `/approve`, and `READY TO LIVE` stays the owner's label; the 4b PR step
stays on `GITHUB_TOKEN` for now.

Sources read (raw): `actions/create-github-app-token` `action.yml` and README (v3.2.0,
`bcd2ba49`; input `client-id`, `app-id` deprecated); `googleapis/release-please-action`
`action.yml` and README (v5.0.0, `45996ed1`); `googleapis/release-please` v17.11.2 `manifest.ts`;
`github/docs` `actions-do-not-trigger-workflows.md`, `additional-permissions.md` and
`server-to-server-permissions.json`; `bentoluizv/patagonia-trip` `claude-pr-review.yml`,
`pr-review.md`, `release.yml`; run logs and artifacts of the runs below.

Changes: `workflows` `cbcd334` (prompts `release-review.md`, `release-issues.md`), `0e8482a`
(`release-review.yml`), `72ac98d` (`release-issues.yml`), `0e481de` (`pull-requests: write`);
`triage-sandbox` `2199926` (`version.txt`, `release-please.yml`), `20cffda` (`pr-checks.yml`),
`e6bc9c9` (callers), `911e50c` (`--shout` fixture with a seeded `eval` defect), `0211639`
(caller `pull-requests: write`); seed tag `v0.1.0` (lightweight, on `20cffda`); App, org variable
`APP_CLIENT_ID` and org secret `APP_PRIVATE_KEY` visible to `triage-sandbox` only; labels
`release-blocker` and `READY TO LIVE` on the sandbox. All pushed.

Fixtures (jq 1.7.1, SHA-256 verified against the release checksum; real `run:` blocks, stub `gh`):
`release-review` 50 cases (gate 31, post 19), `release-issues` 57 (gate 19, create 38; stateful
stub). Mutations (4 and 4) fail as expected. zizmor 1.30.1 offline, auditor: no findings on the
two shared workflows; `release-please.yml` keeps `secrets-outside-env` (accepted: the key is an
organisation secret, the workflow runs on `push` to `main` only); the two callers carry the same
three findings as the other callers (`unpinned-uses`, `excessive-permissions`,
`undocumented-permissions`).

Live results (`gh` and run-log read-back):

| Check | Run | Result |
|---|---|---|
| 5a: first push with seed tag | `38250366025` | App token minted; baseline from the tag; 0 commits after it; no PR |
| 5a: `chore:` only | `38250593500` | "No user facing commits found since 20cffda… - skipping"; no PR |
| 5a: `fix:` | `38251263422` | PR #26 `chore(main): release 0.1.1`, branch `release-please--branches--main`, author `becloud-dev-release[bot]`, `autorelease: pending`, `CHANGELOG.md` added, `version.txt` modified |
| 5a: checks on the App PR | `38251310675` | `pr-checks` `pull_request` run started and succeeded, not approval-required |
| 5b: `/review` | `38253965265` | Opus 5.5, 8 turns, 0.223 USD, 0 denials; blocking `bin/greet:5` (`eval`), deferred `tests/greet_test.sh:7` (no test) |
| 5b: `/reject` with a reason | `38254781174` | new review comment, 7 turns, 0.073 USD; the reason (no-argument case) is in the blocking item |
| 5b: `/approve`, first | `38255071190` | issues #27 and #28 created and set; step failed on the final comment, HTTP 403 |
| 5b: `/approve`, second (after the fix) | `38257406730` | no new issue; #27 and #28 re-checked; `<!-- release-review-issues -->` comment; Sonnet 5.5, 4 turns, 0.037 USD |
| 5b: `/approve`, third | `38257868747` | refused by the gate, no model run |
| 5b: `/review` on closed PR #25 | `38257868740` | "No review: this pull request is not open." |

Inference: an App installation token starts `pull_request` runs on the release PR (one sample);
a seed tag is a sufficient baseline over a history of direct pushes; the stage 5 mechanics hold
end to end (gate, range from the tag, review, reject loop, issue creation, idempotent repeat).
The review read `bin/greet:5`, which is on `main` and not on the release branch, so the file reads
came from the default-branch checkout. One full cycle cost about 0.33 USD.

Corrections to earlier records:

1. "Release tooling, stage 5 read": the row "Releasable units" and its Correction paragraph said
   the code showed no type filter. Run `38250593500` shows a `chore:` commit alone opens no
   release PR in the action's bundled release-please. The README list (feat, fix, deps) is the
   behaviour seen. `release-please-action` v5.0.0 runs release-please **17.6.0** (log line
   "Running release-please version: 17.6.0"), not the 17.11.2 that was read; where the filter
   sits was not read. `perf`, `refactor`, `revert`, `style`, `docs`, `build` and `ci` were not
   run.
2. "`gh` CLI flags (#20)" and the stage 4 notes listed the comment permission as unverified. A
   comment on a pull request through `POST /issues/{n}/comments` needs `pull-requests: write`;
   `issues: write` with `pull-requests: read` was refused (HTTP 403, run `38255071190`). The raw
   permission data lists the endpoint under both `issues` and `pull_requests` with the
   "additional permissions" mark and does not say which applies to a pull request.
3. "Release tooling (#21)": the unverified App-token question is closed for `pull_request` runs
   on the release PR (above), one sample.

Defects found by the fixtures or the live run, fixed before use:

| Defect | Bug class | What caught it |
|---|---|---|
| `blocking=$(jq -er ...)` exits 1 for `false`, so every deferred item stopped the create step | `jq -e` on a boolean that may be `false` | a fixture with a `false` value |
| Final comment refused: job had `pull-requests: read` | a write whose token permission was not checked before the live run | the live run; the stub `gh` does not model permissions |

Gaps (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| `perf`, `refactor`, `revert` and the other types untested for a release PR | the git-workflow table says patch | one `refactor:` commit on a fresh baseline |
| `release-blocker` merge or deploy gate not built | the review creates blockers, nothing refuses the merge | a job modelled on Patagonia's `blockers` job, its own change |
| Owner-edited review comment read as it is | Sonnet parsing an edit not run; an editor who is not an owner is not checked | edit the comment, approve; a check of the comment's last editor |
| Non-owner trigger and a non-release open PR not run | gate read from the expressions only | a second account; an open non-release PR |
| One sample per model and per path | cost and quality variance unknown | more runs |
| Marker lookup lists the last 300 issues | a repository with more would miss a marker | a bounded search or a label scan |
| Release PR not merged, `READY TO LIVE` not exercised, tag and release not created | the gate evaluated at merge time is not built | merge #26 after the gate job exists |
| Org setting "Create and approve pull requests" still on | the 4b step relies on it | move the 4b PR step to the App, then turn it off |
| Installation on all repositories | the App can write contents, issues and PRs on every repository | the user's decision, recorded |
| Review blank lines (two before `### Defer`) | cosmetic | renderer change if wanted |
| Review comment not marked stale after a newer commit on `main` | the issues come from the review as approved | compare the review's SHA with `HEAD` in the gate |

### Release gate (2026-10-12)

Source read (raw): `github/docs` `server-to-server-permissions.json` (fpt-2026-03-10):
`POST /repos/{o}/{r}/statuses/{sha}` needs `statuses: write`, no additional permissions;
`GET .../issues/{n}/events` needs `issues: read` with the "additional permissions" mark.
`events-that-trigger-workflows.md`: `issues` runs on the last default-branch commit;
`pull_request` runs in the context of the merge commit.

Change: `workflows` `1883156` (`release-gate.yml`), `triage-sandbox` `f619bf4` (caller). The gate
sets the commit status `release-gate` on the release PR head: success when `READY TO LIVE` is set
by an owner and no `release-blocker` issue is open. Advisory: no ruleset requires it.

Fixtures (jq 1.7.1, stub `gh`): 22 cases, 7 mutations caught; zizmor auditor: no findings on the
shared workflow.

Live results:

| Check | Run | Status on `4d9fe9e` |
|---|---|---|
| `labeled` on PR #26 before the merge ref refreshed | none | no run started |
| label by owner, #27 open (`issues` event) | `38261899164` | failure: open release-blocker: #27 |
| label missing, #27 open | `38262077137` | failure: missing label READY TO LIVE; open release-blocker: #27 |
| label set, #27 closed | `38263152468` | success |
| merge of #26 | `release-please` `38263623779` | tag `v0.1.1` on `4715338`, Release created |

Inference: a `pull_request` run takes its workflow file from the merge commit; on #26 the merge
ref was stale after the caller push, so the PR event started nothing until later events (two runs
after the merge). The `issues` event is the reliable trigger. Unverified: the output of the two
post-merge runs (logs show the script, not its lines); the cause of the missed first event.

Corrections: "Release PR not merged, `READY TO LIVE` not exercised, tag and release not created"
is closed. Open: no ruleset (the gate does not block); the `refactor`/`perf`/`revert` types; the
stale-review check; a non-owner labeler and a non-release open PR are fixture-only.

### Stale-review check (2026-10-12)

Source read (raw): `github/docs` `server-to-server-permissions.json` (fpt-2026-03-10):
`GET .../commits/{ref}` needs `contents: read`; `GET .../issues/{n}/comments` needs `issues` or
`pull_requests` read. `events-that-trigger-workflows.md`: `workflow_run` runs on the default branch
and fires regardless of the conclusion of the watched workflow. `trigger-a-workflow.md`: events
caused by `GITHUB_TOKEN` start no workflow. GraphQL introspection of `IssueComment`: `editor` and
`lastEditedAt` exist; the REST `issue-comment` object has `updated_at` and no editor.

Change: `workflows` `e527254` (`release-review.yml` writes line 2,
`<!-- release-review-sha: <40 hex> -->`), `ec70b3e` (`release-gate.yml`: `contents: read`; for a
release PR with a review, reviewed SHA against the default-branch tip, last editor through
GraphQL); `triage-sandbox` `f4d80ba` (caller `contents: read`), `b333d66` (caller triggers `push`
to `main` and `workflow_run` of `release-review`). Rules: the review is the last
`github-actions[bot]` comment starting `<!-- release-review -->`; no review: the gate is as before;
line 2 missing or malformed: stale; an edited review passes only if the last editor is an owner,
and an unreadable editor fails.

Fixtures (jq 1.7.1, stub `gh`): 35 cases (15 for the earlier behaviour, rebuilt because the
earlier scripts were not kept, so not the 22 recorded before; 20 new), 8 mutations caught; zizmor
auditor: no findings on the two shared workflows.

Live results (PR #29, head `5f4fb50`):

| Check | Run | Status |
|---|---|---|
| no review, label missing | `38267765984`, `38267766138` | failure: missing label |
| `/review` | `38267952201` | line 2 equals the `main` tip `d0948d2` |
| label set, review current | `38268932754` | success |
| `chore:` push to `main` | `release-please` `38269387914` | no gate run; status stayed success |
| label toggled, review of `d0948d2`, `main` at `b52e912` | `38269819486` | failure: review is stale |
| `/review` again | `38270323748` | no gate run; status stayed failure |
| label toggled, review current | after 15:31 | success |
| owner edit of the review, label toggled | after 15:31:18 | success (editor `bentoluizv`) |
| `push` to `main` (caller change) | `38271343990` | failure: stale (reviewed `b52e912`, `main` `b333d66`) |
| `/review` after the push | `38271524175` (`workflow_run`) | success |
| ordinary comment | `38271582453` | skipped |

Inference: the editor query works under `GITHUB_TOKEN` with `issues`, `pull-requests` and
`contents` read (a readable node came back for an unedited and an owner-edited comment; the
statuses are the evidence, the logs were not read). Before the caller change, the status moved
only on PR and issue events; the two events above show a green status on a stale review and a red
status on a current one.

Not verified: an edit by a non-owner (no second account); only the last editor is read, so an
earlier non-owner edit overwritten by an owner edit is not detected; one sample per path.
zizmor reports `dangerous-triggers` on the caller (`workflow_run`), accepted because the job
checks out nothing and uses no event text.

Corrections: gap rows "Review comment not marked stale after a newer commit on `main`" and
"an editor who is not an owner is not checked" are closed by this record, with the limits above.
