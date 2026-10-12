import sys

import yaml

# usage: extract.py <yaml file> <job id | -> <step name or id> <out file>
path, job, wanted, out = sys.argv[1:5]
doc = yaml.safe_load(open(path))
steps = doc["runs"]["steps"] if job == "-" else doc["jobs"][job]["steps"]
for step in steps:
    if "run" in step and wanted in (step.get("name"), step.get("id")):
        open(out, "w").write(step["run"])
        sys.exit(0)
sys.exit(f"no run step named or identified {wanted!r} in {path}")
