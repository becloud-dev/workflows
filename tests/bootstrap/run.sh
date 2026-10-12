#!/usr/bin/env bash
# templates/consumer/bootstrap.sh against a stub gh: arguments, order of reads and writes, dry run.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
B=$ROOT/templates/consumer/bootstrap.sh; H=$WORK
mkdir -p "$H/bin"; export PATH="$H/bin:$PATH"
cat > "$H/bin/gh" <<'STUB'
#!/usr/bin/env bash
# stub gh: logs argv; `api` answers from env-controlled fixtures and applies --jq with jq
echo "gh $*" >> "$STUB_LOG"
if [ "$1" = api ]; then
  shift; method=GET; path=""; jqf=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -X) method=$2; shift 2 ;;
      -f) shift 2 ;;
      --jq) jqf=$2; shift 2 ;;
      *) path=$1; shift ;;
    esac
  done
  [ "$method" = POST ] && exit 0
  case "$path" in
    repos/*/git/ref/tags/*) [ "${STUB_TAG_EXISTS:-0}" = 1 ] && body='{"object":{"sha":"1111111111111111111111111111111111111111"}}' || exit 1 ;;
    repos/*/commits/*) [ "${STUB_EMPTY:-0}" = 1 ] && exit 1; body='{"sha":"abcdef0123456789abcdef0123456789abcdef01"}' ;;
    repos/*) [ "${STUB_NO_REPO:-0}" = 1 ] && exit 1; body='{"default_branch":"main"}' ;;
    orgs/*/issue-fields)
      case "${STUB_FIELDS:-one}" in
        one) body='[{"id":48149712,"name":"Priority"},{"id":48149713,"name":"Start date"}]' ;;
        none) body='[{"id":48149713,"name":"Start date"}]' ;;
        two) body='[{"id":1,"name":"Priority"},{"id":2,"name":"Priority"}]' ;;
        fail) exit 1 ;;
      esac ;;
    *) echo "unexpected api path: $path" >&2; exit 99 ;;
  esac
  if [ -n "$jqf" ]; then printf '%s' "$body" | jq -r "$jqf"; else printf '%s\n' "$body"; fi
  exit 0
fi
exit 0
STUB
chmod +x "$H/bin/gh"

ARGS=(--repo becloud-dev/scratch --owners bentoluizv --check 'sh -n bin/x' --test 'sh tests/t.sh' --test-paths 'tests/*')
writes() { grep -cE '^gh (label create|variable set|api -X POST)' "$LOG"; }

run() { # name want_exit want_writes [env...] -- args...
  local name=$1 want=$2 wantw=$3; shift 3
  local envs=()
  while [ "$1" != -- ]; do envs+=("$1"); shift; done; shift
  LOG=$(mktemp "$H/log.XXXXXX"); export LOG
  env STUB_LOG="$LOG" "${envs[@]}" bash "$B" "$@" > "$LOG.out" 2> "$LOG.err"
  local rc=$?
  [ "$rc" = "$want" ] && ok || bad "$name: exit $rc, want $want ($(head -1 "$LOG.err"))"
  [ "$(writes)" = "$wantw" ] && ok || bad "$name: writes $(writes), want $wantw"
}

run "happy path"          0 12 X=1 -- "${ARGS[@]}"
grep -q 'gh variable set PRIORITY_FIELD_ID --repo becloud-dev/scratch --body 48149712' "$LOG" && ok || bad "happy: priority id from the org field"
grep -q 'gh api -X POST repos/becloud-dev/scratch/git/refs -f ref=refs/tags/v0.1.0 -f sha=abcdef0123456789abcdef0123456789abcdef01' "$LOG" && ok || bad "happy: tag on the tip"
grep -q 'gh variable set OWNERS --repo becloud-dev/scratch --body bentoluizv' "$LOG" && ok || bad "happy: OWNERS"
[ "$(grep -c '^gh label create' "$LOG")" = 6 ] && ok || bad "happy: six labels"
grep -q -- '--force' "$LOG" && ok || bad "happy: labels forced"
grep -q 'CLAUDE_CODE_OAUTH_TOKEN' "$LOG.out" && ok || bad "happy: remaining steps printed"
grep -q 'EXECUTOR_APP_PRIVATE_KEY' "$LOG.out" && grep -q 'EXECUTOR_APP_CLIENT_ID' "$LOG.out" && ok || bad "happy: executor App grants printed"
! grep -q 'accepted gap' "$LOG.out" && ok || bad "happy: no accepted gap for the pull request step"
! grep -q 'gh secret set' "$LOG" && ok || bad "happy: creates no secret"
README=$ROOT/templates/consumer/README.md
grep -q 'EXECUTOR_APP_PRIVATE_KEY' "$README" && grep -q 'EXECUTOR_APP_CLIENT_ID' "$README" && ok || bad "readme: names the executor App grants"
! grep -q 'accepted gap' "$README" && ok || bad "readme: no accepted gap for the pull request step"
grep -q '^Done for becloud-dev/scratch' "$LOG.out" && ok || bad "happy: says Done"

run "custom seed"         0 12 X=1 -- "${ARGS[@]}" --seed 1.2.3
grep -q 'ref=refs/tags/v1.2.3' "$LOG" && ok || bad "seed: tag name"

run "dry run"             0 0  X=1 -- "${ARGS[@]}" --dry-run
grep -q '^+ gh label create' "$LOG.out" && ok || bad "dry: prints the label writes"
grep -q '^+ gh api -X POST' "$LOG.out" && ok || bad "dry: prints the tag write"
grep -q 'Dry run for becloud-dev/scratch: nothing was written' "$LOG.out" && ok || bad "dry: says nothing was written"
! grep -q '^Done for' "$LOG.out" && ok || bad "dry: must not say Done"

run "tag exists"          0 11 STUB_TAG_EXISTS=1 -- "${ARGS[@]}"
grep -q 'left as it is' "$LOG.out" && ok || bad "tag exists: noticed"

run "missing argument"    2 0  X=1 -- --repo becloud-dev/scratch --owners a --check c --test t
run "unknown flag"        2 0  X=1 -- "${ARGS[@]}" --nope
run "bad repo"            1 0  X=1 -- --repo scratch --owners a --check c --test t --test-paths 'tests/*'
run "owners with a space" 1 0  X=1 -- --repo becloud-dev/scratch --owners 'a, b' --check c --test t --test-paths 'tests/*'
run "bad seed"            1 0  X=1 -- "${ARGS[@]}" --seed v1
run "unknown repo"        1 0  STUB_NO_REPO=1 -- "${ARGS[@]}"
grep -q 'cannot read becloud-dev/scratch' "$LOG.err" && ok || bad "unknown repo: message"
run "empty repo"          1 0  STUB_EMPTY=1 -- "${ARGS[@]}"
grep -q 'push the template files first' "$LOG.err" && ok || bad "empty repo: message"
run "no Priority field"   1 0  STUB_FIELDS=none -- "${ARGS[@]}"
grep -q 'exactly one issue field named Priority' "$LOG.err" && ok || bad "no Priority: message"
run "two Priority fields" 1 0  STUB_FIELDS=two -- "${ARGS[@]}"
grep -q 'exactly one issue field named Priority' "$LOG.err" && ok || bad "two Priority: message"
run "fields unreadable"   1 0  STUB_FIELDS=fail -- "${ARGS[@]}"
grep -q 'cannot read the issue fields' "$LOG.err" && ok || bad "fields unreadable: message"

summary
