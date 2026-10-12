import json, os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TIP = "a" * 40
OLD = "b" * 40
OWNERS = "owner1,owner2"
READY = "READY TO LIVE"


def pr(number=26, ref="release-please--branches--main", repo="o/r", labels=(READY,), sha="c" * 40):
    return {"number": number, "head": {"ref": ref, "sha": sha, "repo": {"full_name": repo}},
            "labels": [{"name": l} for l in labels]}


def ev(actor, label=READY, event="labeled"):
    return {"event": event, "label": {"name": label}, "actor": {"login": actor}}


def review(sha=TIP, line2=None, user="github-actions[bot]", node="IC_1", head="<!-- release-review -->", cid=1):
    l2 = f"<!-- release-review-sha: {sha} -->" if line2 is None else line2
    body = f"{head}\n{l2}\n## Release review: v0.1.1...{str(sha)[:7]}\n\nSummary\n"
    return {"id": cid, "user": {"login": user}, "node_id": node, "body": body}


GQ_UNEDITED = {"data": {"node": {"lastEditedAt": None, "editor": None}}}


def gq_edited(login):
    return {"data": {"node": {"lastEditedAt": "2026-10-12T14:00:00Z",
                              "editor": {"login": login} if login else None}}}


def case(name, expect, desc=(), prs=None, events=None, blockers=None, comments=None,
         gq=GQ_UNEDITED, gq_fail=False, event_pr="", nodesc=()):
    return dict(name=name, expect=expect, desc=desc, prs=prs if prs is not None else [pr()],
                events=events if events is not None else [ev("owner1")],
                blockers=blockers if blockers is not None else [], comments=comments or [],
                gq=gq, gq_fail=gq_fail, event_pr=event_pr, nodesc=nodesc)


CASES = [
    # existing behaviour (no review comment present)
    case("old: no open PR", None, prs=[]),
    case("old: non-release PR only", None, prs=[pr(ref="feature/x")]),
    case("old: release branch from a fork", None, prs=[pr(repo="evil/r")]),
    case("old: label missing", "failure", ["missing label"], prs=[pr(labels=())]),
    case("old: label by non-owner", "failure", ["not set by an owner"], events=[ev("mallory")]),
    case("old: no labeled event", "failure", ["not set by an owner"], events=[]),
    case("old: owner then non-owner (last wins)", "failure", ["not set by an owner"], events=[ev("owner1"), ev("mallory")]),
    case("old: non-owner then owner (last wins)", "success", events=[ev("mallory"), ev("owner2")]),
    case("old: ready, no blockers, no review", "success"),
    case("old: blocker open", "failure", ["open release-blocker: #27"], blockers=[{"number": 27}]),
    case("old: two blockers", "failure", ["#27, #28"], blockers=[{"number": 27}, {"number": 28}]),
    case("old: blocker list ignores PRs", "success", blockers=[{"number": 30, "pull_request": {}}]),
    case("old: label missing and blocker", "failure", ["missing label", "open release-blocker"], prs=[pr(labels=())], blockers=[{"number": 27}]),
    case("old: event PR other number", None, event_pr="99"),
    case("old: event PR this number", "success", event_pr="26"),
    # new behaviour
    case("new: review current, unedited", "success", comments=[review()]),
    case("new: review stale", "failure", [f"review is stale (reviewed {OLD[:7]}, main {TIP[:7]})"], comments=[review(sha=OLD)]),
    case("new: marker line 2 missing", "failure", ["review has no recorded sha"], comments=[review(line2="## no marker here")]),
    case("new: sha too short", "failure", ["review has no recorded sha"], comments=[review(line2="<!-- release-review-sha: aaaaaaa -->")]),
    case("new: sha uppercase", "failure", ["review has no recorded sha"], comments=[review(line2=f"<!-- release-review-sha: {'A'*40} -->")]),
    case("new: marker on line 3 only", "failure", ["review has no recorded sha"],
         comments=[{**review(), "body": f"<!-- release-review -->\n\n<!-- release-review-sha: {TIP} -->\n"}]),
    case("new: CRLF line 2 accepted", "success",
         comments=[{**review(), "body": f"<!-- release-review -->\r\n<!-- release-review-sha: {TIP} -->\r\n## x\r\n"}]),
    case("new: edited by owner", "success", comments=[review()], gq=gq_edited("owner2")),
    case("new: edited by non-owner", "failure", ["review edited by non-owner"], comments=[review()], gq=gq_edited("mallory")),
    case("new: edited, editor null", "failure", ["review editor unreadable"], comments=[review()], gq=gq_edited(None)),
    case("new: graphql call fails", "failure", ["review editor unreadable"], comments=[review()], gq_fail=True),
    case("new: graphql errors, node null", "failure", ["review editor unreadable"], comments=[review()],
         gq={"data": {"node": None}, "errors": [{"message": "x"}]}),
    case("new: stale and edited by non-owner", "failure", ["review is stale", "review edited by non-owner"],
         comments=[review(sha=OLD)], gq=gq_edited("mallory")),
    case("new: two reviews, last is current", "success", comments=[review(sha=OLD, cid=1), review(sha=TIP, cid=2)]),
    case("new: two reviews, last is stale", "failure", ["review is stale"], comments=[review(sha=TIP, cid=1), review(sha=OLD, cid=2)]),
    case("new: issues comment is not the review", "success",
         comments=[review(sha=TIP, cid=1), review(sha=OLD, cid=2, head="<!-- release-review-issues -->")]),
    case("new: finding marker is not the review", "success",
         comments=[review(sha=TIP, cid=1), review(sha=OLD, cid=2, head="<!-- release-review-finding:26:abc -->")]),
    case("new: human comment with the marker ignored", "success",
         comments=[review(sha=TIP, cid=1), review(sha=OLD, cid=2, user="mallory")]),
    case("new: review problems and label problem together", "failure", ["missing label", "review is stale"],
         prs=[pr(labels=())], comments=[review(sha=OLD)]),
    case("new: review stale and blocker", "failure", ["review is stale", "open release-blocker: #27"],
         comments=[review(sha=OLD)], blockers=[{"number": 27}]),
]


