# Research: consumer templates and security design

The consumer template build, the security design checklist, pinning by tag and the static site template facts.

Moved from the former `third-party-review.md` and the CLI design draft, entries kept as written. Decisions in force are
in [decisions.md](../decisions.md); where a later entry corrects an earlier one, the entry says so.
Each entry names its sources, marks inference, and lists what is unverified.

### Consumer template: facts read (2026-10-12)

Source read: `workflows` `triage.yml` (lines 93, 150-158) and `release-issues.yml` (lines 115,
167-170): `priority_field_id` is a required input, used as `jq --argjson id` in
`issue_field_values`; an empty or non-numeric value fails the step that applies the verdict.
Live read (`gh api`, owner token): `GET orgs/becloud-dev/issue-fields` lists the field `Priority`
(`48149712`, single select Urgent, High, Medium, Low, visibility `organization_members_only`),
`Start date`, `Target date` and `Effort`; `GET orgs/becloud-dev/issue-types` lists `Task`, `Bug`,
`Feature` and `Project`, all enabled. Org secrets `CLAUDE_CODE_OAUTH_TOKEN` and
`APP_PRIVATE_KEY` and org variable `APP_CLIENT_ID` have visibility `selected`, granted to
`triage-sandbox` only. Sandbox settings: default workflow permissions `read`, approving pull
requests off, no ruleset. `gh` 2.102.0 help and manual: `gh label create --force` updates an
existing label; `gh variable set --body` sets a repository variable. `rest-api-description`
(`api.github.com.json`): `POST /repos/{owner}/{repo}/git/refs` takes `ref` and `sha`, answers 201,
409 or 422, and cannot create a reference in an empty repository.

Inference: the Priority field is organisation-wide, so a new repository in the organisation can
use the same id; the template looks the id up and does not hardcode it. A new repository needs a
grant of the two secrets and the variable before any caller that uses them runs. The seed tag
comes after the first push to the default branch.

Not verified: that issue field values set through the API work on a new repository (the live run
shows it); the organisation Project (the token lacks `read:project`); whether release-please
treats a tag made through `git/refs` like the sandbox's `v0.1.0`.

### Consumer template: build and live test (2026-10-12)

Decisions (user, 2026-10-12): the template is a directory plus a bootstrap script; all 11
callers; tested on a scratch repository, deleted afterwards.

Change (`workflows`): `fe58880` (`templates/consumer/`: the 11 callers as the sandbox runs them
minus the three "copy to the sandbox" header comments, `release-please-config.json`,
`.release-please-manifest.json` at `0.1.0`, issue templates, `AGENTS.md` and `design-system.md`
stubs), `0b4a993` and `1c1884b` (`bootstrap.sh`), `ab0036e` (`README.md`). The script reads the
repository, its default branch tip, the organisation issue field `Priority` and the seed tag
before it writes; then it creates six labels, sets `OWNERS`, `CHECK_COMMAND`, `TEST_COMMAND`,
`TEST_PATHS` and `PRIORITY_FIELD_ID`, and creates tag `v<seed>` on the tip. Deviation from the
plan: an existing tag is left as it is (its object printed) and not refused, so a re-run after a
partial failure is not blocked.

Fixtures (jq 1.7.1, stub `gh` applying the real `--jq` filters): 46 cases, 14 mutations caught
(a first survivor differed only by an error message; the message is now asserted). Caller
checker (inputs, required inputs, secrets, permissions against the reusable workflows): 9 callers
OK, 2 inline jobs skipped, 3 deliberately broken callers fail. zizmor 1.30.1 auditor on the
template: 27 findings, equal to the sandbox callers (9 `unpinned-uses` from `@main`, 8
`excessive-permissions`, 8 `undocumented-permissions`, 1 `dangerous-triggers` accepted, 1
`secrets-outside-env`).

Live results (`becloud-dev/consumer-template-scratch`, public, created empty):

| Step | Run or object | Result |
|---|---|---|
| first push, before the grant | `release-please` `38281215898` | failure: `client-id` empty (the org variable is not granted yet) |
| bootstrap | labels, variables, tag | six labels, five variables, `v0.1.0` on `c99ac0b`, read back with `gh` |
| `feat:` push `5a57828`, after the grant | `release-please` `38281407694` | PR #1 `chore(main): release 0.2.0`, notes Features, compare from `v0.1.0` |
| PR head `7b383e3` | `pr-checks` `38281443740`; `release-gate` | check success; status failure "missing label READY TO LIVE" |
| issue #2, label `triage` | `38281538887` | type `Feature`, `Priority` `Low` read back |
| issue #2, label `RELEASE` | `38281642497` | plan comment posted |

