# Research: Claude Code, models and agent calls

What was read and tested about claude-code-action, `claude -p`, the Agent SDK, models and billing, monitoring and subscription terms.

Moved from the former `third-party-review.md` and the CLI design draft, entries kept as written. Decisions in force are
in [decisions.md](../decisions.md); where a later entry corrects an earlier one, the entry says so.
Each entry names its sources, marks inference, and lists what is unverified.

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
`claude-sonnet-5`), settled in #19. `docs/usage.md` and `docs/faq.md` read in the monitoring subsection below: no cost content, and nothing on `gh pr create` in automation mode.

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

### Monitoring and metrics, read 2026-10-11

Sources: `anthropics/claude-code-action` at commit `1d6de8c` (`action.yml`,
`base-action/src/run-claude-sdk.ts`, `base-action/src/execution-file.ts`,
`src/entrypoints/run.ts`, `src/entrypoints/update-comment-link.ts`,
`src/entrypoints/format-turns.ts`; `docs/usage.md` and `docs/faq.md` now read, no cost content);
`code.claude.com/docs/en/{costs,monitoring-usage,analytics,headless,github-actions}.md` and
`.../agent-sdk/cost-tracking.md` (raw markdown); `github/rest-api-description` OpenAPI
(`api.github.com.json`); `github/docs` raw `content/` files for billing, workflow commands,
limits and Projects.

| Topic | Finding |
|---|---|
| Action outputs | `conclusion`, `execution_file`, `branch_name`, `github_token`, `structured_output`, `session_id`. No cost or token output |
| Execution file | `claude-execution-output.json` in `RUNNER_TEMP`: the full SDK message array, last element is the `result` message. Contains tool results, so not uploaded raw |
| Default log | Sanitized: `duration_ms`, `num_turns`, `total_cost_usd`, `permission_denials_count`, and `modelUsage` reduced to `contextWindow` and `maxOutputTokens` (token usage and cost per model are hidden on purpose). `show_full_output: true` prints everything and is unsafe on public logs |
| Step summary | `display_report` default `"false"`; when on, `format-turns.ts` renders per-turn token usage and `Cost` and `Duration` |
| Tracking comment | `update-comment-link.ts` reads `total_cost_usd`, `duration_ms`, `duration_api_ms` from the last element of the execution file |
| Cost meaning | `total_cost_usd` and `costUSD` are client-side estimates from a bundled price table, "not authoritative billing data"; `-p` JSON output carries the same; a resumed session reports the conversation total |
| Subscription | Docs: the `/usage` session cost "isn't relevant for billing" for Pro and Max, and is computed locally at list price. Nothing states that an OAuth run omits it |
| OpenTelemetry | `CLAUDE_CODE_ENABLE_TELEMETRY=1`; metrics `claude_code.cost.usage` (USD) and `claude_code.token.usage` (by `type`, `model`); exporters `otlp`, `prometheus`, `console`, `none`; `console` writes to stderr under `-p`. Needs a collector to be useful |
| Analytics | Teams and Enterprise dashboards, the Console dashboard and the Analytics API do not cover an individual Pro or Max subscription |
| Run and job timing | `GET /repos/{o}/{r}/actions/runs/{id}/jobs` and `.../jobs/{id}` return `started_at`, `completed_at`, per-step times, `runner_name`, `labels`, `run_attempt` |
| Billable minutes | `GET .../runs/{id}/timing` (`billable.UBUNTU.total_ms`, `run_duration_ms`) is marked "closing down" in the OpenAPI text; "billable minutes only apply to private repositories". Org usage report `GET /organizations/{org}/settings/billing/usage` needs the enhanced billing platform and an org admin; summary endpoint is public preview |
| Public repos | Actions usage is free for public repositories on standard hosted runners (`billing/concepts/product-billing/github-actions.md`); minutes are time, not money, for this org |
| Job summary | `GITHUB_STEP_SUMMARY`, 1 MiB per step, at most 20 summaries per job, secrets masked; survives as long as the run |
| Artifacts | `retention-days` 1 to 90, default per repo or org setting; share an allowance with Packages on private repos |
| Projects v2 | Number and text fields exist; `updateProjectV2ItemFieldValue` takes `{ text }` or `{ number }` and needs an item added first (`addProjectV2ItemById`); token needs `project` scope or an App with Projects permission |

Implications (inference):

