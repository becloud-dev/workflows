//! The check publish makes before it pushes anything: the plan comment is read again, by the ID
//! the gate pinned, and must be byte-for-byte the one that was approved; only then is the bundle's
//! diff judged against its **Files** list. The rounds job can post and edit comments as the bot
//! (#65), so neither the comment's author nor its marker proves anything; the pin does.

use super::gate::sha256_hex;
use super::{plan, scope};
use crate::github::Gh;
use anyhow::{Context, Result};
use serde_json::Value;
use std::io::Write;
use std::path::Path;

const PLAN_MARKER: &str = "<!-- dev-plan -->";
const BOT: &str = "github-actions[bot]";

/// What the gate recorded about the plan it approved.
pub struct Pin<'a> {
    pub comment_id: u64,
    pub sha256: &'a str,
}

/// The reasons not to take `comment`, as read now, for the plan the gate approved; empty when it
/// is that plan, byte for byte.
pub fn pin_refusals(comment: &Value, repo: &str, issue: u64, pin: &Pin) -> Vec<String> {
    let body = comment["body"].as_str().unwrap_or("");
    let mut refusals = Vec::new();
    if comment["id"].as_u64() != Some(pin.comment_id) {
        refusals.push("the plan comment is not the one that was approved".to_string());
    }
    let on_issue = format!("repos/{repo}/issues/{issue}");
    if !comment["issue_url"]
        .as_str()
        .is_some_and(|u| u.ends_with(&on_issue))
    {
        refusals.push(format!("the plan comment is not on issue #{issue}"));
    }
    if comment["user"]["login"] != BOT || !body.starts_with(PLAN_MARKER) {
        refusals.push(
            "the plan comment is not a development plan written by the automation".to_string(),
        );
    }
    if sha256_hex(body) != pin.sha256 {
        refusals.push("the plan comment was changed after it was approved".to_string());
    }
    refusals
}

/// The reasons to refuse the publication; empty when the bundle may be pushed. `comment` is the
/// plan comment as read now, `changes` the bundle's (deleted, workflow-changed) paths.
pub fn check(
    comment: &Value,
    repo: &str,
    issue: u64,
    pin: &Pin,
    changes: Option<(Vec<String>, Vec<String>)>,
) -> Vec<String> {
    let body = comment["body"].as_str().unwrap_or("");
    let refusals = pin_refusals(comment, repo, issue, pin);
    if !refusals.is_empty() {
        // the plan cannot be trusted, so nothing is judged against its Files list
        return refusals;
    }
    let files = match plan::files(body) {
        Ok(f) => f,
        Err(_) => return vec!["the plan has no **Files** heading".to_string()],
    };
    let Some((deleted, changed)) = changes else {
        return vec!["the changes in the bundle could not be read".to_string()];
    };
    scope::check(Some(&files), &deleted, &changed, &[])
        .violations
        .into_iter()
        .map(|(path, kind)| match kind {
            scope::Kind::Deleted => {
                format!("deleted but not named in the plan Files list: {path}")
            }
            scope::Kind::Changed => {
                format!(
                    "changed under .github/workflows but not named in the plan Files list: {path}"
                )
            }
            // publish-check passes no implementer test paths, so this kind never arises here
            scope::Kind::Test => unreachable!("publish-check does not check implementer tests"),
        })
        .collect()
}

/// Reads the pinned plan comment for the rounds job, which starts on another runner after the gate:
/// writes its body to `plan_file` when it is still the approved plan, otherwise prints each
/// refusal as an error annotation and returns `Ok(false)`, so no round runs on another plan.
pub fn read_pinned(gh: &Gh, repo: &str, issue: u64, pin: &Pin, plan_file: &Path) -> Result<bool> {
    let comment = gh.get(&format!("repos/{repo}/issues/comments/{}", pin.comment_id))?;
    let refusals = pin_refusals(&comment, repo, issue, pin);
    for r in &refusals {
        println!("::error::{r}");
    }
    if refusals.is_empty() {
        std::fs::write(plan_file, comment["body"].as_str().unwrap_or(""))
            .with_context(|| format!("cannot write {}", plan_file.display()))?;
    }
    Ok(refusals.is_empty())
}

/// Whether pushing these changes needs the workflows permission: a path under
/// `.github/workflows/` is deleted, added or modified.
pub fn touches_workflows(deleted: &[String], changed: &[String]) -> bool {
    deleted
        .iter()
        .chain(changed)
        .any(|p| p.starts_with(".github/workflows/"))
}

