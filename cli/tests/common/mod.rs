//! Shared by the integration tests: a scratch directory holding the stub `claude` and `gh`
//! (tests/bin) and their answers, and the recorded fixtures.
//!
//! `claude` answers: `recorded-order.json` is the output of a real `claude -p` 2.1.296 call with the
//! agent module's flags (Haiku 5.5, 2026-10-13). `derived-order-clean.json` cuts each order item to
//! `number` and `reason`; `derived-no-structured-output.json` removes `structured_output`;
//! [`Answer::Output`] puts another output into the recorded result.
//!
//! `gh` answers: real responses of becloud-dev/workflows recorded on 2026-10-13
//! (tests/fixtures/gh-recorded). They hold no open parent and no dependency, so [`scenario`]
//! derives those cases from the recorded objects and names each change.
#![allow(dead_code)]

use becloud_workflows::agent::Agent;
use becloud_workflows::github::Gh;
use serde_json::{Value, json};
use std::path::{Path, PathBuf};

pub const REPO: &str = "becloud-dev/workflows";
const DIR: &str = env!("CARGO_MANIFEST_DIR");

pub fn fixture(path: &str) -> Value {
    serde_json::from_slice(
        &std::fs::read(Path::new(DIR).join("tests/fixtures").join(path)).unwrap(),
    )
    .unwrap()
}

