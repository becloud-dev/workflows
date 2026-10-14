//! The backlog planner (review of #74). The CLI builds the input from the open issues with their
//! relations; an order call ranks the issues and a duplicate call finds duplicates; the CLI
//! enforces the rules on both outputs, renders the report and records the run. It writes nothing
//! on GitHub.

pub mod input;
pub mod render;
pub mod rules;

pub use input::{Input, Issue, RANKED_LIMIT, Ref, Relations, build, fetch, tier};

use crate::agent::{Agent, Request};
use crate::github::Gh;
use crate::record::RunRecord;
use anyhow::{Context, Result};
use rules::{Duplicates, Order};
use serde_json::{Value, json};
use std::path::Path;

pub const STAGE: &str = "planner-backlog";
const ORDER_PROMPT: &str = include_str!("../../../../prompts/planner-backlog-order.md");
const DUPLICATES_PROMPT: &str = include_str!("../../../../prompts/planner-backlog-duplicates.md");

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

fn duplicates_schema() -> Value {
    json!({
        "type": "object",
        "additionalProperties": false,
        "properties": {
            "duplicates": {"type": "array", "items": {
                "type": "object",
                "additionalProperties": false,
                "properties": {
                    "number": {"type": "integer"},
                    "duplicate_of": {"type": "integer"},
                    "evidence": {"type": "string"}
                },
                "required": ["number", "duplicate_of", "evidence"]
            }}
        },
        "required": ["duplicates"]
    })
}

/// What a run leaves in `out`: the input, the run record and, when both calls pass, the report.
pub struct Paths;
impl Paths {
    pub const INPUT: &str = "backlog.json";
    pub const REPORT: &str = "backlog-report.json";
    pub const SUMMARY: &str = "summary.md";
}

/// Runs the step. Returns false, with every reason on stderr, when a call is refused after its
/// retry; the run record is written either way.
pub fn run(
    agent: &Agent,
    gh: &Gh,
    repo: &str,
    model: &str,
    out: &Path,
    env: &[(String, String)],
) -> Result<bool> {
    std::fs::create_dir_all(out).with_context(|| format!("cannot create {}", out.display()))?;
    let input = fetch(gh, repo)?;
    std::fs::write(out.join(Paths::INPUT), serde_json::to_vec_pretty(&input)?)?;
    let mut record = RunRecord::new(STAGE, model, "backlog", env);
    let mut failures: Vec<String> = Vec::new();

    let order: Option<Order> = if input.issues.is_empty() {
        Some(Order {
            order: vec![],
            summary: "No issue with a priority to order.".into(),
        })
    } else {
        let files = [(
            "order-input.json",
            serde_json::to_vec_pretty(
                &json!({"truncated": input.truncated, "issues": input.issues}),
            )?,
        )];
        let outcome = agent.call(
            &Request {
                role: "order",
                model,
                prompt: ORDER_PROMPT,
                schema: &order_schema(),
                files: &files,
            },
            &|o| rules::order_rules(&input, o),
        )?;
        record.add(&outcome.attempts);
        match outcome.output {
            Ok(v) => Some(serde_json::from_value(v)?),
            Err(reasons) => {
                failures.extend(reasons.into_iter().map(|r| format!("order: {r}")));
                None
            }
        }
    };

    let candidates: Vec<Value> = rules::all_issues(&input)
        .map(|i| json!({"number": i.number, "title": i.title, "priority": i.priority, "body": i.body}))
        .collect();
    let duplicates: Option<Duplicates> = if candidates.len() < 2 {
        Some(Duplicates { duplicates: vec![] })
    } else {
        let files = [(
            "duplicates-input.json",
            serde_json::to_vec_pretty(&json!({"issues": candidates}))?,
        )];
        let outcome = agent.call(
            &Request {
                role: "duplicates",
                model,
                prompt: DUPLICATES_PROMPT,
                schema: &duplicates_schema(),
                files: &files,
            },
            &|o| rules::duplicate_rules(&input, o),
        )?;
        record.add(&outcome.attempts);
        match outcome.output {
            Ok(v) => Some(serde_json::from_value(v)?),
            Err(reasons) => {
                failures.extend(reasons.into_iter().map(|r| format!("duplicates: {r}")));
                None
            }
        }
    };

    record.ok = failures.is_empty();
    record.write(out)?;
    let (Some(order), Some(duplicates)) = (order, duplicates) else {
        for f in &failures {
            eprintln!("refused after the retry: {f}");
        }
        return Ok(false);
    };
    let conflicts = rules::conflicts(&input);
    let report = render::Report {
        input: &input,
        order: &order,
        duplicates: &duplicates,
        conflicts: &conflicts,
    };
    std::fs::write(out.join(Paths::REPORT), serde_json::to_vec_pretty(&report)?)?;
    std::fs::write(out.join(Paths::SUMMARY), render::markdown(&report))?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_schemas_are_valid_and_refuse_extra_keys() {
        for schema in [order_schema(), duplicates_schema()] {
            let v = jsonschema::validator_for(&schema).unwrap();
            assert!(
                !v.is_valid(&json!({"order": [], "duplicates": [], "summary": "", "extra": 1}))
            );
        }
    }

    #[test]
    fn the_prompts_are_embedded() {
        assert!(ORDER_PROMPT.contains("order-input.json"));
        assert!(DUPLICATES_PROMPT.contains("duplicates-input.json"));
    }
}