Inference: the org-level grant must precede the first push (the README order is corrected); the
Priority issue field, the App installation and the lightweight seed tag work on a new
repository in the organisation (one sample each).

Not verified: `/approve` execution on a new repository (the pull request step meets the setting,
accepted gap); the gate on a release PR with `READY TO LIVE` and a review; `SETUP_COMMAND`; a
repository outside the organisation; the callers stay on `@main` (Security design). Cleanup,
run by the assistant on the user's instruction: the three grants revoked (read back: only
`triage-sandbox` remains) and the scratch repository deleted (`gh repo list`: `workflows` and
`triage-sandbox`).

### Security design: facts read (2026-10-12)

Source read (raw): `OWASP/Top10` `2025/docs/en` (`index.md`, `0x00_2025-Introduction.md` and
the ten category pages `A01` to `A10`, Description sections; the folder's last commit is
2026-09-24): Broken Access Control, Security Misconfiguration, Software Supply Chain Failures,
Cryptographic Failures, Injection, Insecure Design, Authentication Failures, Software or Data
Integrity Failures, Security Logging and Alerting Failures, Mishandling of Exceptional
Conditions. `workflows` `dev-plan.yml` lines 109-167: the output schema and the jq validation
cap `spec` at 8, `steps` at 10 and `acceptance_criteria` at 8 (2 to 8 required); the comment is
built from the fields and the execution reads it as written. `zizmor` 1.30.1 on
`templates/consumer/.github/workflows/release-gate.yml`: `dangerous-triggers` spans lines 3 to 12
(the whole `on:` mapping); `docs/usage.md` ("Ignoring results"): an ignore comment is valid
anywhere in the span of a finding when it is a YAML comment, and may carry an explanation.
`rest-api-description` (`api.github.com.json`): `PATCH /repos/{owner}/{repo}/git/refs/{ref}`
takes `sha` and `force`; a ruleset `target` is `branch`, `tag` or `push`. `release-please` v17.6.0
`schemas/config.json`: `initial-version`, `bootstrap-sha`, `include-v-in-tag`,
`force-tag-creation`.

Inference: security controls, which are also acceptance criteria and tests, compete with the
existing cap of 8; the cap is a decision of the stage 4 step. `workflows` has no tag, so its first
release needs a seed tag or `bootstrap-sha`; a moving major tag is moved with `PATCH` and
`force: true`.

Not verified: that an ignore comment on the `workflow_run:` line suppresses only that finding
(run in the `dangerous-triggers` step); rulesets for tags on a public repository of a free
organisation; release-please behaviour on the `workflows` repository itself.

### Security design: stage 4 checklist and stage 5 review (2026-10-12)

Decisions (user, 2026-10-12): basis OWASP Top 10:2025; stage 4 gets a `security` field whose
controls are also acceptance criteria and tests; stage 5 is prompt only, no schema change; the
caps of `spec` and `acceptance_criteria` rise from 8 to 10.

Change (`workflows`): `77952b2` (`prompts/dev-plan.md`: the `security` return item with the ten
categories; `dev-plan.yml`: schema field, caps 10, validation, a "Security" section in the plan
comment), `de89f56` (`prompts/release-review.md` item 2: the ten categories, category named in
the finding `body`, titles unprefixed). The validation refuses a plan where a category repeats,
is not `A01` to `A10`, or has a control without an acceptance criterion and a `spec` entry that
start with its id.

Fixtures (jq 1.7.1, stub `gh`, real `run:` block of "Post the plan"): 30 cases pass; the same
cases fail 14 on the block before the change; 10 mutations caught, 1 equivalent survivor (the
`security` length cap is bounded by uniqueness and the category check). zizmor 1.30.1 auditor
on `workflows`: only the earlier informational finding in `ux-ui.yml`. Defect found by the
fixtures and fixed before use: the jq validation did not re-check that `category` is `A01` to
`A10`, only the model's output schema did (class: a constraint enforced only on the producer's
schema; caught by fixtures with out-of-range values).

Live results (sandbox):

| Case | Run | Result |
|---|---|---|
| issue #34 (`--name` flag with an injection angle), label `RELEASE` | `dev-plan` `38283460398` | plan with a Security section A05 and A10, criteria and `spec` entries prefixed `A05:` and `A10:` |
| `/review` on release PR #33 | `release-review` `38283699578` | blocking finding `bin/greet:5` with body "A05 Injection: ..."; deferred test finding; review SHA `6770ff7` |