- The caller workflow, not the Action, must collect metrics: one `jq` step on `execution_file`
  that keeps only the `result` message fields (`total_cost_usd`, `duration_ms`, `duration_api_ms`,
  `num_turns`, `is_error`, `modelUsage`) and drops everything else. `modelUsage` is the field
  the SDK types name for token and cost accounting; `usage` is the main loop only.
- Minimal GitHub-native design: that record goes to the job summary (always), and to an artifact
  or a number field only if cross-run totals are wanted. Stage and model come from the caller
  inputs already decided, so the record carries `stage`, `model`, `run_id`, `issue`.
- For this study, `total_cost_usd` is a list-price equivalent, which is the useful comparison
  against Bedrock later; it is not what the subscription charges (nothing per token).

Read 2026-10-11 (SDK types, `@anthropic-ai/claude-agent-sdk@0.3.296`, the version range the
Action pins): `ModelUsage` carries `inputTokens`, `outputTokens`, `thinkingTokens?`,
`cacheReadInputTokens`, `cacheCreationInputTokens`, `webSearchRequests`, `costUSD`,
`canonicalModel?`, `provider?` and `costBasis?` (`list`, `managed`, `unknown`). Both billing
usage endpoints answer `200` with `usageItems: []` for `becloud-dev` (Free plan, no repos).

Unverified (needs a live run): whether an OAuth run fills `total_cost_usd` and `modelUsage`
with values; whether the billing usage endpoints return rows for a public repo on the Free
plan; Projects v2 writes with an App token from a workflow step; whether `display_report`
output fits the 1 MiB step limit on long runs.

#### Decisions: monitoring record (user, 2026-10-11)

- Fields per record: `ts`, `repo`, `workflow`, `stage`, `issue_or_pr`, `run_id`, `run_attempt`,
  `model` (pinned ID passed by the caller), `auth` (`oauth`, `api_key`, `bedrock`), `is_error`,
  `num_turns`, `duration_ms`, `duration_api_ms`, `total_cost_usd`, and per model `inputTokens`,
  `outputTokens`, `thinkingTokens`, `cacheReadInputTokens`, `cacheCreationInputTokens`,
  `costUSD`, `costBasis`. No prompt, result text or tool output.
- Storage: job summary always, plus a JSON artifact with `retention-days: 90`. No issue comment
  and no metrics branch for now; revisit once real data shows what is worth keeping.
- Producer: one composite action in the shared repo, called after the Claude step by each
  stage workflow, so the `jq` logic exists once.
- Failed and cancelled runs record too (`if: always()`); a run killed before any result message
  records zeros and the job conclusion only.
- Cross-run totals: a documented `gh run download` and `jq` command, run by hand; no
  aggregation workflow until data exists. (Round 2, default accepted if no change.)

Composite action reference (read raw, `workflow-syntax.md`): `./path` resolves against the
caller's workspace, so it fails from a reusable workflow called cross-repo. `$/path/to/action`
resolves to the repository of the file it appears in, at the running commit, with no checkout
and no `@ref`; not on GHES. Fallback: `becloud-dev/workflows/.github/actions/<name>@<ref>`.
Unverified: `$/` from a reusable workflow called cross-repo on a hosted runner; the release
date and minimum runner version (2.336.0) came from a search result, not read raw.

### Agent SDK, `claude -p` and claude-code-action (read 2026-10-12)

Source read: this repository, `.github/actions/dev-round/action.yml:40-47` (the allowlist step)
and `.github/workflows/dev-execute.yml:112-113` (the branch-exists stop); the Claude Code
documentation and the claude-code-action source on the points below. The documentation paths
and commits are not recorded here (see "Not verified").

Facts read:
- The executor allowlist is `CHECK_COMMAND` and `TEST_COMMAND` plus plain `git add`, `commit`,
  `status`, `diff`, `log` and `rm`. Test suites, `python3`, `git -C` and `docker` are denied;
  a compound command is matched per subcommand.
- The executor stops when the branch of the issue already exists; it does not continue there.
- claude-code-action already runs on the Agent SDK; `claude_args` goes to the SDK options and
  to the CLI `extraArgs`.
- A hard allowlist is the allow rules together with permission mode `dontAsk`.
- `--bare` ignores `CLAUDE_CODE_OAUTH_TOKEN` and is to become the default for `-p`.
- `--max-budget-usd` can overshoot; the reported costs are estimates.
- A `PreToolUse` hook can deny a tool call.
- `actions/setup-node` v7 caches unless `package-manager-cache: false`.

Decisions (user, 2026-10-12; superseded 2026-10-13 by the agent-call decision in decisions.md): keep claude-code-action; a Rust binary for plan lint, scope
check, verdict and run records; the Python and TypeScript SDKs are not adopted for now.

