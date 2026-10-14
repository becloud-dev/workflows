//! `wf executor gate` end to end: the binary runs with the stub `gh` first on PATH. The issue and
//! comments are shaped like the REST objects the workflow reads; the plan is pinned by comment ID
//! and body hash.

mod common;

use becloud_workflows::executor::gate::sha256_hex;
use common::{REPO, Stubs};
use serde_json::{Value, json};
use std::path::PathBuf;
use std::process::Output;

const PLAN: &str = "<!-- dev-plan -->\n**Files**\n- `src/a.rs`\n";

fn issue() -> Value {
    json!({
        "number": 13, "title": "Add a --help flag", "user": {"login": "bentoluizv"},
        "labels": [{"name": "RELEASE"}], "type": {"name": "Feature"}
    })
}

fn comment(id: u64, login: &str, body: &str) -> Value {
    json!({"id": id, "user": {"login": login}, "body": body,
           "html_url": format!("https://github.com/{REPO}/issues/13#issuecomment-{id}")})
}

fn stubs(issue: &Value, comments: Vec<Value>) -> Stubs {
    Stubs::new()
        .gh_object(&format!("repos/{REPO}/issues/13"), issue)
        .gh_answers(&[(
            format!("repos/{REPO}/issues/13/comments?per_page=100"),
            comments,
        )])
}

fn run(stubs: &Stubs, body: &str) -> (Output, PathBuf, PathBuf) {
    let plan = stubs.path().join("plan.md");
    let outputs = stubs.path().join("github-output");
    let path = format!(
        "{}:{}",
        stubs.path().display(),
        std::env::var("PATH").unwrap()
    );
    let output = std::process::Command::new(env!("CARGO_BIN_EXE_wf"))
        .args([
            "executor",
            "gate",
            "--repo",
            REPO,
            "--issue",
            "13",
            "--owners",
            "bentoluizv",
        ])
        .arg("--plan-file")
        .arg(&plan)
        .arg("--github-output")
        .arg(&outputs)
        .env_clear()
        .env("PATH", path)
        .env("COMMENT_BODY", body)
        .output()
        .unwrap();
    (output, plan, outputs)
}

#[test]
fn an_approval_writes_the_plan_and_the_outputs_that_pin_it() {
    let stubs = stubs(&issue(), vec![comment(41, "github-actions[bot]", PLAN)]);
    let (out, plan, outputs) = run(&stubs, "/approve");
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(std::fs::read_to_string(plan).unwrap(), PLAN);
    let lines: Vec<String> = std::fs::read_to_string(outputs)
        .unwrap()
        .lines()
        .map(String::from)
        .collect();
    assert!(lines.contains(&"ok=true".to_string()));
    assert!(lines.contains(&"branch=feat/13-add-a-help-flag".to_string()));
    assert!(lines.contains(&"plan_comment_id=41".to_string()));
    assert!(lines.contains(&format!("plan_sha256={}", sha256_hex(PLAN))));
    assert!(
        stubs
            .gh_calls()
            .iter()
            .any(|c| c.contains("git/ref/heads/feat/13-add-a-help-flag"))
    );
}

#[test]
fn a_refused_approval_replies_on_the_issue_and_is_not_a_failure() {
    let mut i = issue();
    i["labels"] = json!([]);
    let stubs = stubs(&i, vec![comment(41, "github-actions[bot]", PLAN)]);
    let (out, _, outputs) = run(&stubs, "/approve");
    assert!(out.status.success());
    assert_eq!(std::fs::read_to_string(outputs).unwrap(), "ok=false\n");
    let post = stubs.post(1);
    assert!(post.contains(&format!("repos/{REPO}/issues/13/comments")));
    assert!(
        post.iter()
            .any(|a| a.starts_with("body=No execution: this issue does not carry `RELEASE`"))
    );
}

#[test]
fn a_lookalike_command_is_answered_without_reading_the_issue() {
    let stubs = Stubs::new();
    let (out, _, outputs) = run(&stubs, "/approved");
    assert!(out.status.success());
    assert_eq!(std::fs::read_to_string(outputs).unwrap(), "ok=false\n");
    assert!(
        stubs
            .post(1)
            .iter()
            .any(|a| a.contains("exactly `/approve`"))
    );
    assert_eq!(
        stubs.gh_calls().len(),
        1,
        "only the reply: {:?}",
        stubs.gh_calls()
    );
}