Inference: with the category list the plan and the review name the right category (one sample
each; A10 in the plan was the model's own addition).

Not verified: a plan with no security angle live (the "no category applies" line is fixture
only); a release that does not touch the file holding a defect; cost and variance per model.

### Security design: pinning by tag (2026-10-12)

Decisions (user, 2026-10-12): callers reference the moving tag `v0` of `workflows`, not `@main`;
the sandbox stays on `@main` (to be archived, no further change); no separate release test, the
first real release of `workflows` is the test; a release creates the exact tag `v0.x.y` and
moves `v0`.

Source read (raw): `googleapis/release-please-action` at `45996ed` `README.md` (root outputs
`release_created`, `major`, `minor`, `sha`; the major and minor tag example); `github/docs` on
`$/` (record "Self-repository action reference": resolves to the commit of the running
workflow); `rest-api-description` (`PATCH` and `POST` on `git/refs`).

Change (`workflows`): `6edb362` (`release-please-config.json` with the sections,
`.release-please-manifest.json` at `0.1.0`, `release-please.yml` with the step "Move the major
tag": `PATCH` with `force` when the tag exists, `POST` otherwise, `MAJOR` and `SHA` validated),
`0712943` (the nine reusable callers of `templates/consumer/` on `@v0`, README limits). Grants:
`APP_PRIVATE_KEY` and `APP_CLIENT_ID` to `workflows` only. Tags `v0.1.0` and `v0` on `0712943`,
created from a temporary branch before `main` was pushed, so the first run found its baseline.

Fixtures (stub `gh`, real `run:` block): 16 cases, 7 mutations caught. Defect found and fixed
before use: the guard `[[ MAJOR ]] && [[ SHA ]]` under `set -e` did not stop on an invalid
`MAJOR`, because a failing non-final operand of an `&&` list does not trigger errexit (class: a
`set -e` guard written as an `&&` chain; caught by a fixture with an invalid first operand).
zizmor 1.30.1 on `release-please.yml`: `secrets-outside-env` on the App key, accepted as on the
sandbox.

Live: `release-please` run `38284908822` on `workflows`: success; "looking for tagName:
v0.1.0"; no release PR; the tag step skipped as no release was created.

Inference: the seed tag is a sufficient baseline; the tag step runs only when a release is
created; `$/` should resolve to the tagged commit (documented, not run).

Not verified: the first real release (tag creation, the `sha` output, the move of `v0`); a tag
ruleset on `refs/tags/v*` (settings step, and rulesets on tags for this organisation's plan);
`$/` and the `prompts` checkout on a caller at `@v0` live; the template callers on `@v0` in a
real project run.

### Static site template: facts read (2026-10-12)

Source read: `getzola/zola` release `v0.23.6` assets (GitHub releases API: Linux `.tar.gz`
assets carry a `sha256` digest) and `docs/content/documentation/getting-started/cli-usage.md`
(`build` writes `public/` and removes it first; `check` builds without writing and fetches
external links in Markdown, `--skip-external-links` skips them) and `configuration.md` (keys
`base_url`, `default_language`, `output_dir`, `minify_html`, `build_search_index`, `[markdown]`,
`[link_checker]`, `[extra]`); `cloudflare/cloudflare-docs` `workers/static-assets` (`routing`,
`binding` with `run_worker_first` as an array of globs and `!` negatives, `headers`,
`billing-and-limitations`), `workers/platform/limits` (20,000 files and 25 MiB per file on the
Free plan) and `workers/testing/test-harness` (`createTestHarness()`, Playwright integration);
npm registry on 2026-10-12 (`@cloudflare/vitest-plugin` 1.4.0: peer `vitest ^4.1.0 || ^5.0.0`,
depends on `wrangler 4.149.0`; `wrangler` needs Node 22 or newer); htmx 2 `hx-select`,
`hx-boost`, `hx-trigger`; RFC 6265 section 6.1 (user agents should store at least 4096 bytes per
cookie, name, value and attributes together, and 50 cookies per domain); `bentoluizv/patagonia-trip`
(private; `package.json`, `wrangler.jsonc`, workflows, hooks, `CLAUDE.md`, `CONTRIBUTING.md`,
`src/index.tsx`, `src/shared/{theme.ts,http.tsx,ui/layout.tsx,ui/hx.tsx}`, `vitest.config.ts`,
`e2e/fixtures.ts`).

Inference: a Zola build into `public/` served by an assets Worker with `run_worker_first`
limited to the dynamic routes keeps static pages free of Worker invocations; a Zola binary can
be installed in CI from the release with its published SHA-256; a cookie value stays near 3 KB
to leave room for attributes.

Not verified: that `run_worker_first` patterns and `hx-select` behave as read on a built site
(the template's own tests are the check); the Worker's behaviour with `vitest` 5 and the
plugin (installed in phase 3); Zola template details for per-question pages.
