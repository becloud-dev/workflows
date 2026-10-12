import re, sys, yaml

# usage: check.py <site-ci workflow file>
# Enforces the rules of the reusable site check: one FAIL line per violation, named by rule, and exit 1.
path = sys.argv[1]
doc = yaml.safe_load(open(path)) or {}
text = open(path).read()
bad = []
PIN = re.compile(r"[0-9a-f]{40}")

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
if re.search(r"secrets\.", text): fail("secrets-reference", "the file refers to secrets.")

for jn, job in (doc.get("jobs") or {}).items():
    if "permissions" not in job: fail("job-permissions", f"job {jn} has no permissions")
    if "uses" in job: check_uses(jn, job["uses"])
    for i, step in enumerate(job.get("steps") or []):
        where = f"{jn}/{step.get('name', f'step {i + 1}')}"
        uses = step.get("uses", "")
        if "uses" in step: check_uses(where, uses)
        if uses.startswith("actions/checkout@") and (step.get("with") or {}).get("persist-credentials") is not False:
            fail("checkout-credentials", f"{where} does not set persist-credentials: false")
        run = step.get("run", "")
        if "${{" in run: fail("expression-in-run", f"{where} has an expression in run:")
        if re.search(r"\bGITHUB_(PATH|ENV)\b", run): fail("github-path-env", f"{where} uses GITHUB_PATH or GITHUB_ENV")

for line in bad: print(line)
if not bad: print(f"OK    {path}")
sys.exit(1 if bad else 0)