def run(script, c):
    d = tempfile.mkdtemp()
    try:
        def w(n, o): open(os.path.join(d, n), "w").write(json.dumps(o))
        w("pulls.json", c["prs"]); w("events.json", c["events"]); w("blockers.json", c["blockers"])
        w("comments.json", c["comments"]); w("graphql.json", c["gq"])
        w("repo.json", {"default_branch": "main"}); w("commit.json", {"sha": TIP})
        if c["gq_fail"]: open(os.path.join(d, "graphql.fail"), "w").close()
        env = {"PATH": f"{HERE}/bin:{os.environ.get('JQ_BIN_DIR', '')}:/usr/bin:/bin", "FX": d, "GITHUB_REPOSITORY": "o/r",
               "GITHUB_STEP_SUMMARY": os.path.join(d, "summary"), "GH_TOKEN": "x", "OWNERS": OWNERS,
               "READY": READY, "BLOCKER": "release-blocker", "EVENT_PR": c["event_pr"],
               "RUN_URL": "http://run"}
        p = subprocess.run(["bash", script], env=env, capture_output=True, text=True)
        posts = []
        pl = os.path.join(d, "posts.log")
        if os.path.exists(pl):
            for line in open(pl):
                parts = line.rstrip("\n").split("\x1f")
                path = parts[0]
                kv = dict(x.split("=", 1) for x in parts[1:] if "=" in x)
                posts.append((path, kv.get("state"), kv.get("description", "")))
        return p.returncode, posts, p.stderr
    finally:
        shutil.rmtree(d)


def check(script, verbose):
    bad = []
    for c in CASES:
        rc, posts, err = run(script, c)
        ok = rc == 0
        if c["expect"] is None:
            ok = ok and posts == []
        else:
            ok = ok and len(posts) == 1 and posts[0][1] == c["expect"] \
                and all(s in posts[0][2] for s in c["desc"]) and posts[0][0].endswith("/statuses/" + "c" * 40) \
                and len(posts[0][2]) <= 140
        if not ok:
            bad.append((c["name"], rc, posts, err.strip()[:200]))
        elif verbose:
            print("ok  ", c["name"], posts[0][1:] if posts else "(no status)")
    return bad


MUTATIONS = [
    ("compare dropped", 'elif [ "$reviewed" != "$tip" ]; then', 'elif false; then'),
    ("non-owner editor passes", 'problems+=("review edited by non-owner")', 'true'),
    ("missing sha treated as current", 'problems+=("review has no recorded sha")', 'true'),
    ("first review taken", "last // empty", "first // empty"),
    ("unedited treated as unreadable", 'elif .data.node.lastEditedAt == null then "unedited"',
     'elif .data.node.lastEditedAt == null then "unreadable"'),
    ("unreadable accepted", '(.data.node // null) == null then "unreadable"',
     '(.data.node // null) == null then "unedited"'),
    ("bot filter dropped", '.user.login == "github-actions[bot]"', 'true'),
    ("editor null accepted", '(.data.node.editor.login // "unreadable")', '(.data.node.editor.login // "unedited")'),
]

if __name__ == "__main__":
    # usage: driver.py <gate step script>; JQ_BIN_DIR names a directory with jq 1.7.1
    script = sys.argv[1]
    bad = check(script, False)
    print(f"cases: {len(CASES)} run, {len(bad)} failed")
    for b in bad:
        print("FAIL", b)
    src = open(script).read()
    survived = 0
    with tempfile.TemporaryDirectory() as td:
        for name, old, new in MUTATIONS:
            assert src.count(old) == 1, (name, src.count(old))
            m = os.path.join(td, "mut.sh")
            open(m, "w").write(src.replace(old, new))
            mb = check(m, False)
            print(f"mutation {name!r}: {'caught by ' + str(len(mb)) + ' case(s)' if mb else 'SURVIVED'}")
            survived += 0 if mb else 1
    sys.exit(1 if bad or survived else 0)
