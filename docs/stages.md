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
| `site-ci.yml` | Check a Zola and Worker site, called by a consumer repository | GITHUB_TOKEN | contents read |
| `site-e2e.yml` | Run the Playwright end-to-end tests of a Zola and Worker site, called by a consumer repository | GITHUB_TOKEN | contents read |

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

The token is minted once per run, after the check rounds, only when the outcome is a pull request or
a draft. It is scoped to the current repository, asks for exactly the three permissions above, and
is used by the push step and the pull request step. The steps that run the model never receive it.