Filed through the flow: #34 (plans fit the executor commands and the tool defaults) and #35
(the executor continues on an existing branch).

Inference: the SDK adds nothing the action does not already expose through `claude_args`; a
`--bare` default would break subscription authentication in CI until the token path changes.

Not verified: that `claude_args` passes `--permission-mode` and `--settings`; the date of the
`--bare` default; workload-identity federation on a subscription account; the CLI version the
pinned action installs; the documentation paths and commits for the facts above.


### Agent calls from the CLI: Agent SDK, `claude -p`, claude-code-action (read 2026-10-13)

Question (owner, 2026-10-13, after the review of #74): the CLI runs the agent calls itself, so a
step runs the same way locally and in CI and is testable through the CLI; the workflow only
orchestrates. This reopens the 2026-10-12 decision (keep claude-code-action, no SDK).

Sources read: code.claude.com `docs/en/agent-sdk/overview`, `docs/en/headless`,
`docs/en/authentication`, `docs/en/cli-reference` (raw pages); claude-code-action at the pinned
`1d6de8cb` (`base-action/src/run-claude-sdk.ts`, `parse-sdk-options.ts`); a docs.rs search.

Facts read:
- The Agent SDK is Python and TypeScript only. "To drive the same agent loop from a language other
  than Python or TypeScript, run the CLI as a subprocess with the `-p` flag and `--output-format
  json`." The SDK is "a library that runs the Claude Code binary".
- No official Rust crate; several community crates (`claude-agent-sdk`, `cc-agent-sdk`,
  `rusty_claw`, ...) wrap the same CLI subprocess. Maintenance and licences not checked.
- The pinned claude-code-action calls `query()` from `@anthropic-ai/claude-agent-sdk`
  (`run-claude-sdk.ts:4,190`): the action is a GitHub wrapper over the TypeScript SDK, which runs
  the CLI.
- `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`, one year, subscription) is documented "for
  CI pipelines and scripts". `--bare` does not read it ("In bare mode, Claude Code never reads OAuth
  credentials"), and "`--bare` ... will become the default for `-p` in a future release".
- Without `--bare`, "a `-p` session runs the hooks in a project's `.claude/settings.json` and
  connects the servers in its `.mcp.json`, even in a folder you've never trusted".
- claude-code-action defaults `settingSources` to `["user", "project", "local"]` unless
  `--setting-sources` is passed (`parse-sdk-options.ts:338-343`); no workflow in this repository
  passes it (grep).
- Flags for a locked-down call: `--json-schema` with `--output-format json` (result in
  `structured_output`, with usage, `total_cost_usd` and a per-model breakdown, client-side
  estimates); `--permission-mode dontAsk`; `--permission-prompts none`; `--tools`;
  `--allowedTools`; `--setting-sources`; `--strict-mcp-config`; `--settings`; `--max-turns`;
  `--max-budget-usd`; `--no-session-persistence`; `--safe-mode` (customisations off,
  "Authentication, model selection, built-in tools, and permissions work normally, which differs
  from `--bare`"); `--restricted` (only managed settings and `--settings`, no command tools unless
  named in `--tools`). `claude auth status` reports `authMethod` (`oauth_token`, ...).
- Agent SDK note: "Unless previously approved, Anthropic does not allow third party developers to
  offer claude.ai login or rate limits for their products, including agents built on the Claude
  Agent SDK."

Inference (not verified):
- The CLI can own every agent call by spawning a pinned `claude -p` with explicit flags: the route
  the docs give for other languages, the same binary the action runs today. Tests stub `claude`
  with recorded JSON as the suites stub `gh` now; a local run uses the owner's login.
- A Python or TypeScript SDK sidecar adds a second runtime for in-process callbacks
  (`canUseTool`) that `--permission-mode dontAsk`, `--allowedTools` and hooks in `--settings`
  already cover.
- Using the owner's own token on the owner's repositories is not offering a login to third
  parties; callers outside the owner would bring their own token, as with the action today.
- On `v0`, an agent call loads the checkout's `.claude/settings.json` hooks. In the rounds job the
  execute call writes files in that checkout before the check call runs there: the #55 class
  (round content reaching a later step). Not reproduced.

