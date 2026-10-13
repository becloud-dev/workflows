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
case " \$* " in
  *" push "*)
    echo "git \$* GIT_DIR=\${GIT_DIR:-} GIT_CONFIG_GLOBAL=\${GIT_CONFIG_GLOBAL:-}" >> "\$STUB_LOG"
    args=()
    for a in "\$@"; do case "\$a" in https://x-access-token:*@github.com/*) a=\$STUB_REMOTE;; esac; args+=("\$a"); done
    exec "$REAL_GIT" "\${args[@]}" ;;
esac
exec "$REAL_GIT" "\$@"
STUB
chmod +x "$W/bin/"*
export PATH="$W/bin:$PATH"

python3 -I - "$ROOT/.github/workflows/dev-execute.yml" "$W" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
n = 0
for j in d["jobs"].values():
  for s in j["steps"]:
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

echo "# bundle, publish verify and push"
# the push goes to a local bare remote in place of the GitHub URL, so the real git runs the hooks and config it reads
pushcase() { newcase; mkrepo; export STUB_REMOTE=$C/remote.git; git init -q --bare "$STUB_REMOTE"; }
remote_ref() { git --git-dir="$1" rev-parse -q --verify refs/heads/feat/13-x || true; }
# the rounds side bundles the commit the Decide step found; the publish side then checks out the base, as its own checkout does
bundled() {
  pushcase; FBASE=$(git -C "$W/repo" rev-parse HEAD); commit; R1O=done R1V=pass R1F=/r1; final
  mkdir -p "$C/tmp/publish-bundle"; mv "$C/tmp/bundle/publish.bundle" "$C/tmp/publish-bundle/"
  NEWHEAD=$(git -C "$W/repo" rev-parse HEAD); git -C "$W/repo" checkout -q --detach "$FBASE"
}
verifyrun() { ( cd "$W/repo" && BUNDLE="$C/tmp/publish-bundle/publish.bundle" GITHUB_REPOSITORY=acme/app bash "$W/Verify_the_bundle.sh" > "$C/stdout" 2>&1 ); }
pushrun() { ( cd "$W/repo" && GH_TOKEN=tok123 BRANCH=feat/13-x GITHUB_REPOSITORY=acme/app bash "$W/Push_the_branch.sh" > "$C/stdout" 2>&1 ); }
publish() { verifyrun && pushrun; }

pushcase; FBASE=$(git -C "$W/repo" rev-parse HEAD); commit
printf '#!/bin/sh\necho ran >> "%s"\n' "$C/marker" > "$W/repo/.git/hooks/pre-push"; chmod +x "$W/repo/.git/hooks/pre-push"
git -C "$W/repo" config uploadpack.packObjectsHook "touch $C/upload-marker"
R1O=done R1V=pass R1F=/r1; final
B=$C/tmp/bundle/publish.bundle
[ -s "$B" ] && git -C "$W/repo" bundle verify "$B" > /dev/null 2>&1 && git bundle list-heads "$B" | grep -qF "$(git -C "$W/repo" rev-parse HEAD) refs/push/head" && [ ! -e "$C/marker" ] && [ ! -e "$C/upload-marker" ] \
  && ok "bundle: holds the commit on the base, and no planted hook or config runs" || bad "bundle: $(cat "$C/stdout")"

bundled; publish
[ "$(remote_ref "$STUB_REMOTE")" = "$NEWHEAD" ] && ok "publish: verifies the bundle and pushes its HEAD under the branch name" || bad "publish: HEAD not pushed ($(remote_ref "$STUB_REMOTE")) $(cat "$C/stdout")"
grep -qF 'git -c core.hooksPath=/dev/null push https://x-access-token:tok123@github.com/acme/app.git refs/push/head:refs/heads/feat/13-x' "$STUB_LOG" && grep -qF "GIT_DIR=$C/tmp/publish.git GIT_CONFIG_GLOBAL=/dev/null" "$STUB_LOG" && ok "publish: token URL and refspec, from the fresh git dir" || bad "publish: push call $(cat "$STUB_LOG")"

