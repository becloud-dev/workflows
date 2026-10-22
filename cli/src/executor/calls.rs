//! The two agent calls of a round, made by the CLI instead of claude-code-action: the executor
//! writes and commits the change in the checkout, the check model judges it. Each call runs a
//! pinned `claude -p --restricted` (see `agent`) with only the tools its role needs. Its inputs
//! (the plan, the earlier findings, the results) are copies in a fresh directory it may read, so
//! the files the later steps read stay out of its reach.

use crate::agent::{Agent, Request, Scope};
use crate::record::RunRecord;
use anyhow::{Context, Result, bail};
use serde_json::{Value, json};
use std::io::Write;
use std::path::{Path, PathBuf};

const EXECUTE_PROMPT: &str = include_str!("../../../prompts/dev-execute.md");
const CHECK_PROMPT: &str = include_str!("../../../prompts/dev-check.md");

/// The executor's built-in tools; what it may run is narrowed by [`allowlist`].
const EXECUTE_TOOLS: [&str; 6] = ["Read", "Edit", "Write", "Grep", "Glob", "Bash"];
const CHECK_TOOLS: [&str; 4] = ["Read", "Grep", "Glob", "Bash"];
const CHECK_ALLOW: [&str; 5] = [
    "Read",
    "Grep",
    "Glob",
    "Bash(git diff:*)",
    "Bash(git log:*)",
];

/// The executor's permission rules: the file tools, the plain git commands of a commit, and the
/// consumer's check and test commands. A command with a quote, backslash, dollar, backtick or
/// newline is refused: it could widen its own rule.
pub fn allowlist(check: &str, test: &str) -> Result<Vec<String>> {
    let mut rules: Vec<String> = [
        "Read",
        "Edit",
        "Write",
        "Grep",
        "Glob",
        "Bash(git add:*)",
        "Bash(git commit:*)",
        "Bash(git status:*)",
        "Bash(git diff:*)",
        "Bash(git log:*)",
        "Bash(git rm:*)",
    ]
    .map(String::from)
    .to_vec();
    for c in [check, test] {
        if c.is_empty() {
            continue;
        }
        if c.contains(['"', '$', '`', '\\', '\n']) {
            bail!("a command contains a quote, backslash, dollar, backtick or newline");
        }
        rules.push(format!("Bash({c}:*)"));
    }
    Ok(rules)
}

pub fn execute_schema() -> Value {
    json!({
        "type": "object",
        "additionalProperties": false,
        "properties": {
            "outcome": {"type": "string", "enum": ["done", "blocked"]},
            "summary": {"type": "string"},
            "red_seen": {"type": "boolean"},
            "commits": {"type": "array", "items": {"type": "string"}},
            "blocked_reason": {"type": "string"}
        },
        "required": ["outcome", "summary"]
    })
}

pub fn check_schema() -> Value {
    json!({
        "type": "object",
        "additionalProperties": false,
        "properties": {
            "verdict": {"type": "string", "enum": ["pass", "fail"]},
            "summary": {"type": "string"},
            "criteria": {"type": "array", "items": {
                "type": "object", "additionalProperties": false,
                "properties": {"criterion": {"type": "integer"}, "met": {"type": "boolean"}},
                "required": ["criterion", "met"]
            }},
            "findings": {"type": "array", "maxItems": 8, "items": {
                "type": "object", "additionalProperties": false,
                "properties": {"criterion": {"type": "integer"}, "problem": {"type": "string"}},
                "required": ["criterion", "problem"]
            }}
        },
        "required": ["verdict", "summary", "criteria", "findings"]
    })
}

/// A failing verdict names its findings and a passing one has none; the verdict step refuses any
/// other result, so the call is asked once more instead.
pub fn check_rules(o: &Value) -> Vec<String> {
    let fail = o["verdict"] == "fail";
    let findings = o["findings"].as_array().map_or(0, Vec::len);
    if fail == (findings > 0) {
        Vec::new()
    } else {
        vec!["a fail verdict needs at least one finding, and a pass verdict none".into()]
    }
}

