//! The agent-call module against a stub `claude` (tests/bin/claude). The answers are
//! `recorded-order.json`, the output of a real `claude -p` 2.1.296 call with the module's flags
//! (Haiku 5.5, 2026-10-13), and two files derived from it with jq: `derived-order-clean.json`
//! (each order item cut to `number` and `reason`) and `derived-no-structured-output.json`
//! (`structured_output` removed).

use becloud_workflows::agent::{Agent, PASSED_ENV, Request};
use becloud_workflows::record::RunRecord;
use serde_json::{Value, json};
use std::path::{Path, PathBuf};

const FIXTURES: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/claude");
const STUB: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/bin/claude");

/// A scratch directory holding the stub and the answers of its calls, in order.
struct Stub {
    dir: tempfile::TempDir,
}

enum Answer<'a> {
    Fixture(&'a str),
    Exit(i32, &'a str),
}

impl Stub {
    fn new(answers: &[Answer]) -> Self {
        let dir = tempfile::tempdir().unwrap();
        std::fs::copy(STUB, dir.path().join("claude")).unwrap();
        for (i, a) in answers.iter().enumerate() {
            let n = i + 1;
            match a {
                Answer::Fixture(name) => {
                    std::fs::copy(
                        Path::new(FIXTURES).join(name),
                        dir.path().join(format!("answer-{n}.json")),
                    )
                    .unwrap();
                }
                Answer::Exit(code, stderr) => {
                    std::fs::write(dir.path().join(format!("exit-{n}")), code.to_string()).unwrap();
                    std::fs::write(dir.path().join(format!("stderr-{n}")), stderr).unwrap();
                }
            }
        }
        Stub { dir }
    }

    fn agent(&self) -> Agent {
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

    fn calls(&self) -> usize {
        std::fs::read_to_string(self.dir.path().join("count"))
            .map_or(0, |s| s.trim().parse().unwrap())
    }

    fn recorded(&self, n: usize, what: &str) -> String {
        std::fs::read_to_string(self.dir.path().join(format!("call-{n}.{what}"))).unwrap()
    }

    fn args(&self, n: usize) -> Vec<String> {
        nul_split(&self.recorded(n, "args"))
    }

    fn env_names(&self, n: usize) -> Vec<String> {
        let mut names: Vec<String> = nul_split(&self.recorded(n, "env"))
            .into_iter()
            .map(|kv| kv.split('=').next().unwrap().to_string())
            .collect();
        names.sort();
        names
    }

    fn path(&self) -> PathBuf {
        self.dir.path().to_path_buf()
    }
}

fn nul_split(s: &str) -> Vec<String> {
    s.split('\0')
        .filter(|x| !x.is_empty())
        .map(String::from)
        .collect()
}

fn order_schema() -> Value {
    json!({
        "type": "object",
        "additionalProperties": false,
        "properties": {
            "order": {"type": "array", "items": {
                "type": "object",
                "additionalProperties": false,
                "properties": {"number": {"type": "integer"}, "reason": {"type": "string"}},
                "required": ["number", "reason"]
            }},
            "summary": {"type": "string"}
        },
        "required": ["order", "summary"]
    })
}

fn no_rules(_: &Value) -> Vec<String> {
    Vec::new()
}

fn call(stub: &Stub, rules: &dyn Fn(&Value) -> Vec<String>) -> becloud_workflows::agent::Outcome {
    let schema = order_schema();
    let files = [("input.json".to_string(), b"{\"issues\":[]}".to_vec())];
    let files: Vec<(&str, Vec<u8>)> = files.iter().map(|(n, b)| (n.as_str(), b.clone())).collect();
    stub.agent()
        .call(
            &Request {
                role: "order",
                model: "claude-haiku-5-5",
                prompt: "Order the issues in input.json.",
                schema: &schema,
                files: &files,
            },
            rules,
        )
        .unwrap()
}

#[test]
fn a_valid_answer_passes_on_the_first_call() {
    let stub = Stub::new(&[Answer::Fixture("derived-order-clean.json")]);
    let out = call(&stub, &no_rules);
    assert_eq!(stub.calls(), 1);
    let output = out.output.unwrap();
    assert_eq!(output["order"][0]["number"], 11);
    assert_eq!(out.attempts.len(), 1);
    assert_eq!(out.attempts[0].outcome, "ok");
    assert_eq!(out.attempts[0].num_turns, 3);
}

#[test]
fn the_agent_gets_no_token_no_stdin_and_only_its_input() {
    let stub = Stub::new(&[Answer::Fixture("derived-order-clean.json")]);
    call(&stub, &no_rules);
    let mut want: Vec<String> = PASSED_ENV
        .iter()
        .filter(|k| ["PATH", "HOME", "CLAUDE_CODE_OAUTH_TOKEN"].contains(k))
        .map(|k| k.to_string())
        .chain(["DISABLE_AUTOUPDATER".to_string()])
        .collect();
    want.sort();
    // bash itself adds PWD, SHLVL and _ to the environment the stub records.
    let got: Vec<String> = stub
        .env_names(1)
        .into_iter()
        .filter(|k| !["PWD", "SHLVL", "_", "OLDPWD"].contains(&k.as_str()))
        .collect();
    assert_eq!(got, want);
    assert_eq!(stub.recorded(1, "stdin").trim(), "/dev/null");
    assert_eq!(stub.recorded(1, "files").trim(), "input.json");
    let args = stub.args(1);
    assert_eq!(args[0..2], ["-p", "Order the issues in input.json."]);
    assert!(args.contains(&"--restricted".to_string()));
}

#[test]
fn keys_the_schema_does_not_allow_are_refused_and_retried() {
    // The recorded answer carries `title` and `number_placeholder` on one item: the real model
    // added keys the schema did not forbid at the time.
    let stub = Stub::new(&[
        Answer::Fixture("recorded-order.json"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let out = call(&stub, &no_rules);
    assert_eq!(stub.calls(), 2);
    assert!(out.output.is_ok());
    assert_eq!(out.attempts[0].outcome, "retry");
    assert!(
        out.attempts[0]
            .reasons
            .iter()
            .any(|r| r.contains("/order/1")),
        "{:?}",
        out.attempts[0].reasons
    );
    let retry_prompt = &stub.args(2)[1];
    assert!(retry_prompt.contains("was refused"));
    assert!(retry_prompt.contains("schema: at '/order/1'"));
}

#[test]
fn a_missing_structured_output_is_retried_once() {
    let stub = Stub::new(&[
        Answer::Fixture("derived-no-structured-output.json"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let out = call(&stub, &no_rules);
    assert!(out.output.is_ok());
    assert_eq!(stub.calls(), 2);
    assert!(stub.args(2)[1].contains("no structured output (subtype success)"));
}

#[test]
fn a_missing_structured_output_twice_fails() {
    let stub = Stub::new(&[
        Answer::Fixture("derived-no-structured-output.json"),
        Answer::Fixture("derived-no-structured-output.json"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let out = call(&stub, &no_rules);
    assert_eq!(stub.calls(), 2);
    assert_eq!(
        out.output.unwrap_err(),
        ["no structured output (subtype success)"]
    );
    assert_eq!(out.attempts[1].outcome, "refused");
}

#[test]
fn a_broken_rule_is_named_in_the_retry() {
    let stub = Stub::new(&[
        Answer::Fixture("derived-order-clean.json"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let calls = std::cell::Cell::new(0);
    let rules = |_: &Value| {
        calls.set(calls.get() + 1);
        if calls.get() == 1 {
            vec!["#12 is ranked before #11, which blocks it".to_string()]
        } else {
            Vec::new()
        }
    };
    let out = call(&stub, &rules);
    assert!(out.output.is_ok());
    assert!(stub.args(2)[1].contains("- #12 is ranked before #11, which blocks it"));
}

#[test]
fn rules_broken_twice_fail_with_every_rule_named() {
    let stub = Stub::new(&[
        Answer::Fixture("derived-order-clean.json"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let rules = |_: &Value| vec!["rule one".to_string(), "rule two".to_string()];
    let out = call(&stub, &rules);
    assert_eq!(out.output.unwrap_err(), ["rule one", "rule two"]);
    assert_eq!(out.attempts.len(), 2);
}

#[test]
fn a_failing_claude_is_not_retried() {
    let stub = Stub::new(&[
        Answer::Exit(1, "Invalid API key · Please run /login"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let out = call(&stub, &no_rules);
    assert_eq!(stub.calls(), 1);
    let reasons = out.output.unwrap_err();
    assert!(
        reasons[0].starts_with("claude exited with 1: Invalid API key"),
        "{reasons:?}"
    );
    assert_eq!(out.attempts[0].outcome, "failed");
}

#[test]
fn the_run_record_sums_tokens_per_model_over_every_attempt() {
    let stub = Stub::new(&[
        Answer::Fixture("recorded-order.json"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let out = call(&stub, &no_rules);
    let mut record = RunRecord::new("planner-backlog", "claude-haiku-5-5", "backlog", &[]);
    record.add(&out.attempts);
    let haiku = &record.tokens["claude-haiku-5-5"];
    assert_eq!(haiku.output, 2 * 453);
    assert_eq!(haiku.cache_read_input, 2 * 4142);
    assert_eq!(record.calls.len(), 2);
    let path = record.write(&stub.path()).unwrap();
    assert!(path.ends_with("run-record-planner-backlog.json"));
    let written: Value = serde_json::from_slice(&std::fs::read(path).unwrap()).unwrap();
    assert_eq!(
        written["calls"][0]["model_usage"]["claude-haiku-5-5"]["outputTokens"],
        453
    );
}
