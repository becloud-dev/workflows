import sys, glob, os, re, yaml
# --reasons DIR...: every entry of a permissions block carries a reason on its line (a `#` and text).
if sys.argv[1] == "--reasons":
    bad = []
    for d in sys.argv[2:]:
        for f in sorted(glob.glob(os.path.join(d, "**", "*.yml"), recursive=True)):
            lines = open(f).read().splitlines()
            for n, line in enumerate(lines):
                m = re.match(r"(\s*)permissions:\s*$", line)
                if not m: continue
                for k in range(n + 1, len(lines)):
                    e = lines[k]
                    if not e.strip() or e.strip().startswith("#"): continue
                    if len(e) - len(e.lstrip()) <= len(m.group(1)): break
                    if not re.search(r"#\s*\S", e): bad.append(f"{os.path.relpath(f, d)}:{k + 1} {e.strip()}")
    for b in bad: print(f"FAIL  permission without a reason: {b}")
    sys.exit(1 if bad else 0)
T, W = sys.argv[1], sys.argv[2]   # template workflows dir, workflows repo root
LV = {"none": 0, "read": 1, "write": 2}
NAME = {v: k for k, v in LV.items()}
def on(d): return d.get("on", d.get(True))
def perms(p):
    if p is None: return {}
    if p in ("read-all",): return {"*": 1}
    if p in ("write-all",): return {"*": 2}
    return {k: LV[v] for k, v in p.items()}
bad = 0
for f in sorted(glob.glob(os.path.join(T, "*.yml"))):
    d = yaml.safe_load(open(f))
    # Without a workflow-level block the default token permissions apply to every job of the caller.
    if "permissions" not in d:
        print(f"FAIL  {os.path.basename(f)}: no workflow-level permissions block"); bad += 1
    for jn, j in d["jobs"].items():
        u = j.get("uses")
        if not u:
            print(f"skip   {os.path.basename(f)}:{jn} (inline job)"); continue
        ref = u.split("@")[0].replace("becloud-dev/workflows/", "")
        for prefix in ("$/", "./"):  # same-repository forms
            if ref.startswith(prefix):
                ref = ref[len(prefix):]
        r = yaml.safe_load(open(os.path.join(W, ref)))
        wc = on(r)["workflow_call"]
        ins, secs = wc.get("inputs", {}) or {}, wc.get("secrets", {}) or {}
        w, s = j.get("with", {}) or {}, j.get("secrets", {}) or {}
        errs = []
        errs += [f"unknown input {k}" for k in w if k not in ins]
        errs += [f"required input {k} not passed" for k, v in ins.items() if v.get("required") and "default" not in v and k not in w]
        errs += [f"unknown secret {k}" for k in s if k not in secs]
        errs += [f"required secret {k} not passed" for k, v in secs.items() if v.get("required") and k not in s]
        need = {}
        for rj in r["jobs"].values():
            for k, lv in perms(rj.get("permissions")).items():
                need[k] = max(need.get(k, 0), lv)
        have = perms(j.get("permissions"))
        for k, lv in need.items():
            if have.get(k, have.get("*", 0)) < lv:
                errs.append(f"permission {k}: reusable needs {lv}, caller has {have.get(k, 0)}")
        for k, lv in have.items():
            if k != "*" and lv > need.get(k, 0):
                errs.append(f"permission {k}: caller grants {NAME[lv]}, reusable needs {NAME[need.get(k, 0)]}")
        status = "OK    " if not errs else "FAIL  "
        print(f"{status}{os.path.basename(f)}:{jn} -> {ref}" + ("" if not errs else "  " + "; ".join(errs)))
        bad += bool(errs)
sys.exit(1 if bad else 0)
