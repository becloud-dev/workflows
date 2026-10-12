#!/usr/bin/env bash
# The tools, commands and verdict steps of the dev-round composite (the red step has its own suite).
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
W=$WORK; mkdir -p "$W/bin"
python3 -I - "$ROOT/.github/actions/dev-round/action.yml" "$W" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
for s in d["runs"]["steps"]:
    if s.get("shell") == "bash" and s.get("id") in ("tools", "commands", "verdict"):
        assert "${{" not in s["run"], f"expression left in run block {s['id']}"
        open(f"{sys.argv[2]}/{s['id']}.sh", "w").write(s["run"])
PY
expect() { # name condition-exit
  if [ "$2" -eq 0 ]; then ok "$1"; else bad "$1"; fi
}

# fresh env for each case
newcase() { C=$W/case; rm -rf "$C"; mkdir -p "$C/tmp"; export RUNNER_TEMP=$C/tmp GITHUB_OUTPUT=$C/out; : > "$GITHUB_OUTPUT"; }
out() { grep -E "^$1=" "$GITHUB_OUTPUT" | tail -1 | cut -d= -f2-; }

echo "# tools"
newcase; CHECK='' TEST='' bash "$W/tools.sh" >/dev/null 2>&1; rc=$?
a=$(out allowed)
expect "tools: empty commands exit 0" $rc
case "$a" in *'Bash(git log:*)') ok "tools: base list only, no stray entry";; *) bad "tools: base list only ($a)";; esac
newcase; CHECK='sh -n bin/greet' TEST='sh tests/greet_test.sh' bash "$W/tools.sh" >/dev/null 2>&1; rc=$?
a=$(out allowed)
expect "tools: two commands exit 0" $rc
case "$a" in *',Bash(sh -n bin/greet:*),Bash(sh tests/greet_test.sh:*)') ok "tools: both entries appended";; *) bad "tools: both entries ($a)";; esac
for bad_cmd in 'echo "x"' 'echo $HOME' 'echo `id`' 'echo \x' $'a\nb'; do
  newcase; CHECK="$bad_cmd" TEST='' bash "$W/tools.sh" >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] && ok "tools: rejects $(printf %q "$bad_cmd")" || bad "tools: accepted $(printf %q "$bad_cmd")"
done

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

echo "# verdict"
EXE_DONE='{"outcome":"done","summary":"s","red_seen":true,"commits":["feat: x"]}'
EXE_BLK='{"outcome":"blocked","summary":"s","blocked_reason":"no such file"}'
PASS='{"verdict":"pass","summary":"s","criteria":[{"criterion":1,"met":true},{"criterion":2,"met":true}],"findings":[]}'
FAIL='{"verdict":"fail","summary":"s","criteria":[{"criterion":1,"met":true},{"criterion":2,"met":false}],"findings":[{"criterion":2,"problem":"help flag missing"}]}'
PASS_UNMET='{"verdict":"pass","summary":"s","criteria":[{"criterion":1,"met":true},{"criterion":2,"met":false}],"findings":[]}'
FAIL_NOFIND='{"verdict":"fail","summary":"s","criteria":[{"criterion":1,"met":false}],"findings":[]}'
vrun() { # EXECUTE CHECK CHECK_EXIT TEST_EXIT
  newcase; ROUND=2 EXECUTE="$1" CHECK="$2" CHECK_EXIT="$3" TEST_EXIT="$4" bash "$W/verdict.sh" >"$C/log" 2>&1; VRC=$?
  O=$(out outcome); V=$(out verdict); F=$(out findings_file)
}
vrun "$EXE_BLK" "" "" "";           expect "verdict: step exit 0 (blocked)" $VRC
[ "$O/$V" = blocked/none ] && grep -q 'no such file' "$F" && ok "verdict: blocked, reason in findings" || bad "verdict: blocked ($O/$V)"
vrun "$EXE_DONE" "$PASS" 0 0
[ "$O/$V" = done/pass ] && ok "verdict: done and pass" || bad "verdict: pass ($O/$V)"
vrun "$EXE_DONE" "$FAIL" 0 0
[ "$O/$V" = done/fail ] && grep -q 'criterion 2: help flag missing' "$F" && ok "verdict: model fail keeps findings" || bad "verdict: fail ($O/$V)"
vrun "$EXE_DONE" "$PASS" 0 1
[ "$O/$V" = done/fail ] && grep -q 'test command exited 1' "$F" && ok "verdict: non-zero test exit forces fail" || bad "verdict: forced fail ($O/$V)"
vrun "$EXE_DONE" "$PASS" 2 0
[ "$O/$V" = done/fail ] && grep -q 'check command exited 2' "$F" && ok "verdict: non-zero check exit forces fail" || bad "verdict: forced fail check ($O/$V)"
vrun "$EXE_DONE" "$PASS_UNMET" 0 0
[ "$O/$V" = done/fail ] && grep -q 'criterion 2 is not met' "$F" && ok "verdict: pass with unmet criterion becomes fail, named" || bad "verdict: unmet ($O/$V)"
vrun "$EXE_DONE" "$FAIL_NOFIND" 0 0
[ "$O/$V" = failed/none ] && ok "verdict: fail without findings is invalid (failed)" || bad "verdict: fail no findings ($O/$V)"
vrun "$EXE_DONE" 'not json' 0 0
[ "$O/$V" = failed/none ] && ok "verdict: invalid check JSON is failed" || bad "verdict: bad json ($O/$V)"
vrun "$EXE_DONE" "" "" ""
[ "$O/$V" = failed/none ] && ok "verdict: missing check result is failed" || bad "verdict: no check ($O/$V)"
vrun "" "" "" ""
[ "$O/$V" = failed/none ] && ok "verdict: missing execute result is failed" || bad "verdict: no execute ($O/$V)"
vrun "garbage" "$PASS" 0 0
[ "$O/$V" = failed/none ] && ok "verdict: invalid execute JSON is failed" || bad "verdict: bad execute json ($O/$V)"
[ "$(basename "$F")" = round-2-findings.md ] && ok "verdict: file named by round" || bad "verdict: file name $F"

summary
