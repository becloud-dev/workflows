# Workflow tests

Every suite runs the real `run:` blocks of the workflows and actions in this repository, extracted from
the YAML at test time, against stub `gh` and `git push`, on the jq version the runner image has (1.7.1).
Nothing is mocked in the block under test, so a change to a block is tested as written.

```
bash tests/run-all.sh          # all suites; exit 1 when one fails
bash tests/<suite>/run.sh      # one suite
```

Needs `bash`, `git`, `curl`, `python3` with PyYAML, `sha256sum`. When the local `jq` is not 1.7.1, the
upstream binary is downloaded to `tests/.cache/jq` and its SHA-256 is verified before use.

The CLI under `cli/` has its own tests, run by the `Rust CLI` job: `cargo test --locked` in `cli/`,
against stub `claude` and `gh` (`cli/tests/bin`) answering with recorded real output, and against real git
history for the executor (`cli/tests/executor_*.rs`). The steps that moved to the CLI keep only a wrapper
test here; their cases are those cargo tests.

| Suite | What it covers |
|---|---|
| `agent-calls` | every claude-code-action call left passes `--setting-sources user` (#78); the checker fails on a missing, widened or repeated flag; the steps moved to the CLI (backlog planner, the executor's gate and rounds) make no claude-code-action call and run `wf` |
| `bootstrap` | `templates/consumer/bootstrap.sh`: arguments, reads before writes, dry run |
| `callers` | every template caller against the inputs, secrets and permissions of its reusable workflow (no broader scope, a workflow-level block); every permissions entry in the workflows, actions and templates has a reason comment |
| `dev-execute` | the gate and decide steps' calls to `wf`, the findings comment of `dev-execute.yml`; the job split (the token only in `dev-publish`), the bundle verify, the push from the bundle against planted hooks and config, the pull request; the pin and base outputs the publish check reads |
| `dev-plan-post` | "Post the plan" of `dev-plan.yml`: structure, security links, refusal comment |
| `dev-publish-scope` | "Check the bundle against the plan" of `dev-publish`: its call to `wf executor publish-check` with the gate's pin, and that a refusal or a CLI that cannot run fails the step |
| `executor-fixtures` | the forged-plan regression (#65) on a production-shaped bundle: `v0`'s own publish step accepts a plan comment the rounds edited to name an unapproved workflow (red), while `cli/tests/executor_publish.rs` shows `publish-check` refuses it on the pin (green); and the `BASH_ENV` isolation pin (#56): the publish job needs the no-code gate, runs no round or consumer command, and trusts only the gate's pins |
| `dev-round` | the commands step of the `dev-round` composite; the execute, check and verdict steps' calls to `wf` (the pinned claude first on `PATH`, the token, a failing call fails the step, the check call gets no consumer command) |
| `dev-round-scope` | the scope step's call to `wf executor scope`; a failing or missing CLI leaves `scope_state=error` |
| `dev-round-red` | the red step's call to `wf executor red`; a failing CLI leaves `red_state=error` |
| `planner-backlog` | "Plan the backlog" of `planner-backlog.yml` (wf's exit status is the step's, the summary and the record reach the step summary) and the `setup-cli` composite (the Claude Code binary is used only when its SHA-256 and version match; the toolchain is installed explicitly, then the CLI is built `--release --locked`) |
| `record-run` | what a run record holds and how it is named |
| `release-config` | the release-please config of the repository and the consumer template: `bump-minor-pre-major` is set, the manifest is still 0.x |
| `release-gate` | owner label, blockers, stale or edited review; also mutates the step |
| `release-issues` | approval gate and issue creation |
| `release-please-tag` | moving the major tag after a release |
| `release-review` | the command gate and the review comment |
| `zizmor-audit` | the zizmor job of `ci.yml`: the audit (workflow files, actions and consumer templates are read) and the comparison of findings, the path filter, fail-closed reports |

A suite named like a step is the place to add a case when that step changes: write the case, see it
fail, then change the step.
