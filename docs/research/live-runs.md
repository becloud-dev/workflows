# Research: live runs by stage

Dated results of runs on the sandbox and on `workflows`, by stage, with the interpretation and what stayed unverified.

Moved from the former `third-party-review.md` and the CLI design draft, entries kept as written. Decisions in force are
in [decisions.md](../decisions.md); where a later entry corrects an earlier one, the entry says so.
Each entry names its sources, marks inference, and lists what is unverified.

### Stage design inputs, read 2026-10-11

Sources: `bentoluizv/patagonia-trip` through `gh api` (`CONTRIBUTING.md`,
`.github/pull_request_template.md`, `.github/workflows/{claude-issue-review,claude-pr-review,
release,pr-title}.yml`, `.github/claude/{issue-review,pr-review}.md`); raw `github/docs`
(`about-issue-fields.md`, `managing-issue-fields-in-your-organization.md`,
`adding-and-managing-issue-fields.md`, `events-that-trigger-workflows.md`,
reusable `actions-do-not-trigger-workflows.md`, `about-code-owners.md`,
`managing-github-actions-settings-for-a-repository.md`, `adding-items-automatically.md`,
`src/github-apps/data/fpt-2026-03-10/server-to-server-permissions.json`); raw
`platform.claude.com` model overview and pricing.

| Topic | Finding |
|---|---|
| Patagonia engine | Issue review: `issues` `opened` and `labeled` (label `claude`, removed at the end), skipped when `sender.type == 'Bot'`, `concurrency` per issue number, `timeout-minutes: 15`, `claude-code-action@v1` with `claude_code_oauth_token`, `track_progress: true`, `--model` and `--allowedTools`/`--disallowedTools` in `claude_args`. The prompt only says "read and follow `.github/claude/issue-review.md`" |
| Patagonia PR review | `issue_comment` beginning `@claude review`, `timeout-minutes: 25`, opus. A release PR (head `release-please--*`) is reviewed over `git describe --tags --abbrev=0 HEAD...HEAD`. Normal PRs are not reviewed by Claude unless the owner asks |
| Patagonia gates | A cross-layer issue gets an Options section and code starts after the owner's `Decisão:` comment; a plan the owner approves comes before code for a new entry point, a migration, 3 or more hand-written files, or any change under `.github/workflows/`. Both are prose and local Plan Mode, not workflow logic. A `release-blocker` issue open makes the deploy job fail |
| Patagonia has no | Planner, UX/UI research or DEV workflow. Implementation runs in a local Claude Code session; stage 4 of section 1 has no source to port |
| Patagonia release | `release-please-action@v4` on push to `main`; merging the release PR tags and deploys; `pr-title` uses `amannn/action-semantic-pull-request@v6` with the same type list |
| Issue fields | Org-level, up to 25; types single-select, text, number, date; defaults Priority (Urgent, High, Medium, Low), Effort, Start date, Target date, all editable. Settable from the sidebar, projects, the API or Actions; not from templates or URL prefill; issues only, not pull requests. Docs feature flag `issue-fields` is `fpt: '*'` |
| Issue field events | `issues` types `field_added` (set or changed) and `field_removed` (cleared) start workflows |
| Issue field API | `PUT`/`POST`/`DELETE /repos/{o}/{r}/issues/{n}/issue-field-values`, `GET` the same; `GET`/`POST`/`PATCH`/`DELETE /orgs/{org}/issue-fields`. Values need `issues: write` (and `pull_requests: write` is also listed); the endpoint rows carry `additional-permissions: true`, meaning not read. Field definitions have their own `issue_fields` permission, read or write |
| Other permissions | `POST .../dispatches` needs `actions: write`; merge a pull request needs `contents: write`; create a pull request and create a review need `pull_requests: write` |
| PR creation by token | The repository setting "Allow GitHub Actions to create and approve pull requests" governs whether `GITHUB_TOKEN` can create and approve; new organization repos inherit the organization setting |
| Code owners | "Individuals or teams", with write access; a user or team without it is not assigned |
| Projects on Free | Built-in auto-add workflows: 1 per project on the Free plan; 50 fields per project, issue fields included |
| Prices (API, per MTok) | Haiku 5.5: $0.10 input, $0.50 output up to a 100,000-token prompt; $0.50 and $2.50 above it. Sonnet 5.5: $2 and $10. Opus 5.5: $4 and $20. Fable 5.1: $10 and $50 |

Implications (inference):

- Priority can be an issue field instead of a Projects field: it is writable with the same
  token as labels, and a change to it can start a workflow. Section 2's mapping row "Priority,
  backlog / planned / in progress: Projects v2 single-select fields" is superseded for priority if
  the field exists on the Free org.
- Backlog order is a saved search over the Priority field; no AI run is needed to sort.
- A bot cannot satisfy a required code-owner review, since it cannot be listed as a code owner.
- Reusable stage workflows can be chained with `workflow_dispatch` using `actions: write`;
  other `GITHUB_TOKEN` events do not chain.
- Haiku's price advantage shrinks above 100,000 prompt tokens, which long agentic runs may reach.

Unverified: issue fields on a Free organization (docs convention `fpt`, needs the org settings
page); the meaning of `additional-permissions: true`; whether an approval by `GITHUB_TOKEN`
counts toward a code-owner requirement; whether native auto-merge works on a Free public repo;
`vars` inside a called workflow (the contexts page states nothing); how a called workflow locates
its own repository for a second checkout; Haiku 5.5 behaviour as executor (no measured run).

### Stage design, round 4 inputs, read 2026-10-11

Sources: `bentoluizv/patagonia-trip` through `gh api` (`labels`, `CONTRIBUTING.md`,
`pull_request_template.md`, 6 most recent issues); raw `github/docs`
(`reference/workflows-and-actions/contexts.md`, `how-tos/reuse-automations/reuse-workflows.md`,
`managing-issue-fields-in-your-organization.md`, `data/reusables/actions/workflow-ref-description.md`,
`src/github-apps/data/fpt-2026-03-10/server-to-server-permissions.json`).

| Topic | Finding |
|---|---|
| Called workflow finds its own repository | `job.workflow_repository` is the `owner/repo` of the repository containing the workflow file that defines the current job; `job.workflow_sha` is that file's commit SHA; `job.workflow_ref` "refers to the reusable workflow file" for a job defined in a reusable workflow. The contexts page gives an example reusable workflow that passes the first and second to `actions/checkout` (`repository`, `ref`) to read files co-located with the workflow. Marked unavailable only on GitHub Enterprise Server |
| Context availability | `job` is available in `jobs.<job_id>.steps.with` and `steps.run`. `vars` is available in `jobs.<job_id>.with.<with_id>` (the caller), in steps and in `jobs.<job_id>.if`. `github.workflow_ref` is "the ref path to the workflow"; the page does not say caller or called, and `job.workflow_ref` is described as equal to it for jobs defined directly in a workflow file |
| `vars` in a called workflow | Neither the reusable-workflows page nor the contexts page says whose variables a called workflow reads |
| Patagonia labels | 14 labels: GitHub defaults, `autorelease: pending` / `autorelease: tagged`, `claude` ("Run the Claude issue reviewer", removed when the review ends) and `release-blocker`. No priority, routing or stage labels. The 6 most recent issues have no issue type |
| Patagonia plan and checks | The plan is local Plan Mode, "isn't copied anywhere": the issue keeps the `Decisão:` and the PR body says what was done. No plan file. Checks are `npm run check` and `npm run e2e` |
| Issue field options | Up to 25 fields per org; default fields are editable (name, description, options) or deletable; single-select options carry a name, description and colour; a field is pinned to issue types and "Issues without a type" can be selected; an unpinned field with no value stays hidden. The page states no option-count limit |
| Milestone permissions | `list/get/create/update/delete-a-milestone` sit under the `issues` key (read, write), server-to-server true |

Implications (inference):

- A called workflow reads its prompt files with a second checkout at `job.workflow_repository` and
  `job.workflow_sha`; prompts and workflow file are then always the same commit, and the caller's
  `uses: ...@<ref>` picks both.
- Consumer values travel as `with:` inputs filled from `vars` in the caller, a documented path that
  does not depend on `vars` inside the called workflow.
- The Priority field needs pinning to the issue types in use and to "Issues without a type",
  otherwise it is hidden on typeless issues.
- Milestones and labels need the same `issues: write` as issue fields; no extra App permission for 2b.
- Patagonia has no routing labels, planner or plan file; items 1-3 are design, not a port.

Corrected: the last paragraph of "Stage design inputs" lists "how a called workflow locates its own
repository" as unverified; it is documented above. Still unverified: `job.workflow_sha` populated in
a called workflow on a Free public repo (docs state it; live probe postponed); org issue fields
present (needs the account); option-count limit of a single-select.

### Live results: org issue fields (2026-10-11)

