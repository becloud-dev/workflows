# The `wf` CLI

The CLI in `cli/` holds the deterministic work of the workflow steps and makes every agent call.
The workflow files keep triggers, the job split, identities and tokens ([stages.md](stages.md)),
set up the CLI and run it.

## Principle

- Agents read, judge, write code and tests, search, and propose criteria. One role per agent call:
  a step that needs two roles makes two calls, and the handoff is a file the CLI validates against
  a schema.
- The CLI fetches the inputs, validates each agent output against its schema and the rules,
  enforces the rules and records the run. A rule the CLI enforces leaves the prompt.
- Agents find, the CLI enforces, the owner approves the rule. A finding becomes an enforced rule
  only when the owner accepts it; the rule then lives in the CLI with a test. No agent output is
  a gate.

## Shipped (0.3.0)

| Command | What it does |
| --- | --- |
| `wf planner backlog --repo <owner/repo> --model <id> --out <dir>` | Orders the open issues and reports parents, blockers, duplicates and gaps. Writes nothing on GitHub |
| `wf executor gate --repo <owner/repo> --issue <n> --owners <logins> --plan-file <f> --github-output <f>` | Reads an `/approve` comment (body in `COMMENT_BODY`): replies on the issue when it refuses, otherwise writes the plan and pins it (comment ID and body SHA-256). Replaces the gate shell step |
| `wf executor test-write --repo <owner/repo> --issue <n> --round <n> --model <id> --plan-file <f> --findings-file <f or none> --work-dir <d> --github-output <f>` | The test-writer call: the pinned `claude` in the checkout with the file tools and the plain git commands of a commit (no consumer command); writes and commits the plan's tests. Reads copies of its inputs |
| `wf executor implement --repo <owner/repo> --issue <n> --round <n> --model <id> --plan-file <f> --findings-file <f or none> --work-dir <d> --github-output <f>` | The implementer call: like the test-writer, plus the consumer's check and test commands (`CHECK`, `TEST`); writes and commits the change so the tests pass. May not edit the test files (the `scope` step enforces it) |
| `wf executor check --repo <owner/repo> --issue <n> --round <n> --model <id> --plan-file <f> --results-file <f> --base <sha> --work-dir <d> --github-output <f>` | The check call: read-only tools and `git diff`/`git log`; a verdict that contradicts its findings is asked again once |
| `wf executor plan --repo <owner/repo> --issue <n> --plan-comment-id <id> --plan-sha256 <h> --plan-file <f>` | Writes the plan the gate pinned for the rounds job, which runs on another runner; refuses a comment that changed after the approval |
| `wf executor scope --base <sha> --plan-file <f> --results <f> --github-output <f>` | Judges a round's deletions and workflow changes against the plan's Files list, and refuses a test file the implementer changed (`TEST_BOUNDARY`, the commit after the test-writer, and `TEST_PATHS`); fails closed. Replaces the `scope` shell step |
| `wf executor red --base <sha> --round <n> --work-dir <d> --results <f> --github-output <f>` | Runs the test command (`TEST`) on the checkout after the test-writer's commit, with the tests present (`TEST_PATHS` globs) and no implementation; they must fail (`red`), a pass is `green_without_impl`. Replaces the `red` shell step |
| `wf executor verdict --round <n> --findings-file <f> --github-output <f>` | The round's verdict from the implementer and check outputs and the recorded results; failing commands, tests green without the implementation, scope violations and unmet criteria force fail. Replaces the `verdict` shell step |
| `wf executor decide --base <sha> --work-dir <d> --github-output <f>` | Pull request, draft or comment from the last round; bundles the commits from a fresh git dir with no global or system git config read. Replaces the `final` shell step |
| `wf executor publish-check --repo <owner/repo> --issue <n> --plan-comment-id <id> --plan-sha256 <h> --base <sha> --git-dir <d> --github-output <f>` | Refuses a bundle whose plan comment changed after the approval, or whose changes the plan does not name; says whether the push needs the workflows permission. Replaces the publish plan-check shell step |

### Agent calls

Every agent call spawns a pinned `claude -p` with `--restricted`, explicit `--tools` and
`--allowedTools` from the call's scope (the planner's calls: `Read` only, in a directory holding
only their inputs; the executor's: see the commands above; probes in `research/claude-code.md`),
its own `--settings`, `--json-schema`, `--output-format json`, `--no-session-persistence` and stdin from `/dev/null`. A missing `structured_output` is retried
once. The CLI validates the output against the schema (additional properties forbidden) and the
rules, and writes a run record with tokens per model.

### Backlog planner rules

