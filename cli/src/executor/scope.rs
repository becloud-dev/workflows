//! The scope check of a round: every deleted path, and every added, modified or renamed-to path
//! under `.github/workflows`, must be named in the plan's **Files** list. A path outside the list,
//! or a diff or plan that cannot be read, fails the round whatever the check model says.

use super::plan;
use anyhow::{Context, Result};
use serde_json::json;
use std::io::Write;
use std::path::Path;
use std::process::Command;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum State {
    /// Nothing was deleted and no workflow changed.
    None,
    Ok,
    OutOfScope,
    /// The plan, or one of the diffs, could not be read.
    Error,
}

impl State {
    pub fn as_str(self) -> &'static str {
        match self {
            State::None => "none",
            State::Ok => "ok",
            State::OutOfScope => "out_of_scope",
            State::Error => "error",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Deleted,
    Changed,
}

#[derive(Debug, PartialEq, Eq)]
pub struct Report {
    pub state: State,
    pub violations: Vec<(String, Kind)>,
}

/// Judges the diff against the plan. `files` is `None` when the plan could not be read.
pub fn check(files: Option<&[String]>, deleted: &[String], changed: &[String]) -> Report {
    let Some(files) = files else {
        return Report {
            state: State::Error,
            violations: Vec::new(),
        };
    };
    let mut violations = Vec::new();
    for d in deleted.iter().filter(|d| !plan::names(files, d)) {
        violations.push((d.clone(), Kind::Deleted));
    }
    for c in changed.iter().filter(|c| !plan::names(files, c)) {
        violations.push((c.clone(), Kind::Changed));
    }
    let state = if !violations.is_empty() {
        State::OutOfScope
    } else if !deleted.is_empty() || !changed.is_empty() {
        State::Ok
    } else {
        State::None
    };
    Report { state, violations }
}

/// Where the history to diff lives.
pub enum Repo<'a> {
    /// A working checkout.
    Checkout(&'a Path),
    /// A bare git directory, such as the one a bundle was fetched into.
    GitDir(&'a Path),
}

/// The paths `git diff` lists with `-z` for `args`; `None` when git fails. No global or system
/// git config is read, so the answer does not depend on the runner's or the rounds' settings.
fn diff_names(repo: &Repo, args: &[&str]) -> Option<Vec<String>> {
    let mut cmd = Command::new("git");
    match repo {
        Repo::Checkout(dir) => cmd.current_dir(dir),
        Repo::GitDir(dir) => cmd.arg("--git-dir").arg(dir),
    };
    let out = cmd
        .args(["diff", "--name-only", "--no-renames", "-z"])
        .args(args)
        .env("GIT_CONFIG_GLOBAL", "/dev/null")
        .env("GIT_CONFIG_NOSYSTEM", "1")
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    Some(
        out.stdout
            .split(|b| *b == 0)
            .filter(|p| !p.is_empty())
            .map(|p| String::from_utf8_lossy(p).into_owned())
            .collect(),
    )
}

/// The deleted paths, and the added or modified paths under `.github/workflows`, between `base`
/// and `tip` (a merge-base diff, as for a pull request); `None` when either diff cannot be read.
pub fn changes(repo: &Repo, base: &str, tip: &str) -> Option<(Vec<String>, Vec<String>)> {
    let range = format!("{base}...{tip}");
    let deleted = diff_names(repo, &["--diff-filter=D", &range])?;
    let changed = diff_names(
        repo,
        &["--diff-filter=AM", &range, "--", ".github/workflows"],
    )?;
    Some((deleted, changed))
}

/// What the round's results file gets for a report.
pub fn render(report: &Report) -> String {
    let mut s = format!("### scope check\nstate: {}\n", report.state.as_str());
    match report.state {
        State::Error => {
            s.push_str(
                "the deletions, the workflow changes or the plan Files list could not be read\n",
            );
        }
        State::OutOfScope => {
            let of = |k: Kind| -> Vec<&str> {
                report
                    .violations
                    .iter()
                    .filter(|(_, kind)| *kind == k)
                    .map(|(p, _)| p.as_str())
                    .collect()
            };
            for (kind, text) in [
                (
                    Kind::Deleted,
                    "deleted but not named in the plan Files list:",
                ),
                (
                    Kind::Changed,
                    "changed under .github/workflows but not named in the plan Files list:",
                ),
            ] {
                let paths = of(kind);
                if !paths.is_empty() {
                    s.push_str(text);
                    s.push('\n');
                    for p in paths {
                        s.push_str(&format!("- {p}\n"));
                    }
                }
            }
        }
        _ => {}
    }
    s.push('\n');
    s
}

/// Runs the check for the commits between `base` and HEAD of the repository at `repo_dir`, appends
/// the section to `results` and the outputs (`scope_state`, `scope_violations`,
/// `scope_violation_kinds`) to `github_output`.
pub fn run(
    repo_dir: &Path,
    base: &str,
    plan_file: &Path,
    results: &Path,
    github_output: &Path,
) -> Result<bool> {
    let files = std::fs::read_to_string(plan_file)
        .ok()
        .and_then(|plan| plan::files(&plan).ok());
    let report = match (files, changes(&Repo::Checkout(repo_dir), base, "HEAD")) {
        (Some(f), Some((d, c))) => check(Some(&f), &d, &c),
        _ => check(None, &[], &[]),
    };
    let mut r = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(results)
        .with_context(|| format!("cannot open {}", results.display()))?;
    r.write_all(render(&report).as_bytes())?;
    let paths: Vec<&str> = report.violations.iter().map(|(p, _)| p.as_str()).collect();
    let kinds: Vec<&str> = report
        .violations
        .iter()
        .map(|(_, k)| match k {
            Kind::Deleted => "deleted",
            Kind::Changed => "changed",
        })
        .collect();
    let mut out = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(github_output)
        .with_context(|| format!("cannot open {}", github_output.display()))?;
    writeln!(out, "scope_state={}", report.state.as_str())?;
    writeln!(out, "scope_violations={}", json!(paths))?;
    writeln!(out, "scope_violation_kinds={}", json!(kinds))?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn list(p: &[&str]) -> Vec<String> {
        p.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn a_deletion_and_a_workflow_change_must_each_be_named() {
        let files = list(&["src/old.rs", ".github/workflows/ci.yml"]);
        let r = check(
            Some(&files),
            &list(&["src/old.rs", "src/other.rs"]),
            &list(&[".github/workflows/ci.yml", ".github/workflows/new.yml"]),
        );
        assert_eq!(r.state, State::OutOfScope);
        assert_eq!(
            r.violations,
            vec![
                ("src/other.rs".to_string(), Kind::Deleted),
                (".github/workflows/new.yml".to_string(), Kind::Changed)
            ]
        );
    }

    #[test]
    fn named_paths_are_ok_and_an_empty_diff_is_none() {
        let files = list(&["docs/"]);
        assert_eq!(
            check(Some(&files), &list(&["docs/a.md"]), &[]).state,
            State::Ok
        );
        assert_eq!(check(Some(&files), &[], &[]).state, State::None);
    }

    #[test]
    fn an_unreadable_plan_is_an_error_not_a_pass() {
        assert_eq!(check(None, &list(&["x"]), &[]).state, State::Error);
    }

    #[test]
    fn the_section_names_deletions_and_workflow_changes_apart() {
        let r = check(
            Some(&[]),
            &list(&["a"]),
            &list(&[".github/workflows/b.yml"]),
        );
        let text = render(&r);
        assert!(text.contains("state: out_of_scope\n"));
        assert!(text.contains("deleted but not named in the plan Files list:\n- a\n"));
        assert!(text.contains(
            "changed under .github/workflows but not named in the plan Files list:\n- .github/workflows/b.yml\n"
        ));
    }
}
