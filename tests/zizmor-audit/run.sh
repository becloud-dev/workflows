#!/usr/bin/env bash
# The zizmor job of ci.yml: the audit and the comparison steps against canned zizmor reports, the path
# filter in a scratch git repository, and the structure of the job.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
CI="$ROOT/.github/workflows/ci.yml"
extract_step "$CI" zizmor "Audit the base and head trees with zizmor" "$WORK/audit.sh"
extract_step "$CI" zizmor "Report the findings the pull request adds" "$WORK/compare.sh"
extract_step "$CI" zizmor "Check whether the pull request changes workflows or actions" "$WORK/scope.sh"

# A stub docker: the audit runs `docker run -v <tree>:/audit:ro <image> <zizmor args> /audit/<path>...`; the
# stub logs the arguments and prints the canned report of the tree (base or head), or fails when it has none.
# Like zizmor, it reads workflow files (workflows/*.yml) only under an audited directory named .github; the
# composite actions (*/action.yml) are always read. A finding whose file was not read is not reported.
mkdir -p "$WORK/bin" "$WORK/tmp" "$WORK/fixtures" "$WORK/ws/base" "$WORK/ws/head"
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
src=""; paths=(); args="$*"
while [ $# -gt 0 ]; do
  case $1 in
    -v) src=${2%%:/audit*}; shift ;;
    /audit*) p=${1#/audit}; paths+=("${p#/}") ;;
  esac
  shift
done
echo "docker $args" >> "$STUB_LOG"
[ -f "$FIXTURES/$(basename "$src").json" ] || exit 1
dirs=$(jq -nc --args '$ARGS.positional' "${paths[@]}")
jq -c --argjson dirs "$dirs" '[ .[] | .locations[0].symbolic.key.Local.given_path as $f
  | select(any($dirs[]; . as $d
      | ($d == "" or ($f | startswith($d + "/")))
        and (($f | contains("/workflows/") | not) or ((split("/") | last) == ".github"))))
]' "$FIXTURES/$(basename "$src").json"
STUB
chmod +x "$WORK/bin/docker"
export PATH="$WORK/bin:$PATH" FIXTURES="$WORK/fixtures" RUNNER_TEMP="$WORK/tmp" STUB_LOG="$WORK/docker.log"

# F <ident> <path> <annotation> <line> <feature>: one zizmor finding; arr <finding>...: a report
F() {
  jq -nc --arg i "$1" --arg p "$2" --arg a "$3" --argjson l "$4" --arg f "$5" '
    {ident:$i, desc:"d", url:"u", determinations:{confidence:"High", severity:"High", persona:"Regular"},
     locations:[{symbolic:{key:{Local:{given_path:$p, verbatim_path:$p}}, annotation:$a},
                 concrete:{location:{start_point:{row:$l, column:0}}, feature:$f}}], ignored:false, fixes:[]}'
}
arr() { printf '%s\n' "$@" | jq -sc .; }
PERM=$(F excessive-permissions .github/workflows/ci.yml "default permissions" 9 "permissions: write-all")
PERM2=$(F excessive-permissions .github/workflows/ci.yml "default permissions" 9 "permissions: write-all # edited")
U1=$(F unpinned-uses .github/workflows/ci.yml "action is not pinned to a hash" 24 "uses: actions/foo@v1")
U1_MOVED=$(F unpinned-uses .github/workflows/ci.yml "action is not pinned to a hash" 60 "uses: actions/foo@v1")
U1_SECOND=$(F unpinned-uses .github/workflows/ci.yml "action is not pinned to a hash" 70 "uses: actions/foo@v1")
ACT=$(F unpinned-uses .github/actions/x/action.yml "action is not pinned to a hash" 5 "uses: actions/bar@v1")
TPL=$(F excessive-permissions templates/consumer/.github/workflows/triage.yml "default permissions" 9 "permissions: write-all")

# compare_reports <base json> <head json>: the comparison step on two reports, sets RC and OUT
compare_reports() {
  printf '%s' "$1" > "$WORK/tmp/zizmor-base.json"; printf '%s' "$2" > "$WORK/tmp/zizmor-head.json"
  OUT=$(bash -eo pipefail "$WORK/compare.sh" 2>&1); RC=$?
}
# verdict <name> pass|fail: RC is 0 for pass, non-zero for fail
verdict() {
  if [ "$2" = pass ]; then [ "$RC" = 0 ] && ok || bad "$1: exit $RC: $OUT"
  else [ "$RC" != 0 ] && ok || bad "$1: exit 0, want non-zero"; fi
}

echo "# comparison"
compare_reports "$(arr "$PERM" "$U1")" "$(arr "$PERM" "$U1")"
verdict "head report equal to base report" pass

