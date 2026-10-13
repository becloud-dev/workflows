#!/usr/bin/env bash
# The `scope` step (deletions and workflow changes outside the plan's Files list) and the verdict step of the dev-round composite.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
extract_step "$ROOT/.github/actions/dev-round/action.yml" - scope "$WORK/scope.sh"
extract_step "$ROOT/.github/actions/dev-round/action.yml" - verdict "$WORK/verdict.sh"
SCOPE=$WORK/scope.sh; VERDICT=$WORK/verdict.sh; S=$WORK
mkrepo() { # builds a repository with a base commit, prints its directory
  local d; d=$(mktemp -d "$S/w.XXXXXX")
  git init -q -b main "$d"
  ( cd "$d" && git config user.email t@t && git config user.name t \
    && mkdir -p bin tests tests_extra docs 'my dir' .github/workflows \
    && printf 'echo hi\n' > bin/greet \
    && printf 'exit 0\n' > tests/greet_test.sh \
    && printf 'exit 0\n' > tests_extra/keep.sh \
    && printf 'a\n' > docs/a.md && printf 'b\n' > docs/b.md \
    && printf 'x\n' > 'my dir/x y.sh' \
    && printf 'on: push\n' > .github/workflows/ci.yml \
    && git add . && git commit -qm base )
  echo "$d"
}
mkplan() { # writes a plan whose Files list holds the arguments, prints its path
  local p; p=$(mktemp "$S/plan.XXXXXX")
  { printf '<!-- dev-plan -->\n## Development plan\n\n**Objective.** test\n\n**Files**\n'
    for e in "$@"; do printf -- '- `%s`\n' "$e"; done
    printf '\n**Risks and assumptions**\n- none\n'; } > "$p"
  echo "$p"
}

run_scope() { # name want_state PLAN_FILE setup-function     (BASE_OVERRIDE replaces the base)
  local name=$1 want=$2 plan=$3 setup=$4 base repo out state
  repo=$(mkrepo); base=$(git -C "$repo" rev-parse HEAD)
  ( cd "$repo" && eval "$setup" )
  out=$(mktemp "$S/out.XXXXXX"); : > "$out.res"
  ( cd "$repo" && env RUNNER_TEMP="$S" PLAN_FILE="$plan" BASE="${BASE_OVERRIDE:-$base}" \
        RESULTS="$out.res" GITHUB_OUTPUT="$out" bash "$SCOPE" >/dev/null 2>&1 )
  state=$(grep -h '^scope_state=' "$out" | tail -1 | cut -d= -f2)
  if [ "$state" = "$want" ]; then ok; else bad "$name: want $want got '$state'"; fi
  SC_STATE=$state
  SC_VIOL=$(grep -h '^scope_violations=' "$out" | tail -1 | cut -d= -f2-)
  SC_KINDS=$(grep -h '^scope_violation_kinds=' "$out" | tail -1 | cut -d= -f2-)
  SC_RES=$out.res
}

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

del() { git rm -q "$@"; git commit -qm "feat: drop $*"; }

echo "# deletions"
# deletion of a file named in the plan
run_scope "planned deletion"            ok           "$(mkplan bin/greet)" 'del bin/greet'
[ "$SC_VIOL" = '[]' ] && ok || bad "planned deletion: violations $SC_VIOL"
run_verdict "planned deletion passes"   pass ok "$SC_VIOL"

# deletion of a file the plan does not name
run_scope "unnamed deletion"            out_of_scope "$(mkplan bin/greet)" 'del tests/greet_test.sh'
[ "$SC_VIOL" = '["tests/greet_test.sh"]' ] && ok || bad "unnamed deletion: violations $SC_VIOL"
grep -q '^### scope check' "$SC_RES" && grep -q '^- tests/greet_test.sh$' "$SC_RES" && ok || bad "unnamed deletion: results file lacks the path"
run_verdict "unnamed deletion fails"    fail out_of_scope "$SC_VIOL"
grep -q 'deletion of tests/greet_test.sh is not in the plan Files list' "$VF" && ok || bad "unnamed deletion: findings lack the path"

echo "# directories"
# a directory named with a trailing slash allows deletions under it
run_scope "deletion under a planned dir" ok          "$(mkplan tests/)" 'del tests/greet_test.sh'
run_scope "sibling with shared prefix"   out_of_scope "$(mkplan tests/)" 'del tests_extra/keep.sh'
[ "$SC_VIOL" = '["tests_extra/keep.sh"]' ] && ok || bad "sibling prefix: violations $SC_VIOL"
# without the slash the entry is an exact file match only
run_scope "dir without slash is exact"   out_of_scope "$(mkplan tests)" 'del tests/greet_test.sh'

echo "# renames"
# the old path of a rename counts as a deletion
run_scope "rename of an unnamed file"    out_of_scope "$(mkplan bin/hello)" 'git mv bin/greet bin/hello && git commit -qm "feat: rename"'
[ "$SC_VIOL" = '["bin/greet"]' ] && ok || bad "rename: violations $SC_VIOL"
run_scope "rename with the old path named" ok         "$(mkplan bin/greet bin/hello)" 'git mv bin/greet bin/hello && git commit -qm "feat: rename"'

