# Decisions

Each entry is the state in force today: what was decided, why, and what it replaced. What was
read or run to support a decision is in [research/](research/). Not yet built parts are in
[cli.md](cli.md) under **Planned**.

## Scope and hosting

### Framework-agnostic shared repository
The shared workflows rely on GitHub capabilities only. No stack command lives here; a consuming
repository supplies `setup_command`, `check_command` and `test_command` through the caller's
`with:` (filled from repository variables). Conventions stay in the consumer's `AGENTS.md` or
`CLAUDE.md`.

### Public repositories, MIT
All repositories under `becloud-dev` are public and MIT licensed. Why: a study project open to
the community, and the cheapest setup (Free plan; standard runners are free on public
repositories; native gates work there). Replaces: all-private with workflow-enforced gates.
Contributions arrive under the repository license; no CLA.

### The owner starts every AI run
Only the code owner starts an AI run, by a label or a comment that needs write access; the sender
is checked against the `OWNERS` variable. Planners run only by `workflow_dispatch`. Why: issue and
PR text from strangers is untrusted prompt input, and the subscription token is the owner's.

### The AI does not merge
The owner approves and merges. The executor opens the pull request under its own App identity so
the owner can approve it under the native gate. Release is the release PR that release-please
keeps open; merging it tags and deploys.

## State model

### Types, Priority field, labels, milestones
- Kind of work: org issue types (Task, Bug, Feature).
- Priority: the org issue field with GitHub's default options Urgent, High, Medium, Low (written
  by option name; `PRIORITY_FIELD_ID` comes from a caller variable). Replaces `P1` to `P5`.
- Labels only for routing: `triage` (start, removed at the end), `needs-info`, `RELEASE` and
  `UX/UI` (persist; start a run on `labeled`), `READY TO LIVE`, `release-blocker`.
- One milestone per release, named by order and theme (`R1: <theme>`); the tag is
  release-please's.
- Projects v2 is not written by automation (`GITHUB_TOKEN` cannot reach it).

### Priority is judged by business impact
A business-critical flow stopped or corrupted (purchase, payment, sign-in, submission, data loss
or exposure) is `Urgent`; a broken control outside a critical flow is not. A stated workaround
moves a stopped flow to `High`; silence about one moves nothing. The comment carries separate
evidence for type and priority, and a missing field aborts before any write.

### Plans are issue comments
The development plan is an issue comment with a marker line, not a repository file. The owner's
approving comment (`/approve`) starts execution.

## Runtime and cost

### Subscription authentication, no usage credits
`CLAUDE_CODE_OAUTH_TOKEN` (organization secret). Usage credits stay off: the plan allowance is the
ceiling. Models are pinned by full ID, never aliases; Fable is not used. Each run records its
tokens per model and stage, so a Bedrock cost can be inferred later. Bedrock is skipped for now.

### Monitoring record
One record per run: repository, workflow, stage, issue or PR, run ID and attempt, model, auth,
error flag, turns, durations, per-model tokens and `costUSD`/`costBasis`. No prompt, result text
or tool output. Stored in the job summary and a 90-day artifact; cross-run totals by hand.

### Pinned actions
Third-party actions are pinned by commit SHA. A composite action of this repository is referenced
with `$/.github/actions/<name>` so it runs at the same commit as the workflow.

## The CLI

### Core logic lives in a Rust CLI in this repository
The crate is `cli/` (`wf`), so a caller on `@v0` gets workflows and CLI from one commit. Agents
find, the CLI enforces, the owner approves the rule: an agent finding becomes an enforced rule
only when the owner accepts it, with a test. Workflow files keep triggers, the job split,
identities and tokens. Replaces: shell and `jq` in YAML, and the earlier plan of a Rust binary
for lint and scope checks only.

### The CLI makes every agent call
A pinned `claude -p` with `--restricted`, explicit `--tools` and `--allowedTools`, its own
`--settings`, `--json-schema`, `--output-format json`, `--no-session-persistence` and stdin from
`/dev/null`; a missing `structured_output` is retried once. `claude-code-action` leaves the
workflows. Why: a step runs the same locally and in CI, and a default `claude -p` runs the
checkout's project hooks and reads its `CLAUDE.md`. Replaces: keep claude-code-action.

### One role per agent call
A step that needs two roles makes two calls; the handoff is a file the CLI validates against a
schema. Output schemas forbid additional properties.

### Storage and runner interface, GitHub first
The CLI defines a storage interface with a GitHub-only backend first. AWS (DynamoDB for run
state, OIDC only, no stored keys) is decided with the increment that adds that backend.

### Release cadence
Each step that moves to the CLI is released on its own. 0.3.0 is the crate, its CI and the
backlog planner.

## Repository rules

### Ruleset on `main`
Pull request required (squash only, 0 approvals); `Workflow tests`, `zizmor audit` and `Rust CLI`
required from GitHub Actions; force-push and deletion blocked; admins bypass on pull requests only.
`release-gate` is not required until it reports on every pull request.

### Hand-built pull requests until the CLI executor ships
The issue comes first and gets `triage`, never `RELEASE`; the pull request says it was built by
hand and closes the issue. Pushes and merges are the owner's call.

### Fixtures for the executor
Two cases only, built with the CLI executor increment.

- Forged plan (#65) is red on `v0`, green on the CLI. On `v0` the publish job reads "the last bot
  `<!-- dev-plan -->` comment" with no pin, so a bundle adding a workflow the owner never approved
  is published once the rounds edit or repost that comment; the gate's `(comment id, sha256)` pin,
  re-checked by `publish-check`, refuses it. The red half runs `v0`'s own step
  (`tests/executor-fixtures/run.sh`); the green half is `cli/tests/executor_publish.rs`.
- `BASH_ENV` injection (#55, #56, #61) is a regression **pin**, not a v0-red case. The push and
  pull request run in a separate publish job that runs no consumer command, and this job split
  shipped in 0.3.0 — so injected `GITHUB_ENV`/`GITHUB_PATH` entries already cannot reach the
  token-holding steps on `v0`. The fixture pins that isolation (publish needs the no-code gate,
  runs no round or command, and trusts only the gate's pins) so a later change cannot regress it.

### The scope check covers `.github/actions` (#53)
A file added or modified under `.github/actions` must be named in the plan's **Files** list, the
literal match `.github/workflows` has; the round's scope step and `publish-check` both judge it. Why:
the executor App's push starts the pull request's `pull_request` runs, which resolve a local action
at the pull request's commit with the secrets its caller passes, before any review
(`docs/research/github-platform.md`, "Local actions and secrets before review"). The `workflows`
permission request still follows `.github/workflows` only. Replaces: the workflows directory alone.

### `triage-sandbox` is archived
Changes are tested on `workflows`. The repository's open release PR and test issues are frozen
with it.