compare_reports "$(arr "$PERM")" "$(arr "$PERM" "$U1")"
verdict "head adds an unpinned-uses finding" fail
case "$OUT" in *unpinned-uses*.github/workflows/ci.yml*"uses: actions/foo@v1"*) ok ;;
  *) bad "new finding: rule, file and feature not all named ($OUT)" ;; esac

compare_reports "$(arr "$U1")" "$(arr "$U1_MOVED")"
verdict "same finding moved to another line" pass

compare_reports "$(arr "$PERM")" "$(arr "$PERM2")"
verdict "file edited, file-level finding unchanged" pass

compare_reports "$(arr "$U1")" "$(arr "$U1" "$U1_SECOND")"
verdict "second finding of an existing kind" fail
case "$OUT" in *unpinned-uses*) ok ;; *) bad "second finding: key not named ($OUT)" ;; esac

compare_reports "$(arr "$PERM" "$U1")" "$(arr "$PERM")"
verdict "head removes a finding" pass

compare_reports "[]" "[]"
verdict "no findings on either tree" pass

echo "# comparison fails closed"
compare_reports "$(arr "$PERM")" "$(arr "$PERM")"; rm -f "$WORK/tmp/zizmor-head.json"
OUT=$(bash -eo pipefail "$WORK/compare.sh" 2>&1); RC=$?
verdict "head report missing" fail
compare_reports "$(arr "$PERM")" ""
verdict "head report empty" fail
compare_reports "$(arr "$PERM")" "[{"
verdict "head report not valid JSON" fail
compare_reports "$(arr "$PERM")" '{"findings":[]}'
verdict "head report not an array" fail

echo "# audit"
set_reports() { printf '%s' "$1" > "$FIXTURES/base.json"; printf '%s' "$2" > "$FIXTURES/head.json"; }
set_reports "$(arr "$PERM")" "$(arr "$PERM" "$U1")"
: > "$STUB_LOG"
OUT=$(cd "$WORK/ws" && bash -eo pipefail "$WORK/audit.sh" 2>&1); RC=$?
verdict "audit of both trees" pass
for flag in --offline --persona=auditor --format=json --no-exit-codes; do
  grep -qF -- "$flag" "$STUB_LOG" && ok || bad "audit: flag $flag not passed to zizmor"
done
grep -qF 'ghcr.io/zizmorcore/zizmor:1.30.1@sha256:a2eb396d886c053073405c7a980f2139ba2248ec172243cfa3841e57196e8101' "$STUB_LOG" \
  && ok || bad "audit: image not pinned by version and digest"
[ -s "$WORK/tmp/zizmor-base.json" ] && [ -s "$WORK/tmp/zizmor-head.json" ] && ok || bad "audit: reports not written"
[ "$(grep -cE ' /audit/(\S+/)?\.github( |$)' "$STUB_LOG")" = 2 ] && ok || bad "audit: no .github path audited for both trees ($(cat "$STUB_LOG"))"
grep -q excessive-permissions "$WORK/tmp/zizmor-head.json" && ok || bad "audit: workflow file finding missing from the head report"
compare_reports "$(cat "$WORK/tmp/zizmor-base.json")" "$(cat "$WORK/tmp/zizmor-head.json")"
verdict "audit output compared: new finding fails" fail

echo "# audit scope"
set_reports "$(arr "$PERM" "$TPL")" "$(arr "$PERM" "$TPL")"
: > "$STUB_LOG"
OUT=$(cd "$WORK/ws" && bash -eo pipefail "$WORK/audit.sh" 2>&1); RC=$?
verdict "audit with consumer templates" pass
[ "$(grep -cE ' /audit/templates/consumer/\.github( |$)' "$STUB_LOG")" = 2 ] && ok || bad "audit: templates/consumer/.github not audited for both trees"
grep -q 'templates/consumer/.github/workflows/triage.yml' "$WORK/tmp/zizmor-head.json" && ok || bad "audit: template-only finding not in the head report"
set_reports "$(arr "$ACT")" "$(arr "$ACT" "$PERM")"
OUT=$(cd "$WORK/ws" && bash -eo pipefail "$WORK/audit.sh" 2>&1); RC=$?
verdict "audit of a workflow-only addition" pass
compare_reports "$(cat "$WORK/tmp/zizmor-base.json")" "$(cat "$WORK/tmp/zizmor-head.json")"
verdict "workflow-only addition fails the comparison" fail
case "$OUT" in *.github/workflows/ci.yml*) ok ;; *) bad "workflow-only addition: file not named ($OUT)" ;; esac

