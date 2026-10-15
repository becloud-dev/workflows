#!/usr/bin/env bash
# Every claude-code-action call passes `--setting-sources user`, so it loads no project or local settings,
# hooks or CLAUDE.md from the checkout (#78); and the checker itself fails on calls that do not.
# The steps moved to the CLI make no claude-code-action call: the CLI calls `claude -p --restricted`,
# pinned by its own tests (cli/tests/agent_call.rs).
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"

out=$(python3 -I agent_calls.py "$ROOT"); rc=$?
[ "$rc" = 0 ] && ok || bad "agent calls: $(printf '%s\n' "$out" | grep '^FAIL' | head -3 | tr '\n' ' ')"
[ "$(printf '%s\n' "$out" | grep -c '^OK')" -ge 7 ] && ok || bad "fewer than 7 agent calls checked"

# Steps on the CLI: no claude-code-action call, the CLI built by setup-cli and run.
for step in planner-backlog:'planner backlog' dev-execute:'executor gate'; do
  f=$ROOT/.github/workflows/${step%%:*}.yml cmd=${step#*:}
  ! grep -q 'anthropics/claude-code-action@' "$f" && ok || bad "${step%%:*} still calls claude-code-action"
  grep -q 'uses: \$/.github/actions/setup-cli$' "$f" && ok || bad "${step%%:*} does not set up the CLI"
  grep -q "\"\$WF\" $cmd " "$f" && ok || bad "${step%%:*} does not run wf $cmd"
done
# the executor's rounds: the composite makes its calls through wf, not claude-code-action
f=$ROOT/.github/actions/dev-round/action.yml
! grep -q 'anthropics/claude-code-action@' "$f" && ok || bad "dev-round still calls claude-code-action"
grep -q '"$WF" executor execute ' "$f" && grep -q '"$WF" executor check ' "$f" && ok || bad "dev-round does not run wf executor execute and check"

# The checker must be able to fail: the same workflow with the flag missing, widened, and given twice.
for case in missing widened twice; do
  w=$WORK/$case; mkdir -p "$w/.github/workflows"
  cp "$ROOT/.github/workflows/triage.yml" "$w/.github/workflows/"
  f=$w/.github/workflows/triage.yml
  case $case in
    missing) sed -i '/--setting-sources user/d' "$f" ;;
    widened) sed -i 's/--setting-sources user/--setting-sources user,project/' "$f" ;;
    twice)   sed -i 's/--setting-sources user/--setting-sources user --setting-sources=project/' "$f" ;;
  esac
  got=$(python3 -I agent_calls.py "$w"); grc=$?
  [ "$grc" != 0 ] && ok || bad "checker passed a call with the flag $case"
  printf '%s\n' "$got" | grep -q '^FAIL  .github/workflows/triage.yml' && ok || bad "flag $case not named"
done

summary
