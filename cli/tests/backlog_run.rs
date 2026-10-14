//! `wf planner backlog` end to end: the binary runs with the stub `gh` and `claude` first on PATH,
//! on the derived [`common::scenario`]: #69 is a parent, #59 is blocked by #57 in the same tier, #63
//! (High) by #56 (Medium), #21 has no type and #20 no priority.

mod common;

use becloud_workflows::planner::backlog;
use common::{Answer, REPO, Stubs, scenario};
use serde_json::{Value, json};
use std::process::Output;

/// The ranked set the scenario builds, in input order (by tier, then oldest first).
fn ranked() -> Vec<u64> {
    let stubs = Stubs::new().gh_answers(&scenario());
    let input = backlog::fetch(&stubs.gh(), REPO).unwrap();
    input.issues.iter().map(|i| i.number).collect()
}

fn order(numbers: &[u64]) -> Value {
    json!({
        "order": numbers.iter().map(|n| json!({"number": n, "reason": "quoted words"})).collect::<Vec<_>>(),
        "summary": "Ordered the backlog."
    })
}

fn no_duplicates() -> Value {
    json!({"duplicates": []})
}

fn run(stubs: &Stubs) -> (Output, std::path::PathBuf) {
    let out = stubs.path().join("out");
    let path = format!(
        "{}:{}",
        stubs.path().display(),
        std::env::var("PATH").unwrap()
    );
    let output = std::process::Command::new(env!("CARGO_BIN_EXE_wf"))
        .args([
            "planner",
            "backlog",
            "--repo",
            REPO,
            "--model",
            "claude-haiku-5-5",
            "--out",
        ])
        .arg(&out)
        .env_clear()
        .env("PATH", path)
        .env("HOME", std::env::var("HOME").unwrap())
        .env("GH_TOKEN", "secret-gh")
        .output()
        .unwrap();
    (output, out)
}

fn read(path: std::path::PathBuf) -> String {
    std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("{}: {e}", path.display()))
}

#[test]
fn a_valid_run_writes_the_report_the_summary_and_the_record() {
    let stubs = Stubs::new().gh_answers(&scenario()).claude_answers(&[
        Answer::Output(order(&ranked())),
        Answer::Output(no_duplicates()),
    ]);
    let (output, out) = run(&stubs);
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(stubs.claude_calls(), 2);

    let summary = read(out.join("summary.md"));
    for want in [
        "### Backlog order\n1. #53 [High]",
        "(blocked by #57): quoted words",
        "- #63 is blocked by #56: the blocker is Medium and the issue High; the tiers are triage's, not reordered.",
        "### Parents not ranked as work\n- #69 [Medium]",
        "open sub-issues #63, #65, #56, #59",
        "### Duplicates\nNone.",
        "### No type\n- #21 [Medium]",
        "### Unprioritised\n- #20 [no priority]",
        "13 open issues after the filters; 11 ranked. The claims in the issues are not verified",
    ] {
        assert!(summary.contains(want), "missing {want:?} in:\n{summary}");
    }

    let record: Value =
        serde_json::from_str(&read(out.join("run-record-planner-backlog.json"))).unwrap();
    assert_eq!(record["ok"], true);
    assert_eq!(record["auth"], "login");
    assert_eq!(record["calls"][0]["role"], "order");
    assert_eq!(record["calls"][1]["role"], "duplicates");
    assert_eq!(record["tokens"]["claude-haiku-5-5"]["output"], 2 * 453);

    let report: Value = serde_json::from_str(&read(out.join("backlog-report.json"))).unwrap();
    assert_eq!(report["order"]["order"].as_array().unwrap().len(), 11);

    // The order call reads its own input, and the duplicate call sees every issue in the input.
    assert_eq!(stubs.recorded(1, "files").trim(), "order-input.json");
    assert_eq!(stubs.recorded(2, "files").trim(), "duplicates-input.json");
    assert!(!stubs.env_names(1).contains(&"GH_TOKEN".to_string()));
}

#[test]
fn a_blocker_ranked_after_its_issue_is_named_and_fixed_in_the_retry() {
    let good = ranked();
    let mut bad = good.clone();
    let (a, b) = (
        bad.iter().position(|&n| n == 57).unwrap(),
        bad.iter().position(|&n| n == 59).unwrap(),
    );
    bad.swap(a, b);
    let stubs = Stubs::new().gh_answers(&scenario()).claude_answers(&[
        Answer::Output(order(&bad)),
        Answer::Output(order(&good)),
        Answer::Output(no_duplicates()),
    ]);
    let (output, _) = run(&stubs);
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(stubs.args(2)[1].contains(
        "- #59 is ranked before #57, which blocks it; in one tier a blocker comes first"
    ));
}

#[test]
fn a_parent_ranked_as_work_is_refused() {
    let mut with_parent = ranked();
    with_parent.push(69);
    let stubs = Stubs::new().gh_answers(&scenario()).claude_answers(&[
        Answer::Output(order(&with_parent)),
        Answer::Output(order(&ranked())),
        Answer::Output(no_duplicates()),
    ]);
    let (output, _) = run(&stubs);
    assert!(output.status.success());
    assert!(stubs.args(2)[1].contains("#69 has open sub-issues, so it is not ranked as work"));
}

#[test]
fn a_refused_call_fails_the_run_names_every_reason_and_still_records() {
    let bad = json!({"duplicates": [{"number": 999, "duplicate_of": 21, "evidence": "e"}]});
    let stubs = Stubs::new().gh_answers(&scenario()).claude_answers(&[
        Answer::Output(order(&ranked())),
        Answer::Output(bad.clone()),
        Answer::Output(bad),
    ]);
    let (output, out) = run(&stubs);
    assert!(!output.status.success());
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("refused after the retry: duplicates: #999 is not in the input"),
        "{stderr}"
    );
    let record: Value =
        serde_json::from_str(&read(out.join("run-record-planner-backlog.json"))).unwrap();
    assert_eq!(record["ok"], false);
    assert_eq!(record["calls"].as_array().unwrap().len(), 3);
    assert!(!out.join("summary.md").exists());
}

#[test]
fn a_failed_github_read_fails_before_any_agent_call() {
    let stubs = Stubs::new().claude_answers(&[Answer::Output(order(&ranked()))]);
    let (output, _) = run(&stubs);
    assert!(!output.status.success());
    assert!(String::from_utf8_lossy(&output.stderr).contains("HTTP 404"));
    assert_eq!(stubs.claude_calls(), 0);
}