Reliability today (owner's question, 2026-10-13; the `--bare` default is left for later):
- Run history of the agent workflows on `workflows` (`gh run list`, last 100 each): 112 success,
  7 failure. Failed steps (`gh run view --log-failed`): 4 in our own shell steps (two `Push the
  branch`, one `Post the plan`, one `/approve` gate refusal by design); 2 model outputs refused by
  our check ("the issue list is not valid", release-issues); 1 in the action: "--json-schema was
  provided but Claude did not return structured_output. Result subtype: success" (dev-plan run
  38295496819). No failure in the action's install, auth or SDK.
- The pinned action installs Bun 1.3.14 and runs `bun install --production` (no
  `--frozen-lockfile`); `bun.lock` locks `@anthropic-ai/claude-agent-sdk` 0.3.296 with a hash and
  its platform packages. Its argument parser once widened `--allowedTools Bash(gh:*)` to `Bash`
  silently (comment in `parse-sdk-options.ts`, fixed by escaping): a layer between our flags and
  the binary that a direct call does not have.
- Inference: the action is the only path with measured runs here; a direct `claude -p` runs the
  same binary with one layer less and lets the CLI retry a missing `structured_output` itself, but
  has no runs in this pipeline yet.

Local test (2026-10-13, owner's go): the backlog planner step through `claude -p` 2.1.296 (the
action's SDK is 0.3.296), Haiku 5.5, the claude.ai login (Pro). Scratch copy: the real prompt and
schema, the input built by the workflow's own `jq` from live issues (25 ranked), a planted
`.claude/settings.json` with `SessionStart` and `PreToolUse(Read)` hooks that touch a marker, and a
`CLAUDE.md` asking for a canary word. Flags in every run: `--allowedTools Read --permission-mode
dontAsk --output-format json --json-schema <the workflow's schema> --no-session-persistence`.

| Variant | Exit | `structured_output` | Workflow validation | Project hooks ran | `CLAUDE.md` canary | Turns | Cost (estimate) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| default | 0 | yes | pass | both | yes | 6 | $0.0148 |
| `--setting-sources user` | 0 | yes | pass | none | no | 4 | $0.0094 |
| `--safe-mode` | 0 | yes | pass | none | no | 5 | $0.0089 |
| `--restricted --tools Read` | 0 | yes | pass | none | no | 6 | $0.0079 |
| `--bare` | 1 | no | n/a | n/a | n/a | 1 | $0 ("Not logged in · Please run /login") |

- A default `claude -p` runs the checkout's project hooks and reads its `CLAUDE.md`: the binary
  behaviour behind the `v0` finding above (the action's default `settingSources` includes
  `project`). Reproduced on the binary, not through the action.
- The canary is one sample per variant: a missing word may be the model's choice; the hook markers
  are deterministic.
- Each call waited 3 s for stdin ("no stdin data received in 3s"): the CLI passes `< /dev/null`.
- `--restricted` is the documented mode for a harness that must not read user or project settings;
  the executor would name `Bash` in `--tools` explicitly.

Not verified (gaps, need a live run):
- `CLAUDE_CODE_OAUTH_TOKEN` with these flags: the local runs used the claude.ai login; the token
  needs `claude setup-token` or a CI run.
- When `--bare` becomes the default for `-p`, and whether an opt-out keeps OAuth.
- Whether `--setting-sources` accepts an empty list.

### CLI increment 1: live results (2026-10-14, PR #83)

Run 38492096576 (`local-planner-backlog` on the PR branch): `CLAUDE_CODE_OAUTH_TOKEN` with
`--restricted` and the flags of section 2 works in CI (`auth` `oauth_token`; order and duplicate
calls passed on the first attempt, 3 turns each, no denial; 15 issues ranked; estimate $0.0060).
Build per job: `cargo build --release --locked` 51.8 s on the runner (16.0 s on 16 local cores,
3.8 s without `jsonschema`); toolchain download 8.3 s, because the runner image does not hold
`1.99.0` under that name (the plan's claim that it did was wrong); `Rust CLI` job 48 s. After the
fix (`rustup toolchain install --no-self-update`, commit `6cc0ca3`; without the flag it also
self-updates rustup), run 38495372554: build 34.5 s, `Set up the CLI` 45 s, `Rust CLI` job 41 s;
the build time varies by about 50% between runners. Owner, 2026-10-14: keep `jsonschema`, measure
again when the executor moves.

Not exercised: the sub-issue and dependency endpoints (no open issue has either); GitHub's
permissions reference lists their `GET` under "Issues" read for installation tokens (docs).

Found while recording the fixture: without `additionalProperties: false`, `structured_output`
carried keys the schema did not name; the CLI's schemas forbid them.
