//! The verdict of a round, from the executor's and the check model's structured outputs and the
//! results the commands recorded. Mechanism, not prose: a failing command, new tests that pass on
//! the base, a scope violation or an unmet criterion fail the round whatever the check model says.

use anyhow::{Context, Result};
use serde_json::Value;
use std::io::Write;
use std::path::Path;

/// What the round recorded; every field is the raw text of the step output it comes from.
#[derive(Debug, Default, Clone)]
pub struct Inputs {
    pub execute: String,
    pub check: String,
    pub check_exit: String,
    pub test_exit: String,
    pub red_state: String,
    pub scope_state: String,
    pub scope_violations: String,
    pub scope_kinds: String,
    pub round: String,
}

#[derive(Debug, PartialEq, Eq)]
pub struct Verdict {
    /// done, blocked or failed.
    pub outcome: &'static str,
    /// pass, fail or none.
    pub verdict: &'static str,
    pub findings: String,
}

/// A value as jq's string interpolation prints it: a string raw, anything else as JSON.
fn interp(v: &Value) -> String {
    match v {
        Value::String(s) => s.clone(),
        other => other.to_string(),
    }
}

/// An unset or empty step output counts as its default.
fn or<'a>(v: &'a str, default: &'a str) -> &'a str {
    if v.is_empty() { default } else { v }
}

fn valid_check(check: &Value) -> bool {
    let verdict = check["verdict"].as_str();
    let findings = check["findings"].as_array().map_or(0, Vec::len);
    matches!(verdict, Some("pass") | Some("fail"))
        && check["criteria"].is_array()
        && ((verdict == Some("fail")) == (findings > 0))
}

fn met(c: &Value) -> bool {
    !matches!(c["met"], Value::Null | Value::Bool(false))
}

pub fn decide(i: &Inputs) -> Verdict {
    let execute: Value = serde_json::from_str(or(&i.execute, "null")).unwrap_or(Value::Null);
    let exec_outcome = execute["outcome"].as_str().unwrap_or("");
    if exec_outcome == "blocked" {
        let reason = match &execute["blocked_reason"] {
            Value::Null | Value::Bool(false) => "no reason given".to_string(),
            v => interp(v),
        };
        return Verdict {
            outcome: "blocked",
            verdict: "none",
            findings: format!("The executor reported it is blocked:\n{reason}\n"),
        };
    }
    let check: Value = serde_json::from_str(&i.check).unwrap_or(Value::Null);
    if exec_outcome != "done" || i.check.is_empty() || !valid_check(&check) {
        return Verdict {
            outcome: "failed",
            verdict: "none",
            findings: "The round produced no valid result.\n".to_string(),
        };
    }
    let (check_exit, test_exit) = (or(&i.check_exit, "0"), or(&i.test_exit, "0"));
    let red = or(&i.red_state, "none");
    let scope = or(&i.scope_state, "none");
    let criteria = check["criteria"].as_array().cloned().unwrap_or_default();
    let unmet: Vec<&Value> = criteria.iter().filter(|c| !met(c)).collect();
    let forced = check_exit != "0"
        || test_exit != "0"
        || red == "green_on_base"
        || scope == "out_of_scope"
        || scope == "error"
        || !unmet.is_empty();
    let verdict = if forced || check["verdict"] == "fail" {
        "fail"
    } else {
        "pass"
    };
    let mut f = format!("Round {} check findings:\n", i.round);
    for x in check["findings"].as_array().into_iter().flatten() {
        f.push_str(&format!(
            "- criterion {}: {}\n",
            interp(&x["criterion"]),
            interp(&x["problem"])
        ));
    }
    for c in &unmet {
        f.push_str(&format!(
            "- criterion {} is not met\n",
            interp(&c["criterion"])
        ));
    }
    if check_exit != "0" {
        f.push_str(&format!("- the check command exited {check_exit}\n"));
    }
    if test_exit != "0" {
        f.push_str(&format!("- the test command exited {test_exit}\n"));
    }
    if red == "green_on_base" {
        f.push_str("- the new tests pass on the base tree; they do not pin the change\n");
    }
    if scope == "out_of_scope" {
        let paths: Vec<Value> = serde_json::from_str(&i.scope_violations).unwrap_or_default();
        let kinds: Vec<Value> = serde_json::from_str(or(&i.scope_kinds, "[]")).unwrap_or_default();
        for (n, p) in paths.iter().enumerate() {
            if kinds.get(n).and_then(Value::as_str) == Some("changed") {
                f.push_str(&format!(
                    "- change of {} under .github/workflows is not in the plan Files list\n",
                    interp(p)
                ));
            } else {
                f.push_str(&format!(
                    "- deletion of {} is not in the plan Files list\n",
                    interp(p)
                ));
            }
        }
    }
    if scope == "error" {
        f.push_str(
            "- the deletions, the workflow changes or the plan Files list could not be read\n",
        );
    }
    Verdict {
        outcome: "done",
        verdict,
        findings: f,
    }
}

