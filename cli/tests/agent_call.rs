//! The agent-call module against the stub `claude`, answering with the recorded result and the
//! files derived from it (see `common`).

mod common;

use becloud_workflows::agent::{Outcome, PASSED_ENV, Request};
use becloud_workflows::record::RunRecord;
use common::{Answer, Stubs};
use serde_json::{Value, json};

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

fn call(stubs: &Stubs, rules: &dyn Fn(&Value) -> Vec<String>) -> Outcome {
    let schema = order_schema();
    let files = [("input.json", b"{\"issues\":[]}".to_vec())];
    stubs
        .agent()
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
    let stubs = Stubs::new().claude_answers(&[Answer::Fixture("derived-order-clean.json")]);
    let out = call(&stubs, &no_rules);
    assert_eq!(stubs.claude_calls(), 1);
    let output = out.output.unwrap();
    assert_eq!(output["order"][0]["number"], 11);
    assert_eq!(out.attempts.len(), 1);
    assert_eq!(out.attempts[0].outcome, "ok");
    assert_eq!(out.attempts[0].num_turns, 3);
}

#[test]
fn the_agent_gets_no_token_no_stdin_and_only_its_input() {
    let stubs = Stubs::new().claude_answers(&[Answer::Fixture("derived-order-clean.json")]);
    call(&stubs, &no_rules);
    let mut want: Vec<String> = PASSED_ENV
        .iter()
        .filter(|k| ["PATH", "HOME", "CLAUDE_CODE_OAUTH_TOKEN"].contains(k))
        .map(|k| k.to_string())
        .chain(["DISABLE_AUTOUPDATER".to_string()])
        .collect();
    want.sort();
    // bash itself adds PWD, SHLVL and _ to the environment the stub records.
    let got: Vec<String> = stubs
        .env_names(1)
        .into_iter()
        .filter(|k| !["PWD", "SHLVL", "_", "OLDPWD"].contains(&k.as_str()))
        .collect();
    assert_eq!(got, want);
    assert_eq!(stubs.recorded(1, "stdin").trim(), "/dev/null");
    assert_eq!(stubs.recorded(1, "files").trim(), "input.json");
    let args = stubs.args(1);
    assert_eq!(args[0..2], ["-p", "Order the issues in input.json."]);
    assert!(args.contains(&"--restricted".to_string()));
}

#[test]
fn keys_the_schema_does_not_allow_are_refused_and_retried() {
    // The recorded answer carries `title` and `number_placeholder` on one item: the real model
    // added keys the schema did not forbid at the time.
    let stubs = Stubs::new().claude_answers(&[
        Answer::Fixture("recorded-order.json"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let out = call(&stubs, &no_rules);
    assert_eq!(stubs.claude_calls(), 2);
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
    let retry_prompt = &stubs.args(2)[1];
    assert!(retry_prompt.contains("was refused"));
    assert!(retry_prompt.contains("schema: at '/order/1'"));
}

#[test]
fn a_missing_structured_output_is_retried_once() {
    let stubs = Stubs::new().claude_answers(&[
        Answer::Fixture("derived-no-structured-output.json"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let out = call(&stubs, &no_rules);
    assert!(out.output.is_ok());
    assert_eq!(stubs.claude_calls(), 2);
    assert!(stubs.args(2)[1].contains("no structured output (subtype success)"));
}

#[test]
fn a_missing_structured_output_twice_fails() {
    let stubs = Stubs::new().claude_answers(&[
        Answer::Fixture("derived-no-structured-output.json"),
        Answer::Fixture("derived-no-structured-output.json"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let out = call(&stubs, &no_rules);
    assert_eq!(stubs.claude_calls(), 2);
    assert_eq!(
        out.output.unwrap_err(),
        ["no structured output (subtype success)"]
    );
    assert_eq!(out.attempts[1].outcome, "refused");
}

#[test]
fn a_broken_rule_is_named_in_the_retry() {
    let stubs = Stubs::new().claude_answers(&[
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
    let out = call(&stubs, &rules);
    assert!(out.output.is_ok());
    assert!(stubs.args(2)[1].contains("- #12 is ranked before #11, which blocks it"));
}

#[test]
fn rules_broken_twice_fail_with_every_rule_named() {
    let stubs = Stubs::new().claude_answers(&[
        Answer::Fixture("derived-order-clean.json"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let rules = |_: &Value| vec!["rule one".to_string(), "rule two".to_string()];
    let out = call(&stubs, &rules);
    assert_eq!(out.output.unwrap_err(), ["rule one", "rule two"]);
    assert_eq!(out.attempts.len(), 2);
}

#[test]
fn a_failing_claude_is_not_retried() {
    let stubs = Stubs::new().claude_answers(&[
        Answer::Exit(1, "Invalid API key · Please run /login"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let out = call(&stubs, &no_rules);
    assert_eq!(stubs.claude_calls(), 1);
    let reasons = out.output.unwrap_err();
    assert!(
        reasons[0].starts_with("claude exited with 1: Invalid API key"),
        "{reasons:?}"
    );
    assert_eq!(out.attempts[0].outcome, "failed");
}

#[test]
fn the_run_record_sums_tokens_per_model_over_every_attempt() {
    let stubs = Stubs::new().claude_answers(&[
        Answer::Fixture("recorded-order.json"),
        Answer::Fixture("derived-order-clean.json"),
    ]);
    let out = call(&stubs, &no_rules);
    let mut record = RunRecord::new("planner-backlog", "claude-haiku-5-5", "backlog", &[]);
    record.add(&out.attempts);
    let haiku = &record.tokens["claude-haiku-5-5"];
    assert_eq!(haiku.output, 2 * 453);
    assert_eq!(haiku.cache_read_input, 2 * 4142);
    assert_eq!(record.calls.len(), 2);
    let path = record.write(&stubs.path()).unwrap();
    assert!(path.ends_with("run-record-planner-backlog.json"));
    let written: Value = serde_json::from_slice(&std::fs::read(path).unwrap()).unwrap();
    assert_eq!(
        written["calls"][0]["model_usage"]["claude-haiku-5-5"]["outputTokens"],
        453
    );
}
