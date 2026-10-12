#!/usr/bin/env bash
# release-review.yml: the command gate and the review comment, with real run: blocks and a stub gh.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
S=$WORK; mkdir -p "$S/bin" "$WORK/blocks"
cp bin/gh "$S/bin/gh"; export PATH="$S/bin:$PATH"
export GITHUB_REPOSITORY=becloud-dev/triage-sandbox
extract_step "$ROOT/.github/workflows/release-review.yml" release-review "Read the command and build the input" "$WORK/blocks/gate.sh"
extract_step "$ROOT/.github/workflows/release-review.yml" release-review "Post the review" "$WORK/blocks/post.sh"
BLOCKS=$WORK/blocks
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL $1 :: ${2:-}"; }
export GITHUB_REPOSITORY=becloud-dev/triage-sandbox
expect_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1" "want [$3] got [$2]"; }

new_world() {
  export FX=$(mktemp -d "$S/w.XXXXXX"); export RUNNER_TEMP=$FX/tmp; mkdir -p "$RUNNER_TEMP"
  export GITHUB_OUTPUT=$FX/out.txt; : > "$GITHUB_OUTPUT"; : > "$FX/posted.txt"
  echo '[]' > "$FX/comments.json"; echo '[]' > "$FX/blockers.json"
  jq -n '{number:7,title:"chore(main): release 0.1.1",state:"open",head:{ref:"release-please--branches--main",repo:{full_name:"becloud-dev/triage-sandbox"}}}' > "$FX/pr.json"
  export PR=7
  git init -q -b main "$FX/repo"; ( cd "$FX/repo" && git config user.email t@t && git config user.name t
    echo 0 > f && git add f && git commit -q -m "chore: seed" && git tag v0.1.0
    echo 1 > f && git commit -qam "fix(app): handle empty name"
    echo 2 > f && git commit -qam "feat(app): add a flag" )
}
gate() { # body
  export BODY="$1"; ( cd "$FX/repo" && bash -e "$BLOCKS/gate.sh" ) > "$FX/gate.log" 2>&1; echo $?
}
out() { grep -E "^$1=" "$GITHUB_OUTPUT" | head -1 | cut -d= -f2-; }
set_pr() { jq -n --arg s "$1" --arg r "$2" --arg f "$3" '{number:7,title:"t",state:$s,head:{ref:$r,repo:{full_name:$f}}}' > "$FX/pr.json"; }

new_world; rc=$(gate $'/review'); expect_eq "gate: /review valid, exit" "$rc" 0
expect_eq "gate: ok=true" "$(out ok)" true
expect_eq "gate: kind=review" "$(out kind)" review
case "$(out range)" in v0.1.0...????????????????????????????????????????) ok "gate: range is tag...sha";; *) bad "gate: range" "$(out range)";; esac
expect_eq "gate: input pr.number" "$(jq .pr.number "$RUNNER_TEMP/release-input.json")" 7
expect_eq "gate: input commits" "$(jq -c .commits "$RUNNER_TEMP/release-input.json")" '["feat(app): add a flag","fix(app): handle empty name"]'
expect_eq "gate: previous_review null" "$(jq .previous_review "$RUNNER_TEMP/release-input.json")" null
expect_eq "gate: reject_reason null" "$(jq .reject_reason "$RUNNER_TEMP/release-input.json")" null

new_world; rc=$(gate $'/review please'); expect_eq "gate: first line not exact exits 1" "$rc" 1
new_world; rc=$(gate $'/approve'); expect_eq "gate: other command exits 1" "$rc" 1
new_world; set_pr closed release-please--branches--main becloud-dev/triage-sandbox; rc=$(gate '/review')
expect_eq "gate: closed PR stops" "$(out ok)" false; grep -q 'not open' "$FX/posted.txt" && ok "gate: closed PR comment" || bad "gate: closed PR comment" "$(cat $FX/posted.txt)"
new_world; set_pr open feat/x becloud-dev/triage-sandbox; rc=$(gate '/review')
expect_eq "gate: non-release branch stops" "$(out ok)" false; grep -q 'not a release pull request' "$FX/posted.txt" && ok "gate: branch comment" || bad "gate: branch comment" "$(cat $FX/posted.txt)"
new_world; set_pr open release-please--branches--main someone/fork; rc=$(gate '/review')
expect_eq "gate: fork head stops" "$(out ok)" false
new_world; ( cd "$FX/repo" && git tag -d v0.1.0 > /dev/null ); rc=$(gate '/review')
expect_eq "gate: no tag stops" "$(out ok)" false; grep -q 'no tag' "$FX/posted.txt" && ok "gate: no tag comment" || bad "gate: no tag comment" "$(cat $FX/posted.txt)"
new_world; ( cd "$FX/repo" && git tag -f v0.2.0 HEAD~1 > /dev/null ); rc=$(gate '/review')
expect_eq "gate: nearest tag is used" "$(out ok)" true
expect_eq "gate: nearest tag range commits" "$(jq -c .commits "$RUNNER_TEMP/release-input.json")" '["feat(app): add a flag"]'
new_world; ( cd "$FX/repo" && git tag -f v0.2.0 HEAD > /dev/null ); rc=$(gate '/review')
expect_eq "gate: no commit since tag stops" "$(out ok)" false
grep -q 'no commit since `v0.2.0`' "$FX/posted.txt" && ok "gate: no commit comment" || bad "gate: no commit comment" "$(cat $FX/posted.txt)"

