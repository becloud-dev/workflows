#!/usr/bin/env bash
# The `red` step (new tests must fail on the base tree) and the verdict step of the dev-round composite.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
extract_step "$ROOT/.github/actions/dev-round/action.yml" - red "$WORK/red.sh"
extract_step "$ROOT/.github/actions/dev-round/action.yml" - verdict "$WORK/verdict.sh"
RED=$WORK/red.sh; VERDICT=$WORK/verdict.sh; S=$WORK
mkrepo() { # builds origin with base commit, shallow clone, prints clone dir
  local d; d=$(mktemp -d "$S/w.XXXXXX")
  git init -q -b main "$d/origin"
  ( cd "$d/origin" && git config user.email t@t && git config user.name t \
    && mkdir bin tests && printf 'echo hi\n' > bin/greet \
    && printf 'test "$(sh bin/greet)" = hi\n' > tests/greet_test.sh \
    && git add . && git commit -qm base )
  git clone -q --depth 1 "file://$d/origin" "$d/clone"
  ( cd "$d/clone" && git config user.email t@t && git config user.name t )
  echo "$d/clone"
}

run_red() { # name expect_state expect_files_re  TEST TEST_PATHS  setup-function
  local name=$1 want=$2 test=$3 paths=$4 setup=$5 base repo out state
  repo=$(mkrepo); base=$(git -C "$repo" rev-parse HEAD)
  ( cd "$repo" && $setup )
  out=$(mktemp "$S/out.XXXXXX"); : > "$out.res"
  state=$( cd "$repo" && env RUNNER_TEMP="$S" TEST="$test" TEST_PATHS="$paths" BASE="${BASE_OVERRIDE:-$base}" \
        ROUND=1 RESULTS="$out.res" GITHUB_OUTPUT="$out" bash "$RED" >/dev/null 2>&1; grep -h '^red_state=' "$out" | cut -d= -f2)
  if [ "$state" = "$want" ]; then ok; else bad "$name: want $want got '$state'"; cat "$out.res"; fi
  # no leftover worktree
  if [ -n "$(git -C "$repo" worktree list | sed 1d)" ]; then bad "$name: worktree left behind"; fi
  LAST_RES="$out.res"
}

add_failing_test() { printf 'test "$(sh bin/greet --shout)" = HI\n' > tests/shout_test.sh; printf 'echo hi\n' > bin/greet; git add .; git commit -qm 'test: shout'; }
add_passing_test() { printf 'test -f bin/greet\n' > tests/exists_test.sh; git add .; git commit -qm 'test: exists'; }
touch_code_only() { printf 'echo hello\n' > bin/greet; git add .; git commit -qm 'feat: x'; }
delete_test() { git rm -q tests/greet_test.sh; git commit -qm 'test: drop'; }
add_test_in_other_dir() { mkdir spec; printf 'exit 1\n' > spec/a_spec.sh; git add .; git commit -qm 'test: spec'; }
no_commit() { :; }

T='sh tests/shout_test.sh'
run_red "red on base"               red           'sh tests/shout_test.sh' 'tests/*' add_failing_test
grep -q 'exit code on the base tree: 1' "$LAST_RES" && ok || bad "red: results file lacks exit code"
run_red "green on base"             green_on_base 'sh tests/exists_test.sh' 'tests/*' add_passing_test
run_red "code only, no test file"   none          'sh tests/greet_test.sh' 'tests/*' touch_code_only
run_red "paths empty"               none          'sh tests/shout_test.sh' ''        add_failing_test
run_red "test command empty"        none          ''                       'tests/*' add_failing_test
run_red "deleted test is skipped"   none          'sh tests/greet_test.sh' 'tests/*' delete_test
run_red "two globs, second matches" red           'sh spec/a_spec.sh'      'nope/*,spec/*' add_test_in_other_dir
run_red "no commits ahead"          none          'sh tests/greet_test.sh' 'tests/*' no_commit
BASE_OVERRIDE=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef \
run_red "bad base gives error"      error         'sh tests/shout_test.sh' 'tests/*' add_failing_test
unset BASE_OVERRIDE

# verdict step: needs jq 1.7.1; env EXECUTE, CHECK, CHECK_EXIT, TEST_EXIT, RED_STATE, ROUND
run_verdict() { # name want_verdict RED_STATE CHECK_EXIT TEST_EXIT
  local name=$1 want=$2 red=$3 ce=$4 te=$5 out got
  out=$(mktemp "$S/vout.XXXXXX")
  EX='{"outcome":"done","summary":"s","red_seen":true,"commits":["a"]}'
  CK='{"verdict":"pass","summary":"s","criteria":[{"criterion":1,"met":true}],"findings":[]}'
  got=$(RUNNER_TEMP="$S" EXECUTE="$EX" CHECK="$CK" CHECK_EXIT="$ce" TEST_EXIT="$te" RED_STATE="$red" ROUND=1 \
        GITHUB_OUTPUT="$out" bash "$VERDICT" >/dev/null 2>&1; grep -h '^verdict=' "$out" | cut -d= -f2)
  if [ "$got" = "$want" ]; then ok; else bad "verdict $name: want $want got '$got'"; fi
  VF="$S/round-1-findings.md"
}
run_verdict "red state red passes"       pass red           0 0
run_verdict "none passes"                pass none          0 0
run_verdict "unset passes"               pass ""            0 0
run_verdict "error passes"               pass error         0 0
run_verdict "green_on_base forces fail"  fail green_on_base 0 0
grep -q 'pass on the base tree' "$VF" && ok || bad "findings lack the green_on_base line"
run_verdict "test exit still fails"      fail red           0 1
run_verdict "check exit still fails"     fail none          2 0
run_verdict "test exit with green_on_base" fail green_on_base 0 1

summary