/// What one round call needs to know about where it runs.
pub struct Round<'a> {
    pub repo: &'a str,
    pub issue: &'a str,
    pub round: &'a str,
    pub model: &'a str,
    /// The checkout the executor works in, and the check reads.
    pub repo_dir: &'a Path,
    /// Where the inputs, the run record and nothing else are written (`$RUNNER_TEMP`).
    pub work_dir: &'a Path,
}

/// A fresh directory under `work_dir` holding copies of `files` (name, source); a source of
/// `None` is skipped.
fn inputs(
    work_dir: &Path,
    role: &str,
    round: &str,
    files: &[(&str, Option<&Path>)],
) -> Result<PathBuf> {
    let dir = work_dir.join(format!("agent-inputs-{role}-r{round}"));
    if dir.exists() {
        std::fs::remove_dir_all(&dir)?;
    }
    std::fs::create_dir_all(&dir)?;
    for (name, src) in files {
        if let Some(src) = src {
            std::fs::copy(src, dir.join(name))
                .with_context(|| format!("cannot copy {} for the {role} call", src.display()))?;
        }
    }
    Ok(dir.canonicalize()?)
}

/// Runs a call, writes its run record to `work_dir` and, when it gave a valid result, appends
/// `structured_output=<json>` to `github_output`. `Ok(false)` when it gave none.
fn finish(
    r: &Round,
    agent: &Agent,
    req: &Request,
    rules: &dyn Fn(&Value) -> Vec<String>,
    stage: &str,
    env: &[(String, String)],
    github_output: &Path,
) -> Result<bool> {
    let outcome = agent.call(req, rules)?;
    let mut record = RunRecord::new(stage, r.model, r.issue, env);
    record.add(&outcome.attempts);
    record.ok = outcome.output.is_ok();
    record.write(r.work_dir)?;
    match outcome.output {
        Ok(output) => {
            let mut out = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open(github_output)
                .with_context(|| format!("cannot open {}", github_output.display()))?;
            writeln!(out, "structured_output={output}")?;
            Ok(true)
        }
        Err(reasons) => {
            for reason in reasons {
                println!(
                    "::error::the {} call gave no valid result: {reason}",
                    req.role
                );
            }
            Ok(false)
        }
    }
}

/// The executor call: writes and commits the change in `repo_dir`.
#[allow(clippy::too_many_arguments)]
pub fn execute(
    agent: &Agent,
    r: &Round,
    plan_file: &Path,
    findings_file: &str,
    check: &str,
    test: &str,
    env: &[(String, String)],
    github_output: &Path,
) -> Result<bool> {
    let allow = allowlist(check, test)?;
    let findings = (findings_file != "none").then(|| Path::new(findings_file));
    let dir = inputs(
        r.work_dir,
        "execute",
        r.round,
        &[("plan.md", Some(plan_file)), ("findings.md", findings)],
    )?;
    let findings_path = if findings.is_some() {
        dir.join("findings.md").display().to_string()
    } else {
        "none".to_string()
    };
    let prompt = format!(
        "Repository: {}\nIssue number: {}\nPlan file: {}\nFindings file: {}\nCheck command: {}\nTest command: {}\n\n{EXECUTE_PROMPT}",
        r.repo,
        r.issue,
        dir.join("plan.md").display(),
        findings_path,
        check,
        test
    );
    let allow: Vec<&str> = allow.iter().map(String::as_str).collect();
    let schema = execute_schema();
    let req = Request {
        role: "execute",
        model: r.model,
        prompt: &prompt,
        schema: &schema,
        files: &[],
        scope: Scope {
            tools: &EXECUTE_TOOLS,
            allow: &allow,
            cwd: Some(r.repo_dir),
            add_dirs: &[&dir],
        },
    };
    let stage = format!("dev-execute-r{}", r.round);
    finish(r, agent, &req, &|_| Vec::new(), &stage, env, github_output)
}

