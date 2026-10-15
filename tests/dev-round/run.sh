#!/usr/bin/env bash
# The commands step of the dev-round composite, and the execute, check and verdict steps' calls to wf
# (the red and scope steps have their own suites).
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
W=$WORK; mkdir -p "$W/bin"
python3 -I - "$ROOT/.github/actions/dev-round/action.yml" "$W" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
for s in d["runs"]["steps"]:
    if s.get("shell") == "bash" and s.get("id") in ("execute", "commands", "check", "verdict"):
        assert "${{" not in s["run"], f"expression left in run block {s['id']}"
        open(f"{sys.argv[2]}/{s['id']}.sh", "w").write(s["run"])
PY
expect() { # name condition-exit
  if [ "$2" -eq 0 ]; then ok "$1"; else bad "$1"; fi
}

# fresh env for each case
newcase() { C=$W/case; rm -rf "$C"; mkdir -p "$C/tmp"; export RUNNER_TEMP=$C/tmp GITHUB_OUTPUT=$C/out; : > "$GITHUB_OUTPUT"; }
out() { grep -E "^$1=" "$GITHUB_OUTPUT" | tail -1 | cut -d= -f2-; }

echo "# execute and check: the steps run wf"
# the allowlist (the plain git commands, the consumer's commands, refused characters), the scope of
# each call and its inputs are cli/src/executor/calls.rs and cli/tests/executor_calls.rs
cat > "$W/bin/wf-call" <<'STUB'
#!/usr/bin/env bash
echo "$*" > "$STUB_ARGS"
printf 'PATH0=%s\nTOKEN=%s\nCHECK=%s\nTEST=%s\n' "${PATH%%:*}" "${CLAUDE_CODE_OAUTH_TOKEN-unset}" "${CHECK-unset}" "${TEST-unset}" >> "$STUB_ARGS"
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$W/bin/wf-call"
crun() { # step exit-code
  STUB_ARGS=$(mktemp "$W/cargs.XXXXXX"); export STUB_ARGS STUB_EXIT=$2; CO=$(mktemp "$W/cout.XXXXXX")
  ( cd "$W" && WF="$W/bin/wf-call" CLAUDE_DIR=/pinned/claude CLAUDE_CODE_OAUTH_TOKEN=tok REPO=o/r ISSUE=13 ROUND=2 MODEL=m \
      PLAN_FILE=/p/plan.md FINDINGS_FILE=none RESULTS=/r/results.md BASE=abc CHECK='npm run check' TEST='npm test' \
      RUNNER_TEMP="$W/tmp" GITHUB_OUTPUT="$CO" bash "$W/$1.sh" > /dev/null 2>&1 ); CRC=$?; }
crun execute 0
[ "$CRC" = 0 ] && [ "$(head -1 "$STUB_ARGS")" = "executor execute --repo o/r --issue 13 --round 2 --model m --plan-file /p/plan.md --findings-file none --work-dir $W/tmp --github-output $CO" ] \
  && ok || bad "execute step arguments: $(head -1 "$STUB_ARGS")"
grep -qx 'PATH0=/pinned/claude' "$STUB_ARGS" && grep -qx 'TOKEN=tok' "$STUB_ARGS" && grep -qx 'TEST=npm test' "$STUB_ARGS" && ok \
  || bad "execute step: the pinned claude, the token and the commands do not reach wf: $(cat "$STUB_ARGS")"
crun execute 1
[ "$CRC" != 0 ] && ok || bad "execute step: a call without a valid result must fail the step, so the commands do not run"
crun check 0
[ "$CRC" = 0 ] && [ "$(head -1 "$STUB_ARGS")" = "executor check --repo o/r --issue 13 --round 2 --model m --plan-file /p/plan.md --results-file /r/results.md --base abc --work-dir $W/tmp --github-output $CO" ] \
  && ok || bad "check step arguments: $(head -1 "$STUB_ARGS")"
python3 -I - "$ROOT/.github/actions/dev-round/action.yml" <<'PY' && ok || bad "dev-round still calls claude-code-action or keeps a token for it"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert not any("claude-code-action" in str(s.get("uses", "")) for s in d["runs"]["steps"])
assert "github_token" not in d["inputs"]
check = [s for s in d["runs"]["steps"] if s.get("id") == "check"][0]
assert not {"CHECK", "TEST"} & set(check["env"]), "the check call gets no consumer command"
PY

