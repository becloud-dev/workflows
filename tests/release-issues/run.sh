#!/usr/bin/env bash
# release-issues.yml: the approval gate and the issue creation, with real run: blocks and a stateful stub gh.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
S=$WORK; mkdir -p "$S/bin" "$WORK/blocks"
cp bin/gh "$S/bin/gh"; export PATH="$S/bin:$PATH"
export GITHUB_REPOSITORY=becloud-dev/triage-sandbox
extract_step "$ROOT/.github/workflows/release-issues.yml" release-issues "Read the approval and the review" "$WORK/blocks/gate.sh"
extract_step "$ROOT/.github/workflows/release-issues.yml" release-issues "Create the issues" "$WORK/blocks/create.sh"
BLOCKS=$WORK/blocks
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL $1 :: ${2:-}"; }
export GITHUB_REPOSITORY=becloud-dev/triage-sandbox
eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "want [$3] got [$2]"; }
has() { grep -qF -- "$2" "$FX/posted.txt" && ok "$1" || bad "$1" "missing [$2] in: $(head -c 300 "$FX/posted.txt")"; }

world() {
  export FX=$(mktemp -d "$S/w.XXXXXX"); export RUNNER_TEMP=$FX/tmp; mkdir -p "$RUNNER_TEMP"
  export GITHUB_OUTPUT=$FX/out.txt; : > "$GITHUB_OUTPUT"; : > "$FX/posted.txt"
  echo '[]' > "$FX/comments.json"
  jq -n '{number:7,state:"open",head:{ref:"release-please--branches--main",repo:{full_name:"becloud-dev/triage-sandbox"}}}' > "$FX/pr.json"
  export PR=7 FIELD_ID=48149712 REVIEW_URL=https://github.com/x/issues/7#c10
  unset STUB_DROP_TYPE STUB_FAIL_CREATE
}
out() { grep -E "^$1=" "$GITHUB_OUTPUT" | head -1 | cut -d= -f2-; }
gate() { export BODY="$1"; bash -e "$BLOCKS/gate.sh" > "$FX/gate.log" 2>&1; echo $?; }
REVIEW=$'<!-- release-review -->\n## Release review: v0.1.0...abcdef0\n\nSmall.\n\n### Fix now (blocking)\n\n1. **Name is not quoted** (`bin/greet:12`, Bug)\n   The name splits.\n\n### Defer\n\n1. **No test for --help** (`tests/greet_test.sh:1`, Task)\n   Missing.\n\nReply `/approve` to create the issues.'
bot() { jq -n --argjson id "$1" --arg b "$2" '{id:$id,user:{login:"github-actions[bot]"},body:$b,html_url:"https://github.com/x/issues/7#c\($id)"}'; }
comments() { jq -s . > "$FX/comments.json"; }

world; bot 10 "$REVIEW" | comments
rc=$(gate '/approve'); eq "gate: valid exit" "$rc" 0
eq "gate: ok=true" "$(out ok)" true
eq "gate: items counted" "$(out items)" 2
eq "gate: review_url" "$(out review_url)" "https://github.com/x/issues/7#c10"
eq "gate: review file is the comment" "$(head -1 "$(out review_file)")" "<!-- release-review -->"
world; bot 10 "$REVIEW" | comments; rc=$(gate '/approve now'); eq "gate: first line not exact exits 1" "$rc" 1
world; bot 10 "$REVIEW" | comments; jq '.state="closed"' "$FX/pr.json" > "$FX/p" && mv "$FX/p" "$FX/pr.json"
rc=$(gate '/approve'); eq "gate: closed PR stops" "$(out ok)" false; has "gate: closed comment" "not open"
world; bot 10 "$REVIEW" | comments; jq '.head.ref="feat/x"' "$FX/pr.json" > "$FX/p" && mv "$FX/p" "$FX/pr.json"
rc=$(gate '/approve'); eq "gate: non-release branch stops" "$(out ok)" false; has "gate: branch comment" "not a release pull request"
world; bot 10 "$REVIEW" | comments; jq '.head.repo.full_name="someone/fork"' "$FX/pr.json" > "$FX/p" && mv "$FX/p" "$FX/pr.json"
rc=$(gate '/approve'); eq "gate: fork head stops" "$(out ok)" false
world; rc=$(gate '/approve'); eq "gate: no review stops" "$(out ok)" false; has "gate: no review comment" "there is no review"
world; jq -n --arg b "$REVIEW" '[{id:10,user:{login:"bentoluizv"},body:$b},{id:11,user:{login:"mallory"},body:$b}]' > "$FX/comments.json"
rc=$(gate '/approve'); eq "gate: marker by non-bot is no review" "$(out ok)" false
world; { bot 10 "$REVIEW"; bot 11 $'<!-- release-review-issues -->\nIssues made'; } | comments
rc=$(gate '/approve'); eq "gate: issues already created stops" "$(out ok)" false; has "gate: already comment" "already created"
world; { bot 10 "$REVIEW"; bot 11 $'<!-- release-review-issues-failed -->\nSome failed'; } | comments
rc=$(gate '/approve'); eq "gate: failed marker does not stop" "$(out ok)" true
world; { bot 10 "$REVIEW"; bot 11 $'<!-- release-review-issues -->\nIssues made'; bot 12 "$REVIEW"; } | comments
rc=$(gate '/approve'); eq "gate: newer review after issues is ok" "$(out ok)" true
world; { bot 10 "$REVIEW"; bot 12 $'<!-- release-review -->\n## Release review: new\n\n1. **Only one** (`a:1`, Bug)\n   x'; } | comments
rc=$(gate '/approve'); eq "gate: latest review used" "$(out items)" 1

