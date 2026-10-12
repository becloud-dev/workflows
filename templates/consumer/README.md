# Consumer template

Files and a bootstrap script for a new repository that uses the shared workflows of
`becloud-dev/workflows`. The callers are the ones `triage-sandbox` runs; each calls a reusable
workflow at the moving tag `@v0`.

## Contents

| Path | Purpose |
|---|---|
| `.github/workflows/` | the 11 callers: `pr-checks`, `release-please`, `release-gate`, `release-review`, `release-issues`, `triage`, `dev-plan`, `dev-execute`, `ux-ui`, `planner-backlog`, `planner-roadmap` |
| `release-please-config.json`, `.release-please-manifest.json` | release notes sections (`refactor` visible), the seed version `0.1.0`, and `bump-minor-pre-major`: while the version is 0.x a breaking change bumps the minor version, so 1.0.0 is chosen by hand |
| `.github/ISSUE_TEMPLATE/` | `bug.md`, `project.yml` |
| `AGENTS.md`, `docs/design-system.md` | stubs to fill; `ux-ui` reads the design system |
| `bootstrap.sh` | labels, repository variables and the seed tag |

## Order of use

1. Create the repository on GitHub (owner).
2. Grant the repository the organisation secrets `CLAUDE_CODE_OAUTH_TOKEN` and
   `APP_PRIVATE_KEY` and the organisation variable `APP_CLIENT_ID` (visibility `selected`;
   a settings step). Do this before the first push: without `APP_CLIENT_ID` the
   `release-please` run on that push fails.

   Also grant the organisation secret `EXECUTOR_APP_PRIVATE_KEY` and the organisation variable
   `EXECUTOR_APP_CLIENT_ID` (visibility `selected`), and install the executor App on the
   repository. The development execution pushes its branch and opens its pull request with that
   App; without them the execution stops at the push. What the App may do is recorded in
   `docs/stages.md` of `workflows`.
3. Copy the contents above, except `README.md` and `bootstrap.sh`, into a clone. Fill
   `AGENTS.md`. When the seed version is not `0.1.0`, set it in `.release-please-manifest.json`
   and pass the same value as `--seed`. Commit and push to the default branch.
4. Run `bootstrap.sh` as the owner with `gh` logged in; `--dry-run` first:

       templates/consumer/bootstrap.sh --repo OWNER/NAME --owners LOGIN \
         --check 'CHECK COMMAND' --test 'TEST COMMAND' --test-paths 'tests/*' --dry-run

   It reads the default branch, the organisation issue field `Priority` and the seed tag,
   writes nothing when a read fails, then creates the six labels, sets `OWNERS`,
   `CHECK_COMMAND`, `TEST_COMMAND`, `TEST_PATHS` and `PRIORITY_FIELD_ID`, and tags the tip of
   the default branch `v<seed>`. An existing tag is left as it is.
5. Read back: labels, variables and tag with `gh`; then push a `feat:` commit and read the
   release pull request and the `release-gate` status.

## Settings left as they are

Default workflow permissions `read`; "Allow GitHub Actions to create and approve pull requests"
off. The executor App opens the pull request, so the setting is not needed.

## Limits

- Callers use the moving tag `@v0` of `workflows`, not a SHA; a change to `workflows` reaches
  them only after its release pull request is merged, which moves `v0`.
- `CHECK_COMMAND` and `TEST_COMMAND` cannot contain a quote, backslash, dollar, backtick or
  newline (`dev-round` refuses them).
- `SETUP_COMMAND` is optional and not set by the script.
- `bootstrap.sh` creates no organisation secret, variable or Project; the grant in step 2 is
  yours.
- The version stays below 1.0.0 until someone decides otherwise. 1.0.0 is reached only by a
  deliberate step: a commit with a `Release-As: 1.0.0` footer, or removing `bump-minor-pre-major`
  from `release-please-config.json`.
