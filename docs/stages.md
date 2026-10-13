# Stages: identity and permissions

Every workflow in `.github/workflows` runs under one identity per step. This table is the record of
which one, and what it is allowed to do. A change to a workflow's permissions or token changes this
file in the same pull request; `tests/dev-execute/run.sh` checks that every workflow has a row.

| Workflow | Stage | Identity | Permissions |
| --- | --- | --- | --- |
| `triage.yml` | Set type and priority, comment, label, create sub-issues | GITHUB_TOKEN | contents read, issues write |
| `dev-plan.yml` | Post the development plan | GITHUB_TOKEN | contents read, issues write |
| `dev-execute.yml` | Read the approval, run the rounds and the check, post the findings | GITHUB_TOKEN | contents read, issues write |
| `dev-execute.yml` | Push the branch and open the pull request | executor App | contents write, pull-requests write, workflows write |
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

`dev-execute.yml` runs in two jobs on two runners. The `dev-execute` job runs the gate, the rounds, the
check and the findings comment. When the outcome is a pull request or a draft, it bundles the commits
from the base to HEAD and uploads the bundle as an artifact. The `dev-publish` job runs only for a
pull request or a draft. It takes that bundle and the job outputs `action`, `verdict`, `rounds`,
`branch`, `ctype` and `plan_url`, verifies the bundle and checks that its history reaches the base
commit of its own checkout. Only then does it mint the token, push and open the pull request.

The token is minted once per run, in the `dev-publish` job, and is scoped to the current repository
with exactly the three permissions above. It is used by the push step and the pull request step. No
step of the `dev-execute` job receives the executor key or the token, and no step of `dev-publish`
runs the model, the setup, the check or the test commands. Environment files that the rounds write
stay on the rounds runner, so they never reach the push or the pull request step.

The push step does not run git in the checkout. The verify step fetches the bundle into a fresh bare
repository in the runner's temporary directory, and the push runs from there, with `core.hooksPath`
set to `/dev/null` and the global and system git config disabled. The bundle is made the same way in
the rounds job. A hook or config that the rounds wrote into the checkout's `.git` therefore cannot run
during the bundle or the push, or redirect the push, so the token reaches only the push URL.

## The deletion check

The `scope` step of the `dev-round` action lists the files the executor deleted between the base and
HEAD, with a rename counted as a deletion of its old path. A deletion is allowed only when its path is
named in the plan's **Files** list, or lies under a listed path that ends in `/`; the comparison is
literal. A deletion outside the list, or a diff or plan that cannot be read, sets the verdict to fail,
whatever the check model says. The findings name each path.