cr() { export VERDICT="$1" ITEMS="$2"; bash -e "$BLOCKS/create.sh" > "$FX/create.log" 2>&1; echo $?; }
issue() { jq -r "$2" "$FX/state/issues/$1.json"; }
count() { ls "$FX/state/issues" 2>/dev/null | wc -l | tr -d ' '; }
TWO='{"issues":[{"title":"Name is not quoted","body":"The name splits.","type":"Bug","blocking":true},{"title":"No test for --help","body":"Missing.","type":"Task","blocking":false}]}'

world; rc=$(cr "$TWO" 2); eq "create: two issues exit" "$rc" 0
eq "create: two created" "$(count)" 2
eq "create: blocking labelled" "$(issue 100 '.labels|join(",")')" release-blocker
eq "create: blocking type" "$(issue 100 .type)" Bug
eq "create: blocking priority" "$(issue 100 .prio)" Urgent
eq "create: deferred no label" "$(issue 101 '.labels|length')" 0
eq "create: deferred type" "$(issue 101 .type)" Task
eq "create: deferred no priority" "$(issue 101 .prio)" ""
case "$(issue 100 .body)" in *"Found in the release review of #7: https://github.com/x/issues/7#c10"*"<!-- release-review-finding:7:"*) ok "create: body has link and marker";; *) bad "create: body" "$(issue 100 .body)";; esac
eq "create: done marker first" "$(head -1 "$FX/posted.txt")" "<!-- release-review-issues -->"
has "create: blocking listed" "- #100 Name is not quoted"; has "create: deferred listed" "- #101 No test for --help"
has "create: ready to live hint" 'Set `READY TO LIVE`'

world; mkdir -p "$FX/state/issues"; echo 50 > "$FX/state/next"
h=$(printf '%s' "Name is not quoted" | sha256sum | cut -c1-16)
jq -n --arg b "old body <!-- release-review-finding:7:$h -->" '{number:49,body:$b,labels:[],type:"",prio:""}' > "$FX/state/issues/49.json"
rc=$(cr '{"issues":[{"title":"Name is not quoted","body":"The name splits.","type":"Bug","blocking":true}]}' 1)
eq "create: marker found exit" "$rc" 0
eq "create: marker found makes no new issue" "$(count)" 1
eq "create: marker found type re-applied" "$(issue 49 .type)" Bug
eq "create: marker found label added" "$(issue 49 '.labels|join(",")')" release-blocker
eq "create: marker found priority" "$(issue 49 .prio)" Urgent

