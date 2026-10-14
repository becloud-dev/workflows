#!/usr/bin/env bash
# The `red` step of the dev-round composite: a call to `wf executor red`. The red check itself (red
# on the base, green on the base, code only, deleted or trimmed tests, two globs, lines added to an
# existing test, a bad base, no worktree left behind) is cli/src/executor/red.rs and
# cli/tests/executor_red.rs, on a shallow clone as the runner's checkout is.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
extract_step "$ROOT/.github/actions/dev-round/action.yml" - red "$WORK/red.sh"
S=$WORK

cat > "$S/wf" <<'STUB'
#!/usr/bin/env bash
echo "$*" > "$STUB_ARGS"
printf 'TEST=%s\nTEST_PATHS=%s\n' "${TEST-unset}" "${TEST_PATHS-unset}" >> "$STUB_ARGS"
[ "${STUB_EXIT:-0}" = 0 ] && echo "red_state=red" >> "$GITHUB_OUTPUT"
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$S/wf"
run_red() { # exit code of wf
  RO=$(mktemp "$S/rout.XXXXXX"); STUB_ARGS=$(mktemp "$S/rargs.XXXXXX"); export STUB_ARGS STUB_EXIT=$1
  ( cd "$S" && WF="$S/wf" TEST='make test' TEST_PATHS='tests/*,spec/*' BASE=abc123 ROUND=2 RUNNER_TEMP="$S/tmp" \
      RESULTS=/r/results.md GITHUB_OUTPUT="$RO" bash "$WORK/red.sh" > /dev/null 2>&1 ); RC=$?
}

run_red 0
[ "$(head -1 "$STUB_ARGS")" = "executor red --base abc123 --round 2 --work-dir $S/tmp --results /r/results.md --github-output $RO" ] \
  && ok || bad "red step arguments: $(head -1 "$STUB_ARGS")"
grep -qx 'TEST=make test' "$STUB_ARGS" && grep -qx 'TEST_PATHS=tests/\*,spec/\*' "$STUB_ARGS" && ok \
  || bad "red step: the test command and paths do not reach wf through the environment"
[ "$RC" = 0 ] && grep -qx 'red_state=red' "$RO" && ok || bad "red step: the CLI's state is not passed through"
run_red 2
[ "$RC" = 0 ] && [ "$(grep -c '^red_state=' "$RO")" = 1 ] && grep -qx 'red_state=error' "$RO" && ok \
  || bad "red step: a failing CLI must leave red_state=error and not fail the step: $(cat "$RO")"

summary
