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

### Gate decisions (2026-10-11)

- A failed gate sets a failing check and a blocking comment; the code owner merges by hand. No
  automatic reverts or closes.
- Gating labels (`RELEASE`, `READY TO LIVE`): a workflow removes the label and comments when the
  actor is not in an owners list kept as a repo variable.

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
`claude-sonnet-5`), settled in #19. `docs/usage.md` and `docs/faq.md` not read.

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