Source: two screenshots from the user, taken 14:49 and 14:50, and two terminal outputs pasted by
the user (`gh api` run with the user's own login, not `GITHUB_TOKEN`).

| Check | Result |
|---|---|
| Org Settings > Planning > Issue fields (`becloud-dev`) | 4 fields listed: Priority, Start date, Target date, Effort |
| `gh api orgs/becloud-dev/issue-fields --jq '.[] \| [.id,.name,.data_type]'` | Priority `48149712` single_select; Start date `48149713` date; Target date `48149714` date; Effort `48149715` single_select |
| Priority field object, same endpoint | 4 options, GitHub defaults: `84291383` Urgent (`priority` 1, pink), `84291384` High (2, red), `84291385` Medium (3, yellow), `84291386` Low (4, green); every option `description` null; `visibility` `organization_members_only`; `created_at` 2026-10-08. Returned in name order |

Implications (inference):

- `PRIORITY_FIELD_ID` is `48149712`. The list endpoint answers on a Free org, so issue fields
  are present there.
- The user keeps the four default options; no `P1` to `P5`. Values are written by option name,
  so the verdict schema and the prompt use Urgent, High, Medium, Low as returned.
- Rank is in each option's `priority` key (1 to 4); response order is alphabetical.
- The API object carries no pin data; pins to issue types are checked in the UI.
- The criticality description per option lives only in the triage prompt, because the field's
  descriptions are null.

Corrected: "Stage design, round 4 inputs" lists "org issue fields present (needs the account)"
as unverified; the field list above shows them present. The "Live confirmations before triage"
table, item 1, asks for editing to P1-P5; superseded by Round 5 item 9.

Still open: pinning to Task, Bug, Feature and "Issues without a type" (UI); option-count limit
(not tested, no option added); meaning of `organization_members_only` on a public repo.

### Live results: sandbox repo and org secret (2026-10-11)

Source: two screenshots from the user (15:11, 15:13) and read-only `gh` metadata calls (names,
visibility and repository list; no secret value read).

| Check | Result |
|---|---|
| A5 `gh repo create becloud-dev/triage-sandbox --public --description "Consumer of the becloud-dev triage workflow" --clone` | Printed `https://github.com/becloud-dev/triage-sandbox`; no error |
| A6a `gh secret set CLAUDE_CODE_OAUTH_TOKEN --org becloud-dev --repos triage-sandbox`, first attempt | `failed to fetch public key: HTTP 403: You must be an org admin or have the actions secrets fine-grained permission.` and `This API operation needs the "admin:org" scope`; CLI scopes were `delete_repo`, `gist`, `read:org`, `repo`, `workflow` |
| A6a same command after the user's `gh auth refresh -h github.com -s admin:org` | `Set Actions secret CLAUDE_CODE_OAUTH_TOKEN for becloud-dev`; `gh secret list --org becloud-dev` shows `SELECTED`, updated `2026-10-11T18:13:43Z`; the repositories endpoint lists `becloud-dev/triage-sandbox` only |

Implications (inference):

- Writing an organization secret from the CLI needs `admin:org` (or the fine-grained secrets
  permission); a repository secret needs only `repo`.
- The Free plan accepts a public repository in an organization secret's selected list. Whether a
  run in that repository reads it is live item 14, confirmed by the first run.
- The CLI token now carries `admin:org`; removal is `gh auth refresh --remove-scopes admin:org`
  (flag from the `gh` help; the effect on `read:org` is untested).

Still open: A3, A4, A6b, A7 (labels, issue types, Actions setting); item 14 by run.

Corrected 2026-10-11: A4, A6b and A7 are done and item 14 held by outcome; see "Live results:
first triage run". A3 stays open.

### Live results: first triage run (2026-10-11)

Source: `gh` read-only calls with the user's login on `becloud-dev/triage-sandbox` and
`becloud-dev/workflows`; run `38164369843` (event `issues`, `labeled`, started 18:34:16Z), issue
#1; the run-record artifact `run-record-38164369843-1`. The job summary text is not exposed by
the API and was not read.

| Step | Result |
|---|---|
| A6b | Variables `OWNERS` (`bentoluizv`) and `PRIORITY_FIELD_ID` (`48149712`) set by the user; read back |
| A7a | Labels `triage`, `needs-info` created by the user; read back with descriptions |
| A7b | `GET /orgs/becloud-dev/issue-types`: Task `897472419`, Bug `897472420`, Feature `897472421`, all `is_enabled: true` |
| A7c | `GET .../actions/permissions`: `enabled: true`, `allowed_actions: all`, `sha_pinning_required: false` |
| A4 | `gh repo create becloud-dev/workflows --public` printed the URL; main pushed; `gh api .../commits` head equals the local `HEAD` |
| R1 | Caller workflow committed as the first commit of `triage-sandbox` (`0929a1b`) and pushed; `gh workflow list` shows `triage`, active |
| R2-R4 | Issue #1 created, label `triage` applied: run started, 9 steps and post steps `success`, job 35 s |
| Issue after run | Type `Bug`; field `48149712` value `Urgent` (`GET issue-field-values`); one comment with a two-sentence rationale citing the issue text; label `triage` removed |
| Run record | `is_error` false, `num_turns` 4, `duration_ms` 4972, `permission_denials_count` 0, model `claude-haiku-5-5`, `auth` oauth, `total_cost_usd` 0.00467535; `modelUsage` has one model: 1220 input, 699 output, 36945 cache read, 19172 cache creation tokens, `provider` firstParty, `costBasis` list |
| Annotation | `ubuntu-latest` migrates to Ubuntu 26 on 2026-10-19 (notice only) |

Interpretation (inference):

- `GITHUB_TOKEN` with `issues: write` wrote the issue type (`PATCH ... -f type=<name>`) and a
  Priority option name (`POST issue-field-values`, body `{field_id, value}`) in a called
  workflow, and the read-back step, which fails the job on a mismatch, passed. Live item 2 is
  confirmed.
- The prompt checkout, the owner gate, `vars` through `with:`, `--model claude-haiku-5-5`, the
  `Bash(gh ...)` allowlist, `structured_output`, the composite action at `@main` and the
  artifact upload each ran without error; items 4-9 are confirmed by outcome, not by reading the
  value of `job.workflow_sha` (summary not read).
- The Classify step ran with the organization secret in a public repository on Free; item 14
  holds by outcome.
- `total_cost_usd` on OAuth is populated; `costBasis: list` suggests a list-price figure, not a
  charge. What the subscription is charged is unverified.
- One triage costs about half a cent at list price, mostly cache tokens.

Unverified or not exercised: `needs-info`, the format fix and the split; the haiku verdict
quality on real issues; A3 (the Anthropic reply); the "Workflow identity" block of the job
summary. Concurrency is covered in the next subsection.

### Live results: concurrency (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after one sandbox write sequence on
the user's go: issue #2 created; label `triage` added at 18:47:21Z, added again at about
18:47:28Z, removed and re-added by 18:47:33Z. Runs `38165283016` (A) and `38165294100` (B). This
settles item 8 of section B in "Live confirmations before triage"; the earlier citation "Round 5
item 13" does not exist (Round 5 has items 1 to 10) and is corrected.

| Observation | Value |
|---|---|
| Add events sent / runs created for issue #2 | 3 / 2 |
| Run A | created 18:47:25Z, job 18:47:28Z to 18:48:16Z, all steps `success` |
| Run B | created 18:47:35Z, `pending` while A was `in_progress`; job 18:48:19Z to 18:48:51Z, all steps `success` |
| Issue after both runs | type `Bug`, Priority `High`, labels none, 2 comments (18:48:10Z, 18:48:46Z) |

Interpretation (inference):

- Job-level `concurrency` (group `triage-<issue>`, `cancel-in-progress: false`) on a job that
  calls a reusable workflow serializes runs: B waited `pending` and started 3 s after A ended;
  nothing was cancelled. The docs do not mention this case; the live run does.
- Adding a label already present fired no `labeled` event: 3 adds produced 2 runs.
- B's "Remove the start label" step succeeded although A had most likely removed the label
  already (label state at that instant not read), so `gh issue edit --remove-label` on an absent
  label does not fail the step.
- A queued run is a full second run: B repeated the classification and posted a second comment
  with the same type and priority and different wording. Two quick applications cost two haiku
  calls and two comments.

Unverified or not exercised: three events in a row (the docs say the middle pending run is
cancelled); which docs variant (`queue: single|max`, flag `actions-nga`) applies on Free; whether
a duplicate comment matters to the owner (a design question, not a defect found).

### Live results: needs_info (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after the user's sandbox writes:
issues #3 ("The app is broken") and #4 (accented search) created, label `triage` applied to
both. Runs `38167016110` (#3) and `38167018047` (#4), both `success`; run-record artifacts
`run-record-38167016110-1` and `run-record-38167018047-1` downloaded and read.

| Observation | #3 | #4 |
|---|---|---|
| Run start / end | 19:12:15Z / about 19:12:52Z | 19:12:16Z / about 19:12:54Z |
| Issue after run | label `needs-info`; type none; no Priority value; label `triage` removed | type `Bug`; Priority `High`; no labels |
| Comment | 5 numbered questions and a reason line | two-sentence rationale |
| Run record | `num_turns` 4, 937 output tokens, 19622 cache creation, `total_cost_usd` 0.00489 | `num_turns` 4, 659 output tokens, 5802 cache creation, `total_cost_usd` 0.00212 |
| Common | model `claude-haiku-5-5`, `auth` oauth, `is_error` false, `permission_denials_count` 0, `costBasis` list | same |

Interpretation (inference):

- The `needs_info` outcome skips the type and Priority writes and still removes the start
  label, as designed.
- Runs for different issues are not serialized: the two jobs overlapped.
- `costBasis: list` is present on OAuth in both records, so `total_cost_usd` is a list-price
  figure; what the subscription is charged is unverified. The 2.3x cost difference tracks
  cache-creation tokens; its cause was not read.
- #3 received exactly 5 questions, the cap, for a four-word issue.

Unverified or not exercised: the value of `job.workflow_sha` and the job summary text; the
haiku verdict quality on real issues; the format fix and the split; A3 (the Anthropic reply).

### Live results: format fix (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after the user's writes: template
`.github/ISSUE_TEMPLATE/bug.md` committed (`546c224`) and pushed together with `workflows`
`fc02671`; issue #5 ("Export button does nothing on the reports page", free-form body) created
and label `triage` applied. Run `38171318935`, `success`, every step `success`; run-record
artifact `run-record-38171318935-1` read; edit history read through GraphQL
`userContentEdits`.

| Observation | Value |
|---|---|
| Issue after run | type `Bug`; Priority `Urgent`; no labels (`triage` removed) |
| Body | reflowed under `## What happened`, `## Expected behaviour`, `## Steps to reproduce`; wording kept, one sentence moved |
| Comment | one comment: rationale, then `Format fix: <one line>` |
| Edit history | two entries at 20:14:32Z: the original body (editor `bentoluizv`) and the new one (editor `github-actions`) |
| Run record | `num_turns` 5, `total_cost_usd` 0.00569, `permission_denials_count` 0, model `claude-haiku-5-5`, `costBasis` list |

Interpretation (inference):

- The `Bash(ls .github/ISSUE_TEMPLATE:*)` allowlist entry matched and the relative path resolved
  in the caller checkout: the model listed and read the template (the extra turn).
- The read-back step passed, so the body read back equal after any GitHub normalization; the
  step summary line itself was not read.
- Edits made through the API are kept in the edit history, so the original body is
  recoverable. Visibility of that history to a viewer without write access is unverified.
- The model followed "reformat only": nothing was added or dropped.

Quality observations (one sample, recorded as open items, then acted on below):

- Priority `Urgent` rested on "no workaround is mentioned": absence of a mention was read as
  absence of a workaround.
- The rationale named evidence for the priority and left the type implicit, although the prompt
  asked for evidence on both.

Decision (user, 2026-10-11): priority is judged by operational impact on the business: a
business-critical flow stopped or corrupted (purchase, payment, sign-in, submission, core
transaction, data loss or exposure) is `Urgent`; a broken control outside a critical flow is
not, however visible. A stated workaround moves a stopped critical flow to `High`; silence about
a workaround moves nothing. The comment carries separate evidence for the type and the priority,
enforced by the prompt and by the workflow (a missing field aborts before any write).
Criticality is inferred from the issue text; an optional per-repo file naming the critical flows
is a later increment.

Unverified or not exercised: visibility of the edit history without write access; behaviour
with several templates or a `.yml` form; the split; three events in a row; the value of
`job.workflow_sha` and the job summary text; A3 (the Anthropic reply).

### Live results: priority by business impact (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after `workflows` `856e74e` was
pushed to `main`; issue #6 ("Print preview icon on the reports page does nothing", free-form
body, a stated workaround) created and label `triage` applied by the user's go. Run
`38172402379`, `success`; run-record artifact read; run log read (full tool output is hidden by
the action).

| Observation | Value |
|---|---|
| Issue after run | type `Bug`; Priority `Medium`; no labels (`triage` removed) |
| Comment | impact sentence, `Type: Bug. <evidence>`, `Priority: Medium. <evidence>`, `Format fix: <one line>` |
| Priority evidence | names the flow, states it is not a purchase, payment, sign-in, submission or data loss, cites the stated workaround |
| Body | text under `## What happened`; `## Expected behaviour` empty; the environment line under `## Steps to reproduce` |
| Run record | `num_turns` 7, `total_cost_usd` 0.00636, 2656 output tokens, `permission_denials_count` 1, model `claude-haiku-5-5` |

Interpretation (inference):

- A visible but non-critical broken control is not `Urgent`: the business-impact rule held on
  the case opposite to issue #5, and type and priority carry separate evidence.
- The enforcement path that aborts on a missing evidence field was exercised offline with `jq`
  (rc 4 on a missing or empty field), not yet by a live run.
- `priority_evidence` ran five sentences, arguing why `High` did not apply; the prompt asked
  for the flow, its criticality and the workaround.
- The template has no environment heading, so "closest heading" placed the environment line
  under `## Steps to reproduce`. Nothing was lost; the placement is slightly off.
- One permission denial occurred (earlier runs: 0), with 7 turns against 5. The denied call is
  not in the log. A guess (a command outside the allowlist) is unverified.

Decisions (user, 2026-10-11): leave the denied call open and watch the count on later runs
(`show_full_output` would print issue text in a public log); cap `priority_evidence` at two
sentences; keep "closest heading" for text that fits no template heading.

Unverified or not exercised: the denied tool call; the live abort path on a missing evidence
field; the `Urgent` case on a stopped critical flow with no stated workaround; the split; A3.

### Live results: urgent case (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after `workflows` `92bd555` was
pushed to `main`; issue #7 ("Checkout page rejects every payment with \"Something went
wrong\"", free-form body, no workaround) created and label `triage` applied by the user's go.
Run `38172779881`, `success`; run-record artifact read.

