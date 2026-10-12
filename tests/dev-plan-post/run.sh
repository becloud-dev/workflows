#!/usr/bin/env bash
# The "Post the plan" step of dev-plan.yml: structure checks, the security links by number, the comments.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
extract_step "$ROOT/.github/workflows/dev-plan.yml" dev-plan "Post the plan" "$WORK/post.sh"
P=$WORK/post.sh; H=$WORK
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >> "$STUB_LOG"
case "$1 $2" in
  "issue comment") while [ $# -gt 0 ]; do [ "$1" = --body-file ] && cp "$2" "$STUB_COMMENT"; shift; done ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/gh"; export PATH="$WORK/bin:$PATH"
# plan <security-json> [extra criteria count] [extra spec count]
plan() {
  jq -nc --argjson sec "$1" --argjson nc "${2:-3}" --argjson ns "${3:-2}" '
   {outcome:"planned",rationale:"r",objective:"o",steps:["a","b"],
    spec:[range(0;$ns)|{test:"t\(.)",asserts:"behaviour \(.)"}],
    acceptance_criteria:[range(0;$nc)|"criterion \(.+1)"],
    security:$sec, files:["f"], risks:[]}'
}
run() { # name want_exit json
  LOG=$(mktemp "$H/log.XXXXXX"); export STUB_LOG="$LOG" STUB_COMMENT="$LOG.comment"
  VERDICT="$3" ISSUE=1 GH_TOKEN=x RUNNER_TEMP="$H" bash "$P" > "$LOG.out" 2> "$LOG.err"
  local rc=$?
  if [ "$2" = 0 ]; then [ $rc = 0 ] && ok || bad "$1: exit $rc want 0 ($(head -2 "$LOG.err" | tr '\n' ' '))"
  else [ $rc != 0 ] && ok || bad "$1: exit 0, want non-zero"; fi
}
refused() { # name json: refused with a comment that names the reason pattern $3
  run "$1" 1 "$2"
  grep -q '<!-- dev-plan-error -->' "$LOG.comment" 2>/dev/null && ok || bad "$1: no error comment"
  grep -qE "$3" "$LOG.comment" 2>/dev/null && ok || bad "$1: reason not named ($3)"
  grep -q '<!-- dev-plan -->' "$LOG.comment" 2>/dev/null && bad "$1: a plan was posted too" || ok
}
S1='[{"category":"A05","risk":"input reaches the shell","control":"quote the value","criterion":2,"test":1}]'

run "valid with security" 0 "$(plan "$S1")"
grep -q '^- A05: input reaches the shell Control: quote the value (criterion 2, test 1)$' "$LOG.comment" && ok || bad "valid: security line with links"
run "empty security" 0 "$(plan '[]')"
grep -q 'no category applies' "$LOG.comment" && ok || bad "empty: no-category line"
run "last criterion and last test" 0 "$(plan '[{"category":"A01","risk":"r","control":"c","criterion":3,"test":2}]')"

refused "criterion past the end"   "$(plan '[{"category":"A05","risk":"r","control":"c","criterion":4,"test":1}]')" 'A05.*criterion'
refused "criterion zero"           "$(plan '[{"category":"A05","risk":"r","control":"c","criterion":0,"test":1}]')" 'A05.*criterion'
refused "criterion not integer"    "$(plan '[{"category":"A05","risk":"r","control":"c","criterion":1.5,"test":1}]')" 'A05.*criterion'
refused "test past the end"        "$(plan '[{"category":"A05","risk":"r","control":"c","criterion":1,"test":3}]')" 'A05.*test'
refused "test zero"                "$(plan '[{"category":"A05","risk":"r","control":"c","criterion":1,"test":0}]')" 'A05.*test'
refused "category A00"             "$(plan '[{"category":"A00","risk":"r","control":"c","criterion":1,"test":1}]')" 'A00'
refused "category A11"             "$(plan '[{"category":"A11","risk":"r","control":"c","criterion":1,"test":1}]')" 'A11'
refused "test missing"             "$(plan '[{"category":"A05","risk":"r","control":"c","criterion":1}]')" 'A05.*test'
refused "unknown category"         "$(plan '[{"category":"A99","risk":"r","control":"c","criterion":1,"test":1}]')" 'A99'
refused "lower-case category"      "$(plan '[{"category":"a05","risk":"r","control":"c","criterion":1,"test":1}]')" 'a05'
refused "duplicate category"       "$(plan "$(jq -nc --argjson a "$S1" '$a + $a')")" 'twice'
refused "two problems are both named" "$(plan '[{"category":"A05","risk":"r","control":"c","criterion":9,"test":1},{"category":"A01","risk":"r","control":"c","criterion":1,"test":9}]')" 'A05.*criterion'
grep -qE 'A01.*test' "$LOG.comment" && ok || bad "second problem named"

run "11 criteria fail the structure check" 1 "$(plan '[]' 11 2)"
run "10 criteria and 10 specs pass" 0 "$(plan '[]' 10 10)"
run "security missing" 1 "$(plan '[]' | jq -c 'del(.security)')"
run "needs_info path unchanged" 0 '{"outcome":"needs_info","rationale":"r","questions":["q1"]}'
grep -q 'dev-plan-questions' "$LOG.comment" && ok || bad "needs_info: marker"
summary
