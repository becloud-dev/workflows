#!/usr/bin/env bash
# "Check the bundle against the plan" of dev-execute.yml's dev-publish job: a call to
# `wf executor publish-check` with the pin the gate recorded. The decision itself (unnamed
# deletions and workflow changes, a plan edited or reposted after the approval, a foreign author or
# issue, no Files heading, an unreadable bundle) is cli/src/executor/publish.rs and
# cli/tests/executor_publish.rs, which run against a real git directory.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
extract_step "$ROOT/.github/workflows/dev-execute.yml" dev-publish "Check the bundle against the plan" "$WORK/check.sh"

cat > "$WORK/wf" <<'STUB'
#!/usr/bin/env bash
echo "$*" > "$STUB_ARGS"
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$WORK/wf"
run_check() { # exit code of wf
  STUB_ARGS=$(mktemp "$WORK/args.XXXXXX"); export STUB_ARGS STUB_EXIT=$1
  ( cd "$WORK" && WF="$WORK/wf" GITHUB_REPOSITORY=acme/app ISSUE=13 PLAN_COMMENT_ID=41 PLAN_SHA256=abc123 \
      BASE=def456 RUNNER_TEMP="$WORK/tmp" GH_TOKEN=x bash "$WORK/check.sh" > /dev/null 2>&1 ); RC=$?
}

run_check 0
[ "$RC" -eq 0 ] && ok || bad "an accepted bundle must pass the step (rc $RC)"
want="executor publish-check --repo acme/app --issue 13 --plan-comment-id 41 --plan-sha256 abc123 --base def456 --git-dir $WORK/tmp/publish.git"
[ "$(cat "$STUB_ARGS")" = "$want" ] && ok || bad "arguments: $(cat "$STUB_ARGS")"
run_check 1
[ "$RC" -ne 0 ] && ok || bad "a refused bundle must fail the step, so nothing is pushed"
run_check 127
[ "$RC" -ne 0 ] && ok || bad "a CLI that cannot run must fail the step"

# the step takes the pin from the gate's outputs, never from a comment lookup of its own
python3 -I - "$ROOT/.github/workflows/dev-execute.yml" <<'PY' && ok || bad "the step reads the plan itself"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
st = [s for s in d["jobs"]["dev-publish"]["steps"] if s.get("name") == "Check the bundle against the plan"][0]
assert "gh api" not in st["run"] and "jq" not in st["run"] and "awk" not in st["run"], st["run"]
assert "plan_comment_id" in str(st["env"]) and "plan_sha256" in str(st["env"])
PY

summary
