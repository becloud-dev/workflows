#!/usr/bin/env bash
# Every claude-code-action call passes `--setting-sources user`, so it loads no project or local settings,
# hooks or CLAUDE.md from the checkout (#78); and the checker itself fails on calls that do not.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"

out=$(python3 -I agent_calls.py "$ROOT"); rc=$?
[ "$rc" = 0 ] && ok || bad "agent calls: $(printf '%s\n' "$out" | grep '^FAIL' | head -3 | tr '\n' ' ')"
[ "$(printf '%s\n' "$out" | grep -c '^OK')" -ge 10 ] && ok || bad "fewer than 10 agent calls checked"
printf '%s\n' "$out" | grep -q 'dev-round/action.yml -/' && ok || bad "the composite action's calls are not checked"

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
