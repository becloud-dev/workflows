#!/usr/bin/env bash
# The forged-plan regression (#65), reproduced on a production-shaped bundle. The publish job checks a
# bundle's diff against the approved plan's Files list. On `v0` the step reads "the last bot dev-plan
# comment" with no pin, so a plan comment the rounds job edited or reposted is trusted: a bundle that
# adds a workflow file the owner never approved is published with the executor App's workflows-write
# token. This suite runs v0's own step and shows it accepts that bundle (red).
#
# The fix is the gate's (comment id, sha256) pin, re-checked by `wf executor publish-check` in the
# isolated publish job: a comment whose body changed after the approval is refused. That half is
# cli/tests/executor_publish.rs (`a_forged_plan_naming_an_unapproved_workflow_is_refused`,
# `a_plan_edited_after_the_approval_is_refused_although_it_now_names_the_deletion`,
# `a_reposted_plan_has_another_id_and_is_refused`), which build and run the real `wf` against a real
# git dir. The two halves are the red (here) and the green (there) of the same case.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"

# v0's publish-scope step, vendored verbatim beside this suite (v0-publish-check.sh): the CI checkout
# has no tags, so the released step is tested from a committed copy, not `git show v0:`.
VENDORED=$PWD/v0-publish-check.sh  # this suite's directory: the script cd'd into it above
cp "$VENDORED" "$WORK/v0-check.sh"

# When the v0 tag is present (any checkout with tags), the vendored copy must still match the shipped
# step, so the snapshot cannot drift unnoticed; skipped where the tag is absent (the CI checkout).
if git -C "$ROOT" rev-parse -q --verify v0 >/dev/null 2>&1; then
  git -C "$ROOT" show v0:.github/workflows/dev-execute.yml > "$WORK/v0.yml"
  extract_step "$WORK/v0.yml" dev-publish "Check the bundle against the plan" "$WORK/v0-live.sh"
  # compare against the vendored copy with its provenance header (through the marker) stripped
  sed '1,/^#@@ v0 verbatim below @@$/d' "$VENDORED" | diff - "$WORK/v0-live.sh" > /dev/null \
    && ok || bad "v0-publish-check.sh has drifted from the v0 tag; refresh it from git show v0:..."
else
  echo "# skip: the v0 tag is not in this checkout; the vendored copy is used as is"
fi

# A production-shaped bundle: a shallow-free bare git dir holding the approved base and, at
# refs/push/head, one commit that adds an unapproved workflow .github/workflows/evil.yml.
SRC=$WORK/src
git init -q -b main "$SRC"
mkdir -p "$SRC/src" "$SRC/.github/workflows"
printf 'x\n' > "$SRC/src/a.rs"
printf 'name: ci\n' > "$SRC/.github/workflows/ci.yml"
git -C "$SRC" -c user.email=t@t -c user.name=t add -A
git -C "$SRC" -c user.email=t@t -c user.name=t commit -q -m base
BASE=$(git -C "$SRC" rev-parse HEAD)
printf 'name: evil\non: {push: {}}\njobs: {x: {runs-on: ubuntu-latest, steps: [{run: id}]}}\n' > "$SRC/.github/workflows/evil.yml"
git -C "$SRC" -c user.email=t@t -c user.name=t add -A
git -C "$SRC" -c user.email=t@t -c user.name=t commit -q -m evil
PUSH=$(git -C "$SRC" rev-parse HEAD)

RT=$WORK/rt; mkdir -p "$RT"
git init -q --bare "$RT/publish.git"
git -C "$RT/publish.git" fetch -q "$SRC" "$PUSH:refs/push/head"  # brings the base object too (its ancestor)

# The checkout the step reads HEAD from: a worktree at the approved base.
CO=$WORK/co
git clone -q "$SRC" "$CO"
git -C "$CO" -c advice.detachedHead=false checkout -q "$BASE"

# A stub gh that answers the step's one read with the comment body in $STUB_PLAN, as the rounds job
# could leave it. --jq '.[]' is applied by real gh to the comments array; the stub prints the object.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
[ "$1 $2" = "api --paginate" ] || { echo "unexpected gh call: $*" >&2; exit 99; }
jq -nc --rawfile b "$STUB_PLAN" '{user: {login: "github-actions[bot]"}, body: $b}'
STUB
chmod +x "$WORK/bin/gh"

run_v0() { # $1 = plan file; runs v0's step against the bundle, returns its exit code in RC
  ( cd "$CO" \
    && PATH="$WORK/bin:$PATH" GH_TOKEN=x GITHUB_REPOSITORY=acme/app ISSUE=13 \
       RUNNER_TEMP="$RT" STUB_PLAN="$1" bash "$WORK/v0-check.sh" > "$WORK/v0.log" 2>&1 )
  RC=$?
}

# The approved plan names only src/a.rs. v0 refuses the bundle and names the unapproved workflow: v0's
# scope check itself is sound when it reads the real plan.
printf '<!-- dev-plan -->\n**Files**\n- `src/a.rs`\n' > "$WORK/approved.md"
run_v0 "$WORK/approved.md"
{ [ "$RC" -ne 0 ] && grep -q 'evil.yml' "$WORK/v0.log"; } \
  && ok || bad "v0 should refuse the unapproved workflow under the approved plan (rc $RC): $(cat "$WORK/v0.log")"

# The forged plan the rounds leave behind names evil.yml. v0 has no pin, reads the forged comment, and
# publishes the unapproved workflow: the regression (#65). Red on v0.
printf '<!-- dev-plan -->\n**Files**\n- `src/a.rs`\n- `.github/workflows/evil.yml`\n' > "$WORK/forged.md"
run_v0 "$WORK/forged.md"
[ "$RC" -eq 0 ] \
  && ok || bad "v0 is expected to accept the forged plan (the regression); rc $RC: $(cat "$WORK/v0.log")"

# The injected-environment case (#55, #56, #61). The check, test and red commands run code the
# executor wrote and can append BASH_ENV, GITHUB_ENV and GITHUB_PATH entries that run at the start of
# every later bash step of their job. The defence is structural, not a guard: the push and pull request
# run in dev-publish, a separate job on its own runner that runs no consumer command and no round, and
# the only inputs it trusts for whether and what to publish are the pins the no-code dev-gate job
# recorded. So nothing a round wrote into the environment reaches the step that holds the App token.
# This pins that structure; it holds on v0 too (the separate publish job shipped in 0.3.0), so #56 is a
# regression pin, not a v0-red case (docs/decisions.md, docs/cli.md).
python3 -I - "$ROOT/.github/workflows/dev-execute.yml" <<'PY' && ok || bad "dev-publish is not isolated from the rounds' environment"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
j = d["jobs"]["dev-publish"]
assert "dev-gate" in j["needs"], j["needs"]
# no consumer command and no round runs in the token-holding job
blob = yaml.dump(j)
for forbidden in ("setup_command", "check_command", "test_command", "dev-round", 'bash -c "$CHECK', 'bash -c "$TEST'):
    assert forbidden not in blob, forbidden
# the security decision (the plan pin and the base) comes only from the no-code gate job
check = [s for s in j["steps"] if s.get("id") == "check"][0]
env = str(check["env"])
assert "needs.dev-gate.outputs.plan_comment_id" in env and "needs.dev-gate.outputs.plan_sha256" in env, env
assert "needs.dev-execute" not in env, env
# the App token is minted and the branch pushed only after that check step
ids = [s.get("id") or s.get("name") for s in j["steps"]]
assert ids.index("check") < ids.index("executor_app"), ids
assert ids.index("executor_app") < ids.index("Push the branch"), ids
PY

summary