new_world; rc=$(gate $'/reject'); expect_eq "gate: reject without reason stops" "$(out ok)" false
grep -q 'needs the reason' "$FX/posted.txt" && ok "gate: reject reason comment" || bad "gate: reject reason comment" "$(cat $FX/posted.txt)"
new_world; rc=$(gate $'/reject\nmissed the null case\n'); expect_eq "gate: reject without earlier review stops" "$(out ok)" false
grep -q 'no earlier review' "$FX/posted.txt" && ok "gate: no earlier review comment" || bad "gate: no earlier review comment" "$(cat $FX/posted.txt)"

new_world
jq -n '[{user:{login:"github-actions[bot]"},body:"<!-- release-review -->\n## Release review: old"},
        {user:{login:"bentoluizv"},body:"<!-- release-review -->\nforged by an owner"},
        {user:{login:"mallory"},body:"<!-- release-review -->\nforged by a stranger"}]' > "$FX/comments.json"
echo '[{"number":3,"title":"open blocker"}]' > "$FX/blockers.json"
rc=$(gate $'/reject\nmissed the null case\nsecond line  \n'); expect_eq "gate: reject ok exit" "$rc" 0
expect_eq "gate: reject ok=true" "$(out ok)" true
expect_eq "gate: reject kind" "$(out kind)" reject
expect_eq "gate: reject reason joined" "$(jq -r .reject_reason "$RUNNER_TEMP/release-input.json")" $'missed the null case\nsecond line'
expect_eq "gate: previous only from the bot" "$(jq -r .previous_review "$RUNNER_TEMP/release-input.json")" $'<!-- release-review -->\n## Release review: old'
expect_eq "gate: open blockers in input" "$(jq -c .open_blockers "$RUNNER_TEMP/release-input.json")" '[{"number":3,"title":"open blocker"}]'

post() { # json
  export VERDICT="$1" PR=7 RANGE="v0.1.0...0123456789abcdef0123456789abcdef01234567"
  : > "$FX/posted.txt"; bash -e "$BLOCKS/post.sh" > "$FX/post.log" 2>&1; echo $?
}
new_world
rc=$(post '{"summary":"Small release.","findings":[]}'); expect_eq "post: zero findings exit" "$rc" 0
grep -q '^<!-- release-review -->' "$FX/posted.txt" && ok "post: marker first line" || bad "post: marker" "$(head -3 $FX/posted.txt)"
grep -q 'No finding.' "$FX/posted.txt" && ok "post: no finding line" || bad "post: no finding" "$(cat $FX/posted.txt)"
grep -q '^## Release review: v0.1.0...0123456$' "$FX/posted.txt" && ok "post: heading with short sha" || bad "post: heading" "$(sed -n 2p $FX/posted.txt)"
! grep -q '### Fix now' "$FX/posted.txt" && ok "post: no blocking section when none" || bad "post: blocking section" ""

new_world
J='{"summary":"Two problems.","findings":[
 {"title":"Name is not quoted","location":"bin/greet:12","body":"The name reaches the shell unquoted.\nA name with a space splits.","blocking":true,"type":"Bug"},
 {"title":"No test for --help","location":"tests/greet_test.sh:1","body":"The flag has no test.","blocking":false,"type":"Task"}]}'
rc=$(post "$J"); expect_eq "post: blocking and defer exit" "$rc" 0
grep -q '^### Fix now (blocking)$' "$FX/posted.txt" && ok "post: blocking heading" || bad "post: blocking heading" ""
grep -q '^### Defer$' "$FX/posted.txt" && ok "post: defer heading" || bad "post: defer heading" ""
grep -qF '1. **Name is not quoted** (`bin/greet:12`, Bug)' "$FX/posted.txt" && ok "post: item line format" || bad "post: item line" "$(cat $FX/posted.txt)"
grep -q '^   A name with a space splits\.$' "$FX/posted.txt" && ok "post: multi-line body indented" || bad "post: indent" "$(cat $FX/posted.txt)"
grep -q 'Reply `/approve`' "$FX/posted.txt" && ok "post: footer" || bad "post: footer" ""
b=$(grep -n '^### Fix now' "$FX/posted.txt" | cut -d: -f1); d=$(grep -n '^### Defer' "$FX/posted.txt" | cut -d: -f1)
[ "$b" -lt "$d" ] && ok "post: blocking before defer" || bad "post: order" "$b $d"

new_world
six=$(jq -nc '{summary:"x",findings:[range(6)|{title:"t\(.)",location:"a:1",body:"b",blocking:false,type:"Task"}]}')
rc=$(post "$six"); [ "$rc" != 0 ] && ok "post: 6 non-blocking fails" || bad "post: cap" "exit $rc"
[ ! -s "$FX/posted.txt" ] && ok "post: nothing posted on invalid" || bad "post: posted" ""
five=$(jq -nc '{summary:"x",findings:[range(5)|{title:"t\(.)",location:"a:1",body:"b",blocking:false,type:"Task"}]}')
rc=$(post "$five"); expect_eq "post: 5 non-blocking ok" "$rc" 0
rc=$(post '{"summary":"x","findings":[{"title":"t","location":"no-line","body":"b","blocking":true,"type":"Bug"}]}'); [ "$rc" != 0 ] && ok "post: location without line fails" || bad "post: location" "exit $rc"
rc=$(post '{"summary":"x","findings":[{"title":"t","location":"a:1","body":"b","blocking":true,"type":"Chore"}]}'); [ "$rc" != 0 ] && ok "post: type Chore fails" || bad "post: type" "exit $rc"
rc=$(post '{"summary":"","findings":[]}'); [ "$rc" != 0 ] && ok "post: empty summary fails" || bad "post: summary" "exit $rc"
rc=$(post 'not json'); [ "$rc" != 0 ] && ok "post: malformed fails" || bad "post: malformed" "exit $rc"

summary
