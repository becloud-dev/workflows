#!/usr/bin/env bash
# The `scope` step of the dev-round composite (a call to `wf executor scope` that fails closed) and
# what the verdict step does with each scope state. The scope cases themselves (deletions, renames,
# workflow changes, literal matching, unreadable plan or base) are cli/tests/executor_scope.rs and
# cli/src/executor/scope.rs, which run against real git history.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
extract_step "$ROOT/.github/actions/dev-round/action.yml" - scope "$WORK/scope.sh"
extract_step "$ROOT/.github/actions/dev-round/action.yml" - verdict "$WORK/verdict.sh"
SCOPE=$WORK/scope.sh; VERDICT=$WORK/verdict.sh; S=$WORK

echo "# the scope step wraps wf"
cat > "$S/wf-ok" <<'STUB'
#!/usr/bin/env bash
echo "$*" > "$STUB_ARGS"
echo "scope_state=ok" >> "$GITHUB_OUTPUT"
STUB
cat > "$S/wf-broken" <<'STUB'
#!/usr/bin/env bash
exit 3
STUB
chmod +x "$S/wf-ok" "$S/wf-broken"
run_scope_step() { # wf-path -> $SO holds the step outputs
  SO=$(mktemp "$S/sout.XXXXXX"); : > "$SO"; STUB_ARGS=$(mktemp "$S/args.XXXXXX"); export STUB_ARGS
  ( cd "$S" && WF="$1" BASE=abc123 PLAN_FILE=/p/plan.md RESULTS=/r/results.md GITHUB_OUTPUT="$SO" bash "$SCOPE" > /dev/null 2>&1 )
}
run_scope_step "$S/wf-ok"
[ "$(cat "$STUB_ARGS")" = "executor scope --base abc123 --plan-file /p/plan.md --results /r/results.md --github-output $SO" ] \
  && ok || bad "scope step arguments: $(cat "$STUB_ARGS")"
grep -qx 'scope_state=ok' "$SO" && ok || bad "scope step does not pass the CLI's outputs through"
run_scope_step "$S/wf-broken"
[ "$(grep -c '^scope_state=' "$SO")" = 1 ] && grep -qx 'scope_state=error' "$SO" && ok \
  || bad "a CLI that fails must leave scope_state=error: $(cat "$SO")"
run_scope_step "$S/does-not-exist"
grep -qx 'scope_state=error' "$SO" && ok || bad "a missing CLI must leave scope_state=error: $(cat "$SO")"

# verdict step: needs jq 1.7.1; env EXECUTE, CHECK, CHECK_EXIT, TEST_EXIT, RED_STATE, SCOPE_STATE, SCOPE_VIOLATIONS, SCOPE_KINDS, ROUND
run_verdict() { # name want_verdict SCOPE_STATE SCOPE_VIOLATIONS [SCOPE_KINDS]
  local name=$1 want=$2 st=$3 viol=$4 kinds=${5:-} out got
  out=$(mktemp "$S/vout.XXXXXX")
  EX='{"outcome":"done","summary":"s","red_seen":true,"commits":["a"]}'
  CK='{"verdict":"pass","summary":"s","criteria":[{"criterion":1,"met":true}],"findings":[]}'
  got=$(RUNNER_TEMP="$S" EXECUTE="$EX" CHECK="$CK" CHECK_EXIT=0 TEST_EXIT=0 RED_STATE=none \
        SCOPE_STATE="$st" SCOPE_VIOLATIONS="$viol" SCOPE_KINDS="$kinds" ROUND=1 GITHUB_OUTPUT="$out" bash "$VERDICT" >/dev/null 2>&1; grep -h '^verdict=' "$out" | cut -d= -f2)
  if [ "$got" = "$want" ]; then ok; else bad "verdict $name: want $want got '$got'"; fi
  VF="$S/round-1-findings.md"
}

echo "# verdict"
run_verdict "an ok scope passes"              pass ok '[]' '[]'
run_verdict "no deletion or change passes"    pass none '[]' '[]'
run_verdict "an unnamed deletion fails"       fail out_of_scope '["tests/greet_test.sh"]' '["deleted"]'
grep -qx -- '- deletion of tests/greet_test.sh is not in the plan Files list' "$VF" && ok || bad "deletion finding: $(cat "$VF")"
run_verdict "an unnamed workflow change fails" fail out_of_scope '[".github/workflows/new.yml"]' '["changed"]'
grep -qx -- '- change of .github/workflows/new.yml under .github/workflows is not in the plan Files list' "$VF" && ok || bad "workflow finding: $(cat "$VF")"
run_verdict "both kinds are named apart"      fail out_of_scope '["a","b.yml"]' '["deleted","changed"]'
grep -qx -- '- deletion of a is not in the plan Files list' "$VF" && grep -q -- '- change of b.yml' "$VF" && ok || bad "mixed findings: $(cat "$VF")"
run_verdict "an unreadable scope forces fail" fail error '[]' '[]'
# #57: the wording names every input that could not be read
grep -qx -- '- the deletions, the workflow changes or the plan Files list could not be read' "$VF" && ok || bad "error finding: $(cat "$VF")"

summary
