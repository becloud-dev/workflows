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
- Triage reads a markdown body; form labels should stay stable because the body layout depends
  on them (layout not shown in the docs read).
- Labels named by a form must exist in each repo (sync step) or they are dropped without error.
- Public preview: forms are pinned in `workflows` and re-checked at each release.

Unverified: that `required` blocks submission in a public repo of a Free org (documented, not
tested); what `type` does when the type is missing; the rendered body layout of a submitted
form; the forbidden-word list for labels; any limit on body size or element count (none stated
in the files read).
