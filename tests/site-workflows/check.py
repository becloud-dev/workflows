import json, os, re, sys, yaml

# usage: check.py <site workflow file>
# Enforces the rules of the reusable site workflows: one FAIL line per violation, named by rule, and exit 1.
path = sys.argv[1]
doc = yaml.safe_load(open(path)) or {}
text = open(path).read()
bad = []
DEPLOY = os.path.basename(path) == "site-deploy.yml"
PIN = re.compile(r"[0-9a-f]{40}")
BROWSERS_CHECK = "^[a-z]+( [a-z]+)*$"
INPUT_ENV = {"BROWSERS": "${{ inputs.browsers }}", "E2E": "${{ inputs.e2e_command }}",
             "CHECK": "${{ inputs.check_command }}", "BUILD": "${{ inputs.build_command }}"}
GUARD, WRANGLER = "Require the Cloudflare credentials", "Deploy with Wrangler"

def fail(rule, detail): bad.append(f"FAIL  {rule}: {detail}")

def check_uses(where, uses):
    # Local actions of this repository are allowed; anything else must be pinned to a full commit SHA.
    if uses.startswith("$/"): return
    ref = uses.rsplit("@", 1)[-1] if "@" in uses else ""
    if not PIN.fullmatch(ref): fail("pinned-uses", f"{where} uses {uses}, not a 40-character SHA")

on = doc.get("on", doc.get(True))
events = {on} if isinstance(on, str) else set(on or [])
if events != {"workflow_call"}: fail("only-workflow-call", f"triggers are {sorted(events)}")
if "permissions" not in doc or doc["permissions"] != {}: fail("top-level-permissions", "must be {}")
# Only site-deploy.yml may refer to secrets; its uses are checked below. Every other site workflow must not.
if not DEPLOY and re.search(r"secrets\.", text): fail("secrets-reference", "the file refers to secrets.")
inputs = (((on if isinstance(on, dict) else {}).get("workflow_call") or {}).get("inputs")) or {}

steps = []
for jn, job in (doc.get("jobs") or {}).items():
    if "permissions" not in job: fail("job-permissions", f"job {jn} has no permissions")
    if "uses" in job: check_uses(jn, job["uses"])
    for i, step in enumerate(job.get("steps") or []):
        where = f"{jn}/{step.get('name', f'step {i + 1}')}"
        steps.append((where, step))
        uses = step.get("uses", "")
        if "uses" in step: check_uses(where, uses)
        if uses.startswith("actions/checkout@") and (step.get("with") or {}).get("persist-credentials") is not False:
            fail("checkout-credentials", f"{where} does not set persist-credentials: false")
        run = step.get("run", "")
        if "${{" in run: fail("expression-in-run", f"{where} has an expression in run:")
        if re.search(r"\bGITHUB_(PATH|ENV)\b", run): fail("github-path-env", f"{where} uses GITHUB_PATH or GITHUB_ENV")

# An input read by a run: block reaches the shell through the env of its step, with the input as the value.
for where, step in steps:
    run = step.get("run", "")
    env = step.get("env") or {}
    for name, expr in INPUT_ENV.items():
        if re.search(r"\$\{?" + name + r"\b", run) and env.get(name) != expr:
            fail("input-env", f"{where} reads ${name} without env {name}: {expr}")

# A browsers input is validated before the step that installs the browsers uses it.
if "browsers" in inputs:
    install = next((i for i, (w, s) in enumerate(steps) if "playwright install" in s.get("run", "")), None)
    checked = next((i for i, (w, s) in enumerate(steps)
                    if BROWSERS_CHECK in s.get("run", "") and (s.get("env") or {}).get("BROWSERS") == INPUT_ENV["BROWSERS"]), None)
    if install is None or checked is None or checked > install:
        fail("browsers-validation", f"the browsers input is not validated against {BROWSERS_CHECK} before playwright install")

# An uploaded Playwright report is kept 14 days and uploaded only when the run fails.
for where, step in steps:
    if step.get("uses", "").startswith("actions/upload-artifact@"):
        with_ = step.get("with") or {}
        if step.get("if") != "failure()" or with_.get("path") != "playwright-report/" or with_.get("retention-days") != 14 or with_.get("if-no-files-found") != "ignore":
            fail("upload-artifact", f"{where} must upload playwright-report/ on failure with retention-days 14 and if-no-files-found: ignore")

# site-deploy.yml only: a secret is read by the credentials guard or the Wrangler step, through its env or with, and
# nowhere else. The deploy job needs the blockers, runs one deploy at a time and never restores a cache.
if DEPLOY:
    reads = 0
    for where, step in steps:
        n = len(re.findall(r"secrets\.", json.dumps(step)))
        if not n: continue
        reads += n
        scoped = len(re.findall(r"secrets\.", json.dumps({k: step.get(k) for k in ("env", "with")})))
        if step.get("name") not in (GUARD, WRANGLER) or scoped != n:
            fail("secrets-scope", f"{where} reads a secret outside its env or with, or outside the guard and Wrangler steps")
    if reads != len(re.findall(r"secrets\.", text)): fail("secrets-scope", "a secret is read outside the steps")
    deploy = (doc.get("jobs") or {}).get("deploy") or {}
    needs = deploy.get("needs") or []
    if "blockers" not in ([needs] if isinstance(needs, str) else needs): fail("deploy-needs-blockers", "job deploy does not need blockers")
    if deploy.get("concurrency") != {"group": "deploy", "cancel-in-progress": False}:
        fail("concurrency", "job deploy is not in concurrency group deploy with cancel-in-progress false")
    for step in deploy.get("steps") or []:
        if step.get("uses", "").startswith("actions/setup-node@") and "cache" in (step.get("with") or {}):
            fail("setup-node-cache", f"job deploy sets up Node.js with a cache: {step.get('name')}")

for line in bad: print(line)
if not bad: print(f"OK    {path}")
sys.exit(1 if bad else 0)
