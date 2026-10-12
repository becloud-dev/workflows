#!/usr/bin/env bash
# site-ci.yml, site-e2e.yml and pr-title.yml, the reusable site workflows, and site-deploy.yml: check.py enforces their
# rules on the real files and fails on a broken copy of each.
. "$(dirname "$0")/../lib.sh"
cd "$(dirname "$0")"
CI=$ROOT/.github/workflows/site-ci.yml
E2E=$ROOT/.github/workflows/site-e2e.yml
PRT=$ROOT/.github/workflows/pr-title.yml
DEPLOY=$ROOT/.github/workflows/site-deploy.yml

# broke <file> <case> <rule> <sed expression>: one edit of the file must change it, and check.py must fail naming the rule.
# The copy keeps the file name, because check.py picks its rules by it.
broke() {
  local name copy out rc
  name=$(basename "$1" .yml)
  copy=$WORK/$2/$(basename "$1")
  mkdir -p "$WORK/$2"
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

# pr-title.yml only: the real file passes, each rule is shown failing on a broken copy, and the inputs, job and step
# have the stated shape. Its step has no run: block, so the broken copies add a run: step before the action step.
out=$(python3 -I check.py "$PRT"); rc=$?
[ "$rc" = 0 ] && ok || bad "real pr-title.yml: $out"
broke "$PRT" trigger only-workflow-call 's/^  workflow_call:$/  pull_request:\n  workflow_call:/'
broke "$PRT" top-level-removed top-level-permissions '/^permissions: {}$/d'
broke "$PRT" top-level-scope top-level-permissions 's/^permissions: {}$/permissions:\n  contents: read/'
broke "$PRT" job-permissions job-permissions '/^    permissions:$/,/pull-requests: read/d'
broke "$PRT" pinned-uses pinned-uses 's/@48f256284bd46cdaab1048c3721360e808335d50/@v6/'
broke "$PRT" expression-in-run expression-in-run 's/^    steps:$/    steps:\n      - name: x\n        run: echo "${{ inputs.types }}"/'
broke "$PRT" github-env-write github-path-env 's/^    steps:$/    steps:\n      - name: x\n        run: echo "x=1" >> "$GITHUB_ENV"/'
broke "$PRT" github-path-write github-path-env 's/^    steps:$/    steps:\n      - name: x\n        run: echo "$PWD" >> "$GITHUB_PATH"/'
broke "$PRT" secrets-reference secrets-reference 's/GITHUB_TOKEN: \${{ github\.token }}/GITHUB_TOKEN: ${{ secrets.TOKEN }}/'

python3 -I - "$PRT" > "$WORK/prt-shape.txt" 2>&1 <<'PY'
import sys, yaml
path = sys.argv[1]
text = open(path).read()
d = yaml.safe_load(open(path))
on = d.get("on", d.get(True))
inp = on["workflow_call"]["inputs"]
job = d["jobs"]["title"]
steps = job["steps"]
errs = []
if set(inp) != {"types", "scopes"}: errs.append("input set")
types = inp.get("types") or {}
if types.get("type") != "string" or types.get("default", "").splitlines() != ["build", "chore", "ci", "docs", "feat", "fix", "perf", "refactor", "revert", "style", "test"]: errs.append("types input")
scopes = inp.get("scopes") or {}
if scopes.get("type") != "string" or scopes.get("default") != "[a-z0-9-]+": errs.append("scopes input")
if len(d["jobs"]) != 1 or job.get("permissions") != {"pull-requests": "read"} or job.get("runs-on") != "ubuntu-latest" or not isinstance(job.get("timeout-minutes"), int): errs.append("job settings")
if "amannn/action-semantic-pull-request@48f256284bd46cdaab1048c3721360e808335d50 # v6.1.1" not in text: errs.append("pinned action comment")
if len(steps) != 1: errs.append("step count")
else:
    s = steps[0]
    if s.get("uses") != "amannn/action-semantic-pull-request@48f256284bd46cdaab1048c3721360e808335d50" or s.get("with") != {"types": "${{ inputs.types }}", "scopes": "${{ inputs.scopes }}"} or s.get("env") != {"GITHUB_TOKEN": "${{ github.token }}"} or "run" in s: errs.append("action step")
print("; ".join(errs))
sys.exit(1 if errs else 0)
PY
src=$?
[ "$src" = 0 ] && ok || bad "pr-title.yml inputs, job or step: $(cat "$WORK/prt-shape.txt")"

# site-deploy.yml only: the real file passes the shared rules and the deploy rules, and each break fails naming its rule.
out=$(python3 -I check.py "$DEPLOY"); rc=$?
[ "$rc" = 0 ] && ok || bad "real site-deploy.yml: $out"
broke "$DEPLOY" trigger only-workflow-call 's/^  workflow_call:$/  pull_request:\n  workflow_call:/'
broke "$DEPLOY" top-level-removed top-level-permissions '/^permissions: {}$/d'
broke "$DEPLOY" top-level-scope top-level-permissions 's/^permissions: {}$/permissions:\n  contents: read/'
broke "$DEPLOY" job-permissions job-permissions '/^    permissions:$/{N;/contents: read/d}'
broke "$DEPLOY" deploy-permissions deploy-permissions 's/^      contents: read/      contents: write/'
broke "$DEPLOY" pinned-uses pinned-uses 's/@3d3c42e5aac5ba805825da76410c181273ba90b1/@v7/'
broke "$DEPLOY" checkout-removed checkout-credentials '/persist-credentials: false/d'
broke "$DEPLOY" checkout-true checkout-credentials 's/persist-credentials: false/persist-credentials: true/'
broke "$DEPLOY" expression-in-run expression-in-run 's/^        run: npm ci$/        run: echo "${{ inputs.check_command }}"/'
broke "$DEPLOY" github-env-write github-path-env 's/^        run: npm ci$/        run: echo "x=1" >> "$GITHUB_ENV"/'
broke "$DEPLOY" github-path-write github-path-env 's/^        run: npm ci$/        run: echo "$PWD" >> "$GITHUB_PATH"/'
broke "$DEPLOY" deploy-needs-removed deploy-needs '/^    needs: blockers$/d'
broke "$DEPLOY" concurrency-removed deploy-concurrency '/^    concurrency:$/,/cancel-in-progress/d'
broke "$DEPLOY" concurrency-cancel deploy-concurrency 's/cancel-in-progress: false/cancel-in-progress: true/'
broke "$DEPLOY" setup-node-cache-added setup-node-cache 's/^          package-manager-cache: false$/          package-manager-cache: false\n          cache: npm/'
broke "$DEPLOY" setup-node-cache-removed setup-node-cache '/^          package-manager-cache: false$/d'
broke "$DEPLOY" secret-in-run secrets-scope 's/^        run: npm ci$/        run: echo "${{ secrets.cloudflare_api_token }}"/'
broke "$DEPLOY" secret-in-check-env secrets-scope 's/^          CHECK: \${{ inputs.check_command }}$/          CHECK: ${{ inputs.check_command }}\n          TOKEN: ${{ secrets.cloudflare_api_token }}/'

# The site-deploy.yml inputs, secrets, jobs and steps in the order the plan states, read from the real file.
python3 -I - "$DEPLOY" > "$WORK/deploy-shape.txt" 2>&1 <<'PY'
import sys, yaml
path = sys.argv[1]
d = yaml.safe_load(open(path))
on = d.get("on", d.get(True))
wc = on["workflow_call"]
inp = wc["inputs"]
sec = wc.get("secrets") or {}
errs = []
if set(inp) != {"ref", "node_version", "check_command", "build_command"}: errs.append("input set")
if (inp.get("ref") or {}).get("type") != "string" or (inp.get("ref") or {}).get("required") is not True or "default" in (inp.get("ref") or {}): errs.append("ref input")
for k, v in {"node_version": "24", "check_command": "npm run check", "build_command": "npm run build"}.items():
    spec = inp.get(k) or {}
    if spec.get("default") != v or spec.get("type") != "string": errs.append(f"{k} input")
if set(sec) != {"cloudflare_api_token", "cloudflare_account_id"} or any((sec[k] or {}).get("required") is not True for k in sec): errs.append("secrets")
if set(d["jobs"]) != {"blockers", "deploy"}: errs.append("job set")
blk = d["jobs"]["blockers"]
if blk.get("permissions") != {"issues": "read"} or blk.get("runs-on") != "ubuntu-latest" or blk.get("needs"): errs.append("blockers job settings")
bsteps = blk["steps"]
if len(bsteps) != 1 or bsteps[0].get("name") != "List the open release blockers" or bsteps[0].get("env") != {"GH_TOKEN": "${{ github.token }}", "GH_REPO": "${{ github.repository }}"}: errs.append("blockers step")
job = d["jobs"]["deploy"]
if job.get("needs") != "blockers" or job.get("timeout-minutes") != 20 or job.get("permissions") != {"contents": "read"} or job.get("runs-on") != "ubuntu-latest": errs.append("deploy job settings")
if job.get("concurrency") != {"group": "deploy", "cancel-in-progress": False}: errs.append("deploy concurrency")
steps = job["steps"]
if len(steps) != 8: errs.append("step count")
else:
    if not (steps[0].get("uses", "").startswith("actions/checkout@") and steps[0].get("with") == {"ref": "${{ inputs.ref }}", "persist-credentials": False}): errs.append("checkout step")
    if not (steps[1].get("uses", "").startswith("actions/setup-node@") and steps[1].get("with") == {"node-version": "${{ inputs.node_version }}", "package-manager-cache": False}): errs.append("setup-node step")
    if steps[2].get("run") != "npm ci": errs.append("npm ci step")
    if steps[3].get("uses") != "$/.github/actions/install-zola": errs.append("install-zola step")
    if steps[4].get("env") != {"CHECK": "${{ inputs.check_command }}"} or steps[4].get("run") != 'bash -c "$CHECK"': errs.append("check step")
    if steps[5].get("env") != {"BUILD": "${{ inputs.build_command }}"} or steps[5].get("run") != 'bash -c "$BUILD"': errs.append("build step")
    g = steps[6]
    if g.get("name") != "Require the Cloudflare credentials" or g.get("env") != {"CLOUDFLARE_API_TOKEN": "${{ secrets.cloudflare_api_token }}", "CLOUDFLARE_ACCOUNT_ID": "${{ secrets.cloudflare_account_id }}"}: errs.append("guard step")
    w = steps[7]
    if w.get("uses") != "cloudflare/wrangler-action@953926a2e2182532811c01a25e53647d93bf07c0" or w.get("with") != {"command": "deploy", "apiToken": "${{ secrets.cloudflare_api_token }}", "accountId": "${{ secrets.cloudflare_account_id }}"}: errs.append("wrangler step")
print("; ".join(errs))
sys.exit(1 if errs else 0)
PY
src=$?
[ "$src" = 0 ] && ok || bad "site-deploy.yml inputs, secrets, jobs or steps: $(cat "$WORK/deploy-shape.txt")"

# The blockers and credentials-guard run blocks, extracted from the real file and run with the stub gh (bin/gh, copied
# out and made executable here) and a temp GITHUB_STEP_SUMMARY, so no network is needed.
S=$WORK/deploy; mkdir -p "$S/bin"
cp bin/gh "$S/bin/gh"; chmod +x "$S/bin/gh"
extract_step "$DEPLOY" blockers "List the open release blockers" "$S/blockers.sh"
extract_step "$DEPLOY" deploy "Require the Cloudflare credentials" "$S/guard.sh"

# run_blockers <issues json>: the blockers step against a fixture of open issues; sets rc and writes $S/summary.md
run_blockers() {
  printf '%s' "$1" > "$S/issues.json"; : > "$S/summary.md"
  (export PATH="$S/bin:$PATH" GH_ISSUES="$S/issues.json" GH_TOKEN=test GH_REPO=becloud-dev/workflows GITHUB_STEP_SUMMARY="$S/summary.md"; bash "$S/blockers.sh") > "$S/blockers.log" 2>&1
  rc=$?
}
run_blockers '[]'
[ "$rc" = 0 ] && [ ! -s "$S/summary.md" ] && ok || bad "blockers, none open: exit $rc, summary: $(cat "$S/summary.md")"
run_blockers '[{"number":12,"title":"Checkout fails"},{"number":15,"title":"Empty cart"}]'
[ "$rc" != 0 ] && grep -qF -- "#12 Checkout fails" "$S/summary.md" && grep -qF -- "#15 Empty cart" "$S/summary.md" && ok || bad "blockers, two open: exit $rc, summary: $(cat "$S/summary.md")"

# run_guard <token> <account>: the credentials guard with the two secrets as env values; sets rc
run_guard() {
  (export CLOUDFLARE_API_TOKEN="$1" CLOUDFLARE_ACCOUNT_ID="$2"; bash "$S/guard.sh") > "$S/guard.log" 2>&1
  rc=$?
}
run_guard token account
[ "$rc" = 0 ] && ok || bad "credentials guard, both set: exit $rc: $(cat "$S/guard.log")"
run_guard '' account
[ "$rc" != 0 ] && grep -qF -- "::error::" "$S/guard.log" && ok || bad "credentials guard, empty token: exit $rc, log: $(cat "$S/guard.log")"
run_guard token ''
[ "$rc" != 0 ] && grep -qF -- "::error::" "$S/guard.log" && ok || bad "credentials guard, empty account: exit $rc, log: $(cat "$S/guard.log")"
summary