world; rc=$(cr '{"issues":[{"title":"A","body":"b","type":"Bug","blocking":true}]}' 2)
[ "$rc" != 0 ] && ok "create: count mismatch fails" || bad "create: count" "exit $rc"
eq "create: count mismatch creates nothing" "$(count)" 0; has "create: mismatch comment" "No issue was created"
world; rc=$(cr '{"issues":[{"title":"A","body":"b","type":"Bug","blocking":true},{"title":"A","body":"c","type":"Task","blocking":false}]}' 2)
[ "$rc" != 0 ] && ok "create: duplicate titles fail" || bad "create: duplicates" "exit $rc"; eq "create: duplicates create nothing" "$(count)" 0
one() { jq -n --arg t "$1" '{issues:[{title:$t,body:"b",type:"Bug",blocking:true}]}'; }
long1=$(printf 'say "hi" $HOME %.0s' $(seq 12)); long1=${long1% }
world; rc=$(cr "$(one "$long1")" 1); eq "create: title over 100 is shortened exit" "$rc" 0
t=$(issue 100 .title)
case "$t" in *…) ok ;; *) bad "create: shortened title ends with an ellipsis" "$t" ;; esac
eq "create: shortened title is at most 100 characters" "$(jq -rn --arg t "$t" '$t | length <= 100')" true
case "$long1" in "${t%…}"\ *) ok ;; *) bad "create: shortened title cut at a word boundary" "$t" ;; esac
eq "create: shortened body starts with the full title" "$(issue 100 .body | head -1)" "Full title: $long1"
long2=$(printf 'x%.0s' $(seq 101))
world; rc=$(cr "$(one "$long2")" 1); eq "create: long title without spaces exit" "$rc" 0
eq "create: long title without spaces cut at 99" "$(issue 100 .title)" "$(printf 'x%.0s' $(seq 99))…"
world; rc=$(cr "$(jq -n --arg t "$long2" '{issues:[{title:$t,body:"b",type:"Bug",blocking:true},{title:"No test for --help",body:"Missing.",type:"Task",blocking:false}]}')" 2)
eq "create: one long title exit" "$rc" 0; eq "create: one long title does not block the others" "$(count)" 2
common=$(printf 'abcdefghi %.0s' $(seq 10))
world; rc=$(cr "$(jq -n --arg a "${common}one" --arg b "${common}two" '{issues:[{title:$a,body:"b",type:"Bug",blocking:true},{title:$b,body:"c",type:"Task",blocking:false}]}')" 2)
[ "$rc" != 0 ] && ok "create: titles that shorten to the same text fail" || bad "create: shortened duplicates" "exit $rc"
eq "create: shortened duplicates create nothing" "$(count)" 0; has "create: shortened duplicates name the items" "items 1 and 2"
world; rc=$(cr "$(one "$long1")" 1); has "create: results comment lists shortened titles" "item 1 as #100"
world; rc=$(cr "$TWO" 2); case "$(cat "$FX/posted.txt")" in *"Titles shortened"*) bad "create: no shortened line without a long title" ;; *) ok ;; esac
world; rc=$(cr "$(one "$long1")" 1); rc=$(cr "$(one "$long1")" 1)
eq "create: re-run with a shortened title exit" "$rc" 0; eq "create: re-run with a shortened title does not duplicate" "$(count)" 1
world; rc=$(cr '{"issues":[{"title":"A","body":"b","type":"Chore","blocking":true}]}' 1)
[ "$rc" != 0 ] && ok "create: type Chore fails" || bad "create: type" "exit $rc"
has "create: invalid item names index" "item 1"; has "create: invalid item names rule" "Bug, Task or Feature"
for w in release-issues release-review; do
  f="$ROOT/.github/workflows/$w.yml"
  if grep -qF '"description":"At most 100 characters; shorten without changing the meaning"' "$f"; then ok; else bad "schemas: $w title states the limit" "$f"; fi
  if grep -q maxLength "$f"; then bad "schemas: $w has no maxLength" "$f"; else ok; fi
done
if grep -qF '100 characters' "$ROOT/prompts/release-review.md"; then ok; else bad "prompt: release review states the limit"; fi
world; rc=$(cr 'not json' 1); [ "$rc" != 0 ] && ok "create: malformed fails" || bad "create: malformed" "exit $rc"
world; rc=$(cr '{"issues":[]}' 0); eq "create: zero issues exit" "$rc" 0
has "create: no finding text" "no finding"; eq "create: zero done marker" "$(head -1 "$FX/posted.txt")" "<!-- release-review-issues -->"

world; export STUB_DROP_TYPE=1; rc=$(cr "$TWO" 2)
[ "$rc" != 0 ] && ok "create: dropped type fails" || bad "create: dropped type" "exit $rc"
eq "create: dropped type still creates both" "$(count)" 2
eq "create: failed marker" "$(head -1 "$FX/posted.txt")" "<!-- release-review-issues-failed -->"
unset STUB_DROP_TYPE; : > "$FX/posted.txt"; rc=$(cr "$TWO" 2)
eq "create: re-run exit" "$rc" 0; eq "create: re-run no duplicates" "$(count)" 2
eq "create: re-run repairs type" "$(issue 100 .type)" Bug
eq "create: re-run done marker" "$(head -1 "$FX/posted.txt")" "<!-- release-review-issues -->"
world; export STUB_FAIL_CREATE=1; rc=$(cr "$TWO" 2)
[ "$rc" != 0 ] && ok "create: create failure fails" || bad "create: create failure" "exit $rc"
eq "create: create failure failed marker" "$(head -1 "$FX/posted.txt")" "<!-- release-review-issues-failed -->"

summary