/// Reads the pinned comment, reads the bundle's diff from `git_dir` (the tip is `refs/push/head`),
/// prints each refusal as an error annotation. `Ok(false)` when anything is refused. When accepted,
/// appends `workflows=true|false` to `github_output`, so the token asks for the workflows
/// permission only when the push needs it.
pub fn run(
    gh: &Gh,
    repo: &str,
    issue: u64,
    pin: &Pin,
    base: &str,
    git_dir: &Path,
    github_output: &Path,
) -> Result<bool> {
    let comment = gh.get(&format!("repos/{repo}/issues/comments/{}", pin.comment_id))?;
    let changes = scope::changes(&scope::Repo::GitDir(git_dir), base, "refs/push/head");
    let workflows = changes
        .as_ref()
        .is_some_and(|(d, c)| touches_workflows(d, c));
    let refusals = check(&comment, repo, issue, pin, changes);
    for r in &refusals {
        println!("::error::{r}");
    }
    if refusals.is_empty() {
        let mut out = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(github_output)
            .with_context(|| format!("cannot open {}", github_output.display()))?;
        writeln!(out, "workflows={workflows}")?;
    }
    Ok(refusals.is_empty())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    const PLAN: &str = "<!-- dev-plan -->\n**Files**\n- `src/a.rs`\n- `docs/`\n";

    fn comment(body: &str) -> Value {
        json!({"id": 41, "user": {"login": BOT}, "body": body,
               "issue_url": "https://api.github.com/repos/o/r/issues/13"})
    }

    fn pin(body: &str) -> String {
        sha256_hex(body)
    }

    fn judge(c: &Value, p: &str, changes: Option<(Vec<String>, Vec<String>)>) -> Vec<String> {
        check(
            c,
            "o/r",
            13,
            &Pin {
                comment_id: 41,
                sha256: p,
            },
            changes,
        )
    }

    fn v(p: &[&str]) -> Vec<String> {
        p.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn only_a_path_under_the_workflows_directory_needs_the_workflows_permission() {
        assert!(touches_workflows(&v(&[".github/workflows/old.yml"]), &[]));
        assert!(touches_workflows(&[], &v(&[".github/workflows/ci.yml"])));
        assert!(!touches_workflows(&v(&["src/a.rs"]), &v(&[])));
        assert!(!touches_workflows(
            &v(&[".github/workflowsx/a"]),
            &v(&[".github/actions/x/action.yml"])
        ));
    }

    #[test]
    fn the_approved_plan_with_named_changes_is_published() {
        let c = comment(PLAN);
        let r = judge(&c, &pin(PLAN), Some((v(&["src/a.rs"]), v(&[]))));
        assert!(r.is_empty(), "{r:?}");
    }

    #[test]
    fn a_plan_edited_after_the_approval_is_refused_even_if_it_now_names_the_change() {
        let forged = format!("{PLAN}- `.github/workflows/evil.yml`\n");
        let r = judge(
            &comment(&forged),
            &pin(PLAN),
            Some((v(&[]), v(&[".github/workflows/evil.yml"]))),
        );
        assert_eq!(
            r,
            vec!["the plan comment was changed after it was approved"]
        );
    }

    #[test]
    fn a_reposted_plan_has_another_id_and_is_refused() {
        let mut c = comment(PLAN);
        c["id"] = json!(99);
        let r = judge(&c, &pin(PLAN), Some((v(&[]), v(&[]))));
        assert_eq!(r, vec!["the plan comment is not the one that was approved"]);
    }

    #[test]
    fn a_comment_of_another_issue_or_author_is_refused() {
        let mut c = comment(PLAN);
        c["issue_url"] = json!("https://api.github.com/repos/o/r/issues/14");
        assert!(
            judge(&c, &pin(PLAN), Some((v(&[]), v(&[]))))
                .iter()
                .any(|m| m.contains("#13"))
        );
        let mut c = comment(PLAN);
        c["user"]["login"] = json!("mallory");
        assert!(
            judge(&c, &pin(PLAN), Some((v(&[]), v(&[]))))
                .iter()
                .any(|m| m.contains("written by the automation"))
        );
    }

    #[test]
    fn a_change_the_plan_does_not_name_is_refused_with_its_path() {
        let c = comment(PLAN);
        let r = judge(
            &c,
            &pin(PLAN),
            Some((v(&["src/other.rs"]), v(&[".github/workflows/ci.yml"]))),
        );
        assert_eq!(
            r,
            vec![
                "deleted but not named in the plan Files list: src/other.rs",
                "changed under .github/workflows but not named in the plan Files list: .github/workflows/ci.yml"
            ]
        );
    }

    #[test]
    fn a_plan_without_files_or_an_unreadable_bundle_is_refused() {
        let body = "<!-- dev-plan -->\nno list\n";
        let r = judge(&comment(body), &pin(body), Some((v(&[]), v(&[]))));
        assert_eq!(r, vec!["the plan has no **Files** heading"]);
        let r = judge(&comment(PLAN), &pin(PLAN), None);
        assert_eq!(r, vec!["the changes in the bundle could not be read"]);
    }
}