echo "# commands"
# A tiny project the commands run in: a script and its test (the test fails when the script changes).
mkfix() {
  rm -rf "$W/repo"; mkdir -p "$W/repo/bin" "$W/repo/tests"
  printf '#!/bin/sh\n# Print a greeting.\necho "hello"\n' > "$W/repo/bin/greet"
  chmod +x "$W/repo/bin/greet"
  cat > "$W/repo/tests/greet_test.sh" <<'T'
#!/bin/sh
set -eu
dir=$(cd "$(dirname "$0")/.." && pwd)
out=$("$dir/bin/greet")
[ "$out" = hello ] || { echo "FAIL: expected 'hello', got '$out'" >&2; exit 1; }
echo ok
T
}
mkfix; newcase; (cd "$W/repo" && ROUND=1 CHECK='sh -n bin/greet' TEST='sh tests/greet_test.sh' bash "$W/commands.sh" >/dev/null 2>&1); rc=$?
expect "commands: both pass, step exit 0" $rc
[ "$(out check_exit)" = 0 ] && [ "$(out test_exit)" = 0 ] && ok "commands: exits 0 and 0" || bad "commands: exits ($(out check_exit),$(out test_exit))"
f=$(out results_file); grep -q 'exit code: 0' "$f" && grep -q '^ok$' "$f" && ok "commands: results file has exit code and output tail" || bad "commands: results file"
[ "$(basename "$f")" = round-1-results.md ] && ok "commands: file named by round" || bad "commands: file name $f"
mkfix; sed -i 's/^echo "hello"$/echo "bye"/' "$W/repo/bin/greet"
newcase; (cd "$W/repo" && ROUND=2 CHECK='sh -n bin/greet' TEST='sh tests/greet_test.sh' bash "$W/commands.sh" >/dev/null 2>&1); rc=$?
expect "commands: failing test does not fail the step" $rc
[ "$(out check_exit)" = 0 ] && [ "$(out test_exit)" = 1 ] && ok "commands: test exit 1 reported" || bad "commands: exits ($(out check_exit),$(out test_exit))"
grep -q "FAIL: expected 'hello'" "$(out results_file)" && ok "commands: failure output in the tail" || bad "commands: failure output"
mkfix; newcase; (cd "$W/repo" && ROUND=1 CHECK='' TEST='' bash "$W/commands.sh" >/dev/null 2>&1); rc=$?
expect "commands: nothing configured exit 0" $rc
grep -q 'not configured' "$(out results_file)" && [ -z "$(out check_exit)" ] && ok "commands: not configured, no exit output" || bad "commands: not configured"
# long output is cut to 4000 characters
mkfix; newcase; (cd "$W/repo" && ROUND=1 CHECK='yes aaaaaaaaaaaaaaaaaaaa | head -n 500' TEST='' bash "$W/commands.sh" >/dev/null 2>&1)
n=$(awk '/^```$/{c++;next} c==1{print}' "$(out results_file)" | wc -c)
[ "$n" -le 4100 ] && ok "commands: tail capped ($n characters)" || bad "commands: tail $n characters"

echo "# verdict: the step runs wf"
# the verdict cases (blocked, pass, model fail, forced fails, unmet criterion, invalid results) are
# cli/src/executor/verdict.rs; here only what the step wraps around the CLI
cat > "$W/bin/wf-verdict" <<'STUB'
#!/usr/bin/env bash
echo "$*" > "$STUB_ARGS"
env | grep -E '^(EXECUTE|CHECK|CHECK_EXIT|TEST_EXIT|RED_STATE|SCOPE_STATE|SCOPE_VIOLATIONS|SCOPE_KINDS)=' | sort > "$STUB_ARGS.env"
echo "outcome=done" >> "$GITHUB_OUTPUT"
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$W/bin/wf-verdict"
vrun() { # exit code of wf
  VO=$(mktemp "$W/vout.XXXXXX"); STUB_ARGS=$(mktemp "$W/vargs.XXXXXX"); export STUB_ARGS STUB_EXIT=$1
  ( cd "$W" && WF="$W/bin/wf-verdict" RUNNER_TEMP="$W/tmp" ROUND=2 EXECUTE='{"outcome":"done"}' CHECK='{"verdict":"pass"}' \
      CHECK_EXIT=0 TEST_EXIT=1 RED_STATE=red SCOPE_STATE=ok SCOPE_VIOLATIONS='[]' SCOPE_KINDS='[]' GITHUB_OUTPUT="$VO" \
      bash "$W/verdict.sh" > /dev/null 2>&1 )
}
vrun 0
[ "$(cat "$STUB_ARGS")" = "executor verdict --round 2 --findings-file $W/tmp/round-2-findings.md --github-output $VO" ] \
  && ok || bad "verdict step arguments: $(cat "$STUB_ARGS")"
[ "$(wc -l < "$STUB_ARGS.env")" = 8 ] && grep -qx 'TEST_EXIT=1' "$STUB_ARGS.env" && ok || bad "verdict step: the results do not reach wf: $(cat "$STUB_ARGS.env")"
grep -qx 'outcome=done' "$VO" && ! grep -q 'outcome=failed' "$VO" && ok || bad "verdict step: the CLI's outputs are not passed through"
vrun 3
grep -qx 'outcome=failed' "$VO" && grep -qx 'verdict=none' "$VO" && ok || bad "verdict step: a failing CLI must leave the round failed: $(cat "$VO")"

summary
