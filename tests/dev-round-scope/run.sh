#!/usr/bin/env bash
# The `scope` step of the dev-round composite: a call to `wf executor scope` that fails closed. The
# scope cases themselves (deletions, renames, workflow changes, literal matching, unreadable plan or
# base) are cli/tests/executor_scope.rs and cli/src/executor/scope.rs, against real git history.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
extract_step "$ROOT/.github/actions/dev-round/action.yml" - scope "$WORK/scope.sh"
SCOPE=$WORK/scope.sh; S=$WORK

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

# what the verdict does with each scope state (ok and none pass; out_of_scope names each path by kind;
# error forces fail and names every input, #57) is cli/src/executor/verdict.rs

summary
