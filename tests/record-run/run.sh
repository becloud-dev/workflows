#!/usr/bin/env bash
# The record-run composite: what a run record holds, how it is named, how denials are cut.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
H=$WORK
python3 -I -c "import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); b=d['runs']['steps'][0]['run']; assert '\${{' not in b; open(sys.argv[2],'w').write(b)" "$ROOT/.github/actions/record-run/action.yml" "$H/body.sh" || { echo "cannot extract record-run" >&2; exit 1; }
rec() { # stage execfile  -> sets REC path
  T=$H/t; mkdir -p "$T"; export RUNNER_TEMP=$T GITHUB_OUTPUT=$T/out GITHUB_STEP_SUMMARY=$T/sum GITHUB_REPOSITORY=a/b GITHUB_RUN_ID=1 GITHUB_RUN_ATTEMPT=1
  : > "$GITHUB_OUTPUT"; : > "$GITHUB_STEP_SUMMARY"
  EXEC="$2" STAGE="$1" MODEL=m AUTH=oauth ISSUE=13 WORKFLOW=w bash "$H/body.sh" > /dev/null 2>&1; RC=$?
  REC=$(grep '^record_path=' "$GITHUB_OUTPUT" | cut -d= -f2-)
}
rm -rf "$H/t"; mkdir -p "$H/t"
echo '[{"type":"system"},{"type":"result","is_error":false,"num_turns":4,"duration_ms":10,"total_cost_usd":0.05,"permission_denials":[]}]' > "$H/e0.json"
echo '[{"type":"result","is_error":false,"num_turns":5,"permission_denials":[{"tool_name":"Bash","tool_input":{"command":"rm -rf x"}}]}]' > "$H/e1.json"
echo '[{"type":"result","is_error":true,"num_turns":5,"permission_denials":[{"tool_name":"Bash","tool_input":{"command":"a"}},{"tool_name":"Edit","tool_input":{"file_path":"f"}}]}]' > "$H/e2.json"
long=$(head -c 500 /dev/zero | tr '\0' x)
jq -n --arg c "$long" '[{"type":"result","is_error":false,"permission_denials":[{"tool_name":"Bash","tool_input":{"command":$c}}]}]' > "$H/e500.json"
rec dev-plan "$H/e0.json"; [ "$RC" = 0 ] && [ "$(jq .permission_denials_count "$REC")" = 0 ] && [ "$(jq -r .stage "$REC")" = dev-plan ] && ok "0 denials" || bad "0 denials"
case "$REC" in */run-record-dev-plan.json) ok "file named by stage";; *) bad "file name $REC";; esac
rec dev-plan "$H/e1.json"; [ "$(jq .permission_denials_count "$REC")" = 1 ] && [ "$(jq -r '.permission_denials[0].tool_name' "$REC")" = Bash ] && ok "1 denial named" || bad "1 denial"
rec dev-plan "$H/e2.json"; [ "$(jq .permission_denials_count "$REC")" = 2 ] && [ "$(jq .is_error "$REC")" = true ] && ok "2 denials" || bad "2 denials"
rec dev-plan "$H/e500.json"; [ "$(jq '.permission_denials[0].tool_input | length' "$REC")" -le 300 ] && ok "500-character input cut to 300 or less ($(jq '.permission_denials[0].tool_input | length' "$REC"))" || bad "cut"
rec dev-plan "$H/missing.json"; [ "$RC" = 0 ] && [ "$(jq .num_turns "$REC")" = 0 ] && [ "$(jq .is_error "$REC")" = null ] && ok "missing file gives an empty record" || bad "missing file"
rec "" "$H/e0.json"; [ "$RC" = 0 ] && ok "empty stage still writes (file run-record-.json)" || bad "empty stage ($RC)"
rm -rf "$H/t"; mkdir -p "$H/t"
rec dev-execute-r1 "$H/e0.json"; A=$REC; rec dev-check-r1 "$H/e1.json"; B=$REC; rec dev-execute-r2 "$H/e2.json"; C=$REC
[ "$A" != "$B" ] && [ "$B" != "$C" ] && [ -s "$A" ] && [ -s "$B" ] && [ -s "$C" ] && [ "$(ls "$H"/t/run-record-*.json | wc -l)" = 3 ] && ok "three stages leave three files" || bad "three stages"
[ "$(jq -r .stage "$A")" = dev-execute-r1 ] && [ "$(jq .permission_denials_count "$B")" = 1 ] && ok "each file keeps its own content" || bad "content"
rec 'a/b c' "$H/e0.json"; case "$REC" in */run-record-a_b_c.json) ok "unsafe characters in the stage replaced";; *) bad "sanitise $REC";; esac
summary