bundled; printf '#!/bin/sh\necho ran >> "%s"\n' "$C/marker" > "$W/repo/.git/hooks/pre-push"; chmod +x "$W/repo/.git/hooks/pre-push"
publish
[ ! -e "$C/marker" ] && [ "$(remote_ref "$STUB_REMOTE")" = "$NEWHEAD" ] && ok "publish: ignores a planted pre-push hook" || bad "publish: ran a planted pre-push hook"

bundled; mkdir -p "$C/evilhooks"; printf '#!/bin/sh\necho ran >> "%s"\n' "$C/marker" > "$C/evilhooks/pre-push"; chmod +x "$C/evilhooks/pre-push"
git -C "$W/repo" config core.hooksPath "$C/evilhooks"
publish
[ ! -e "$C/marker" ] && [ "$(remote_ref "$STUB_REMOTE")" = "$NEWHEAD" ] && ok "publish: ignores planted core.hooksPath" || bad "publish: ran a hook from a planted core.hooksPath"

bundled; EVIL=$C/evil.git; git init -q --bare "$EVIL"; git -C "$W/repo" config "url.$EVIL.insteadOf" "$STUB_REMOTE"
publish
[ "$(remote_ref "$STUB_REMOTE")" = "$NEWHEAD" ] && [ -z "$(remote_ref "$EVIL")" ] && ok "publish: ignores a planted url.insteadOf" || bad "publish: redirected to $EVIL"

bundled; git -C "$W/repo" config uploadpack.packObjectsHook "touch $C/upload-marker"
publish
[ ! -e "$C/upload-marker" ] && [ "$(remote_ref "$STUB_REMOTE")" = "$NEWHEAD" ] && ok "publish: the fetch of the bundle ignores a planted uploadpack hook" || bad "publish: the fetch ran a planted uploadpack hook"

bundled; publish
if grep -rqF tok123 "$W/repo"; then bad "publish: token written to the checkout"; else ok "publish: token stays out of checkout config and files"; fi

bundled; printf 'not a bundle\n' > "$C/tmp/publish-bundle/publish.bundle"
if publish; then bad "publish: a corrupt bundle was accepted"; else [ -f "$W/Verify_the_bundle.sh" ] && [ -z "$(remote_ref "$STUB_REMOTE")" ] && ok "publish: a corrupt bundle is refused and nothing is pushed" || bad "publish: corrupt bundle pushed"; fi

bundled; U=$C/unrelated; git init -q -b main "$U"; git -C "$U" -c user.email=t@t -c user.name=t commit -q --allow-empty -m other
git -C "$U" bundle create "$C/tmp/publish-bundle/publish.bundle" HEAD > /dev/null 2>&1
if publish; then bad "publish: a bundle off the base was accepted"; else [ -f "$W/Verify_the_bundle.sh" ] && [ -z "$(remote_ref "$STUB_REMOTE")" ] && ok "publish: a bundle that does not extend the base is refused and nothing is pushed" || bad "publish: unrelated bundle pushed"; fi

# the executor's checkout is a depth-1 clone and the remote already holds the base history
pushcase; ORIGIN=$C/origin; mkdir -p "$ORIGIN"
( cd "$ORIGIN" && git init -q -b main && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m one \
  && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m two )
rm -rf "$STUB_REMOTE" "$W/repo"; git clone -q --bare "file://$ORIGIN" "$STUB_REMOTE"; git clone -q --depth 1 "file://$ORIGIN" "$W/repo"
[ "$(git -C "$W/repo" rev-parse --is-shallow-repository)" = true ] || bad "publish: the shallow fixture is not shallow"
FBASE=$(git -C "$W/repo" rev-parse HEAD)
git -C "$W/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m change
R1O=done R1V=pass R1F=/r1; final
mkdir -p "$C/tmp/publish-bundle"; mv "$C/tmp/bundle/publish.bundle" "$C/tmp/publish-bundle/"
NEWHEAD=$(git -C "$W/repo" rev-parse HEAD); git -C "$W/repo" checkout -q --detach "$FBASE"
publish
[ "$(remote_ref "$STUB_REMOTE")" = "$NEWHEAD" ] && ok "publish: pushes from a shallow checkout" || bad "publish: shallow checkout not pushed ($(sed -n 1,3p "$C/stdout"))"

