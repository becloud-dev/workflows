#!/usr/bin/env bash
# The "Check the bundle against the plan" step of dev-publish in dev-execute.yml: the plan Files list read from a
# stub gh, the bundle's deletions and workflow changes from the fresh git dir, and no use of the rounds' outputs.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
W=$WORK; mkdir -p "$W/bin"
cat > "$W/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >> "$STUB_LOG"
case "$1 $2" in
  "api --paginate") cat "$STUB_COMMENTS" ;;
  *) echo "unexpected gh call: $*" >&2; exit 99 ;;
esac
STUB
chmod +x "$W/bin/gh"
export PATH="$W/bin:$PATH"

extract_step "$ROOT/.github/workflows/dev-execute.yml" dev-publish "Verify the bundle" "$W/verify.sh"
extract_step "$ROOT/.github/workflows/dev-execute.yml" dev-publish "Check the bundle against the plan" "$W/check.sh"
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL $1"; }

# a checkout at the base, as the publish job has it; its base commit holds a workflow, a doc and a script
mkrepo() {
  rm -rf "$W/repo"; mkdir -p "$W/repo"
  ( cd "$W/repo" && git init -q -b main && git config user.email t@t && git config user.name t \
    && mkdir -p .github/workflows docs bin && printf 'on: push\n' > .github/workflows/ci.yml \
    && printf 'a\n' > docs/a.md && printf 'b\n' > docs/b.md && printf 'echo hi\n' > bin/greet \
    && git add . && git commit -qm base )
  BASE=$(git -C "$W/repo" rev-parse HEAD)
}
newcase() { # a scratch run with its own RUNNER_TEMP, comments and log
  C=$W/case; rm -rf "$C"; mkdir -p "$C/tmp/publish-bundle"; mkrepo
  export RUNNER_TEMP=$C/tmp STUB_LOG=$C/log STUB_COMMENTS=$C/comments.json GITHUB_REPOSITORY=acme/app ISSUE=13
  : > "$STUB_LOG"; : > "$STUB_COMMENTS"
}
plan_comment() { # login body
  jq -nc --arg u "$1" --arg b "$2" '{user:{login:$u}, body:$b}' >> "$STUB_COMMENTS"
}
planbody() { # a plan whose Files list holds the arguments
  printf '<!-- dev-plan -->\n## Development plan\n\n**Objective.** test\n\n**Files**\n'
  for e in "$@"; do printf -- '- `%s`\n' "$e"; done
  printf '\n**Risks and assumptions**\n- none\n'
}
change() { # commits the edits in $1 on the base, then bundles that commit the way the rounds job does
  ( cd "$W/repo" && eval "$1" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m "feat: change" )
  rm -rf "$C/src.git"; git init -q --bare "$C/src.git"
  GIT_DIR=$C/src.git git fetch -q "$W/repo" HEAD:refs/push/head
  GIT_DIR=$C/src.git git bundle create "$C/tmp/publish-bundle/publish.bundle" refs/push/head "^$BASE" > /dev/null 2>&1
  git -C "$W/repo" checkout -q --detach "$BASE"
}
verify() { # the verify step fetches the bundle into publish.git, as the job does before the check
  ( cd "$W/repo" && BUNDLE="$C/tmp/publish-bundle/publish.bundle" bash "$W/verify.sh" > "$C/verify.out" 2>&1 ) \
    || { echo "verify step failed: $(cat "$C/verify.out")"; exit 1; }
}
check() { # the rounds' outputs are set to a forged pass; the step must not read them
  ( cd "$W/repo" && GH_TOKEN=x VERDICT=pass ACTION=pr bash "$W/check.sh" > "$C/stdout" 2>&1 ); CRC=$?
}
expect_pass() { # name
  [ "$CRC" = 0 ] && ok || bad "$1: exit $CRC: $(cat "$C/stdout")"
}
expect_fail() { # name
  [ "$CRC" != 0 ] && ok || bad "$1: exit 0"
}
expect_refuse() { # name path...: refused, and each path is named in the output
  local n=$1 p; shift
  [ "$CRC" != 0 ] || { bad "$n: exit 0"; return; }
  for p in "$@"; do grep -qF -- "$p" "$C/stdout" || { bad "$n: output does not name $p: $(cat "$C/stdout")"; return; }; done
  ok
}

