# Stages: identity and permissions

Every workflow in `.github/workflows` runs under one identity per step. This table is the record of
which one, and what it is allowed to do. A change to a workflow's permissions or token changes this
file in the same pull request; `tests/dev-execute/run.sh` checks that every workflow has a row.

| Workflow | Stage | Identity | Permissions |
| --- | --- | --- | --- |
| `triage.yml` | Set type and priority, comment, label, create sub-issues | GITHUB_TOKEN | contents read, issues write |
| `dev-plan.yml` | Post the development plan | GITHUB_TOKEN | contents read, issues write |
| `dev-execute.yml` | Read the approval and pin the plan, reply when it is refused | GITHUB_TOKEN | contents read, issues write |
| `dev-execute.yml` | Run the rounds and the check, post the findings | GITHUB_TOKEN | contents read, issues write |
| `dev-execute.yml` | Push the branch and open the pull request | executor App | contents write, pull-requests write, workflows write |
| `dev-execute.yml` | Report a publication that failed or was refused | GITHUB_TOKEN | issues write |
| `release-please.yml` | Open and update the release pull request, tag the release | release App | contents write, issues write, pull-requests write |
| `release-review.yml` | Review the release pull request | GITHUB_TOKEN | contents read, issues read, pull-requests write |
| `release-issues.yml` | Create the blocker issues from an approved review | GITHUB_TOKEN | contents read, issues write, pull-requests write |
| `release-gate.yml` | Set the release-gate status on the release pull request | GITHUB_TOKEN | contents read, issues read, pull-requests read, statuses write |
| `planner-backlog.yml` | Order the open issues; the report writes nothing | GITHUB_TOKEN | contents read, issues read |
| `planner-roadmap.yml` | Create milestones and assign issues, only when `apply` is true | GITHUB_TOKEN | contents read, issues write |
| `ux-ui.yml` | Post the UX and UI research | GITHUB_TOKEN | contents read, issues write |
| `ci.yml` | Run the test suites on a pull request | GITHUB_TOKEN | contents read |

## The rule

A stage that needs a capability `GITHUB_TOKEN` lacks gets its own strict App, holding only that
capability. The capability is not added to an App that already exists, so no App holds the
permissions of more than one role.

`GITHUB_TOKEN` cannot change files under `.github/workflows`, and a pull request opened with it does
not start its checks without approval. Pushing the executor's branch and opening its pull request
are the steps that need an App for that reason.

## The release App

`release-please.yml` mints a token from the release App for the release pull request, so the
release pull request starts its checks. The job itself declares no `GITHUB_TOKEN` permission.
The App is installed on the organisation with contents, issues and pull requests write, and
metadata read.

## The executor App

| Item | Value |
| --- | --- |
| Repository permissions | Contents, Pull requests and Workflows, read and write; Metadata read is implicit; nothing else |
| Webhook | none |
| Installed on | only the repositories that use the executor |
| Secret | `EXECUTOR_APP_PRIVATE_KEY` |
| Variable | `EXECUTOR_APP_CLIENT_ID` |

`dev-execute.yml` runs in four jobs on four runners. The `dev-gate` job runs no model code and no
consumer command: `wf executor gate` reads the `/approve` comment and the issue, replies when it
refuses, and pins the plan it approves (the plan comment's ID and the SHA-256 of its body) with the
commit it saw as the base. The `dev-execute` job starts only after an approval, checks out that
base, reads the plan again by the pinned ID (`wf executor plan` refuses a body whose hash
differs), and runs the rounds, the check and the findings comment. When the outcome is a pull
request or a draft, it bundles the commits from the base to HEAD from a fresh git dir and uploads
the bundle as an artifact; its outputs are only `action`, `verdict` and `rounds`. The `dev-publish`
job runs only for a pull request or a draft. It checks out the base, takes the bundle, verifies it
and checks that its history reaches the base. `wf executor publish-check` then reads the plan
comment by the gate's pin and refuses a comment whose body hash differs, whose author is not the
bot, or that is not on the issue; only then does it judge the bundle's deletions and workflow
changes against the plan's **Files** list. Only after that does the job mint the token, push and
open the pull request. The `dev-report` job holds only `issues: write`, runs no model code, no
checkout and no consumer command, and comments on the issue when `dev-publish` failed, which
includes a refusal.

The token is minted once per run, in the `dev-publish` job, and is scoped to the current repository
with contents and pull requests write, and workflows write only when the bundle adds, changes or
deletes a file under `.github/workflows` (the publish check says so). It is used by the push step and the pull request step. No
step of the `dev-execute` job receives the executor key or the token, and no step of `dev-publish`
runs the model, the setup, the check or the test commands. Environment files that the rounds write
stay on the rounds runner, so they never reach the push or the pull request step.

The push step does not run git in the checkout. The verify step fetches the bundle into a fresh bare
repository in the runner's temporary directory, and the push runs from there, with `core.hooksPath`
set to `/dev/null` and the global and system git config disabled. The bundle is made the same way in
the rounds job. A hook or config that the rounds wrote into the checkout's `.git` therefore cannot run
during the bundle or the push, or redirect the push, so the token reaches only the push URL.

## The scope check

The `scope` step of the `dev-round` action runs `wf executor scope`. It lists the files the executor
deleted between the base and HEAD, with a rename counted as a deletion of its old path, and the
files added or modified under `.github/workflows` or `.github/actions`. A path is allowed only when it is named in the
plan's **Files** list, or lies under a listed path that ends in `/`; the comparison is literal. It
also lists the test files the implementer changed between the test-writer's commit and HEAD (the
`TEST_PATHS` globs): only the test-writer may touch the tests, so any such change is a violation
whether or not the plan names the file, which keeps the red proof meaningful. A path outside the
list, a test file the implementer changed, a diff or plan that cannot be read, or a CLI that does
not run to its end, sets the verdict to fail, whatever the check model says. The findings name each
path. The publish job makes the same Files-list judgement on the bundle, against the plan that was
approved.

## The repository ruleset

Ruleset `main` on `becloud-dev/workflows` (id 25008202) requires a pull request (squash only, no
approvals), the checks `Workflow tests`, `zizmor audit` and `Rust CLI` from GitHub Actions (not
strict), and blocks force-push and deletion. Admins bypass on pull requests only. `release-gate` is
not required until it reports on every pull request.
