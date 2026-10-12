#!/usr/bin/env bash
# The run blocks of dev-execute.yml: the gate (owner, label, type, plan, branch), what to publish, the
# pull request and the findings comment, with a stub gh and git push.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
W=$WORK; mkdir -p "$W/bin"
REAL_GIT=$(command -v git)
cat > "$W/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >> "$STUB_LOG"
case "$1 $2" in
  "issue comment")
    # find --body or --body-file
    while [ $# -gt 0 ]; do
      case "$1" in --body) echo "BODY: $2" >> "$STUB_LOG"; shift;; --body-file) echo "BODYFILE:" >> "$STUB_LOG"; cat "$2" >> "$STUB_LOG"; shift;; esac; shift
    done ;;
  "pr create")
    while [ $# -gt 0 ]; do
      case "$1" in --body-file) echo "PRBODY:" >> "$STUB_LOG"; cat "$2" >> "$STUB_LOG"; shift;; esac; shift
    done ;;
  "api --paginate") cat "$STUB_COMMENTS" ;;
  "api repos/"*)
    case "$2" in
      */git/ref/heads/*) [ "${STUB_BRANCH_EXISTS:-0}" = 1 ] && exit 0 || exit 1 ;;
      */issues/*) cat "$STUB_ISSUE" ;;
    esac ;;
  *) echo "unexpected gh call: $*" >&2; exit 99 ;;
esac
STUB
cat > "$W/bin/git" <<STUB
#!/usr/bin/env bash
if [ "\$1" = push ]; then echo "git \$*" >> "\$STUB_LOG"; exit 0; fi
exec "$REAL_GIT" "\$@"
STUB
chmod +x "$W/bin/"*
export PATH="$W/bin:$PATH"

python3 -I - "$ROOT/.github/workflows/dev-execute.yml" "$W" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
n = 0
for s in d["jobs"]["dev-execute"]["steps"]:
    if "run" in s:
        assert "${{" not in s["run"], f"expression left in run block: {s.get('id') or s.get('name')}"
        open(f"{sys.argv[2]}/{(s.get('id') or s['name']).replace(' ', '_')}.sh", "w").write(s["run"]); n += 1
PY
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL $1"; }
out() { grep -E "^$1=" "$GITHUB_OUTPUT" | tail -1 | cut -d= -f2-; }

# a repo with a base commit, for the git calls
mkrepo() { rm -rf "$W/repo"; mkdir -p "$W/repo"; ( cd "$W/repo" && git init -q -b main && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m base ); }
newcase() { C=$W/case; rm -rf "$C"; mkdir -p "$C/tmp"; export RUNNER_TEMP=$C/tmp GITHUB_OUTPUT=$C/out STUB_LOG=$C/log GITHUB_REPOSITORY=acme/app ISSUE=13; : > "$GITHUB_OUTPUT"; : > "$STUB_LOG"; export STUB_ISSUE=$C/issue.json STUB_COMMENTS=$C/comments.json; unset STUB_BRANCH_EXISTS; }
issue() { # type-json title labels-json
  jq -n --argjson t "$1" --arg title "$2" --argjson l "$3" --arg u "${AUTHOR:-bentoluizv}" '{title:$title, type:$t, labels:$l, user:{login:$u}}' > "$STUB_ISSUE"; }
plan_comment() { # login body url
  jq -nc --arg u "$1" --arg b "$2" --arg h "$3" '{user:{login:$u}, body:$b, html_url:$h}' >> "$STUB_COMMENTS"; }
gate() { ( cd "$W/repo" && BODY="$1" GH_TOKEN=x OWNERS="${OWNERS_VAR-bentoluizv}" bash "$W/gate.sh" > "$C/stdout" 2>&1 ); GRC=$?; }
LBL='[{"name":"RELEASE"},{"name":"feature"}]'

echo "# gate"
mkrepo; newcase; issue '{"name":"Feature"}' "Add a --help flag" "$LBL"; plan_comment github-actions[bot] $'<!-- dev-plan -->\nplan one' https://x/1
gate '/approved'
[ "$GRC" -ne 0 ] && grep -q 'exactly /approve' "$C/stdout" && ok "gate: /approved rejected with an error" || bad "gate: /approved ($GRC)"
gate $'/approve\r\nthanks'
[ "$GRC" -eq 0 ] && [ "$(out ok)" = true ] && ok "gate: /approve with CRLF and a second line accepted" || bad "gate: accept ($GRC)"
[ "$(out branch)" = feat/13-add-a-help-flag ] && ok "gate: branch feat/13-add-a-help-flag" || bad "gate: branch $(out branch)"
[ "$(out ctype)" = feat ] && [ "$(out plan_url)" = https://x/1 ] && [ -n "$(out base)" ] && ok "gate: type, plan url and base" || bad "gate: outputs"
grep -q '^plan one$' "$RUNNER_TEMP/plan.md" && ok "gate: plan body written" || bad "gate: plan body"

newcase; mkrepo; issue '{"name":"Bug"}' 'Fix: Crash on "Save" — NOW!! with a very long title that keeps going and going' "$LBL"; plan_comment github-actions[bot] $'<!-- dev-plan -->\np' u
gate /approve
b=$(out branch)
case "$b" in fix/13-fix-crash-on-save-now-with-a-very-long*) ok "gate: Bug gives fix, slug cleaned ($b)";; *) bad "gate: slug $b";; esac
[ "${#b}" -le 48 ] && ok "gate: slug cut, no trailing dash" || bad "gate: length ${#b}"
case "$b" in *-) bad "gate: trailing dash";; *) ok "gate: no trailing dash";; esac

newcase; mkrepo; issue null "Tidy" "$LBL"; plan_comment github-actions[bot] $'<!-- dev-plan -->\np' u
gate /approve; [ "$(out branch)" = chore/13-tidy ] && ok "gate: no type gives chore" || bad "gate: chore $(out branch)"

newcase; mkrepo; issue '{"name":"Feature"}' "!!!" "$LBL"; plan_comment github-actions[bot] $'<!-- dev-plan -->\np' u
gate /approve; [ "$(out branch)" = feat/13-change ] && ok "gate: empty slug falls back to change" || bad "gate: empty slug $(out branch)"

newcase; mkrepo; issue '{"name":"Feature"}' "T" '[{"name":"feature"}]'; plan_comment github-actions[bot] $'<!-- dev-plan -->\np' u
gate /approve
[ "$GRC" -eq 0 ] && [ "$(out ok)" = false ] && grep -q 'does not carry `RELEASE`' "$STUB_LOG" && ok "gate: no RELEASE stops with a comment" || bad "gate: no RELEASE"

newcase; mkrepo; issue '{"name":"Project"}' "T" "$LBL"; plan_comment github-actions[bot] $'<!-- dev-plan -->\np' u
gate /approve; [ "$(out ok)" = false ] && grep -q 'sub-issues of a Project' "$STUB_LOG" && ok "gate: Project stops with a comment" || bad "gate: Project"

newcase; mkrepo; issue '{"name":"Feature"}' "T" "$LBL"; : > "$STUB_COMMENTS"
gate /approve; [ "$(out ok)" = false ] && grep -q 'no development plan comment' "$STUB_LOG" && ok "gate: no plan stops with a comment" || bad "gate: no plan"

newcase; mkrepo; issue '{"name":"Feature"}' "T" "$LBL"; plan_comment mallory $'<!-- dev-plan -->\nevil plan' https://x/evil
gate /approve; [ "$(out ok)" = false ] && ok "gate: a marker comment by another author is not a plan" || bad "gate: spoof accepted"

newcase; mkrepo; issue '{"name":"Feature"}' "T" "$LBL"
plan_comment github-actions[bot] $'<!-- dev-plan -->\nold' https://x/old
plan_comment mallory $'<!-- dev-plan -->\nevil' https://x/evil
plan_comment github-actions[bot] $'<!-- dev-plan -->\nnew' https://x/new
gate /approve; [ "$(out plan_url)" = https://x/new ] && grep -q '^new$' "$RUNNER_TEMP/plan.md" && ok "gate: latest bot plan wins over older and spoofed" || bad "gate: latest ($(out plan_url))"

newcase; mkrepo; issue '{"name":"Feature"}' "T" "$LBL"; plan_comment github-actions[bot] $'<!-- dev-plan -->\np' u; export STUB_BRANCH_EXISTS=1
gate /approve; [ "$(out ok)" = false ] && grep -q 'already exists' "$STUB_LOG" && ok "gate: existing branch stops with a comment" || bad "gate: branch exists"

echo "# gate: author"
for a in bentoluizv BentoLuizV github-actions[bot]; do
  newcase; mkrepo; AUTHOR=$a issue '{"name":"Feature"}' "T" "$LBL"; plan_comment github-actions[bot] $'<!-- dev-plan -->\np' u
  gate /approve; [ "$(out ok)" = true ] && ok "gate: author $a accepted" || bad "gate: author $a ($(out ok))"
done
newcase; mkrepo; AUTHOR=mallory issue '{"name":"Feature"}' "T" "$LBL"; plan_comment github-actions[bot] $'<!-- dev-plan -->\np' u
gate /approve; [ "$(out ok)" = false ] && grep -q 'not written by an owner' "$STUB_LOG" && ok "gate: non-owner author stops with a comment" || bad "gate: non-owner author"
newcase; mkrepo; AUTHOR=bentoluizv issue '{"name":"Feature"}' "T" "$LBL"; plan_comment github-actions[bot] $'<!-- dev-plan -->\np' u
OWNERS_VAR="" gate /approve; [ "$(out ok)" = false ] && ok "gate: empty owners refuses an owner-named author" || bad "gate: empty owners"
newcase; mkrepo; AUTHOR=bentoluizv issue '{"name":"Feature"}' "T" "$LBL"; plan_comment github-actions[bot] $'<!-- dev-plan -->\np' u
OWNERS_VAR="bentoluizv-evil" gate /approve; [ "$(out ok)" = false ] && ok "gate: owners entry that only contains the login does not match" || bad "gate: substring"

echo "# final"
final() { # base-ref R1 R2 R3 outcomes... via env set by caller
  ( cd "$W/repo" && BASE="$FBASE" R1_OUTCOME="${R1O:-}" R1_VERDICT="${R1V:-}" R1_FINDINGS="${R1F:-}" \
      R2_OUTCOME="${R2O:-}" R2_VERDICT="${R2V:-}" R2_FINDINGS="${R2F:-}" \
      R3_OUTCOME="${R3O:-}" R3_VERDICT="${R3V:-}" R3_FINDINGS="${R3F:-}" bash "$W/final.sh" > "$C/stdout" 2>&1 ); FRC=$?; unset R1O R1V R1F R2O R2V R2F R3O R3V R3F; }
commit() { ( cd "$W/repo" && echo x >> f && git add f && git -c user.email=t@t -c user.name=t commit -q -m "feat: x" ); }
newcase; mkrepo; FBASE=$(git -C "$W/repo" rev-parse HEAD); commit
R1O=done R1V=pass R1F=/r1; final
[ "$(out action)" = pr ] && [ "$(out rounds)" = 1 ] && [ "$(out ahead)" = 1 ] && ok "final: pass with commits gives pr" || bad "final: pass ($(out action))"
R1O=done R1V=fail R1F=/r1 R2O=done R2V=fail R2F=/r2 R3O=done R3V=fail R3F=/r3; final
[ "$(out action)" = draft ] && [ "$(out rounds)" = 3 ] && [ "$(out findings_file)" = /r3 ] && ok "final: three failing rounds give draft with last findings" || bad "final: draft ($(out action) $(out rounds))"
R1O=done R1V=fail R1F=/r1 R2O=done R2V=pass R2F=/r2; final
[ "$(out action)" = pr ] && [ "$(out rounds)" = 2 ] && ok "final: pass in round 2 gives pr" || bad "final: round 2 pass"
R1O=blocked R1V=none R1F=/r1; final
[ "$(out action)" = comment ] && [ "$(out outcome)" = blocked ] && ok "final: blocked gives comment" || bad "final: blocked"
R1O=failed R1V=none R1F=/r1; final
[ "$(out action)" = comment ] && ok "final: failed gives comment" || bad "final: failed"
R1O=done R1V=fail R1F=/r1 R2O=blocked R2V=none R2F=/r2; final
[ "$(out action)" = comment ] && [ "$(out findings_file)" = /r2 ] && ok "final: blocked in round 2 gives comment" || bad "final: r2 blocked"
final; [ "$(out action)" = comment ] && [ "$(out rounds)" = 0 ] && [ "$(out outcome)" = none ] && ok "final: no round ran gives comment" || bad "final: none"
newcase; mkrepo; FBASE=$(git -C "$W/repo" rev-parse HEAD)
R1O=done R1V=pass R1F=/r1; final
[ "$(out action)" = comment ] && [ "$(out ahead)" = 0 ] && ok "final: pass with no commits gives comment" || bad "final: no commits ($(out action))"

echo "# push, pull request, findings"
newcase; mkrepo
( cd "$W/repo" && GH_TOKEN=tok123 BRANCH=feat/13-x GITHUB_REPOSITORY=acme/app bash "$W/Push_the_branch.sh" > "$C/stdout" 2>&1 )
grep -q 'git push https://x-access-token:tok123@github.com/acme/app.git HEAD:refs/heads/feat/13-x' "$STUB_LOG" && ok "push: token URL and refspec" || bad "push: $(cat "$STUB_LOG")"
prrun() { ( cd "$W/repo" && GH_TOKEN=x BRANCH=feat/13-x CTYPE=feat PLAN_URL=https://x/1 ISSUE=13 TITLE="Add A --Help Flag" DEFAULT_BRANCH=main ACTION="$1" VERDICT="$2" ROUNDS="$3" bash "$W/Open_the_pull_request.sh" > "$C/stdout" 2>&1 ); }
prrun pr pass 1
grep -q -- '--head feat/13-x --base main --title feat: add a --help flag --body-file' "$STUB_LOG" && ok "pr: head, base, lower-case conventional title" || bad "pr: $(grep 'gh pr' "$STUB_LOG")"
grep -q -- '--draft' "$STUB_LOG" && bad "pr: draft flag on a pass" || ok "pr: no draft flag on a pass"
grep -q '^Closes #13$' "$STUB_LOG" && grep -q 'Plan: https://x/1' "$STUB_LOG" && grep -q 'Check verdict: pass after 1 round' "$STUB_LOG" && ok "pr: body has Closes, plan, verdict" || bad "pr: body"
newcase; mkrepo; prrun draft fail 3
grep -q -- '--draft' "$STUB_LOG" && ok "pr: draft flag on fail" || bad "pr: draft missing"
echo "findings text" > "$C/f.md"
postrun() { ( cd "$W/repo" && GH_TOKEN=x ISSUE=13 ACTION="$1" OUTCOME="$2" ROUNDS="$3" AHEAD="$4" FINDINGS="$5" bash "$W/Post_the_findings.sh" > "$C/stdout" 2>&1 ); }
newcase; mkrepo; echo "- criterion 2: x" > "$C/f.md"
postrun draft done 3 2 "$C/f.md"
grep -q 'dev-execute-findings' "$STUB_LOG" && grep -q 'draft pull request was opened after 3 round' "$STUB_LOG" && grep -q 'criterion 2: x' "$STUB_LOG" && ok "findings: draft text, marker, findings" || bad "findings: draft"
newcase; mkrepo
postrun comment blocked 1 0 ""
grep -q 'No pull request was opened (last outcome: blocked, 1 round(s), 0 commit(s) ahead)' "$STUB_LOG" && grep -q 'No round produced a result' "$STUB_LOG" && ok "findings: comment text, no findings file" || bad "findings: comment"

echo "# executor App token"
python3 -I - "$ROOT/.github/workflows/dev-execute.yml" "$ROOT/.github/workflows/release-please.yml" > "$W/app.out" <<'PY'
import sys, json, yaml
d = yaml.safe_load(open(sys.argv[1]))
rp = yaml.safe_load(open(sys.argv[2]))
wc = (d.get("on") or d.get(True))["workflow_call"]
job = d["jobs"]["dev-execute"]
steps = job["steps"]
def emit(ok, name): print(("ok|" if ok else "bad|") + name)
is_mint = lambda s: str(s.get("uses", "")).startswith("actions/create-github-app-token@")
mints = [s for s in steps if is_mint(s)]
emit(len(mints) == 1, "app: exactly one App token step in the job")
perms = job.get("permissions", {})
emit(perms.get("contents") != "write" and perms.get("pull-requests") != "write",
     "app: job permissions hold no contents or pull-requests write")
if len(mints) != 1:
    for n in ("push and PR take GH_TOKEN from the App token step",
              "token scope is contents, pull-requests and workflows write only",
              "only the push and PR steps reference the token",
              "minted after the rounds, only for a pr or draft action",
              "same pinned action as release-please"):
        emit(False, "app: " + n)
    emit("executor_app_private_key" in wc.get("secrets", {})
         and wc["secrets"]["executor_app_private_key"].get("required") is True
         and wc.get("inputs", {}).get("executor_app_client_id", {}).get("required") is True,
         "app: workflow_call requires the executor App key and client id")
    sys.exit(0)
mint = mints[0]
ref = f"steps.{mint.get('id', '')}.outputs.token"
by_name = {s.get("name"): s for s in steps}
push_pr = ["Push the branch", "Open the pull request"]
emit(bool(mint.get("id")) and all(
    ref in str((by_name.get(n) or {}).get("env", {}).get("GH_TOKEN", "")) for n in push_pr),
    "app: push and PR take GH_TOKEN from the App token step")
w = mint.get("with", {})
scoped = {k: v for k, v in w.items() if k.startswith("permission-")}
emit(scoped == {"permission-contents": "write", "permission-pull-requests": "write",
                "permission-workflows": "write"},
     "app: token scope is contents, pull-requests and workflows write only")
users = sorted(s.get("name") for s in steps if s is not mint and ref in json.dumps(s))
emit(users == sorted(push_pr), "app: only the push and PR steps reference the token")
cond = str(mint.get("if", ""))
names = [s.get("id") for s in steps]
emit("steps.final.outputs.action == 'pr'" in cond and "steps.final.outputs.action == 'draft'" in cond
     and "final" in names and steps.index(mint) > names.index("final"),
     "app: minted after the rounds, only for a pr or draft action")
rp_pins = {s["uses"] for j in rp["jobs"].values() for s in j["steps"] if is_mint(s)}
emit(mint["uses"] in rp_pins, "app: same pinned action as release-please")
emit("executor_app_private_key" in wc.get("secrets", {})
     and wc["secrets"]["executor_app_private_key"].get("required") is True
     and wc.get("inputs", {}).get("executor_app_client_id", {}).get("required") is True,
     "app: workflow_call requires the executor App key and client id")
PY
while IFS='|' read -r r n; do [ "$r" = ok ] && ok || bad "$n"; done < "$W/app.out"

summary
