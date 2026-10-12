#!/usr/bin/env bash
# site-ci.yml and site-e2e.yml, the reusable site workflows: check.py enforces their rules on the real files and fails on a broken copy of each.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
CI=$ROOT/.github/workflows/site-ci.yml
E2E=$ROOT/.github/workflows/site-e2e.yml

# broke <file> <case> <rule> <sed expression>: one edit of the file must change it, and check.py must fail naming the rule.
broke() {
  local name copy out rc
  name=$(basename "$1" .yml)
  copy=$WORK/$name-$2.yml
  sed "$4" "$1" > "$copy" || { bad "$name $2: cannot edit $1"; return; }
  cmp -s "$1" "$copy" && { bad "$name $2: the edit did not change the file"; return; }
  out=$(python3 -I check.py "$copy"); rc=$?
  [ "$rc" != 0 ] && printf '%s\n' "$out" | grep -q "$3" && ok || bad "$name $2: check.py did not report $3"
}

# The rules both site workflows share: the real file passes, and each deliberate break fails naming its rule.
shared() {
  local site=$1 name out rc
  name=$(basename "$site")
  out=$(python3 -I check.py "$site"); rc=$?
  [ "$rc" = 0 ] && ok || bad "real $name: $out"
  broke "$site" trigger only-workflow-call 's/^  workflow_call:$/  pull_request:\n  workflow_call:/'
  broke "$site" top-level-removed top-level-permissions '/^permissions: {}$/d'
  broke "$site" top-level-scope top-level-permissions 's/^permissions: {}$/permissions:\n  contents: read/'
  broke "$site" job-permissions job-permissions '/^    permissions:$/,/contents: read/d'
  broke "$site" pinned-uses pinned-uses 's/@3d3c42e5aac5ba805825da76410c181273ba90b1/@v7/'
  broke "$site" checkout-removed checkout-credentials '/persist-credentials: false/d'
  broke "$site" checkout-true checkout-credentials 's/persist-credentials: false/persist-credentials: true/'
  broke "$site" expression-in-run expression-in-run 's/^        run: npm ci$/        run: echo "${{ inputs.check_command }}"/'
  broke "$site" github-env-write github-path-env 's/^        run: npm ci$/        run: echo "x=1" >> "$GITHUB_ENV"/'
  broke "$site" github-path-write github-path-env 's/^        run: npm ci$/        run: echo "$PWD" >> "$GITHUB_PATH"/'
  broke "$site" secrets-reference secrets-reference 's/cache: npm/cache: npm\n          token: ${{ secrets.TOKEN }}/'
}
shared "$CI"
shared "$E2E"

# The site-ci.yml inputs, job and steps in the order the plan states, read from the real file.
python3 -I - "$CI" > "$WORK/shape.txt" 2>&1 <<'PY'
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

# site-e2e.yml only: the browsers and e2e_command inputs reach the shell through env, the browsers value is
# validated before the browsers are installed, and the report is uploaded on failure.
broke "$E2E" browsers-validation-loosened browsers-validation 's|\^\[a-z\]+( \[a-z\]+)\*\$|^[a-z ]*$|'
broke "$E2E" browsers-validation-removed browsers-validation "s/^\( *\)printf '%s' .*grep -Ezq.*\$/\1true/"
broke "$E2E" browsers-inline expression-in-run 's/run: npx playwright install --with-deps \$BROWSERS/run: npx playwright install --with-deps ${{ inputs.browsers }}/'
broke "$E2E" e2e-command-inline expression-in-run 's/run: bash -c "\$E2E"/run: bash -c "${{ inputs.e2e_command }}"/'
broke "$E2E" e2e-command-env input-env 's/E2E: \${{ inputs.e2e_command }}/E2E: x/'
broke "$E2E" retention-removed upload-artifact '/retention-days: 14/d'
broke "$E2E" retention-changed upload-artifact 's/retention-days: 14/retention-days: 7/'
broke "$E2E" no-files-removed upload-artifact '/if-no-files-found: ignore/d'
broke "$E2E" upload-always upload-artifact 's/if: failure()/if: always()/'
broke "$E2E" upload-unpinned pinned-uses 's/actions\/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9/actions\/upload-artifact@v7/'

# The site-e2e.yml inputs, job and steps in the order the plan states, read from the real file.
python3 -I - "$E2E" > "$WORK/e2e-shape.txt" 2>&1 <<'PY'
import sys, yaml
path = sys.argv[1]
text = open(path).read()
d = yaml.safe_load(open(path))
on = d.get("on", d.get(True))
inp = on["workflow_call"]["inputs"]
job = d["jobs"]["e2e"]
steps = job["steps"]
errs = []
want = {"node_version": "24", "browsers": "chromium webkit", "e2e_command": "npm run e2e"}
if set(inp) != set(want): errs.append("input set")
for k, v in want.items():
    spec = inp.get(k) or {}
    if spec.get("default") != v or spec.get("type") != "string": errs.append(f"{k} input")
if job.get("timeout-minutes") != 30 or job.get("permissions") != {"contents": "read"} or job.get("runs-on") != "ubuntu-latest": errs.append("job settings")
for pin in ["actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1",
            "actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0",
            "actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2"]:
    if pin not in text: errs.append(f"pin {pin}")
if len(steps) != 8: errs.append("step count")
else:
    if not (steps[0].get("uses", "").startswith("actions/checkout@") and steps[0].get("with") == {"persist-credentials": False}): errs.append("checkout step")
    if not (steps[1].get("uses", "").startswith("actions/setup-node@") and steps[1].get("with") == {"node-version": "${{ inputs.node_version }}", "cache": "npm"}): errs.append("setup-node step")
    if steps[2].get("run") != "npm ci": errs.append("npm ci step")
    if steps[3].get("uses") != "$/.github/actions/install-zola": errs.append("install-zola step")
    if "^[a-z]+( [a-z]+)*$" not in steps[4].get("run", "") or steps[4].get("env") != {"BROWSERS": "${{ inputs.browsers }}"}: errs.append("browsers validation step")
    if steps[5].get("env") != {"BROWSERS": "${{ inputs.browsers }}"} or steps[5].get("run") != "npx playwright install --with-deps $BROWSERS": errs.append("playwright install step")
    if steps[6].get("env") != {"E2E": "${{ inputs.e2e_command }}"} or steps[6].get("run") != 'bash -c "$E2E"': errs.append("e2e command step")
    up = steps[7]
    if up.get("if") != "failure()" or up.get("uses") != "actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9" or up.get("with") != {"name": "playwright-report", "path": "playwright-report/", "retention-days": 14, "if-no-files-found": "ignore"}: errs.append("upload step")
print("; ".join(errs))
sys.exit(1 if errs else 0)
PY
src=$?
[ "$src" = 0 ] && ok || bad "site-e2e.yml inputs, job or steps: $(cat "$WORK/e2e-shape.txt")"
summary
