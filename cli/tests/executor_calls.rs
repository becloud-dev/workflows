//! The round's agent calls against the stub `claude`: where they run, what they may use, what they
//! read, and what they hand to the later steps (the structured output and the run record).

mod common;

use becloud_workflows::executor::calls::{self, Round};
use common::{Answer, Stubs};
use serde_json::json;
use std::path::{Path, PathBuf};

struct Fixture {
    stubs: Stubs,
    repo: tempfile::TempDir,
    work: tempfile::TempDir,
    plan: PathBuf,
}

fn fixture(answers: &[Answer]) -> Fixture {
    let repo = tempfile::tempdir().unwrap();
    let work = tempfile::tempdir().unwrap();
    let plan = work.path().join("plan.md");
    std::fs::write(&plan, "<!-- dev-plan -->\n**Files**\n- `src/a.rs`\n").unwrap();
    Fixture {
        stubs: Stubs::new().claude_answers(answers),
        repo,
        work,
        plan,
    }
}

impl Fixture {
    fn round(&self) -> Round<'_> {
        Round {
            repo: "o/r",
            issue: "13",
            round: "2",
            model: "claude-haiku-5-5",
            repo_dir: self.repo.path(),
            work_dir: self.work.path(),
        }
    }
    fn output(&self) -> PathBuf {
        self.work.path().join("github-output")
    }
    fn arg_after(&self, flag: &str) -> String {
        let a = self.stubs.args(1);
        a[a.iter().position(|x| x == flag).unwrap() + 1].clone()
    }
}

fn canonical(p: &Path) -> String {
    p.canonicalize().unwrap().display().to_string()
}

#[test]
fn the_executor_runs_in_the_checkout_with_its_commands_and_reads_copies_of_its_inputs() {
    let done = json!({"outcome": "done", "summary": "s", "red_seen": true, "commits": ["abc"]});
    let f = fixture(&[Answer::Output(done.clone())]);
    let findings = f.work.path().join("round-1-findings.md");
    std::fs::write(&findings, "Round 1 check findings:\n").unwrap();
    let ok = calls::execute(
        &f.stubs.agent(),
        &f.round(),
        &f.plan,
        &findings.display().to_string(),
        "npm run check",
        "npm test",
        &[],
        &f.output(),
    )
    .unwrap();
    assert!(ok);
    assert_eq!(f.stubs.recorded(1, "cwd").trim(), canonical(f.repo.path()));
    assert_eq!(f.arg_after("--tools"), "Read,Edit,Write,Grep,Glob,Bash");
    let allow = f.arg_after("--allowedTools");
    assert!(
        allow.ends_with("Bash(git rm:*),Bash(npm run check:*),Bash(npm test:*)"),
        "{allow}"
    );
    // the inputs are copies in an added directory, not the files the later steps read
    let inputs = f.arg_after("--add-dir");
    assert_eq!(
        inputs,
        canonical(&f.work.path().join("agent-inputs-execute-r2"))
    );
    let prompt = f.arg_after("-p");
    assert!(
        prompt.contains(&format!("Plan file: {inputs}/plan.md\n")),
        "{prompt}"
    );
    assert!(prompt.contains(&format!("Findings file: {inputs}/findings.md\n")));
    assert!(prompt.contains("Test command: npm test\n"));
    assert!(prompt.contains("# Development execution"));
    assert!(Path::new(&inputs).join("findings.md").exists());
    // no token but the model's own reaches the executor
    let env = f.stubs.env_names(1);
    for secret in [
        "GH_TOKEN",
        "GITHUB_TOKEN",
        "ACTIONS_RUNTIME_TOKEN",
        "BASH_ENV",
    ] {
        assert!(
            !env.contains(&secret.to_string()),
            "{secret} reached the agent"
        );
    }
    let out = std::fs::read_to_string(f.output()).unwrap();
    assert_eq!(out, format!("structured_output={done}\n"));
    assert!(
        f.work
            .path()
            .join("run-record-dev-execute-r2.json")
            .exists()
    );
}

#[test]
fn a_first_round_has_no_findings_file() {
    let f = fixture(&[Answer::Output(
        json!({"outcome": "blocked", "summary": "s", "blocked_reason": "r"}),
    )]);
    assert!(
        calls::execute(
            &f.stubs.agent(),
            &f.round(),
            &f.plan,
            "none",
            "",
            "",
            &[],
            &f.output()
        )
        .unwrap()
    );
    assert!(f.arg_after("-p").contains("Findings file: none\n"));
    assert!(!f.arg_after("--allowedTools").contains("Bash(:*)"));
}

#[test]
fn a_command_that_could_widen_its_rule_stops_before_any_call() {
    let f = fixture(&[]);
    assert!(
        calls::execute(
            &f.stubs.agent(),
            &f.round(),
            &f.plan,
            "none",
            "",
            "npm test $X",
            &[],
            &f.output()
        )
        .is_err()
    );
    assert_eq!(f.stubs.claude_calls(), 0);
}

#[test]
fn the_check_reads_only_and_a_result_that_contradicts_itself_is_asked_again() {
    let contradicting = json!({"verdict": "fail", "summary": "s", "criteria": [{"criterion": 1, "met": true}], "findings": []});
    let pass = json!({"verdict": "pass", "summary": "s", "criteria": [{"criterion": 1, "met": true}], "findings": []});
    let f = fixture(&[Answer::Output(contradicting), Answer::Output(pass.clone())]);
    let results = f.work.path().join("round-2-results.md");
    std::fs::write(&results, "### check\nexit code: 0\n").unwrap();
    assert!(
        calls::check(
            &f.stubs.agent(),
            &f.round(),
            &f.plan,
            &results,
            "abc123",
            &[],
            &f.output()
        )
        .unwrap()
    );
    assert_eq!(f.arg_after("--tools"), "Read,Grep,Glob,Bash");
    assert_eq!(
        f.arg_after("--allowedTools"),
        "Read,Grep,Glob,Bash(git diff:*),Bash(git log:*)"
    );
    assert!(f.arg_after("-p").contains("Base: abc123\n"));
    assert_eq!(f.stubs.claude_calls(), 2);
    assert!(
        f.stubs
            .recorded(2, "args")
            .contains("a fail verdict needs at least one finding")
    );
    assert_eq!(
        std::fs::read_to_string(f.output()).unwrap(),
        format!("structured_output={pass}\n")
    );
}

#[test]
fn a_call_without_a_valid_result_writes_no_output_and_says_why() {
    let f = fixture(&[Answer::Exit(1, "boom")]);
    assert!(
        !calls::execute(
            &f.stubs.agent(),
            &f.round(),
            &f.plan,
            "none",
            "",
            "",
            &[],
            &f.output()
        )
        .unwrap()
    );
    assert!(!f.output().exists());
    let record: serde_json::Value = serde_json::from_slice(
        &std::fs::read(f.work.path().join("run-record-dev-execute-r2.json")).unwrap(),
    )
    .unwrap();
    assert_eq!(record["ok"], false);
}