echo "# workflow files"
# an added, modified or renamed-in file under .github/workflows must be named in the plan
run_scope "added workflow file not in plan" out_of_scope "$(mkplan bin/greet)" 'echo x > .github/workflows/x.yml && git add . && git commit -qm "feat: add workflow"'
[ "$SC_VIOL" = '[".github/workflows/x.yml"]' ] && ok || bad "added workflow: violations $SC_VIOL"
[ "$SC_KINDS" = '["changed"]' ] && ok || bad "added workflow: kinds $SC_KINDS"
grep -q '^changed under .github/workflows but not named in the plan Files list:$' "$SC_RES" && grep -q '^- .github/workflows/x.yml$' "$SC_RES" && ok || bad "added workflow: results file lacks the path"
run_verdict "added workflow file fails"  fail out_of_scope "$SC_VIOL" "$SC_KINDS"
grep -qF 'change of .github/workflows/x.yml under .github/workflows is not in the plan Files list' "$VF" && ok || bad "added workflow: findings lack the path"

run_scope "modified workflow file not in plan" out_of_scope "$(mkplan bin/greet)" 'echo x > .github/workflows/ci.yml && git add . && git commit -qm "feat: edit workflow"'
[ "$SC_VIOL" = '[".github/workflows/ci.yml"]' ] && ok || bad "modified workflow: violations $SC_VIOL"

run_scope "workflow files named exactly" ok  "$(mkplan .github/workflows/x.yml .github/workflows/ci.yml)" 'echo x > .github/workflows/x.yml && echo y > .github/workflows/ci.yml && git add . && git commit -qm "feat: workflows"'
[ "$SC_VIOL" = '[]' ] && ok || bad "named workflow files: violations $SC_VIOL"
run_verdict "named workflow files pass"  pass ok "$SC_VIOL"

# a directory entry with a trailing slash names the files under it
run_scope "workflow dir named with slash" ok "$(mkplan .github/workflows/)" 'echo x > .github/workflows/x.yml && git add . && git commit -qm "feat: add workflow"'
[ "$SC_VIOL" = '[]' ] && ok || bad "workflow dir with slash: violations $SC_VIOL"
# without the slash the entry is an exact match: it does not name the files under it
run_scope "workflow dir without slash"   out_of_scope "$(mkplan .github/workflows)" 'echo x > .github/workflows/x.yml && git add . && git commit -qm "feat: add workflow"'
# a sibling directory that only shares the prefix is not a workflow path
run_scope "sibling of workflows dir"     none         "$(mkplan .github/workflows)" 'mkdir -p .github/workflows-extra && echo x > .github/workflows-extra/y.yml && git add . && git commit -qm "feat: add file"'
[ "$SC_VIOL" = '[]' ] && ok || bad "sibling of workflows dir: violations $SC_VIOL"

# the new path of a rename into the directory counts as a change
run_scope "rename into workflows not in plan" out_of_scope "$(mkplan docs/a.md)" 'git mv docs/a.md .github/workflows/y.yml && git commit -qm "feat: rename"'
[ "$SC_VIOL" = '[".github/workflows/y.yml"]' ] && ok || bad "rename into workflows: violations $SC_VIOL"
run_scope "rename into workflows named" ok    "$(mkplan docs/a.md .github/workflows/y.yml)" 'git mv docs/a.md .github/workflows/y.yml && git commit -qm "feat: rename"'

# a glob in the plan does not name the workflow files it would match
run_scope "glob entry for workflows"     out_of_scope "$(mkplan '.github/workflows/*.yml')" 'echo x > .github/workflows/x.yml && git add . && git commit -qm "feat: add workflow"'

echo "# no deletions"
run_scope "additions and edits only"     none         "$(mkplan)" 'echo x > docs/new.md && echo 2 > docs/a.md && git add . && git commit -qm "feat: add"'
[ "$SC_VIOL" = '[]' ] && ok || bad "additions: violations $SC_VIOL"
run_verdict "additions and edits pass"   pass none "$SC_VIOL"

echo "# fail closed"
run_scope "unreadable plan file"         error        "$S/missing-plan.md" 'del bin/greet'
run_verdict "unreadable plan forces fail" fail error "$SC_VIOL"
grep -q 'could not be read' "$VF" && ok || bad "unreadable plan: findings lack the reason"
BASE_OVERRIDE=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef \
run_scope "bad base gives error"         error        "$(mkplan bin/greet)" 'del bin/greet'
unset BASE_OVERRIDE
run_verdict "bad base forces fail"       fail error "$SC_VIOL"
printf '## Development plan\n\n**Objective.** test\n' > "$S/nofiles.md"
run_scope "plan without a Files list"    error        "$S/nofiles.md" 'del bin/greet'

echo "# literal matching"
# a glob in the plan matches nothing but itself
run_scope "glob entry does not match"    out_of_scope "$(mkplan 'docs/*.md')" 'del docs/a.md'
run_scope "star entry does not match"    out_of_scope "$(mkplan 'docs/*')" 'del docs/b.md'
# spaces in names match exactly
run_scope "name with a space"            ok           "$(mkplan 'my dir/x y.sh')" 'del "my dir/x y.sh"'
run_scope "directory with a space"       ok           "$(mkplan 'my dir/')" 'del "my dir/x y.sh"'

summary
