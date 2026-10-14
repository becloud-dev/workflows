# Research: GitHub platform

What was read and tested about GitHub: tokens, permissions, events, reusable workflows, issue types and fields, templates, plan features, `gh`, release-please, zizmor, pins.

Moved from the former `third-party-review.md` and the CLI design draft, entries kept as written. Decisions in force are
in [decisions.md](../decisions.md); where a later entry corrects an earlier one, the entry says so.
Each entry names its sources, marks inference, and lists what is unverified.

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

### Release PR types: refactor, perf, revert (2026-10-12)

Decisions (user, 2026-10-12): `refactor` is shown through config and the git-workflow table is
kept; the types are tested by reading the notes of the release PR, with no new seed tag; the
`refactor`-alone case is not isolated.

Source read (raw): `googleapis/release-please` v17.6.0 `src/strategies/base.ts` (a release PR is
skipped with "No user facing commits" when the generated notes are empty), `src/versioning-strategies/default.ts`
(only a breaking change or `feat` bumps above patch; any other commit gives a patch),
`src/changelog-notes/default.ts`, `src/manifest.ts`, `schemas/config.json`
(`changelog-sections`); `conventional-changelog-conventionalcommits` v6.1.0 `writer-opts.js`
(default types: `perf` and `revert` visible, `refactor` `hidden: true`);
`googleapis/release-please-action` at `45996ed` (`action.yml`, `src/index.ts`: with the
`release-type` input the manifest is built from inputs and the config file is not read; there is
no input for `changelog-sections`). Not verified: the preset version the action resolves
(package.json says `^6.0.0`).

Change: `triage-sandbox` `6770ff7` adds `release-please-config.json` (package `.`,
`release-type: simple`, `changelog-sections` with `feat`, `feature`, `fix`, `perf`, `revert` and
`refactor` visible and `docs`, `style`, `chore`, `test`, `build`, `ci` hidden) and
`.release-please-manifest.json` (`{".": "0.1.1"}`), and drops the `release-type` input from
`release-please.yml` so the action runs in manifest mode.

Live results (sandbox, release PR #33, all with one fix after `v0.1.1`: `d0948d2`):

| State | Commits since `v0.1.1` added | Notes of the PR |
|---|---|---|
| default config, tip `615fae0` | `refactor` `64b909e`, `perf` `7007505`, `revert` `615fae0` | Bug Fixes (`fix`), Performance Improvements (`perf`), Reverts (`revert`); `refactor` absent |
| manifest mode with sections, tip `6770ff7`, run `38278143232` | none | the same three, plus Code Refactoring (`64b909e`) |

The title (`chore(main): release 0.1.2`), the head branch (`release-please--branches--main`), the
label (`autorelease: pending`) and the PR number stayed the same across the switch; the
`release-gate` status on the new head is failure, "missing label READY TO LIVE", the designed
result for a release PR without the label.

Inference: `perf` and `revert` release as patch under the default config; `refactor` does not
appear in the notes, so under the default config a `refactor:`-only change would give no release
PR (from the source, not run); with the sections config it is listed and releases as patch (the
PR changed in place; "alone" not run). The git-workflow table holds only with this config.

Not verified: `refactor` alone (a `fix` keeps the PR alive on this `main`); the tag format and
the title after a real release in manifest mode (no release was merged); one sample per type;
the preset version resolved by the action; the release PR types on a repository other than the
sandbox. PR #33 stays open and unmerged; the three test commits stay in the sandbox history.

For plan 4: the caller template carries `release-please-config.json` with `changelog-sections`,
`.release-please-manifest.json` (seed version equal to the seed tag) and `release-please.yml`
without the `release-type` input.