rm -f "$FIXTURES/head.json"
OUT=$(cd "$WORK/ws" && bash -eo pipefail "$WORK/audit.sh" 2>&1); RC=$?
verdict "audit with no head report fails" fail
set_reports "$(arr "$PERM")" ""
OUT=$(cd "$WORK/ws" && bash -eo pipefail "$WORK/audit.sh" 2>&1); RC=$?
verdict "audit with empty head report fails" fail

echo "# path filter"
WS=$WORK/scope; mkdir -p "$WS/head/.github/workflows" "$WS/head/.github/actions/x"
git -C "$WS/head" init -q
echo a > "$WS/head/README.md"; echo "on: push" > "$WS/head/.github/workflows/ci.yml"; echo "runs: {}" > "$WS/head/.github/actions/x/action.yml"
git -C "$WS/head" add -A; git -C "$WS/head" -c user.name=t -c user.email=t@example.com commit -qm base
BASE=$(git -C "$WS/head" rev-parse HEAD)
echo b >> "$WS/head/README.md"
git -C "$WS/head" add -A; git -C "$WS/head" -c user.name=t -c user.email=t@example.com commit -qm docs
DOCS=$(git -C "$WS/head" rev-parse HEAD)
echo b >> "$WS/head/.github/actions/x/action.yml"
git -C "$WS/head" add -A; git -C "$WS/head" -c user.name=t -c user.email=t@example.com commit -qm action
ACTION=$(git -C "$WS/head" rev-parse HEAD)
mkdir -p "$WS/head/templates/consumer/.github/workflows"; echo "on: push" > "$WS/head/templates/consumer/.github/workflows/t.yml"
git -C "$WS/head" add -A; git -C "$WS/head" -c user.name=t -c user.email=t@example.com commit -qm template
TEMPLATE=$(git -C "$WS/head" rev-parse HEAD)
scope() { # base head: the path filter in the scratch repository, sets RC and the output file
  : > "$WORK/gh_out"
  (cd "$WS" && BASE_SHA=$1 HEAD_SHA=$2 GITHUB_OUTPUT="$WORK/gh_out" bash -eo pipefail "$WORK/scope.sh"); RC=$?
}
scope "$BASE" "$DOCS"
[ "$RC" = 0 ] && grep -qx 'audit=false' "$WORK/gh_out" && ok || bad "path filter: PR outside .github/workflows and actions not skipped (exit $RC)"
scope "$BASE" "$ACTION"
[ "$RC" = 0 ] && grep -qx 'audit=true' "$WORK/gh_out" && ok || bad "path filter: PR changing an action not audited (exit $RC)"
scope "$ACTION" "$TEMPLATE"
[ "$RC" = 0 ] && grep -qx 'audit=true' "$WORK/gh_out" && ok || bad "path filter: PR changing only a consumer template not audited (exit $RC)"

echo "# structure"
if python3 - "$CI" <<'PY'
import re, sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
job = doc["jobs"].get("zizmor")
errs = []
if not job: sys.exit("no zizmor job")
on = doc.get(True, doc.get("on"))
if not (isinstance(on, dict) and "pull_request" in on): errs.append("not triggered on pull_request")
if job.get("permissions") != {"contents": "read"}: errs.append(f"permissions are {job.get('permissions')}, want contents: read only")
steps = job.get("steps", [])
for s in steps:
    if "uses" in s and not re.fullmatch(r"[\w.-]+/[\w./-]+@[0-9a-f]{40}", s["uses"]):
        errs.append(f"action not pinned by SHA: {s['uses']}")
    if s.get("uses", "").startswith("actions/checkout") and (s.get("with") or {}).get("persist-credentials") is not False:
        errs.append(f"checkout keeps credentials: {s.get('name')}")
    if "run" in s and re.search(r"\$\{\{\s*github\.", s["run"]):
        errs.append(f"github.* expression inside run: {s.get('name')}")
for s in steps:
    if s.get("name") in ("Audit the base and head trees with zizmor", "Report the findings the pull request adds"):
        if "steps.scope.outputs.audit" not in str(s.get("if", "")):
            errs.append(f"step not skipped when the PR changes nothing audited: {s['name']}")
audit = next((s for s in steps if s.get("name") == "Audit the base and head trees with zizmor"), None)
if audit is None: errs.append("no audit step")
else:
    run = audit.get("run", "")
    if '"$PWD/$tree:/audit:ro"' not in run: errs.append("audit step does not mount the tree root as /audit")
    if re.search(r"/\.github:/audit", run): errs.append("audit step mounts a .github directory")
    for p in ("/audit/.github", "/audit/templates/consumer/.github"):
        if re.search(re.escape(p) + r"(?=\s|$)", run) is None: errs.append(f"audit step does not audit {p}")
for e in errs: print(e, file=sys.stderr)
sys.exit(1 if errs else 0)
PY
then ok; else bad "structure: see the messages above"; fi

summary
