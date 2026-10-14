#!/usr/bin/env bash
# The tools and commands steps of the dev-round composite, and the verdict step's call to wf (the red step has its own suite).
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
case "$a" in *'Bash(git rm:*)') ok "tools: base list only, no stray entry";; *) bad "tools: base list only ($a)";; esac
case ",$a," in *',Bash(git rm:*),'*) ok "tools: allowed list contains git rm";; *) bad "tools: git rm missing ($a)";; esac
missing=""
for e in Read Edit Write Grep Glob 'Bash(git add:*)' 'Bash(git commit:*)' 'Bash(git status:*)' 'Bash(git diff:*)' 'Bash(git log:*)'; do
  case ",$a," in *",$e,"*) ;; *) missing="$missing $e";; esac
done
[ -z "$missing" ] && ok "tools: existing entries unchanged" || bad "tools: existing entries missing:$missing"
case "$a" in *'git mv'*|*'git reset'*|*'git checkout'*|*'git clean'*|*'Bash(rm'*) bad "tools: wider git or rm entry ($a)";; *) ok "tools: no wider git or rm entries";; esac
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
