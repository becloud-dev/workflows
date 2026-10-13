import sys, glob, os, shlex, yaml
# agent_calls.py ROOT: every claude-code-action step in ROOT's workflows and composite actions passes
# `--setting-sources user` exactly once in claude_args, so no call loads the project or local settings,
# hooks or CLAUDE.md of the checkout it runs in (#78).
root = sys.argv[1]
files = sorted(glob.glob(os.path.join(root, ".github", "workflows", "*.yml"))
               + glob.glob(os.path.join(root, ".github", "actions", "*", "action.yml")))
failed = 0
for f in files:
    doc = yaml.safe_load(open(f)) or {}
    if "runs" in doc:
        steps = [("-", s) for s in doc["runs"].get("steps", [])]
    else:
        steps = [(j, s) for j, job in (doc.get("jobs") or {}).items() for s in job.get("steps", [])]
    for job, step in steps:
        if not str(step.get("uses", "")).startswith("anthropics/claude-code-action@"):
            continue
        name = f"{os.path.relpath(f, root)} {job}/{step.get('id', step.get('name'))}"
        args = shlex.split(str((step.get("with") or {}).get("claude_args", "")))
        values = [args[i + 1] if i + 1 < len(args) else "" for i, a in enumerate(args) if a == "--setting-sources"]
        values += [a.split("=", 1)[1] for a in args if a.startswith("--setting-sources=")]
        if values == ["user"]:
            print(f"OK    {name}")
        else:
            failed += 1
            reason = "no --setting-sources" if not values else f"--setting-sources {values}, want exactly ['user']"
            print(f"FAIL  {name}: {reason}")
sys.exit(1 if failed else 0)