| Observation | Value |
|---|---|
| Issue after run | type `Bug`; Priority `Urgent`; no labels (`triage` removed) |
| Comment | impact sentence, `Type: Bug. <quote>`, `Priority: Urgent. <two sentences>`, `Format fix: <one line>` |
| Body | description under `### What happened`; empty `### Expected behaviour` and `### Steps to reproduce` appended |
| Run record | `num_turns` 6, `total_cost_usd` 0.00308, 1527 output tokens, `permission_denials_count` 0 |

Interpretation (inference):

- The business-impact rule holds at both ends: `Medium` for a non-critical control with a stated
  workaround (#6), `Urgent` for a stopped checkout with none (#7); silence about a workaround
  was reported as "No workaround is stated" and did not change the outcome.
- The two-sentence cap on `priority_evidence` held.
- The denial seen in run `38172402379` did not repeat; its cause stays unexplained.
- The template `bug.md` writes `##` headings; #5 and #6 got `##` and #7 got `###`, the level
  the prompt names only for `.yml` forms. One sample of a fidelity slip.
- The model appended the template's empty headings for sections the issue did not fill; no
  content was invented.

Decisions (user, 2026-10-11): the prompt requires each template heading exactly as written,
including its level; empty template headings are accepted as the template's format.

### Live results: split (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after `workflows` `98054ea`, then
`1e6362e`, were pushed to `main`; issues #8 and #12 created and label `triage` applied by the
user's go, and `triage` re-applied to #8. Runs `38174294323` (#8, `failure`), `38174522614`
(#8 again, `success`), `38174777474` (#12, `success`); run-record artifacts read; the failed
step's log read.

| Run | Parent after | Children | Run record |
|---|---|---|---|
| `38174294323` (#8, three changes) | `Feature`, `Medium`; comment ends `Split into: #9 #10 #11`; no format fix | #9 Feature, #10 Bug, #11 Task; parent #8, no labels, no Priority, bodies end `Split from #8` with a "Done when" line | `num_turns` 5, `total_cost_usd` 0.00590, 0 denials; "Apply the verdict" `failure` after the comment was posted |
| `38174522614` (#8 re-labelled) | one more comment, no `Split into` line | still #9 to #11, total 3 | `num_turns` 5, `total_cost_usd` 0.00248, 0 denials; `success` |
| `38174777474` (#12, two changes) | `Feature`, `Medium`; comment ends `Split into: #13 #14` | #13 and #14 Features; parent #12, no labels | `num_turns` 4, `total_cost_usd` 0.00240, 0 denials; `success` |

Interpretation (inference):

- `GITHUB_TOKEN` with `issues: write` created typed issues and set their parent; the runner's
  `gh` handled `--parent` and `--type`; 3 sequential creates showed no secondary rate limit.
- The first run failed at the final status check, after the three children and the comment
  existed: the immediate read-back of `sub_issues_summary.total` is the only remaining path to
  that failure. The count read 3 afterwards (REST and the list). The cause is most likely a lag
  in the derived count; the read value at that instant was not captured.
- With a bounded poll (5 reads, 2 s apart) run `38174777474` passed. This is consistent with the
  lag but does not prove it; the read count is in the step summary, which the API does not
  expose.
- The guard worked: with 3 sub-issues present, the re-applied label created no children and
  posted a second triage comment.
- The parent of a mixed issue was typed `Feature` while its evidence said the parent is mixed.

Unverified or not exercised: whether the poll needed more than one read; that the model returned
`children` again on the guard run (it was skipped either way); a partial-failure path of the
creation loop; a split on an issue with a `.yml` form or several templates; three events in a
row; A3 (the Anthropic reply).

### Live results: pins and the self-repository reference (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after `workflows` `80ccb02` was
pushed to `main`; the `triage` label applied to #8 by the user's go; run `38175350506`
(`success`); run log and run-record artifact read.

| Check | Finding |
|---|---|
| Workflow commit | `Uses: becloud-dev/workflows/.github/workflows/triage.yml@refs/heads/main (80ccb02dbfa88c30febba91e0753bb2ab962ebef)` |
| Pinned actions | log shows `actions/checkout`, `anthropics/claude-code-action` and `actions/upload-artifact` downloaded at the pinned SHAs |
| `record-run` | `Run becloud-dev/workflows/.github/actions/record-run@80ccb02dbfa88c30febba91e0753bb2ab962ebef`; step `success` |
| Guard on #8 | `sub_issues_summary.total` stays 3; one more triage comment; start label removed |
| Run record | `claude-haiku-5-5`, `oauth`, `is_error` false, `num_turns` 5, `total_cost_usd` 0.0021553, 0 denials |

Interpretation (inference): `$/.github/actions/record-run` resolved to the same commit as the
called workflow, so the version skew recorded above is gone for this run. The pins did not
change behaviour.

Also read: the log downloads `oven-sh/setup-bun@0c5077e51419868618aeaa5fe8019c62421857d6`,
which is not in `triage.yml`; it is presumably pulled by `claude-code-action`. Its source was
not read. The parent of the mixed issue was typed `Task` here and `Feature` in earlier runs.

Unverified or not exercised: `$/` from a caller on a SHA other than `main` head; zizmor on the
workflow; a Dependabot config; the `setup-bun` pin inside `claude-code-action`.

### Live results: default permissions and job name (2026-10-11)

Source: `gh` read-only calls on `becloud-dev/triage-sandbox` after `workflows` `d31ebc1` was
pushed to `main`; the `triage` label applied to #8 by the user's go; run `38175941033`
(`success`); run log read.

| Check | Finding |
|---|---|
| Workflow commit | `triage.yml@refs/heads/main (d31ebc161e0a32f6b614dc879bd9aac3b7bcbe59)` |
| Token | log "GITHUB_TOKEN Permissions": `Contents: read`, `Issues: write`, `Metadata: read` |
| Job | `triage / Triage`, all steps `success`; sub-issues on #8 stay 3, one more comment |

Interpretation (inference): the workflow-level `permissions: {}` did not reduce what the job
holds. The job check name changed from `triage / triage` to `triage / Triage`; a caller with
that name as a required check would need updating (not checked; only the sandbox calls the
workflow today).

Unverified: zizmor online audits; a caller with branch protection on the old check name.

### Decision: stage 1 closed (user, 2026-10-11)

Stage 1 (triage) is closed on the sandbox at `workflows` `fe530b9`. Scope as designed in
Round 5 items 1 to 9, all implemented and observed live (runs listed in the "Live results"
sections above, plus `38175350506` and `38175941033` for the pins, `$/` record-run and default
permissions). Tests stay on `becloud-dev/triage-sandbox`; the full flow runs on a real project
later. Work continues on the next stages of section 1.

Gaps carried forward (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| Owner gate rejecting a non-owner never exercised live; only the `OWNERS` variable was read back (A6b) | security gate on who can start a run | a label applied by a second GitHub account or an allowed bot, then read the run (`if:` false, no job) |
| Partial failure of the child-creation loop | a split could leave some children and no read-back | force one `gh issue create` to fail in the sandbox |
| Three events in a row on one issue | concurrency and guard under bursts | apply, remove and re-apply `triage` quickly; read the runs |
| Issue form (`.yml`) or several templates | the format fix and template headings were tried on one markdown template only | a `.yml` form and a second template in the sandbox |
| Quality on real issues | verdicts were checked only on issues written for the test | run on a real project later, as decided |
| `suggest` (type) and Projects v2 | out of stage 1 by decision (Round 5 item 4) | needed only if the decision changes |
| A3: Anthropic reply on subscription OAuth for a public project | decides whether this authentication stays | the user reports the reply; then `gh auth refresh --remove-scopes admin:org`, whose effect on `read:org` is untested |
| Cause of the one permission denial in run `38172402379`; whether the poll needed more than one read; the job summary text; what OAuth is charged (`costBasis: list`); `gh` on the Ubuntu 26 runner (migration 2026-10-19) | unread facts, none blocks the flow | read when the source is reachable |

Not part of stage 1: issue #1 and PR #2 (zizmor in CI) are parked; the check ran green on the
branch (run `38176419903`) and nothing is merged.

### Live results: backlog planner, stage 2a (2026-10-11)

Files: `.github/workflows/planner-backlog.yml` (`9515b68`, fix `83628bb`),
`prompts/planner-backlog.md` (`0736640`); caller `triage-sandbox` `af45e53`. Trigger
`workflow_dispatch`; one haiku call; `Read` only; job `issues: read`; report in the job summary
and the artifact `planner-backlog-<run>-<attempt>`.

| Run | Result |
|---|---|
| `38177471382` | failed in 9s at "Build the backlog input", exit 3, before the model call. jq: `syntax error, unexpected '>', expecting '}'` at `truncated: (...) > 100`, an unparenthesised comparison as an object value. The runner image `ubuntu-24.04` has jq `1.7.1-3ubuntu0.24.04.2` (raw `actions/runner-images` `Ubuntu2404-Readme.md`); the local test had run jq 1.8.1, which accepted the line. The run record and artifact steps still ran, and `$/` resolved to `becloud-dev/workflows/.github/actions/record-run@0736640` |
| `38177571900` | success in 51s after `83628bb`. Input: `total` 13, `truncated` false, ranked `[1,5,7,2,4,6,8,12]`, unprioritised `[9,10,11,13,14]` (equal to the count computed from the baseline). Validate passed. Record: haiku, 3 turns, 24s, `total_cost_usd` 0.00715 (`costBasis: list`), `permission_denials_count` 0, `is_error` false |

Output of `38177571900`:

- Order, tiers kept: `#7, #1, #5` (Urgent), `#2, #4` (High), `#8, #12, #6` (Medium); inside Urgent
  the model moved `#7` ahead of the older `#1` and `#5`.
- `categorize`: empty. `gaps`: one, `#5` `duplicate` of `#2` (same title, same symptom).
- All 12 quoted strings in `order[].reason` and `gaps[].evidence` appear verbatim in the issue
  titles or bodies (script check).
- Issues #1 to #14 compared before and after on type, Priority, labels, milestone, comment count,
  `updated_at` and body length: identical.

Interpretation (inference):

- The path caller, reusable workflow, prompt checkout, `Read`, structured output, validation and
  artifact works end to end. It settles that `Read` opens `.planner/backlog.json`, that the owner
  gate passes under `workflow_dispatch` through `workflow_call`, and that `$/` resolves from a
  caller on `@main`.
- `#5` (Urgent) is a duplicate of `#2` (High) and the report did not say so; the prompt gave no
  place for it. The rule added after this run asks the model to state both priorities in the
  `duplicate` evidence.

Bug class: a check run on a different tool version than production (local jq 1.8.1, runner
1.7.1). The check that would have caught it is running the `run:` blocks with the runner
image's jq, or a CI step that pins the jq used by the local test.

Unverified: the `categorize` path (no miscategorized issue on the sandbox; the empty result
exercises nothing); the build step on jq 1.7.1 outside the runner; pagination past 100 issues
live; the abort of the validate step on a bad model `order` on the runner (tested only on jq);
`sub_issues` use by the model; order quality on real issues.

Retest after `65ad6c6` (the duplicate rule), run `38177887110`, `workflows` `7c4e9fb`: success;
4 turns, 25s, `total_cost_usd` 0.00389, `permission_denials_count` 0. Same input and same order
as `38177571900`. The `#5` gap evidence now reads: "Priorities differ: #2 is High and #5 is
Urgent; neither was changed." The two creation times cited match the input, and the 19 quoted
strings appear verbatim in the issue text. Issues #1 to #14 identical to the baseline. Not asked
for by the prompt: each `reason` begins with the tier name. One run: the rule fires, its
reliability is not measured. `categorize` is still empty.

### Decision: stage 2a closed (user, 2026-10-11)

Stage 2a is closed on the sandbox at `workflows` `7c4e9fb`, scope as in Round 4 item 1 and
the stage 2a decisions above. Tests stay on `becloud-dev/triage-sandbox`; the quality of the
order on real issues is checked when the full flow runs on a real project. Work continues with
stage 2b.

Gaps carried forward (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| `categorize` path never exercised | an empty result on this data proves nothing about type review | one deliberately miscategorized issue in the sandbox, then a dispatch |
| No age or `stale` rule | the model has no clock; an old issue is not flagged | `generated_at` in `backlog.json` and a threshold chosen by the user |
| Build step on jq 1.7.1 outside the runner | the one failure of this stage came from a jq version mismatch | run the `run:` blocks with jq 1.7.1, or accept the runner as the only test |
| Pagination past 100 issues and the cap, live | the cap and `--paginate --slurp` ran only on a fixture | a sandbox with more than 100 open issues, or a fixture-only acceptance |
| Validate abort on a bad model `order`, on the runner | the `jq` was tested locally only | a forced bad order in a sandbox run |
| `sub_issues` use by the model; order quality on real issues | verdicts were read on issues written for the test | run on a real project later, as decided |

### Stage 2b design inputs, read 2026-10-11

Sources: docs.github.com REST pages for repository tags, milestones and update an issue; raw
`github/docs` `workflow-syntax.md` (`on.workflow_call.inputs`, `on.workflow_dispatch.inputs`,
`jobs.<job_id>.with`); live read-only `gh api` on `becloud-dev/triage-sandbox`.

| Topic | Finding |
|---|---|
| Repository tags | `GET /repos/{o}/{r}/tags`: `per_page` max 100, default 30; sort order not stated |
| Milestones | create and update take `title`, `state` (`open`, `closed`), `description`, `due_on` (`YYYY-MM-DDTHH:MM:SSZ`); list takes `state` (`open`, `closed`, `all`), `per_page` max 100; the response carries `number` and `open_issues` |
| Issue milestone | `PATCH issues/{n}` `milestone` is an integer number, `null` clears it; the change needs push access and is silently dropped without it |
| Workflow inputs | `boolean`, `number`, `string` for `workflow_call` and `workflow_dispatch`; booleans stay Booleans in the `inputs` context; inputs passed with `jobs.<id>.with` must match the called workflow's input specifications |
| Sandbox, live | 14 open issues, 0 milestones, 0 tags; types: Bug 7 (#1, #2, #4, #5, #6, #7, #10), Feature 5 (#8, #9, #12, #13, #14), Task 1 (#11), none 1 (#3) |

Implications (inference):

- Tag order is unspecified, so the version scan paginates and sorts by version in jq.
- Open Bug share on the sandbox is 7/12 = 0.58, so the default `bug_budget` of 0.30 fires the
  hold on the first run; a no-hold test needs `bug_budget` of 0.7 or more.
- With 0 milestones and 0 tags only the `v0.1.0` fallback of the title rule runs live; the
  next-minor branch is fixture-only.
- The caller sets `release_days`, `max_issues`, `bug_budget` and `max_releases` as literals in
  `with:`; only `apply` comes from the dispatch input, so `vars` strings are not coerced.

Unverified: a dispatch boolean passed through `with:` to a called boolean input (the docs text
implies it; live probe planned); the local jq is 1.8.1, the runner's is 1.7.1.

### Decision: stage 2b design (user, 2026-10-11)

1. Input scope as stage 2a: open, no PR, no milestone, no `needs-info`, Priority set; cap 100 by
   tier; unprioritised issues are listed and never assigned.
2. Error budget: open `Bug` / (open `Bug` + open `Feature`), repo-wide, `Task` excluded,
   computed in shell. Above `bug_budget` only Bugs are planned and Features go to `held`; the
   shell enforces it in validate, the model does not judge saturation.
3. ETA: shell sets `due_on` to today 00:00:00Z plus k times `release_days` for the k-th new
   milestone; the model groups and gives a theme, it estimates no time.
4. Write gate: dispatch input `apply`, default false (report only); true creates milestones and
   assigns issues.
5. Title: next minor above the highest `vX.Y.Z` found by the shell, `v0.1.0` if none; the theme
   goes in the milestone description.
6. The model may assign issues into existing open milestones while `open_issues` is below
   `max_issues`; it never edits them.
7. Defaults: `release_days` 14, `max_issues` 8, `bug_budget` 0.30, `max_releases` 3.

### Local check: roadmap planner on jq 1.7.1 (2026-10-11)

Method: the `run:` blocks of `.github/workflows/planner-roadmap.yml` at `e5ff873` extracted and
run unchanged against fixtures, `gh` stubbed. jq: upstream `jq-linux-amd64` 1.7.1, SHA-256
matched the release `sha256sum.txt`. Fixtures: 10 issues (5 Bug, 3 Feature, 1 Task, 1 PR), one
open milestone with 5 open issues, tags `v0.2.0`, `v0.3.1`, `latest`. Scratchpad only, not kept.

| Step | Result |
|---|---|
| Build | 7 candidates, 6 ranked by tier then age, 1 unprioritised; `needs-info`, milestoned and PR items excluded; share 0.625; `next_minor` `[0,4,0]` from the tag `v0.3.1`; capacity 3 on the existing milestone |
| Validate | 2 valid plans pass; 10 rejected plans exit 1 (missing, duplicate and unknown issue, 4 new milestones, over capacity, target not open, held without hold, Feature planned, Feature unheld, non-Feature held) |
| Apply | new milestones titled `v0.4.0`, `v0.5.0`, ~~due today + 14 and + 28 days~~ (due dates unverified: the local `date` is uutils 0.10.0, not GNU; see "Live results: roadmap planner apply run"); existing target takes PATCH only; a dropped PATCH aborts on the read-back with exit 1 |
| Report | sections render from `plan.json` and the input |

Earlier run on `ce96acf`: the build failed on the label filter (`.name` read on mapped label
strings); fixed in `e5ff873`.

Inference: with `apply` true, the report step still runs after a failed validate or apply and its
header reads "applied". Not exercised on a failure path; the fix would key the header on the apply
step outcome.

Not covered: the runner's jq build (`1.7.1-3ubuntu0.24.04.2`) against upstream; real `gh`
behaviour for `-F milestone=N`, the milestone POST and `issue_field_values`; the model's output
against `--json-schema`; the dispatch boolean passed through `with:`.

### Live results: roadmap planner dry run (2026-10-11)

Run `38179661635` on `becloud-dev/triage-sandbox`, `workflow_dispatch` with `apply=false`,
caller `542a064`, reusable workflow at `workflows` `main` `82d3ec2`, model `claude-sonnet-5-5`,
literals `release_days` 14, `max_issues` 8, `max_releases` 3, `bug_budget` 0.30.

| Check | Result |
|---|---|
| Steps | build, plan, validate, report, record, upload success; apply skipped |
| Input | 14 open issues; 8 ranked (#1, #5, #7 Urgent; #2, #4 High; #6, #8, #12 Medium); 5 unprioritised (#9, #10, #11, #13, #14); #3 excluded by `needs-info`; Bug share 0.583, hold true; first version `v0.1.0` |
| Plan | new milestone 1: #1, #5, #2, #7 (Export button and checkout); new milestone 2: #4, #6 (accented search, print icon); held #8, #12; unplanned none; all three Urgent issues in milestone 1 |
| Validate | passed on the live plan |
| Quoted evidence | 7 of 7 quotes in the plan `reason` strings found in the issue titles and bodies |
| End state | issues #1 to #14 and milestones (0) identical to the baseline taken before the run |
| Run record | cost $0.0985 (sonnet $0.0984), 4 turns, 8.6 s, `permission_denials_count` 0 |

Confirmed live: the dispatch boolean passed through `with:` to the called boolean input reached
the job as `false` and skipped the apply step; a `--json-schema` `target` of `"new"` was accepted;
the shell-enforced hold held both Features.

Interpretation (inference): the three duplicate Export bugs (#1, #5, #2) were grouped and the
shared root cause was flagged in `summary`; the `held` reasons are a bare "error budget", which
adds nothing because the shell decides the hold. The run record lists a `claude-haiku-5-5` usage
entry (1,228 input tokens, $0.0001) although the caller sets only sonnet; the source is not
established.

Not covered: `apply=true` on real GitHub (`-F milestone=N`, the milestone POST, the read-back);
an integer `target` against an existing milestone; the hold test with a budget above the share;
the validate abort on a live bad plan.

### Live results: roadmap planner apply run (2026-10-11)

Run `38179936884` on `becloud-dev/triage-sandbox`, `apply=true`, caller `542a064`, workflows
`main` `82d3ec2`. Result: failure in the apply step.

| Check | Result |
|---|---|
| Plan, validate | success; plan as in the dry run in 2 new milestones, #8 and #12 held |
| Apply, milestone 1 | POST created `v0.1.0` (number 1) with `due_on` `2026-10-11T00:00:00Z`, expected `2026-10-25`; PATCH and read-back held for #1, #5, #2, #7 |
| Apply, milestone 2 | `date: invalid date 'today 00:00:00 + 28 days'`, exit 1; `v0.2.0` not created, #4 and #6 unassigned |
| Report | ran after the failure; header read "applied" |

Cause (verified in the log for milestone 2; milestone 1's stored value is not explained): the
GNU manual (Coreutils 9.12, "Time of day items") reads `+N` after a time of day as a time zone
correction with a 24-hour maximum, so `+ 28` is invalid and `+ 14` was read as a zone, not days.
The local fixture check ran on uutils `date` 0.10.0, which accepts the string and returned the
expected dates; it did not exercise the runner's `date`.

Fix `1c04177`: due dates from epoch arithmetic (`today_midnight + k * release_days * 86400`).
Unverified: that GNU date on the runner accepts `-d "@N"` (docs page fetch failed twice).

Bug class: implementation-specific parsing of a free-form string; the check that would have
caught it is running the block on the runner's `date`.

Confirmed live: `issues: write` through the caller, the milestone POST, `-F milestone=N` and
the read-back (4 of 4 held); a failed apply leaves milestones and assignments in place.

### Live results: roadmap planner apply run, second attempt (2026-10-11)

Run `38180319305` on `becloud-dev/triage-sandbox`, `apply=true`, workflows `main` `a455c07`
(fix `1c04177`), after a sandbox reset to the dry-run baseline. Result: success.

| Check | Result |
|---|---|
| Steps | plan, validate, apply, report, record success |
| Plan | milestone 1: #1, #5, #7, #2, #4; milestone 2: #6; held #8, #12; unplanned none (grouped differently from the dry run) |
| Apply | milestones number 2 `v0.1.0` and number 3 `v0.2.0`, descriptions from the themes; `-F milestone=N`, the milestone POST and the read-back held for 6 of 6; GNU `date -d "@N"` accepted on the runner |
| Quoted evidence | 7 of 7 quotes found in the issue titles and bodies |
| End state | against the pre-run baseline only the `milestone` field changed, on 6 issues |
| Run record | cost $0.0145, `permission_denials_count` 0 |
| Due dates | stored `2026-10-24` and `2026-11-07`, one day earlier than sent (`2026-10-25`, `2026-11-08` at `T00:00:00Z`) |

Probe (2 throwaway milestones created, read back and deleted; numbers 4 and 5):

| Sent `due_on` | Stored `due_on` |
|---|---|
| `2026-10-25T00:00:00Z` | `2026-10-24T00:00:00Z` |
| `2026-10-25T12:00:00Z` | `2026-10-25T00:00:00Z` |

Source: REST docs "Create a milestone" and "Update a milestone" (read 2026-10-11), which say only
that `due_on` is an ISO 8601 timestamp. Interpretation (inference from two data points): GitHub
stores the date as a calendar date in a zone west of UTC and not further west than UTC-12; the
exact zone is not established.

Fix `5a594e8`: due dates sent at noon UTC. Bug class: an API that normalises a timestamp to a
calendar date in a zone its docs do not state; the check that would have caught it is a live
read-back of `due_on` after the first create.

Open: the fix is untested live; the report header still reads "applied" after a failed apply
(seen in run `38179936884`); the hold test and the forced bad plan are not run.

### Live results: roadmap planner apply run, due dates (2026-10-11)

Run `38181204583` on `becloud-dev/triage-sandbox`, `apply=true`, workflows `main` `eded1ee`
(due date fix `5a594e8`), after a sandbox reset to the baseline. Result: success. Closes the
"fix untested live" item of the second apply run.

| Check | Result |
|---|---|
| Steps | plan, validate, apply, report, record success |
| Milestones | number 6 `v0.1.0` due `2026-10-25`, number 7 `v0.2.0` due `2026-11-08`, as expected from a send at `T12:00:00Z` |
| Plan | milestone 1: #7, #1, #5, #2; milestone 2: #4, #6; held #8, #12; unplanned none |
| Apply | the read-back held for 6 of 6 |
| Quoted evidence | 7 of 7; the quote for #4 contains an ellipsis, both fragments are verbatim in the issue body |
| End state | against the reset baseline only the `milestone` field changed, on 6 issues |
| Run record | cost $0.0139, `permission_denials_count` 0 |

Confirmed live: the milestone POST, `-F milestone=N`, the read-back, `due_on` after the noon send,
`issues: write` through the caller, and GNU `date -d "@N"` on the runner.

Open (stage 2b): the no-hold side of the error budget; the validate abort on a live bad plan; an
integer `target` into an open milestone with capacity (milestones 6 and 7 have room now); the
report header reads "applied" after a failed apply (seen in run `38179936884`).

### Live results: roadmap planner no-hold run and the due date collision (2026-10-11)

Run `38181470415` on `becloud-dev/triage-sandbox`, `apply=true`, workflows `main` `3635222`,
sandbox caller `85d313e` (`bug_budget` 0.70 as a test value). Result: success.

| Check | Result |
|---|---|
| Budget | `bug_share` 0.583 against 0.70, `hold_features` false; `held` empty, validate accepted |
| Plan | #8 and #12 each in a new milestone (`v0.3.0`, `v0.4.0`), although milestones 6 and 7 had capacity 4 and 6; unplanned none |
| Quoted evidence | 6 of 6 found in the issue text |
| End state | only the `milestone` field changed, on #8 and #12 |
| Run record | cost $0.0407, `permission_denials_count` 0 |
| Due dates | `v0.3.0` stored `2026-10-25` and `v0.4.0` `2026-11-08`, the same days as the existing `v0.1.0` and `v0.2.0` |

Finding: ~~ETA by `release_days`: due date is today plus k times `release_days` for the k-th new
milestone~~ ignored the due dates of existing open milestones, so a later release could be dated
no later than an earlier one. Amended rule, commit `1325e84`: the later of today and the latest
open `due_on`, plus k times `release_days` (sent at noon UTC, see the probe). Fixture check on
jq 1.7.1: future, past, null and empty due dates. Not yet run live.

Unverified: the report header on the runner (the job summary is not in the artifact).

Not exercised live: an integer `target` into an open milestone with capacity; the model opened
new milestones although existing ones had room. Covered by fixtures only.

### Decision: stage 2b closed (user, 2026-10-11)

Stage 2b is closed on the sandbox at `workflows` `967d0c1`: dry run, apply, error budget with and
without hold, due date probe and fix, report header fix, due date base fix. Tests stay on
`becloud-dev/triage-sandbox`; grouping quality on real issues is checked when the full flow runs
on a real project. Work continues with the issue type `Project` round, then stage 3.

Gaps carried forward (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| Integer `target` into an open milestone never exercised live | the model opened new milestones although two had room; the validate side ran on fixtures only | an issue that clearly belongs to an existing milestone, then a dispatch |
| Validate abort on a bad plan, on the runner | the 12 `jq` cases ran locally only; the workflow has no injection point | a forced bad plan, or a test-only input (changes the production workflow) |
| Due date base rule (`1325e84`) live | fixtures on jq 1.7.1 only; no run since with dated milestones and something to plan | one run on a sandbox with open issues to plan and dated milestones |
| Report header on the runner | the job summary is not in the artifact; `steps.apply.outcome` read from the docs | read the job summary of the next run in the browser |
| Grouping quality | the no-hold run made two single-issue milestones with room elsewhere | a run on a real project, as decided |
| No age rule; Urgent-first across milestones not enforced | carried from 2a and the 2b design | decisions for stage 3 |

### Queued after stage 2b

Issue type `Project` (org level; triage splits it into sub-issues), the issue form
`ISSUE_TEMPLATE/project.yml` and a sandbox test come after stage 2b and before stage 3, in their
own Plan Mode round. Stages 3, 4 and 5 follow, one per step.

### Issue type Project (2026-10-11)

Decisions (user, Plan Mode round): the type `Project` always splits; the parent keeps `Project` and
is still prioritised; only the author sets it, through the form, so the model `type` enum stays
`Task|Bug|Feature`; a Project that names fewer than two deliverables is `needs_info`; the child
cap stays 5; the org type is created by the agent on the user's go (the user was on a phone);
the form lives in `triage-sandbox` only.

Changes: `workflows` `5652f43` (prompt: three rules; `triage.yml`: step `Read the issue type`,
`Issue type:` in the prompt, `ISSUE_TYPE` in the apply step, Project branch, guard of at least two
children, type PATCH skipped for `Project`). `triage-sandbox` `0d5ba96`
(`.github/ISSUE_TEMPLATE/project.yml`). Both pushed.

Org type: `POST /orgs/becloud-dev/issue-types` with `name`, `is_enabled`, `description`, `color`
created `Project` (id `900748196`, purple). The token had `admin:org`. Body parameters were taken
from the REST docs page through a page summarizer (raw OpenAPI source unread); the call itself
returned the object with those fields.

Fixture check on jq 1.7.1 (SHA-256 `5942c9b0...c8ff5` matches the release `sha256sum.txt`), 9 cases:
Project with 0 or 1 children fails, with 3 passes and ignores a model `type`; Bug and an untyped
issue behave as before. Project/1 and Bug/1 fail in the existing range check, silently.

Sandbox runs (`gh api` read-back):

| Case | Issue | Run | Result |
|---|---|---|---|
| a. Project, 3 deliverables | #15 | `38182908746` | type `Project`, Priority `Medium`, 3 sub-issues #16-#18 typed `Feature`, no label, one comment with "Type: Project. Set by the author in the issue form." |
| b. Project, 1 deliverable | #19 | `38183021152` | type `Project`, label `needs-info`, no Priority, no sub-issues, one comment with 2 questions |
| c. Untyped Bug | #20 | `38183145951` | type `Bug`, Priority `High`, no sub-issues, one comment, as before |

Inference: the Project branch, the skipped PATCH and the always-split rule work on the runner. The
Priority write succeeded through the API with Priority not pinned to `Project`.

Gaps (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| Form `type: Project` applied on submit | only a missing type was observed; cases a and b were created with `gh issue create --type` | the user submits the form in the browser |
| Priority pinned to `Project` in the UI | the API write worked unpinned; the sidebar display is unread | look at #15 in the browser |
| Project with one child from the model | falls into the existing range check: silent fail, no comment | a run where the model returns one child instead of `needs_info` |
| Child cap 5 | a larger project needs a second pass | decision for a later round |
| Org-wide form distribution | the form exists in the sandbox only | the sync step, stage 5 or later |
| Re-run of a Project that has sub-issues | the idempotency reset applies after the guard; not run | a second `triage` label on #15 |
| Job summary of the three runs | only in the browser | read in the browser |

### Stage 3: UX and UI research (2026-10-11)

Decisions (user, Plan Mode round): one reusable `ux-ui.yml` with two Claude steps (UX, then UI
reading `.ux/ux.json`); two issue comments with marker lines `<!-- ux-research -->` and
`<!-- ui-research -->`, no files and no PR; optional caller input `design_system_path`, none means
no tokens; the gate is the owner swapping `UX/UI` for `RELEASE`; a thin issue gets questions and
`needs-info`; read-only tools (`gh issue view`, `Read`, `Grep`, `Glob`); an issue of type `Project`
is skipped with one comment; age rule and Urgent-first stay with the planner.

Changes: `workflows` `6bd173d` (prompts `ux-research.md`, `ui-research.md`; `ux-ui.yml`);
`triage-sandbox` `80e107a` (caller, `docs/design-system.md`); label `UX/UI` created on the sandbox.
Both pushed.

Details chosen inside the decisions: a re-run posts new comments and edits none; `record-run` writes
a fixed `run-record.json`, so the UX record is copied aside before the UI record is built; a
`design_system_path` that is absolute or contains `..` is refused; a UI result with
`design_system_used: false` and tokens is refused; triple backticks in model text are replaced
before a fenced block.

Fixture check on jq 1.7.1 (the real `run:` blocks extracted from the workflow, a stub `gh`): UX
and UI render and validate; `needs_info` with 0 questions, 1 requirement, and tokens without a
design system fail; a fence in the layout is escaped; the path guard accepts none and a relative
file, refuses `/etc/passwd`, `../x` and a missing file.

Sandbox runs (`gh api` read-back):

| Case | Issue | Run | Result |
|---|---|---|---|
| a. clear UI issue, design system given | #13 | `38183744281` | UX and UI comments, `UX/UI` stays; both run records in the artifact (5 and 4 turns, 0.098 and 0.105 USD, sonnet-5-5) |
| b. thin issue | #21 | `38183881071` | label `needs-info`, 5 questions, UI steps skipped |
| c. Project | #15 | `38184069206` | one skip comment, Claude steps skipped, sub-issues untouched |

Inference: the mechanics hold on the runner. In case a the UX is grounded in the issue text, and
every token cites a section of `docs/design-system.md` with matching values. Quality finding: the UI
step chose a one-row-per-invoice table because the design system defines a Table; the issue does
not say whether the button sits on a list or on one invoice, and the gaps list did not flag that.

Gaps (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| Unstated screen shape not flagged as a gap (closed on one run) | case a assumed a list from the available components | closed by `8f6d4b3`: re-run of #13, run `38184680888` (2026-10-11T23:33Z), `Gaps` item 1 names the list-or-single-item assumption; 8 further gaps listed, so the volume is higher; one run, not proof |
| `design_system_path` empty, live | fixture only; the model must design without colours | a caller with the input empty and a run |
| Job summary of the three runs | only in the browser | read in the browser |
| `needs-info` label in a fresh consumer repo | `gh issue edit --add-label` fails when it is missing | the label sync step (stage 5 or later) |
| Model text with `@` mentions goes into comments unfiltered | a mention notifies a person | a decision on filtering |
| Re-run duplicates comments | the latest marker comment is current, old ones stay | a decision: edit in place or keep history |
| The UI step reads the UX of the same run | an owner edit to the UX comment is not seen | a decision, with the gate design for stage 4 |
| Gate (`UX/UI` to `RELEASE`) not exercised | stage 4 does not exist yet | stage 4 |
| No age rule; Urgent-first across milestones | planner decisions carried from 2a and 2b | a planner round |

Re-run after `8f6d4b3` (inference, one run): the UI comment's `Gaps` now states that the page is
assumed to be a list with one button per row and that a single invoice would move the button to the
page header's actions area. The layout is unchanged. Nine gaps in total; unverified whether that
volume is useful or noisy across other issues.

### Stage 4a: development plan (2026-10-11)

Decisions (user, Plan Mode round): two reusable workflows, plan first (`dev-plan.yml`, then
`dev-execute.yml`); the owner's comment `/approve` starts the execution; `GITHUB_TOKEN` opens the PR
now and a GitHub App comes in a later round; a loop that still fails after 2 re-executions opens a
draft PR plus a findings comment. Defaults taken from the plan and not asked: the gate refuses a
`RELEASE` while `UX/UI` is on the issue; the plan reads the latest UX and UI comments as they are
at run time.

Changes: `workflows` `333d034` (`prompts/dev-plan.md`), `9ef164d` (`dev-plan.yml`), `2acb3ca`
(`record-run` keeps `permission_denials` with `tool_name` and `tool_input` cut to 300 characters);
`triage-sandbox` `750a808` (caller); label `RELEASE` created on the sandbox. All pushed.

Source read: `anthropics/claude-code-action` at `1d6de8c` (raw `src/modes/agent/index.ts`,
`src/github/operations/git-config.ts`, `docs/faq.md`, `docs/capabilities-and-limitations.md`) and
the Agent SDK TypeScript reference (`SDKPermissionDenial`). In agent mode the action checks that
the actor is human, replaces the checkout credential with its own token and sets a git user; it
creates no branch and no PR.

Fixture check on jq 1.7.1 (SHA-256 verified; real `run:` blocks, stub `gh`): gate output for a
plain issue, a Project and an issue with `UX/UI`; hold comment; planned post with and without
risks; planned with one step, no `risks` field, or no files fails; `needs_info` posts the
questions, with 0 questions fails. `record-run` with 0, 1 and 2 denials, a 500-character input
and a missing file. zizmor 1.30.1 offline, auditor persona: no findings on `dev-plan.yml` and
`record-run`.

Sandbox runs on #13 (`gh api` read-back):

| Case | Run | Result |
|---|---|---|
| a. `RELEASE` added while `UX/UI` is on | `38185526301` | hold comment `<!-- dev-plan-hold -->`; plan, record and upload steps skipped |
| b. `UX/UI` removed, `RELEASE` re-added | `38185565419` | `<!-- dev-plan -->` comment; sonnet-5-5, 5 turns, 0.127 USD, 19 s; `permission_denials_count` 1 |
| c. same, after `2acb3ca` | `38185834989` | success; 4 turns, 0.054 USD; `permission_denials_count` 0, list empty |

Inference: the mechanics hold on the runner (second checkout from `job.workflow_repository`, the
gate, the hold, the marker comment). In case b the plan cites the UX and UI comments in its
acceptance criteria, takes the tokens from the design system, and lists the list-or-single-item
assumption under Risks, so the stage 3 fix carries over. #13 has no application code, so the plan
invents a greenfield Node app (9 files, a hand-built PDF); that is a fixture limit, not a plan
defect, and slice 4b needs a small issue in a repository with code. One spec item,
"download click does not navigate away", cannot be checked by the stack the plan chose (no
browser); inferred from reading the plan, not run.

Gaps (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| Denied tool call in case b not identified | the log hides tool output and the first record kept only the count | the next occurrence, now named in the record; a prompt line only if it repeats |
| `permission_denials` shape on a live denial | fixture follows the SDK docs; the live array was only seen empty | one run with a denial |
| Plan items not testable on the chosen stack | the executor would write a test that cannot pass | a plan-prompt rule, decided with the first 4b run |
| Plan comment edited by a non-owner | the execution reads the comment as it is | a decision on checking the comment's last editor |
| Re-run duplicates plan comments | the latest `<!-- dev-plan -->` is current, older ones stay | the recorded stage 3 decision on edit in place |
| Hold when `RELEASE` is added before `UX/UI` is removed | the owner must re-add `RELEASE`; order is by design, not exercised in a mixed event order | stays as documented behaviour |
| `ux-ui.yml:160` zizmor `template-injection` (info, low confidence) | pre-existing; `record_path` is a runner temp path | passing it through `env:`, its own change |
| Gate `UX/UI` to `RELEASE` with a real UI change end to end | exercised on #13 only as a plan | slice 4b on a UI issue, later |

### Stage 4b: development execution (2026-10-12)

Decisions (user, 2026-10-12): branch type from the issue type (`Bug` gives `fix`, `Feature`
`feat`, else `chore`); push by an explicit token URL step; a first line other than `/approve`
fails the run; an existing branch stops the run with a comment; a PR opens only with commits ahead
of the base and a last outcome `done` (`fail` gives a draft); `blocked` or `failed` posts a
comment only; PR body is `Closes #N`, the plan link and the verdict. Strictening: a plan is made
and executed only for issues written by an `OWNERS` login or `github-actions[bot]`; the plan reads
a file with the comments of those authors only and has no `gh` tool; `triage` and `ux-ui` stay as
they are because they must read external issues. The user turned on "Allow GitHub Actions to
create and approve pull requests" at the organisation and the repository; it is to be turned off
after the live runs.

Source read (raw, `github/docs`): `data/reusables/actions/actions-do-not-trigger-workflows.md`,
`data/features/actions-github-token-pull-request-approval.yml`,
`events-that-trigger-workflows.md` (`issue_comment`),
`managing-github-actions-settings-for-a-repository.md`, `github-terms-of-service.md` (accounts);
`claude-code-action` at `1d6de8c` (`src/entrypoints/prepare.ts`, `permissions.ts`, `actor.ts`);
`gh pr create --help` 2.102.0.

Corrections: (1) pushes with `GITHUB_TOKEN` start no run, but a `pull_request` `opened`,
`synchronize` or `reopened` from a PR a `GITHUB_TOKEN` workflow creates makes runs in an
approval-required state; this narrows the "known limit" in the stage 4 plan. Unverified live: the
sandbox has no PR workflow. (2) Agent mode also runs `checkWritePermissions` for issue events
(`prepare.ts`), not only `checkHumanActor`; seen in the log as "Permission level retrieved: admin".

Changes: `workflows` `0bc04ef` (execute prompt), `3bbd734` (check prompt), `9115dfc` and `25d08c3`
(`dev-round` composite; unmet criteria named), `6d64c57` (`record-run` names the file by stage),
`14633a0` (`dev-execute.yml`), `2d8d29c` (author gate, filtered comments), `dba3e62` (prompt
wording: `Read` tool, one command at a time); `triage-sandbox` `c0ba872` (greet fixture, vars
`CHECK_COMMAND`, `TEST_COMMAND`), `85c8e70` (caller). Fixture checks on jq 1.7.1 (SHA-256
verified): composite 32 cases, `record-run` 10, `dev-execute` 37, `dev-plan` gate 14; mutations
fail as expected; zizmor 1.30.1 offline: no new findings.

Live runs (`gh` read-back):

| Case | Run | Result |
|---|---|---|
| a. #22, plan approved | `38243213387` | PR #23, 1 commit, pass in round 1; haiku 12 turns 0.008 USD, sonnet 7 turns 0.103 USD; denials 2 and 1 |
| b. #24, plan edited by the owner to a contradictory criterion | `38245576046` | executor `blocked` with the reason; findings comment; no push, no PR |
| c. #24, criterion removed, after `dba3e62` | `38246001793` | PR #25, pass in round 1; haiku 15 turns 0.0054 USD, sonnet 7 turns 0.042 USD; denials 0 and 0 |

Inference: the mechanics hold (gate, branch, composite outputs through `continue-on-error`,
`$/` inside a composite, push and `gh pr create` with `GITHUB_TOKEN`, blocked path, owner edit
honoured). The `Read` of files in the runner temp directory worked (inferred from the checker's
verdict). The wording fix removed the shell-form denials in one sample per case.

Gaps (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| `red_seen` is self-reported | no run evidence that the new tests failed first | the workflow running the tests against the base, its own change |
| `fail` with a draft PR and round 2 `findings_file` not seen live | an honest executor blocks instead of failing | the first real failing round |
| Non-owner trigger not run live | the guard is read from the expression and the action source | a second human account comments `/approve` |
| Approval-required PR runs | the sandbox has no PR workflow | a PR workflow in a consumer |
| Bot-authored issues are trusted | an external issue split by an owner-triggered triage reaches the plan | the owner's `triage` label is the control; recorded |
| One sample per model | cost and quality variance unknown | more runs |
| Non-owner writer edits the plan comment | the execution reads it as it is | a check of the comment's last editor |
| Organisation setting on | any workflow in the organisation can open PRs | turn it off after 4b, or the GitHub App round |

### Stage 5: release (2026-10-12)

Decisions (user, 2026-10-12): a GitHub App `becloud-dev-release`, owned by the organisation, for
the release PR; installed on all repositories of `becloud-dev` because the workflows are to run
organisation-wide (chosen over "Only select repositories"); scope is the review only, the
`release-blocker` merge or deploy gate job, the label sync and the form sync stay later; the stage
is split in 5a (release PR and live checks) and 5b (review); the review and the issues use
`GITHUB_TOKEN`, the App token exists only in the release-please job; the automation applies no
start label, the owner adds `RELEASE` to a blocking issue (skips triage) and `triage` to the
others; the review lives in a PR comment, started by `/review`, answered by `/reject` (reason on
the following lines) or `/approve`, and `READY TO LIVE` stays the owner's label; the 4b PR step
stays on `GITHUB_TOKEN` for now.

Sources read (raw): `actions/create-github-app-token` `action.yml` and README (v3.2.0,
`bcd2ba49`; input `client-id`, `app-id` deprecated); `googleapis/release-please-action`
`action.yml` and README (v5.0.0, `45996ed1`); `googleapis/release-please` v17.11.2 `manifest.ts`;
`github/docs` `actions-do-not-trigger-workflows.md`, `additional-permissions.md` and
`server-to-server-permissions.json`; `bentoluizv/patagonia-trip` `claude-pr-review.yml`,
`pr-review.md`, `release.yml`; run logs and artifacts of the runs below.

Changes: `workflows` `cbcd334` (prompts `release-review.md`, `release-issues.md`), `0e8482a`
(`release-review.yml`), `72ac98d` (`release-issues.yml`), `0e481de` (`pull-requests: write`);
`triage-sandbox` `2199926` (`version.txt`, `release-please.yml`), `20cffda` (`pr-checks.yml`),
`e6bc9c9` (callers), `911e50c` (`--shout` fixture with a seeded `eval` defect), `0211639`
(caller `pull-requests: write`); seed tag `v0.1.0` (lightweight, on `20cffda`); App, org variable
`APP_CLIENT_ID` and org secret `APP_PRIVATE_KEY` visible to `triage-sandbox` only; labels
`release-blocker` and `READY TO LIVE` on the sandbox. All pushed.

Fixtures (jq 1.7.1, SHA-256 verified against the release checksum; real `run:` blocks, stub `gh`):
`release-review` 50 cases (gate 31, post 19), `release-issues` 57 (gate 19, create 38; stateful
stub). Mutations (4 and 4) fail as expected. zizmor 1.30.1 offline, auditor: no findings on the
two shared workflows; `release-please.yml` keeps `secrets-outside-env` (accepted: the key is an
organisation secret, the workflow runs on `push` to `main` only); the two callers carry the same
three findings as the other callers (`unpinned-uses`, `excessive-permissions`,
`undocumented-permissions`).

Live results (`gh` and run-log read-back):

| Check | Run | Result |
|---|---|---|
| 5a: first push with seed tag | `38250366025` | App token minted; baseline from the tag; 0 commits after it; no PR |
| 5a: `chore:` only | `38250593500` | "No user facing commits found since 20cffda… - skipping"; no PR |
| 5a: `fix:` | `38251263422` | PR #26 `chore(main): release 0.1.1`, branch `release-please--branches--main`, author `becloud-dev-release[bot]`, `autorelease: pending`, `CHANGELOG.md` added, `version.txt` modified |
| 5a: checks on the App PR | `38251310675` | `pr-checks` `pull_request` run started and succeeded, not approval-required |
| 5b: `/review` | `38253965265` | Opus 5.5, 8 turns, 0.223 USD, 0 denials; blocking `bin/greet:5` (`eval`), deferred `tests/greet_test.sh:7` (no test) |
| 5b: `/reject` with a reason | `38254781174` | new review comment, 7 turns, 0.073 USD; the reason (no-argument case) is in the blocking item |
| 5b: `/approve`, first | `38255071190` | issues #27 and #28 created and set; step failed on the final comment, HTTP 403 |
| 5b: `/approve`, second (after the fix) | `38257406730` | no new issue; #27 and #28 re-checked; `<!-- release-review-issues -->` comment; Sonnet 5.5, 4 turns, 0.037 USD |
| 5b: `/approve`, third | `38257868747` | refused by the gate, no model run |
| 5b: `/review` on closed PR #25 | `38257868740` | "No review: this pull request is not open." |

Inference: an App installation token starts `pull_request` runs on the release PR (one sample);
a seed tag is a sufficient baseline over a history of direct pushes; the stage 5 mechanics hold
end to end (gate, range from the tag, review, reject loop, issue creation, idempotent repeat).
The review read `bin/greet:5`, which is on `main` and not on the release branch, so the file reads
came from the default-branch checkout. One full cycle cost about 0.33 USD.

Corrections to earlier records:

1. "Release tooling, stage 5 read": the row "Releasable units" and its Correction paragraph said
   the code showed no type filter. Run `38250593500` shows a `chore:` commit alone opens no
   release PR in the action's bundled release-please. The README list (feat, fix, deps) is the
   behaviour seen. `release-please-action` v5.0.0 runs release-please **17.6.0** (log line
   "Running release-please version: 17.6.0"), not the 17.11.2 that was read; where the filter
   sits was not read. `perf`, `refactor`, `revert`, `style`, `docs`, `build` and `ci` were not
   run.
2. "`gh` CLI flags (#20)" and the stage 4 notes listed the comment permission as unverified. A
   comment on a pull request through `POST /issues/{n}/comments` needs `pull-requests: write`;
   `issues: write` with `pull-requests: read` was refused (HTTP 403, run `38255071190`). The raw
   permission data lists the endpoint under both `issues` and `pull_requests` with the
   "additional permissions" mark and does not say which applies to a pull request.
3. "Release tooling (#21)": the unverified App-token question is closed for `pull_request` runs
   on the release PR (above), one sample.

Defects found by the fixtures or the live run, fixed before use:

| Defect | Bug class | What caught it |
|---|---|---|
| `blocking=$(jq -er ...)` exits 1 for `false`, so every deferred item stopped the create step | `jq -e` on a boolean that may be `false` | a fixture with a `false` value |
| Final comment refused: job had `pull-requests: read` | a write whose token permission was not checked before the live run | the live run; the stub `gh` does not model permissions |

Gaps (recorded, not closed):

| Gap | Why it matters | What would close it |
|---|---|---|
| `perf`, `refactor`, `revert` and the other types untested for a release PR | the git-workflow table says patch | one `refactor:` commit on a fresh baseline |
| `release-blocker` merge or deploy gate not built | the review creates blockers, nothing refuses the merge | a job modelled on Patagonia's `blockers` job, its own change |
| Owner-edited review comment read as it is | Sonnet parsing an edit not run; an editor who is not an owner is not checked | edit the comment, approve; a check of the comment's last editor |
| Non-owner trigger and a non-release open PR not run | gate read from the expressions only | a second account; an open non-release PR |
| One sample per model and per path | cost and quality variance unknown | more runs |
| Marker lookup lists the last 300 issues | a repository with more would miss a marker | a bounded search or a label scan |
| Release PR not merged, `READY TO LIVE` not exercised, tag and release not created | the gate evaluated at merge time is not built | merge #26 after the gate job exists |
| Org setting "Create and approve pull requests" still on | the 4b step relies on it | move the 4b PR step to the App, then turn it off |
| Installation on all repositories | the App can write contents, issues and PRs on every repository | the user's decision, recorded |
| Review blank lines (two before `### Defer`) | cosmetic | renderer change if wanted |
| Review comment not marked stale after a newer commit on `main` | the issues come from the review as approved | compare the review's SHA with `HEAD` in the gate |

### Release gate (2026-10-12)

Source read (raw): `github/docs` `server-to-server-permissions.json` (fpt-2026-03-10):
`POST /repos/{o}/{r}/statuses/{sha}` needs `statuses: write`, no additional permissions;
`GET .../issues/{n}/events` needs `issues: read` with the "additional permissions" mark.
`events-that-trigger-workflows.md`: `issues` runs on the last default-branch commit;
`pull_request` runs in the context of the merge commit.

Change: `workflows` `1883156` (`release-gate.yml`), `triage-sandbox` `f619bf4` (caller). The gate
sets the commit status `release-gate` on the release PR head: success when `READY TO LIVE` is set
by an owner and no `release-blocker` issue is open. Advisory: no ruleset requires it.

Fixtures (jq 1.7.1, stub `gh`): 22 cases, 7 mutations caught; zizmor auditor: no findings on the
shared workflow.

Live results:

| Check | Run | Status on `4d9fe9e` |
|---|---|---|
| `labeled` on PR #26 before the merge ref refreshed | none | no run started |
| label by owner, #27 open (`issues` event) | `38261899164` | failure: open release-blocker: #27 |
| label missing, #27 open | `38262077137` | failure: missing label READY TO LIVE; open release-blocker: #27 |
| label set, #27 closed | `38263152468` | success |
| merge of #26 | `release-please` `38263623779` | tag `v0.1.1` on `4715338`, Release created |

Inference: a `pull_request` run takes its workflow file from the merge commit; on #26 the merge
ref was stale after the caller push, so the PR event started nothing until later events (two runs
after the merge). The `issues` event is the reliable trigger. Unverified: the output of the two
post-merge runs (logs show the script, not its lines); the cause of the missed first event.

Corrections: "Release PR not merged, `READY TO LIVE` not exercised, tag and release not created"
is closed. Open: no ruleset (the gate does not block); the `refactor`/`perf`/`revert` types; the
stale-review check; a non-owner labeler and a non-release open PR are fixture-only.

### Stale-review check (2026-10-12)

Source read (raw): `github/docs` `server-to-server-permissions.json` (fpt-2026-03-10):
`GET .../commits/{ref}` needs `contents: read`; `GET .../issues/{n}/comments` needs `issues` or
`pull_requests` read. `events-that-trigger-workflows.md`: `workflow_run` runs on the default branch
and fires regardless of the conclusion of the watched workflow. `trigger-a-workflow.md`: events
caused by `GITHUB_TOKEN` start no workflow. GraphQL introspection of `IssueComment`: `editor` and
`lastEditedAt` exist; the REST `issue-comment` object has `updated_at` and no editor.

Change: `workflows` `e527254` (`release-review.yml` writes line 2,
`<!-- release-review-sha: <40 hex> -->`), `ec70b3e` (`release-gate.yml`: `contents: read`; for a
release PR with a review, reviewed SHA against the default-branch tip, last editor through
GraphQL); `triage-sandbox` `f4d80ba` (caller `contents: read`), `b333d66` (caller triggers `push`
to `main` and `workflow_run` of `release-review`). Rules: the review is the last
`github-actions[bot]` comment starting `<!-- release-review -->`; no review: the gate is as before;
line 2 missing or malformed: stale; an edited review passes only if the last editor is an owner,
and an unreadable editor fails.

Fixtures (jq 1.7.1, stub `gh`): 35 cases (15 for the earlier behaviour, rebuilt because the
earlier scripts were not kept, so not the 22 recorded before; 20 new), 8 mutations caught; zizmor
auditor: no findings on the two shared workflows.

Live results (PR #29, head `5f4fb50`):

| Check | Run | Status |
|---|---|---|
| no review, label missing | `38267765984`, `38267766138` | failure: missing label |
| `/review` | `38267952201` | line 2 equals the `main` tip `d0948d2` |
| label set, review current | `38268932754` | success |
| `chore:` push to `main` | `release-please` `38269387914` | no gate run; status stayed success |
| label toggled, review of `d0948d2`, `main` at `b52e912` | `38269819486` | failure: review is stale |
| `/review` again | `38270323748` | no gate run; status stayed failure |
| label toggled, review current | after 15:31 | success |
| owner edit of the review, label toggled | after 15:31:18 | success (editor `bentoluizv`) |
| `push` to `main` (caller change) | `38271343990` | failure: stale (reviewed `b52e912`, `main` `b333d66`) |
| `/review` after the push | `38271524175` (`workflow_run`) | success |
| ordinary comment | `38271582453` | skipped |

Inference: the editor query works under `GITHUB_TOKEN` with `issues`, `pull-requests` and
`contents` read (a readable node came back for an unedited and an owner-edited comment; the
statuses are the evidence, the logs were not read). Before the caller change, the status moved
only on PR and issue events; the two events above show a green status on a stale review and a red
status on a current one.

Not verified: an edit by a non-owner (no second account); only the last editor is read, so an
earlier non-owner edit overwritten by an owner edit is not detected; one sample per path.
zizmor reports `dangerous-triggers` on the caller (`workflow_run`), accepted because the job
checks out nothing and uses no event text.

Corrections: gap rows "Review comment not marked stale after a newer commit on `main`" and
"an editor who is not an owner is not checked" are closed by this record, with the limits above.

### Stage 4b gaps: red check and fail path (2026-10-12)

Decisions (user, 2026-10-12): `red_seen` closes by a workflow run, not by the checker's judgment;
the fail path is exercised live with a fixture whose test fails only in the workflow run; the
non-owner path stays fixture-only; the setting "Create and approve pull requests" stays off.

Change: `workflows` `c06f7ad` (`dev-round` step `red`, input `test_paths` on `dev-execute.yml` and
the composite, one sentence each in `dev-execute.md` and `dev-check.md`); `triage-sandbox`
`5751011` (caller passes `vars.TEST_PATHS`, set to `tests/*`). Rule: the test files of the diff
(added, modified or renamed; matched against the globs of `test_paths`) are checked out from
`HEAD` into a detached worktree at the base, and the test command runs there. Exit 0 is
`green_on_base` and forces `fail` in `verdict`; non-zero is `red`; no test file in the diff, no
`test_paths` or no test command is `none`; a failed `git diff` or worktree is `error`. `none` and
`error` leave the verdict as it is; the checker reads the `red check` section as evidence.
Follow-up (issue 40, 2026-10-13): a test file with no added lines (only deletions) is skipped, so
a removal-only change gets `none`; the diff is read with `--numstat`.

Fixtures (jq 1.7.1, SHA-256 `5942c9b0...`; real git on a shallow clone): 9 `red` cases and 10
`verdict` cases pass, 8 mutations caught; the composite suite (32) and the `dev-execute` suite
(37, which includes the non-owner `/approve` cases) pass against the current files; zizmor 1.30.1
auditor: one informational finding in `ux-ui.yml`, a file not touched. The first fixture run found
that a failing `git diff` was reported as `none`; fixed before `c06f7ad`, it is `error`. The older
`dev-execute-draft` suite fails 11 `gate` cases against the current workflow because its `gate()`
does not set `OWNERS`, which the author gate reads; it passes 31 of 31 against its own copy and the
37-case suite is its successor (inference from the diff; the old suite was not updated).

Live results (sandbox):

| Case | Run | Result |
|---|---|---|
| #30, red check | `38273662046` | round 1: `RED_STATE: red`, checker pass (4 of 4 criteria), branch pushed with 1 commit; step "Open the pull request" failed: `GitHub Actions is not permitted to create or approve pull requests` |
| #32, `TEST_COMMAND=sh tests/gate_round.sh` | `38274849586` | round 1: executor `done`, `TEST_EXIT: 1`, `RED_STATE: red`, checker `fail`; round 2 read the findings and the executor reported `blocked`; findings comment, no push, no PR; run conclusion success |

Inference: the red check works on a real run (one sample). The executor does not see `ROUND`: its
test run passed and the workflow's failed, as designed. The `fail` verdict reaches the findings
file and round 2 reads it (the executor's reply quotes the round 1 finding). The PR step failure
is the accepted gap (setting off), not a result of this change.

Not verified: the draft PR after a final `fail` (the executor blocked in round 2, the second
sample of an executor that blocks instead of failing; covered by fixtures only, and the PR step
would meet the same setting); `green_on_base` and `error` live; the non-owner `/approve` live (no
second account). Limits of the red check: a non-zero exit on the base can come from a missing file
and not from the reason the plan states; `setup_command` effects are not in the base worktree; a
diff with no test file is not failed by this step; one sample per case.

Corrections: gap row "`red_seen` is self-reported" is closed by this record, with the limits
above; gap row "`fail` with a draft PR and round 2 `findings_file` not seen live" is half closed
(`fail` and the round 2 findings seen, the draft PR not); "Non-owner trigger not run live" is
unchanged. Cleanup: issues #30 and #32 closed, branch deleted, fixture dropped (`f084f48`), #31
closed, `TEST_COMMAND` restored; `TEST_PATHS` stays set.
