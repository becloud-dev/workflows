//! The gate of `dev-execute`: whether an `/approve` comment starts an execution, and against which
//! plan comment. It runs no model and no consumer command, and it pins the plan it read (comment
//! ID and body hash) so that publish can refuse a plan the rounds wrote or edited later (#65).

use crate::github::Gh;
use anyhow::{Context, Result};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::io::Write;
use std::path::Path;

const PLAN_MARKER: &str = "<!-- dev-plan -->";
const BOT: &str = "github-actions[bot]";

/// An approved execution: where it goes and the plan it was approved against.
#[derive(Debug, PartialEq, Eq)]
pub struct Approved {
    pub ctype: &'static str,
    pub branch: String,
    pub plan_body: String,
    pub plan_url: String,
    pub plan_comment_id: u64,
    pub plan_sha256: String,
}

#[derive(Debug, PartialEq, Eq)]
pub enum Gate {
    /// No execution; the text is posted on the issue.
    Stop(String),
    Go(Box<Approved>),
}

/// The lower-case hex SHA-256 of a plan comment body.
pub fn sha256_hex(text: &str) -> String {
    Sha256::digest(text.as_bytes())
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

/// The branch name part of a title: lower case, runs of other characters become one `-`, at most
/// 40 characters, no `-` at either end; `change` when nothing is left.
pub fn slug(title: &str) -> String {
    let mut s = String::new();
    for c in title.to_lowercase().chars() {
        if c.is_ascii_lowercase() || c.is_ascii_digit() {
            s.push(c);
        } else if !s.ends_with('-') {
            s.push('-');
        }
    }
    let s = s.trim_matches('-');
    let s = s[..s.len().min(40)].trim_end_matches('-');
    if s.is_empty() { "change" } else { s }.to_string()
}

/// Decides the approval. `branch_exists` is asked last, only for a branch that would be created.
pub fn decide(
    comment_body: &str,
    issue: &Value,
    comments: &[Value],
    owners: &str,
    branch_exists: impl FnOnce(&str) -> Result<bool>,
) -> Result<Gate> {
    let first = comment_body
        .lines()
        .next()
        .unwrap_or("")
        .trim_end_matches('\r');
    if first != "/approve" {
        return Ok(Gate::Stop(
            "No execution: the first line of the comment must be exactly `/approve`.".into(),
        ));
    }
    let has_release = issue["labels"]
        .as_array()
        .is_some_and(|l| l.iter().any(|l| l["name"] == "RELEASE"));
    if !has_release {
        return Ok(Gate::Stop(
            "No execution: this issue does not carry `RELEASE`.".into(),
        ));
    }
    let kind = issue["type"]["name"].as_str().unwrap_or("");
    if kind == "Project" {
        return Ok(Gate::Stop(
            "An execution applies to the sub-issues of a Project, not to the Project itself."
                .into(),
        ));
    }
    let author = issue["user"]["login"].as_str().unwrap_or("").to_lowercase();
    let owner_ok = owners
        .to_lowercase()
        .split(',')
        .chain(std::iter::once(BOT))
        .any(|o| o == author);
    if !owner_ok {
        return Ok(Gate::Stop(
            "No execution: this issue was not written by an owner or by the automation.".into(),
        ));
    }
    let plan = comments.iter().rev().find(|c| {
        c["user"]["login"] == BOT
            && c["body"]
                .as_str()
                .is_some_and(|b| b.starts_with(PLAN_MARKER))
    });
    let Some(plan) = plan else {
        return Ok(Gate::Stop(
            "No execution: there is no development plan comment on this issue. Add `RELEASE` to get one."
                .into(),
        ));
    };
    let ctype = match kind {
        "Bug" => "fix",
        "Feature" => "feat",
        _ => "chore",
    };
    let number = issue["number"]
        .as_u64()
        .context("the issue has no number")?;
    let branch = format!(
        "{ctype}/{number}-{}",
        slug(issue["title"].as_str().unwrap_or(""))
    );
    if branch_exists(&branch)? {
        return Ok(Gate::Stop(format!(
            "No execution: the branch `{branch}` already exists. Delete it or continue there by hand."
        )));
    }
    let body = plan["body"].as_str().unwrap_or("").to_string();
    Ok(Gate::Go(Box::new(Approved {
        ctype,
        branch,
        plan_sha256: sha256_hex(&body),
        plan_body: body,
        plan_url: plan["html_url"].as_str().unwrap_or("").to_string(),
        plan_comment_id: plan["id"].as_u64().context("the plan comment has no id")?,
    })))
}

/// Reads the issue and its comments, decides, posts the reason when there is none, writes the plan
/// to `plan_file` and the outputs (`key=value` lines) to `github_output`. `Ok(true)` also for a
/// stop: a refused approval is an answer, not a failure of the step.
pub fn run(
    gh: &Gh,
    repo: &str,
    issue_number: u64,
    comment_body: &str,
    owners: &str,
    plan_file: &Path,
    github_output: &Path,
) -> Result<bool> {
    let mut out = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(github_output)
        .with_context(|| format!("cannot open {}", github_output.display()))?;
    // a comment that is not exactly /approve needs no API read to be refused
    let first = comment_body
        .lines()
        .next()
        .unwrap_or("")
        .trim_end_matches('\r');
    let (issue, comments) = if first == "/approve" {
        (
            gh.get(&format!("repos/{repo}/issues/{issue_number}"))?,
            gh.list(&format!(
                "repos/{repo}/issues/{issue_number}/comments?per_page=100"
            ))?,
        )
    } else {
        (Value::Null, Vec::new())
    };
    let gate = decide(comment_body, &issue, &comments, owners, |branch| {
        gh.exists(&format!("repos/{repo}/git/ref/heads/{branch}"))
    })?;
    match gate {
        Gate::Stop(reason) => {
            gh.comment(repo, issue_number, &reason)?;
            writeln!(out, "ok=false")?;
        }
        Gate::Go(a) => {
            std::fs::write(plan_file, &a.plan_body)
                .with_context(|| format!("cannot write {}", plan_file.display()))?;
            writeln!(out, "ok=true")?;
            writeln!(out, "ctype={}", a.ctype)?;
            writeln!(out, "branch={}", a.branch)?;
            writeln!(out, "plan_file={}", plan_file.display())?;
            writeln!(out, "plan_url={}", a.plan_url)?;
            writeln!(out, "plan_comment_id={}", a.plan_comment_id)?;
            writeln!(out, "plan_sha256={}", a.plan_sha256)?;
        }
    }
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn issue() -> Value {
        json!({
            "number": 13, "title": "Add a --help flag!", "user": {"login": "bentoluizv"},
            "labels": [{"name": "RELEASE"}], "type": {"name": "Feature"}
        })
    }

    fn plan(id: u64, login: &str, body: &str) -> Value {
        json!({"id": id, "user": {"login": login}, "body": body, "html_url": format!("https://x/{id}")})
    }

    fn go(body: &str, issue: &Value, comments: &[Value], owners: &str) -> Gate {
        decide(body, issue, comments, owners, |_| Ok(false)).unwrap()
    }

    fn stop(g: Gate) -> String {
        match g {
            Gate::Stop(t) => t,
            Gate::Go(_) => panic!("expected a stop"),
        }
    }

    #[test]
    fn approves_and_pins_the_last_plan_comment_of_the_bot() {
        let comments = [
            plan(1, BOT, "<!-- dev-plan -->\nold"),
            plan(2, "someone", "<!-- dev-plan -->\nforged"),
            plan(3, BOT, "<!-- dev-plan -->\n**Files**\n- `a`\n"),
        ];
        match go("/approve", &issue(), &comments, "bentoluizv") {
            Gate::Go(a) => {
                assert_eq!(a.branch, "feat/13-add-a-help-flag");
                assert_eq!(a.plan_comment_id, 3);
                assert_eq!(
                    a.plan_sha256,
                    sha256_hex("<!-- dev-plan -->\n**Files**\n- `a`\n")
                );
                assert_eq!(a.plan_url, "https://x/3");
            }
            Gate::Stop(t) => panic!("{t}"),
        }
    }

    #[test]
    fn a_comment_that_is_not_exactly_approve_is_answered_with_the_rule() {
        let t = stop(go("/approved", &issue(), &[], "bentoluizv"));
        assert!(t.contains("exactly `/approve`"), "{t}");
    }

    #[test]
    fn a_crlf_first_line_and_a_second_line_are_accepted() {
        let comments = [plan(1, BOT, "<!-- dev-plan -->")];
        assert!(matches!(
            go("/approve\r\nplease", &issue(), &comments, "bentoluizv"),
            Gate::Go(_)
        ));
    }

    #[test]
    fn stops_without_release_for_a_project_and_for_a_stranger() {
        let comments = [plan(1, BOT, "<!-- dev-plan -->")];
        let mut i = issue();
        i["labels"] = json!([]);
        assert!(stop(go("/approve", &i, &comments, "bentoluizv")).contains("`RELEASE`"));
        let mut i = issue();
        i["type"] = json!({"name": "Project"});
        assert!(stop(go("/approve", &i, &comments, "bentoluizv")).contains("Project"));
        let mut i = issue();
        i["user"]["login"] = json!("stranger");
        assert!(
            stop(go("/approve", &i, &comments, "bentoluizv"))
                .contains("owner or by the automation")
        );
    }

    #[test]
    fn an_owners_entry_must_equal_the_login_and_empty_owners_refuse() {
        let comments = [plan(1, BOT, "<!-- dev-plan -->")];
        let mut i = issue();
        i["user"]["login"] = json!("BentoLuizV");
        assert!(matches!(
            go("/approve", &i, &comments, "bentoluizv"),
            Gate::Go(_)
        ));
        assert!(matches!(
            go("/approve", &i, &comments, "bentoluiz"),
            Gate::Stop(_)
        ));
        assert!(matches!(go("/approve", &i, &comments, ""), Gate::Stop(_)));
    }

    #[test]
    fn stops_without_a_plan_comment_by_the_bot() {
        let comments = [plan(1, "someone", "<!-- dev-plan -->")];
        assert!(
            stop(go("/approve", &issue(), &comments, "bentoluizv")).contains("no development plan")
        );
    }

    #[test]
    fn stops_when_the_branch_exists() {
        let comments = [plan(1, BOT, "<!-- dev-plan -->")];
        let g = decide("/approve", &issue(), &comments, "bentoluizv", |_| Ok(true)).unwrap();
        assert!(stop(g).contains("`feat/13-add-a-help-flag` already exists"));
    }

    #[test]
    fn the_branch_type_follows_the_issue_type() {
        let comments = [plan(1, BOT, "<!-- dev-plan -->")];
        for (kind, want) in [("Bug", "fix/13-"), ("Task", "chore/13-"), ("", "chore/13-")] {
            let mut i = issue();
            i["type"] = if kind.is_empty() {
                Value::Null
            } else {
                json!({"name": kind})
            };
            match go("/approve", &i, &comments, "bentoluizv") {
                Gate::Go(a) => assert!(a.branch.starts_with(want), "{}", a.branch),
                Gate::Stop(t) => panic!("{t}"),
            }
        }
    }

    #[test]
    fn the_slug_is_cleaned_cut_and_never_empty() {
        assert_eq!(slug("  Fix: the X/Y thing!! "), "fix-the-x-y-thing");
        assert_eq!(slug("!!!"), "change");
        let cut = slug("abcdefghij abcdefghij abcdefghij abcdefghij abc");
        assert_eq!(cut, "abcdefghij-abcdefghij-abcdefghij-abcdefg");
        // the cut falls on the separator: no trailing `-`
        assert_eq!(slug(&format!("{} -tail", "a".repeat(39))), "a".repeat(39));
    }
}
