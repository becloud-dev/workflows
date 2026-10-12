#!/usr/bin/env bash
# The release-gate step: label by an owner, open release-blockers, a stale or edited review. Cases are
# in driver.py; it also mutates the step and requires every mutation to be caught.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
extract_step "$ROOT/.github/workflows/release-gate.yml" release-gate "$(python3 -I -c "
import yaml,sys
d=yaml.safe_load(open('$ROOT/.github/workflows/release-gate.yml'))
print([s['name'] for s in d['jobs']['release-gate']['steps'] if 'run' in s][0])")" "$WORK/gate.sh"
export JQ_BIN_DIR=$(dirname "$(command -v jq)")
out=$(python3 -I driver.py "$WORK/gate.sh"); rc=$?
printf '%s\n' "$out" | grep -E '^(cases|mutation|FAIL)' | sed 's/^/  /'
[ "$rc" = 0 ] && ok || bad "driver exited $rc"
summary
