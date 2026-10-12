#!/usr/bin/env bash
# site-ci.yml, the reusable site check: check.py enforces its rules on the real file and fails on a broken copy of each.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
SITE=$ROOT/.github/workflows/site-ci.yml

out=$(python3 -I check.py "$SITE"); rc=$?
[ "$rc" = 0 ] && ok || bad "real site-ci.yml: $out"

# broke <case> <rule> <sed expression>: one edit of the real file must change it, and check.py must fail naming the rule.
broke() {
  local copy=$WORK/$1.yml out rc
  sed "$3" "$SITE" > "$copy" || { bad "$1: cannot edit $SITE"; return; }
  cmp -s "$SITE" "$copy" && { bad "$1: the edit did not change the file"; return; }
  out=$(python3 -I check.py "$copy"); rc=$?
  [ "$rc" != 0 ] && printf '%s\n' "$out" | grep -q "$2" && ok || bad "$1: check.py did not report $2"
}
broke trigger only-workflow-call 's/^  workflow_call:$/  pull_request:\n  workflow_call:/'
broke top-level-removed top-level-permissions '/^permissions: {}$/d'
broke top-level-scope top-level-permissions 's/^permissions: {}$/permissions:\n  contents: read/'
broke job-permissions job-permissions '/^    permissions:$/,/contents: read/d'
broke pinned-uses pinned-uses 's/@3d3c42e5aac5ba805825da76410c181273ba90b1/@v7/'
broke checkout-removed checkout-credentials '/persist-credentials: false/d'
broke checkout-true checkout-credentials 's/persist-credentials: false/persist-credentials: true/'
broke expression-in-run expression-in-run 's/^        run: npm ci$/        run: echo "${{ inputs.check_command }}"/'
broke github-env-write github-path-env 's/^        run: npm ci$/        run: echo "x=1" >> "$GITHUB_ENV"/'
broke github-path-write github-path-env 's/^        run: npm ci$/        run: echo "$PWD" >> "$GITHUB_PATH"/'
broke secrets-reference secrets-reference 's/cache: npm/cache: npm\n          token: ${{ secrets.TOKEN }}/'

# The inputs, the job and the steps in the order the plan states, read from the real file.
python3 -I - "$SITE" > "$WORK/shape.txt" 2>&1 <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
on = d.get("on", d.get(True))
inp = on["workflow_call"]["inputs"]
job = d["jobs"]["checks"]
steps = job["steps"]
errs = []
if inp["node_version"].get("default") != "24" or inp["node_version"].get("type") != "string": errs.append("node_version input")
if inp["check_command"].get("default") != "npm run check" or inp["check_command"].get("type") != "string": errs.append("check_command input")
if job.get("timeout-minutes") != 15 or job.get("permissions") != {"contents": "read"} or job.get("runs-on") != "ubuntu-latest": errs.append("job settings")
if len(steps) != 5: errs.append("step count")
else:
    if not (steps[0].get("uses", "").startswith("actions/checkout@") and steps[0].get("with") == {"persist-credentials": False}): errs.append("checkout step")
    if not (steps[1].get("uses", "").startswith("actions/setup-node@") and steps[1].get("with") == {"node-version": "${{ inputs.node_version }}", "cache": "npm"}): errs.append("setup-node step")
    if steps[2].get("run") != "npm ci": errs.append("npm ci step")
    if steps[3].get("uses") != "$/.github/actions/install-zola": errs.append("install-zola step")
    if steps[4].get("env") != {"CHECK": "${{ inputs.check_command }}"} or steps[4].get("run") != 'bash -c "$CHECK"': errs.append("check step")
print("; ".join(errs))
sys.exit(1 if errs else 0)
PY
src=$?
[ "$src" = 0 ] && ok || bad "site-ci.yml inputs, job or steps: $(cat "$WORK/shape.txt")"
summary