echo "# unnamed workflow changes"
newcase; plan_comment github-actions[bot] "$(planbody docs/a.md)"
change 'echo x > .github/workflows/evil.yml'; verify; check
expect_refuse "adds an unnamed workflow" .github/workflows/evil.yml

newcase; plan_comment github-actions[bot] "$(planbody docs/a.md)"
change 'echo y > .github/workflows/ci.yml'; verify; check
expect_refuse "modifies an unnamed workflow" .github/workflows/ci.yml

echo "# unnamed deletions"
newcase; plan_comment github-actions[bot] "$(planbody docs/a.md)"
change 'git rm -q .github/workflows/ci.yml'; verify; check
expect_refuse "deletes an unnamed workflow" .github/workflows/ci.yml

newcase; plan_comment github-actions[bot] "$(planbody docs/a.md)"
change 'git rm -q docs/b.md'; verify; check
expect_refuse "deletes an unnamed file" docs/b.md

echo "# named changes"
newcase; plan_comment github-actions[bot] "$(planbody .github/workflows/x.yml .github/workflows/ci.yml docs/b.md)"
change 'echo x > .github/workflows/x.yml && echo y > .github/workflows/ci.yml && git rm -q docs/b.md'; verify; check
expect_pass "workflow change and deletion named by file"

newcase; plan_comment github-actions[bot] "$(planbody .github/workflows/)"
change 'echo x > .github/workflows/x.yml && git rm -q .github/workflows/ci.yml'; verify; check
expect_pass "workflow change and deletion named by directory"

echo "# no workflow change"
newcase; plan_comment github-actions[bot] "$(planbody)"
change 'echo 2 > docs/a.md && echo n > docs/new.md'; verify; check
expect_pass "non-workflow changes with no workflow entry in the plan"

echo "# fail closed"
newcase; change 'echo 2 > docs/a.md'; verify; check
expect_fail "no plan comment"

newcase; plan_comment mallory "$(planbody docs/a.md)"
change 'echo 2 > docs/a.md'; verify; check
expect_fail "plan from a non-bot author only"

newcase; plan_comment github-actions[bot] $'<!-- dev-plan -->\n## Development plan\n\n**Objective.** test\n'
change 'echo 2 > docs/a.md'; verify; check
expect_fail "plan without a Files heading"

newcase; plan_comment github-actions[bot] "$(planbody docs/a.md)"; plan_comment mallory "$(planbody .github/workflows/evil.yml)"
change 'echo x > .github/workflows/evil.yml'; verify; check
expect_refuse "a forged plan naming the file does not count" .github/workflows/evil.yml

newcase; plan_comment github-actions[bot] "$(planbody .github/workflows/evil.yml)"; plan_comment mallory "$(planbody)"
change 'echo x > .github/workflows/evil.yml'; verify; check
expect_pass "a forged plan naming nothing does not override the bot's plan"

newcase; plan_comment github-actions[bot] "$(planbody docs/a.md)"
change 'echo 2 > docs/a.md'; verify
git --git-dir="$C/tmp/publish.git" update-ref -d refs/push/head; check
expect_fail "the bundle's diff cannot be read"

echo "# hostile checkout config and environment"
# BASH_ENV is not tested here: bash runs it before the step's first line, so no code in the step can guard
# against it; the publish job keeps it from the rounds by running on its own runner, with no shared environment
newcase; plan_comment github-actions[bot] "$(planbody docs/a.md)"
change 'echo x > .github/workflows/evil.yml'; verify
git -C "$W/repo" config core.hooksPath "$C/none"; git -C "$W/repo" config diff.external /bin/false
printf '[diff]\n\trenames = copies\n' > "$C/hostile.gitconfig"
( cd "$W/repo" && GIT_CONFIG_GLOBAL="$C/hostile.gitconfig" GH_TOKEN=x VERDICT=pass ACTION=pr bash "$W/check.sh" > "$C/stdout" 2>&1 ); CRC=$?
expect_refuse "checkout config and a forged environment do not change the decision" .github/workflows/evil.yml

summary