/// The check call: judges the round's change against the plan and the recorded results.
#[allow(clippy::too_many_arguments)]
pub fn check(
    agent: &Agent,
    r: &Round,
    plan_file: &Path,
    results_file: &Path,
    base: &str,
    env: &[(String, String)],
    github_output: &Path,
) -> Result<bool> {
    let dir = inputs(
        r.work_dir,
        "check",
        r.round,
        &[
            ("plan.md", Some(plan_file)),
            ("results.md", Some(results_file)),
        ],
    )?;
    let prompt = format!(
        "Repository: {}\nIssue number: {}\nPlan file: {}\nResults file: {}\nBase: {}\n\n{CHECK_PROMPT}",
        r.repo,
        r.issue,
        dir.join("plan.md").display(),
        dir.join("results.md").display(),
        base
    );
    let schema = check_schema();
    let req = Request {
        role: "check",
        model: r.model,
        prompt: &prompt,
        schema: &schema,
        files: &[],
        scope: Scope {
            tools: &CHECK_TOOLS,
            allow: &CHECK_ALLOW,
            cwd: Some(r.repo_dir),
            add_dirs: &[&dir],
        },
    };
    let stage = format!("dev-check-r{}", r.round);
    finish(r, agent, &req, &check_rules, &stage, env, github_output)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_allowlist_adds_the_consumer_commands_to_the_plain_git_commands() {
        // exactly the file tools and the git commands of a commit: no wider git (checkout, reset,
        // clean, push) and no rm
        assert_eq!(
            allowlist("", "").unwrap(),
            [
                "Read",
                "Edit",
                "Write",
                "Grep",
                "Glob",
                "Bash(git add:*)",
                "Bash(git commit:*)",
                "Bash(git status:*)",
                "Bash(git diff:*)",
                "Bash(git log:*)",
                "Bash(git rm:*)",
            ]
        );
        let a = allowlist("npm run check", "npm test").unwrap();
        assert_eq!(a.len(), 13);
        assert!(a.ends_with(&["Bash(npm run check:*)".into(), "Bash(npm test:*)".into()]));
    }

    #[test]
    fn a_command_that_could_widen_its_rule_is_refused() {
        for bad in [
            "npm test \"x\"",
            "npm $X",
            "npm `x`",
            "npm \\x",
            "npm\ntest",
        ] {
            assert!(allowlist(bad, "").is_err(), "{bad:?}");
            assert!(allowlist("", bad).is_err(), "{bad:?}");
        }
    }

    #[test]
    fn the_prompts_are_embedded_and_the_schemas_forbid_other_keys() {
        assert!(EXECUTE_PROMPT.starts_with("# Development execution"));
        assert!(CHECK_PROMPT.starts_with("# Development check"));
        assert_eq!(execute_schema()["additionalProperties"], false);
        assert_eq!(
            check_schema()["properties"]["findings"]["items"]["additionalProperties"],
            false
        );
    }

    #[test]
    fn the_execute_prompt_says_a_denied_command_is_no_reason_to_stop() {
        // a run on aif-c01-study #1 (39845118368) stopped as blocked after one denied `git -C ... &&`
        let rule = EXECUTE_PROMPT
            .lines()
            .skip_while(|l| !l.contains("A denied command"))
            .take_while(|l| !l.trim().is_empty() && !l.starts_with("- If a step"))
            .flat_map(str::split_whitespace)
            .collect::<Vec<_>>()
            .join(" ");
        assert!(rule.contains("run it again on its own"), "{rule:?}");
        assert!(
            rule.contains("is not a reason to report `blocked`"),
            "{rule:?}"
        );
        // a command the list does not hold has no other form, so it stays a blocked case (#102 review)
        assert!(!rule.contains("a command not listed"), "{rule:?}");
        assert!(
            rule.contains("A command that is not listed stays a `blocked` case"),
            "{rule:?}"
        );
    }

    #[test]
    fn a_check_verdict_and_its_findings_must_agree() {
        assert!(check_rules(&json!({"verdict": "pass", "findings": []})).is_empty());
        assert!(
            check_rules(
                &json!({"verdict": "fail", "findings": [{"criterion": 1, "problem": "x"}]})
            )
            .is_empty()
        );
        assert_eq!(
            check_rules(&json!({"verdict": "fail", "findings": []})).len(),
            1
        );
        assert_eq!(
            check_rules(
                &json!({"verdict": "pass", "findings": [{"criterion": 1, "problem": "x"}]})
            )
            .len(),
            1
        );
    }
}
