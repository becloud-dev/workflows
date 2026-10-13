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

| Suite | What it covers |
|---|---|
| `bootstrap` | `templates/consumer/bootstrap.sh`: arguments, reads before writes, dry run |
| `callers` | every template caller against the inputs, secrets and permissions of its reusable workflow (no broader scope, a workflow-level block); every permissions entry in the workflows, actions and templates has a reason comment |
| `dev-execute` | gate, publish decision, pull request and findings of `dev-execute.yml` |
| `dev-plan-post` | "Post the plan" of `dev-plan.yml`: structure, security links, refusal comment |
| `dev-round` | tools, commands and verdict steps of the `dev-round` composite |
| `dev-round-red` | the red check: new tests must fail on the base tree |
| `record-run` | what a run record holds and how it is named |
| `release-config` | the release-please config of the repository and the consumer template: `bump-minor-pre-major` is set, the manifest is still 0.x |
| `release-gate` | owner label, blockers, stale or edited review; also mutates the step |
| `release-issues` | approval gate and issue creation |
| `release-please-tag` | moving the major tag after a release |
| `release-review` | the command gate and the review comment |
| `zizmor-audit` | the zizmor job of `ci.yml`: the audit (workflow files, actions and consumer templates are read) and the comparison of findings, the path filter, fail-closed reports |

A suite named like a step is the place to add a case when that step changes: write the case, see it
fail, then change the step.