The CLI passes each issue's parent, open sub-issues and blocked-by/blocking links to the planner
and enforces on the `order` it gets back:
- a parent with open sub-issues is not ranked as work but listed with its open children;
- an issue blocked by an open issue in the same tier ranks after it; a conflict across tiers is
  named, not reordered;
- `categorize` and `gaps` name only issues in the input.

The planner is two calls (order, duplicates). Claims in an issue are not checked against the
repositories; the report says they are unverified.

### Build and CI

The `Rust CLI` job runs `cargo fmt --check`, `cargo clippy --locked -- -D warnings`,
`cargo test --locked` and `cargo deny check`, with the toolchain pinned in `rust-toolchain.toml`.
A caller's job builds the CLI from source at `job.workflow_sha` with `--locked` through the
`setup-cli` composite action. Measured on a runner: build 34.5 s to 51.8 s, depending on the
runner.

## Planned

Each step moves to the CLI as its own increment and its own release. The executor goes alone.

Each step has a review issue that holds the accepted review; its open sub-issues stay open.

| Step | Review issue | Open sub-issues |
| --- | --- | --- |
| triage | #67 | none |
| dev-plan | #66 | #20, #21, #34, #42 |
| dev-execute, rounds | #68 | #35, #53, #54, #57 (#47 and #62 closed: done, duplicate of #57) |
| dev-execute, publish | #69 | #56, #59, #63, #65 (#46 and #52 closed) |
| release-please | #70 | none |
| release-review | #71 | none |
| release-issues | #72 | none |
| release-gate | #73 | none |
| planner-backlog | #74 | #16 (stays open until the CLI planner ships) |
| planner-roadmap | #75 | none |
| ux-ui | #76 | none |
| ci | #77 | the consumer `pr-checks.yml` gap (#79) |

#78 (agent calls loaded the checkout's hooks) was fixed on `v0` with `--setting-sources user`.

| Step | Commands | What moves |
| --- | --- | --- |
| triage | `triage format-check` and the classify, split and rewrite calls | The CLI fetches the issue so the agent has `Read` only and no token; it verifies a rewrite keeps every word and reads back its writes |
| dev-plan | `plan gate`, `plan input`, `plan validate`, `plan render` | A research call (domains the repository lists, empty by default), a planner call and a plan reviewer call; every failed rule is named and the plan retried once |
| dev-execute, publish | publish commands | The CLI recomputes the verdict from the recorded results instead of reading the rounds job's `verdict` output |
| release-please | `release tag` | The major tag move, with the same checks; the token and trigger stay in YAML |
| release-review | review commands | A correctness call and a safety call, merged by the CLI with blocking findings first; the review is identified by a `release-review` commit status on the reviewed commit, whose description is the comment body's hash |
| release-issues | issue commands | No agent call: findings are read from a hidden JSON block in the pinned comment; owners change findings only through `/reject` with a reason |
| release-gate | gate commands | A current review is required before `release-gate` is success; a missing and a stale review both fail |
| planner-roadmap | roadmap commands | Takes the backlog's validated order and checks that releases follow it; the error-budget hold applies before the call; `roadmap apply` finds a milestone by title before creating it |
| ux-ui | ux and ui commands | The CLI fetches the issue and comments; rules: `design_system_used` is true exactly when a design system path is given, token and component `source` is a heading, an existing file or `new`, every UX screen element appears in the layout, the layout is at most 30 lines |

### Test fixtures (with the executor)

Two cases (`tests/executor-fixtures/run.sh`, with `cli/tests/executor_publish.rs`), on a
production-shaped bundle:
- Forged plan (#65) — red on `v0`, green on the CLI. The rounds edit or repost the
  `<!-- dev-plan -->` comment to name a workflow the owner never approved. `v0` reads "the last bot
  comment" with no pin and publishes it (the suite runs `v0`'s own step and shows it accepts); the
  gate's `(comment id, sha256)` pin, re-checked by `publish-check`, refuses it (the cargo tests).
- `BASH_ENV` (#55, #56, #61) — a regression pin, not a v0-red case. The check and test commands can
  append `BASH_ENV`/`GITHUB_ENV`/`GITHUB_PATH` entries, but the push and pull request run in a
  separate publish job with no consumer command and no round, trusting only the no-code gate's pins;
  that job split shipped in 0.3.0, so the injection already cannot reach the token on `v0`. The
  fixture pins the isolation so a later change cannot regress it.

### Storage backend

A storage and runner interface with a GitHub backend first. A DynamoDB backend (run state written
by a role the rounds job cannot assume) is decided with its own increment; see
[research/aws.md](research/aws.md).

Why each choice: [decisions.md](decisions.md).