pub enum Answer {
    Fixture(&'static str),
    Output(Value),
    Exit(i32, &'static str),
}

pub struct Stubs {
    pub dir: tempfile::TempDir,
}

impl Stubs {
    pub fn new() -> Self {
        let dir = tempfile::tempdir().unwrap();
        for name in ["claude", "gh"] {
            std::fs::copy(
                Path::new(DIR).join("tests/bin").join(name),
                dir.path().join(name),
            )
            .unwrap();
        }
        Stubs { dir }
    }

    /// The answers of the stub `claude`'s calls, in order.
    pub fn claude_answers(self, answers: &[Answer]) -> Self {
        for (i, a) in answers.iter().enumerate() {
            let n = i + 1;
            let file = |what: &str| self.dir.path().join(format!("{what}-{n}"));
            match a {
                Answer::Fixture(name) => {
                    let v = fixture(&format!("claude/{name}"));
                    std::fs::write(file("answer").with_extension("json"), v.to_string()).unwrap();
                }
                Answer::Output(output) => {
                    let mut v = fixture("claude/recorded-order.json");
                    v["structured_output"] = output.clone();
                    v["result"] = json!(output.to_string());
                    std::fs::write(file("answer").with_extension("json"), v.to_string()).unwrap();
                }
                Answer::Exit(code, stderr) => {
                    std::fs::write(file("exit"), code.to_string()).unwrap();
                    std::fs::write(file("stderr"), stderr).unwrap();
                }
            }
        }
        self
    }

    /// The stub `gh`'s answers: an API path and the items it returns, as one page.
    pub fn gh_answers(self, answers: &[(String, Vec<Value>)]) -> Self {
        for (path, items) in answers {
            let key: String = path
                .chars()
                .map(|c| if "/?&=".contains(c) { '_' } else { c })
                .collect();
            std::fs::write(
                self.dir.path().join(format!("{key}.json")),
                json!([items]).to_string(),
            )
            .unwrap();
        }
        self
    }

    pub fn path(&self) -> PathBuf {
        self.dir.path().to_path_buf()
    }

    pub fn gh(&self) -> Gh {
        Gh {
            program: self.dir.path().join("gh"),
        }
    }

    /// The stub `claude` with an environment that holds every token a runner job can carry.
    pub fn agent(&self) -> Agent {
        let mut env: Vec<(String, String)> = [
            "GH_TOKEN",
            "GITHUB_TOKEN",
            "ACTIONS_RUNTIME_TOKEN",
            "ACTIONS_ID_TOKEN_REQUEST_TOKEN",
            "BASH_ENV",
            "CLAUDE_CODE_OAUTH_TOKEN",
        ]
        .iter()
        .map(|k| (k.to_string(), format!("secret-{k}")))
        .collect();
        for k in ["PATH", "HOME"] {
            env.push((k.into(), std::env::var(k).unwrap()));
        }
        Agent {
            program: self.dir.path().join("claude"),
            parent_env: env,
        }
    }

    pub fn claude_calls(&self) -> usize {
        std::fs::read_to_string(self.dir.path().join("count"))
            .map_or(0, |s| s.trim().parse().unwrap())
    }

    pub fn gh_calls(&self) -> Vec<String> {
        std::fs::read_to_string(self.dir.path().join("calls.log"))
            .unwrap_or_default()
            .lines()
            .map(String::from)
            .collect()
    }

    /// What the stub `claude` recorded for call `n`: `args`, `env`, `stdin` or `files`.
    pub fn recorded(&self, n: usize, what: &str) -> String {
        std::fs::read_to_string(self.dir.path().join(format!("call-{n}.{what}"))).unwrap()
    }

    pub fn args(&self, n: usize) -> Vec<String> {
        nul_split(&self.recorded(n, "args"))
    }

    pub fn env_names(&self, n: usize) -> Vec<String> {
        let mut names: Vec<String> = nul_split(&self.recorded(n, "env"))
            .into_iter()
            .map(|kv| kv.split('=').next().unwrap().to_string())
            .collect();
        names.sort();
        names
    }
}

fn nul_split(s: &str) -> Vec<String> {
    s.split('\0')
        .filter(|x| !x.is_empty())
        .map(String::from)
        .collect()
}

pub fn list_path() -> String {
    format!("repos/{REPO}/issues?state=open&per_page=100")
}

pub fn rel_path(number: u64, kind: &str) -> String {
    format!("repos/{REPO}/issues/{number}/{kind}?per_page=100")
}

pub fn recorded_issues() -> Vec<Value> {
    fixture("gh-recorded/issues-open.json")[0]
        .as_array()
        .unwrap()
        .clone()
}

fn find(issues: &[Value], number: u64) -> Value {
    issues
        .iter()
        .find(|i| i["number"] == number)
        .unwrap()
        .clone()
}

/// The recorded open issues, changed as follows:
/// - #69 is reopened (its recorded object, `state` open): a parent with 4 open sub-issues (63, 65,
///   56, 59) of the 6 recorded;
/// - #59 (Medium) is blocked by #57 (Medium), and #63 (High) by #56 (Medium);
/// - #82 is a pull request, #79 has a milestone and #54 the `needs-info` label: all three leave;
/// - #21 has no type and #20 no priority.
pub fn scenario() -> Vec<(String, Vec<Value>)> {
    let mut issues = recorded_issues();
    let mut parent = fixture("gh-recorded/issue-69.json");
    parent["state"] = json!("open");
    issues.push(parent);
    for i in issues.iter_mut() {
        match i["number"].as_u64().unwrap() {
            82 => {
                i["pull_request"] =
                    json!({"url": "https://api.github.com/repos/becloud-dev/workflows/pulls/82"})
            }
            79 => i["milestone"] = json!({"title": "R1: CLI"}),
            54 => i["labels"] = json!([{"name": "needs-info"}]),
            21 => i["type"] = Value::Null,
            20 => i["issue_field_values"] = json!([]),
            59 | 63 => i["issue_dependencies_summary"]["total_blocked_by"] = json!(1),
            57 | 56 => i["issue_dependencies_summary"]["total_blocking"] = json!(1),
            _ => {}
        }
    }
    let sub_issues = fixture("gh-recorded/sub-issues-69.json")[0]
        .as_array()
        .unwrap()
        .clone();
    let open = |n: u64| -> Value {
        let mut i = find(&issues, n);
        i["state"] = json!("open");
        i
    };
    vec![
        (rel_path(69, "sub_issues"), sub_issues),
        (rel_path(59, "dependencies/blocked_by"), vec![open(57)]),
        (rel_path(57, "dependencies/blocking"), vec![open(59)]),
        (rel_path(63, "dependencies/blocked_by"), vec![open(56)]),
        (rel_path(56, "dependencies/blocking"), vec![open(63)]),
        (list_path(), issues),
    ]
}
