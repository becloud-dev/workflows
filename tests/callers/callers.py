import sys, glob, os, yaml
T, W = sys.argv[1], sys.argv[2]   # template workflows dir, workflows repo root
LV = {"none": 0, "read": 1, "write": 2}
def on(d): return d.get("on", d.get(True))
def perms(p):
    if p is None: return {}
    if p in ("read-all",): return {"*": 1}
    if p in ("write-all",): return {"*": 2}
    return {k: LV[v] for k, v in p.items()}
bad = 0
for f in sorted(glob.glob(os.path.join(T, "*.yml"))):
    d = yaml.safe_load(open(f))
    for jn, j in d["jobs"].items():
        u = j.get("uses")
        if not u:
            print(f"skip   {os.path.basename(f)}:{jn} (inline job)"); continue
        ref = u.split("@")[0].replace("becloud-dev/workflows/", "")
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
        status = "OK    " if not errs else "FAIL  "
        print(f"{status}{os.path.basename(f)}:{jn} -> {ref}" + ("" if not errs else "  " + "; ".join(errs)))
        bad += bool(errs)
sys.exit(1 if bad else 0)
