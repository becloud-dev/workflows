#!/usr/bin/env bash
# The "Move the major tag" step of release-please.yml against a stub gh.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
extract_step "$ROOT/.github/workflows/release-please.yml" release-please "Move the major tag" "$WORK/tag.sh"
T=$WORK/tag.sh; H=$WORK
mkdir -p "$H/bin"; export PATH="$H/bin:$PATH"
cat > "$H/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >> "$STUB_LOG"
# the existence probe: `gh api repos/R/git/ref/tags/vN`
case "$*" in
  "api repos/becloud-dev/workflows/git/ref/tags/"*) [ "${STUB_TAG_EXISTS:-0}" = 1 ] && exit 0 || exit 1 ;;
esac
exit 0
STUB
chmod +x "$H/bin/gh"; export PATH="$H/bin:$PATH"
SHA=0123456789abcdef0123456789abcdef01234567
run() { # name want_exit exists MAJOR SHA
  LOG=$(mktemp "$H/log.XXXXXX"); export STUB_LOG="$LOG"
  STUB_TAG_EXISTS=$3 GITHUB_REPOSITORY=becloud-dev/workflows MAJOR=$4 SHA=$5 GH_TOKEN=x bash "$T" > "$LOG.out" 2> "$LOG.err"
  local rc=$?
  { [ "$2" = 0 ] && [ $rc = 0 ]; } || { [ "$2" != 0 ] && [ $rc != 0 ]; } && ok || bad "$1: exit $rc want $2"
}
run "existing tag is patched" 0 1 0 $SHA
grep -q "gh api -X PATCH repos/becloud-dev/workflows/git/refs/tags/v0 -f sha=$SHA -F force=true" "$LOG" && ok || bad "patch call"
! grep -q 'POST' "$LOG" && ok || bad "no POST when it exists"
run "missing tag is created" 0 0 0 $SHA
grep -q "gh api -X POST repos/becloud-dev/workflows/git/refs -f ref=refs/tags/v0 -f sha=$SHA" "$LOG" && ok || bad "post call"
! grep -q 'PATCH' "$LOG" && ok || bad "no PATCH when missing"
run "major 12" 0 1 12 $SHA
grep -q 'refs/tags/v12 ' "$LOG" && ok || bad "major 12 tag name"
run "non-numeric major" 1 1 'v0; x' $SHA
! grep -qE 'PATCH|POST' "$LOG" && ok || bad "non-numeric: no write"
run "empty major" 1 1 '' $SHA
! grep -qE 'PATCH|POST' "$LOG" && ok || bad "empty major: no write"
run "short sha" 1 1 0 abc123
! grep -qE 'PATCH|POST' "$LOG" && ok || bad "short sha: no write"
run "upper-case sha" 1 1 0 0123456789ABCDEF0123456789ABCDEF01234567
run "empty sha" 1 1 0 ''
summary