echo "# pull request, findings"

prrun() { ( cd "$W/repo" && GH_TOKEN=x GITHUB_REPOSITORY=acme/app BRANCH=feat/13-x CTYPE=feat PLAN_URL=https://x/1 ISSUE=13 TITLE="Add A --Help Flag" DEFAULT_BRANCH=main ACTION="$1" VERDICT="$2" ROUNDS="$3" bash "$W/Open_the_pull_request.sh" > "$C/stdout" 2>&1 ); }
prrun pr pass 1
grep -q -- '--head feat/13-x --base main --title feat: add a --help flag --body-file' "$STUB_LOG" && ok "pr: head, base, lower-case conventional title" || bad "pr: $(grep 'gh pr' "$STUB_LOG")"
grep -q -- '--repo acme/app' "$STUB_LOG" && ok "pr: names the repository" || bad "pr: no --repo"
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
import sys, json, re, yaml
d = yaml.safe_load(open(sys.argv[1]))
rp = yaml.safe_load(open(sys.argv[2]))
wc = (d.get("on") or d.get(True))["workflow_call"]
jobs = d["jobs"]
rj = jobs["dev-execute"]                      # the rounds job
pj = jobs.get("dev-publish", {"steps": []})   # the publish job
rs, ps = rj["steps"], pj["steps"]
def emit(ok, name): print(("ok|" if ok else "bad|") + name)
uses = lambda s: str(s.get("uses", ""))
is_mint = lambda s: uses(s).startswith("actions/create-github-app-token@")
is_round = lambda s: uses(s).startswith("$/.github/actions/dev-round")
is_claude = lambda s: "claude-code-action" in uses(s)
mints = [s for s in ps if is_mint(s)]
mint = mints[0] if len(mints) == 1 else {}
ref = f"steps.{mint.get('id', '')}.outputs.token"
names = [s.get("name") for s in ps]
pos = lambda n: names.index(n) if n in names else -1
by_name = {s.get("name"): s for s in ps}
push_pr = ["Push the branch", "Open the pull request"]
outs = set(rj.get("outputs", {}))
others = {n: j for n, j in jobs.items() if n != "dev-publish"}
pcond = str(pj.get("if", ""))
uploads = [s for s in rs if uses(s).startswith("actions/upload-artifact@") and "publish-bundle" in str(s.get("with", {}).get("name", ""))]
downloads = [s for s in ps if uses(s).startswith("actions/download-artifact@")]
runs = [s.get("run", "") for s in ps]
refs = set(re.findall(r"needs\.dev-execute\.outputs\.(\w+)", json.dumps(ps)))

# job separation: the token is minted and used only by the publish job, which runs no round code
emit(len(mints) == 1 and not any(is_mint(s) for n in others.values() for s in n["steps"]),
     "app: the App token is minted once, in the publish job")
emit(not any(is_round(s) or is_claude(s) for s in ps)
     and not re.search(r"inputs\.(setup|check|test)_command|claude_code_oauth_token", json.dumps(ps)),
     "split: the publish job runs no round, model, setup, check or test step")
emit("executor_app_private_key" not in json.dumps(others),
     "split: the rounds job has no executor key and no App token step")
emit(rj.get("permissions") == {"contents": "read", "issues": "write"},
     "split: the rounds job holds contents read and issues write only")
emit(pj.get("needs") == "dev-execute" and "needs.dev-execute.outputs.action == 'pr'" in pcond
     and "needs.dev-execute.outputs.action == 'draft'" in pcond,
     "publish: needs the rounds job and runs only for a pr or draft action")
emit(pj.get("permissions") == {"contents": "read"}, "publish: contents read only")
emit(outs == {"action", "verdict", "rounds", "branch", "ctype", "plan_url"},
     "publish: the rounds job hands over only the scalar outputs")
emit(len(uploads) == 1 and len(downloads) == 1 and downloads[0].get("with", {}).get("name") == uploads[0]["with"]["name"],
     "publish: downloads only the bundle the rounds job uploads")
emit(refs <= outs and not re.search(r"needs\.(?!dev-execute\.outputs\.)", json.dumps(ps)),
     "publish: reads only the declared outputs of the rounds job")
emit(not any(re.search(r"\b(source|eval)\b|BASH_ENV|GITHUB_ENV|GITHUB_PATH", r) for r in runs),
     "publish: no step sources, evaluates or reads an environment file")
emit(0 <= pos("Verify the bundle") < pos("Mint the executor App token"),
     "publish: verifies the bundle before minting the token")

# the token: scope, use and pinning
emit(bool(mint.get("id")) and all(
    ref in str((by_name.get(n) or {}).get("env", {}).get("GH_TOKEN", "")) for n in push_pr),
    "app: push and PR take GH_TOKEN from the App token step")
w = mint.get("with", {})
scoped = {k: v for k, v in w.items() if k.startswith("permission-")}
emit(scoped == {"permission-contents": "write", "permission-pull-requests": "write",
                "permission-workflows": "write"},
     "app: token scope is contents, pull-requests and workflows write only")
users = sorted(s.get("name") for s in ps if s is not mint and ref in json.dumps(s))
emit(users == sorted(push_pr), "app: only the push and PR steps reference the token")
rp_pins = {s["uses"] for j in rp["jobs"].values() for s in j["steps"] if is_mint(s)}
emit(mint.get("uses") in rp_pins, "app: same pinned action as release-please")
emit(all(re.fullmatch(r"[^@]+@[0-9a-f]{40}", u) for u in
         [uses(s) for s in rs + ps if uses(s) and not uses(s).startswith(("$/", "./"))]),
     "pins: every action in the two jobs is pinned to a full commit SHA")
emit("executor_app_private_key" in wc.get("secrets", {})
     and wc["secrets"]["executor_app_private_key"].get("required") is True
     and wc.get("inputs", {}).get("executor_app_client_id", {}).get("required") is True,
     "app: workflow_call requires the executor App key and client id")
PY
while IFS='|' read -r r n; do [ "$r" = ok ] && ok || bad "$n"; done < "$W/app.out"

echo "# stages record"
python3 -I - "$ROOT" > "$W/stages.out" <<'PY'
import sys, os
root = sys.argv[1]
def emit(ok, name): print(("ok|" if ok else "bad|") + name)
path = os.path.join(root, "docs", "stages.md")
if not os.path.exists(path):
    for n in ("docs/stages.md exists", "every workflow has a row", "every row has an identity and permissions",
              "the executor App row names exactly contents, pull-requests and workflows",
              "states the rule for a stage that needs more than GITHUB_TOKEN"):
        emit(False, "stages: " + n)
    sys.exit(0)
text = open(path).read()
rows = []
for line in text.splitlines():
    if not line.lstrip().startswith("|"):
        continue
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if len(cells) >= 4 and cells[0].startswith("`") and cells[0].endswith("`"):
        rows.append(cells)
wf = sorted(f for f in os.listdir(os.path.join(root, ".github", "workflows"))
            if f.endswith(".yml") and not f.startswith("local-"))
listed = {r[0].strip("`") for r in rows}
emit(True, "stages: docs/stages.md exists")
emit(not [f for f in wf if f not in listed], "stages: every workflow has a row")
emit(bool(rows) and all(r[2] and r[3] for r in rows), "stages: every row has an identity and permissions")
ex = [r for r in rows if "executor App" in r[2]]
perms = sorted(p.split()[0] for p in ex[0][3].split(",")) if len(ex) == 1 else None
emit(perms == ["contents", "pull-requests", "workflows"],
     "stages: the executor App row names exactly contents, pull-requests and workflows")
emit("its own strict App" in text, "stages: states the rule for a stage that needs more than GITHUB_TOKEN")
PY
while IFS='|' read -r r n; do [ "$r" = ok ] && ok || bad "$n"; done < "$W/stages.out"

summary
