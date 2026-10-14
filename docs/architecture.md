# Architecture

Shared, framework-agnostic GitHub workflows that take an issue from triage to a release, with an AI
agent at each stage and the owner at each gate. A consuming repository calls them from thin caller
workflows on `becloud-dev/workflows@v0` and supplies its own commands through inputs.

```
issue -> triage -> planning -> [ux/ui research] -> development -> release
```

## Stages

| # | Stage | Workflow | What it does | Owner gate |
| --- | --- | --- | --- | --- |
| 1 | Triage | `triage.yml` | Classifies the type, sets Priority, asks for missing information, fixes the format, splits a non-atomic issue into sub-issues | Applies `triage` to start; applies it again to each sub-issue |
| 2a | Backlog planner | `planner-backlog.yml` | Orders the open issues by priority and flags duplicates and gaps; writes a report only | Starts it (`workflow_dispatch`) |
| 2b | Roadmap planner | `planner-roadmap.yml` | Groups the backlog into releases (milestones), holds features when the bug budget is exceeded; writes only when `apply` is true | Starts it; approves by applying `RELEASE` or `UX/UI` per issue |
| 3 | UX and UI research | `ux-ui.yml` | Posts a UX and a UI comment (stories, requirements, hierarchy, layout, tokens) for `UX/UI` issues | Swaps `UX/UI` for `RELEASE` |
| 4a | Development plan | `dev-plan.yml` | Posts the plan as an issue comment: objective, files, steps, tests, acceptance criteria | Reviews the plan and comments `/approve` |
| 4b | Development execution | `dev-execute.yml` | Runs the rounds (test first, then code), the check, and publishes the branch and pull request | Reviews and merges the pull request |
| 5a | Release PR | `release-please.yml` | Keeps a release pull request up to date; tags on merge | Merges it |
| 5b | Release review | `release-review.yml` | Reviews the release as a whole and lists blocking and deferred findings | Applies `READY TO LIVE` after approving, or rejects |
| 5c | Release issues | `release-issues.yml` | Creates issues from an approved review; blocking ones carry `release-blocker` | |
| 5d | Release gate | `release-gate.yml` | Sets the `release-gate` commit status on the release PR | |
| - | CI | `ci.yml` | Runs the test suites, zizmor and the Rust CLI checks | |

Identity and permissions per workflow are in [stages.md](stages.md).

Release outcomes: a blocking finding becomes a `release-blocker` issue that goes straight to
development; a deferred finding goes through triage and planning.

## State model

| Concept | GitHub mechanism |
| --- | --- |
| Kind of work | Organization issue types: Task, Bug, Feature |
| Priority | Organization issue field Priority: Urgent, High, Medium, Low |
| Atomic split | Native sub-issues (`--parent`) |
| Release | A milestone per release, named `R<n>: <theme>`, with a due date |
| Error budget | Open Bugs over open Bugs plus Features, per repository; above `bug_budget` only Bugs are planned |
| Routing | Labels: `triage`, `needs-info`, `RELEASE`, `UX/UI`, `READY TO LIVE`, `release-blocker` |
| Human gates | Ruleset on `main`, owner-only start signals, the `release-gate` status |

Projects v2 is not written by automation.

## Start signals and trust

- An owner-applied label starts the issue stages; an owner comment (`/approve`, a review request)
  starts the pull request stages. The sender is checked against the `OWNERS` variable.
- Issue and pull request text from other people is untrusted input to every agent call. Agents get
  the smallest tool list their stage needs and no token; writes are made by workflow steps.
- A workflow cannot stop the merge button. The ruleset and the required checks do.

## Consumer contract

A caller on `@v0` passes, from repository variables where they differ per repository:

| Input | Used by | Meaning |
| --- | --- | --- |
| `setup_command`, `check_command`, `test_command` | development | Stack-specific commands; each is also the tool allowlist entry |
| `design_system_path` | ux-ui | Optional file with tokens and components; none means no tokens |
| `release_days`, `max_issues`, `bug_budget`, `max_releases` | roadmap planner | Planning limits |
| `PRIORITY_FIELD_ID` | triage | Id of the organization Priority field |
| `OWNERS` | all | Logins allowed to start a run |

Secrets: `CLAUDE_CODE_OAUTH_TOKEN` (organization secret) and, for the executor, the App key and
client id named in [stages.md](stages.md).

## Where each part runs

- Workflow files: triggers, the job split, identities and tokens.
- Prompts: files under `prompts/`, read from a second checkout at `job.workflow_repository` and
  `job.workflow_sha`, so a prompt and its workflow are always the same commit.
- The CLI (`cli/`, `wf`): the deterministic work and every agent call. See [cli.md](cli.md).

Why it is built this way: [decisions.md](decisions.md). What was checked: [research/](research/).
