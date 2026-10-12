#!/usr/bin/env bash
# Every caller in templates/consumer passes the inputs, secrets and permissions its reusable workflow
# declares; and the checker itself fails on callers that do not.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
CALLERS=$ROOT/templates/consumer/.github/workflows

out=$(python3 -I callers.py "$CALLERS" "$ROOT"); rc=$?
[ "$rc" = 0 ] && ok || bad "template callers: $(printf '%s\n' "$out" | grep -v '^OK' | head -3 | tr '\n' ' ')"
[ "$(printf '%s\n' "$out" | grep -c '^OK')" -ge 9 ] && ok || bad "fewer than 9 callers checked"

# The callers this repository runs on itself (local-*.yml) are checked the same way.
own=$(python3 -I callers.py "$ROOT/.github/workflows" "$ROOT"); orc=$?
[ "$orc" = 0 ] && ok || bad "own callers: $(printf '%s\n' "$own" | grep -v '^OK\|^skip' | head -3 | tr '\n' ' ')"
[ "$(printf '%s\n' "$own" | grep -c '^OK.*local-')" -ge 6 ] && ok || bad "fewer than 6 own callers checked"

# The checker must be able to fail: break three callers in three ways.
bad_dir=$WORK/bad; mkdir -p "$bad_dir"
cp "$CALLERS/release-gate.yml" "$CALLERS/triage.yml" "$CALLERS/dev-execute.yml" "$bad_dir/"
sed -i '/contents: read/d' "$bad_dir/release-gate.yml"                               # a permission missing
sed -i '/priority_field_id:/d; s/model: claude-haiku-5-5/model: claude-haiku-5-5\n      bogus: 1/' "$bad_dir/triage.yml"   # required input missing, unknown input
sed -i '/claude_code_oauth_token:/d' "$bad_dir/dev-execute.yml"                       # a required secret missing
broken=$(python3 -I callers.py "$bad_dir" "$ROOT"); brc=$?
[ "$brc" != 0 ] && ok || bad "checker passed broken callers"
printf '%s\n' "$broken" | grep -q 'release-gate.*permission contents' && ok || bad "missing permission not reported"
printf '%s\n' "$broken" | grep -q 'triage.*unknown input bogus' && ok || bad "unknown input not reported"
printf '%s\n' "$broken" | grep -q 'triage.*required input priority_field_id' && ok || bad "missing input not reported"
printf '%s\n' "$broken" | grep -q 'dev-execute.*required secret' && ok || bad "missing secret not reported"
summary