/// Writes the findings to `findings_file` and `outcome`, `verdict`, `findings_file` to
/// `github_output`.
pub fn run(i: &Inputs, findings_file: &Path, github_output: &Path) -> Result<bool> {
    let v = decide(i);
    std::fs::write(findings_file, &v.findings)
        .with_context(|| format!("cannot write {}", findings_file.display()))?;
    let mut out = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(github_output)
        .with_context(|| format!("cannot open {}", github_output.display()))?;
    writeln!(out, "outcome={}", v.outcome)?;
    writeln!(out, "verdict={}", v.verdict)?;
    writeln!(out, "findings_file={}", findings_file.display())?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    const DONE: &str = r#"{"outcome":"done","summary":"s","red_seen":true,"commits":["a"]}"#;
    const PASS: &str =
        r#"{"verdict":"pass","summary":"s","criteria":[{"criterion":1,"met":true}],"findings":[]}"#;

    fn base() -> Inputs {
        Inputs {
            execute: DONE.into(),
            check: PASS.into(),
            check_exit: "0".into(),
            test_exit: "0".into(),
            red_state: "none".into(),
            scope_state: "none".into(),
            scope_violations: "[]".into(),
            scope_kinds: "[]".into(),
            round: "1".into(),
        }
    }

    #[test]
    fn a_done_round_with_a_passing_check_passes() {
        let v = decide(&base());
        assert_eq!((v.outcome, v.verdict), ("done", "pass"));
        assert_eq!(v.findings, "Round 1 check findings:\n");
    }

    #[test]
    fn a_blocked_executor_gives_its_reason() {
        let mut i = base();
        i.execute = r#"{"outcome":"blocked","summary":"s","blocked_reason":"no access"}"#.into();
        let v = decide(&i);
        assert_eq!((v.outcome, v.verdict), ("blocked", "none"));
        assert_eq!(
            v.findings,
            "The executor reported it is blocked:\nno access\n"
        );
        i.execute = r#"{"outcome":"blocked","summary":"s"}"#.into();
        assert!(decide(&i).findings.contains("no reason given"));
    }

    #[test]
    fn the_model_fail_keeps_its_findings() {
        let mut i = base();
        i.check = r#"{"verdict":"fail","summary":"s","criteria":[{"criterion":1,"met":true}],"findings":[{"criterion":1,"problem":"wrong"}]}"#.into();
        let v = decide(&i);
        assert_eq!(v.verdict, "fail");
        assert!(v.findings.contains("- criterion 1: wrong\n"));
    }

    #[test]
    fn mechanisms_force_fail_over_a_passing_check() {
        for (set, line) in [
            (("check_exit", "2"), "- the check command exited 2"),
            (("test_exit", "1"), "- the test command exited 1"),
            (("red_state", "green_on_base"), "do not pin the change"),
            (("scope_state", "error"), "could not be read"),
        ] {
            let mut i = base();
            match set.0 {
                "check_exit" => i.check_exit = set.1.into(),
                "test_exit" => i.test_exit = set.1.into(),
                "red_state" => i.red_state = set.1.into(),
                _ => i.scope_state = set.1.into(),
            }
            let v = decide(&i);
            assert_eq!(v.verdict, "fail", "{set:?}");
            assert!(v.findings.contains(line), "{set:?}: {}", v.findings);
        }
    }

    #[test]
    fn an_unmet_criterion_forces_fail_and_is_named() {
        let mut i = base();
        i.check = r#"{"verdict":"pass","summary":"s","criteria":[{"criterion":1,"met":true},{"criterion":2,"met":false}],"findings":[]}"#.into();
        let v = decide(&i);
        assert_eq!(v.verdict, "fail");
        assert!(v.findings.contains("- criterion 2 is not met\n"));
    }

    #[test]
    fn scope_violations_are_named_by_kind() {
        let mut i = base();
        i.scope_state = "out_of_scope".into();
        i.scope_violations = r#"["a","b.yml"]"#.into();
        i.scope_kinds = r#"["deleted","changed"]"#.into();
        let v = decide(&i);
        assert!(
            v.findings
                .contains("- deletion of a is not in the plan Files list\n")
        );
        assert!(
            v.findings.contains(
                "- change of b.yml under .github/workflows is not in the plan Files list\n"
            )
        );
    }

    #[test]
    fn invalid_or_missing_results_fail_the_round() {
        for (execute, check) in [
            (
                DONE,
                r#"{"verdict":"fail","summary":"s","criteria":[],"findings":[]}"#,
            ),
            (DONE, "not json"),
            (DONE, ""),
            ("", PASS),
            ("not json", PASS),
        ] {
            let mut i = base();
            i.execute = execute.into();
            i.check = check.into();
            let v = decide(&i);
            assert_eq!(
                (v.outcome, v.verdict),
                ("failed", "none"),
                "{execute} / {check}"
            );
            assert_eq!(v.findings, "The round produced no valid result.\n");
        }
    }
}
