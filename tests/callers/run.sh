#!/usr/bin/env bash
# Every caller in templates/consumer passes the inputs, secrets and permissions its reusable workflow
# declares; and the checker itself fails on callers that do not.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
CALLERS=$ROOT/templates/consumer/.github/workflows

out=$(python3 -I callers.py "$CALLERS" "$ROOT"); rc=$?
[ "$rc" = 0 ] && ok || bad "template callers: $(printf '%s\n' "$out" | grep -v '^OK' | head -3 | tr '\n' ' ')"
[ "$(printf '%s\n' "$out" | grep -c '^OK')" -ge 9 ] && ok || bad "fewer than 9 callers checked"

# Every permissions entry carries a reason on its line, in the workflows, the actions and the consumer templates.
reasons=$(python3 -I callers.py --reasons "$ROOT/.github" "$ROOT/templates/consumer/.github"); rrc=$?
[ "$rrc" = 0 ] && ok || bad "permissions without a reason: $(printf '%s\n' "$reasons" | head -3 | tr '\n' ' ')"

# The callers this repository runs on itself (local-*.yml) are checked the same way.
own=$(python3 -I callers.py "$ROOT/.github/workflows" "$ROOT"); orc=$?
[ "$orc" = 0 ] && ok || bad "own callers: $(printf '%s\n' "$own" | grep -v '^OK\|^skip' | head -3 | tr '\n' ' ')"
[ "$(printf '%s\n' "$own" | grep -c '^OK.*local-')" -ge 6 ] && ok || bad "fewer than 6 own callers checked"

# The checker must be able to fail: break three callers in three ways.
bad_dir=$WORK/bad; mkdir -p "$bad_dir"
cp "$CALLERS/release-gate.yml" "$CALLERS/triage.yml" "$CALLERS/dev-execute.yml" "$bad_dir/"
sed -i '/contents: read/d' "$bad_dir/release-gate.yml"                               # a permission missing
sed -i '/priority_field_id:/d; s/model: claude-haiku-5-5/model: claude-haiku-5-5\n      bogus: 1/' "$bad_dir/triage.yml"   # required input missing, unknown input
sed -i '/claude_code_oauth_token:/d; s/contents: read/contents: write/' "$bad_dir/dev-execute.yml"   # a required secret missing, a permission broader than the job's
broken=$(python3 -I callers.py "$bad_dir" "$ROOT"); brc=$?
[ "$brc" != 0 ] && ok || bad "checker passed broken callers"
printf '%s\n' "$broken" | grep -q 'release-gate.*permission contents' && ok || bad "missing permission not reported"
printf '%s\n' "$broken" | grep -q 'triage.*unknown input bogus' && ok || bad "unknown input not reported"
printf '%s\n' "$broken" | grep -q 'triage.*required input priority_field_id' && ok || bad "missing input not reported"
printf '%s\n' "$broken" | grep -q 'dev-execute.*required secret' && ok || bad "missing secret not reported"
printf '%s\n' "$broken" | grep -q 'dev-execute.*permission contents: caller grants write' && ok || bad "broader permission not reported"

# A permissions entry without its reason fails: the same copy with the trailing comments removed.
reason_dir=$WORK/reasons; mkdir -p "$reason_dir"
cp "$CALLERS/dev-execute.yml" "$reason_dir/"; sed -i 's/ #.*$//' "$reason_dir/dev-execute.yml"
nr=$(python3 -I callers.py --reasons "$reason_dir"); nrc=$?
[ "$nrc" != 0 ] && ok || bad "entry without a reason passed"
printf '%s\n' "$nr" | grep -q 'dev-execute.yml:1[0-9] contents: read' && ok || bad "entry without a reason not named"
summary
