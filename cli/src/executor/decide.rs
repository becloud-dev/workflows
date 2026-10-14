//! What a run publishes, from the last round that produced a result: a pull request when it passed
//! and left commits, a draft when it failed and left commits, a comment otherwise. For a pull
//! request or a draft, the commits from the base to HEAD are bundled from a fresh bare git dir, so
//! the hooks and config the rounds left in the checkout's `.git` do not run.

use anyhow::{Context, Result, bail};
use std::io::Write;
use std::path::Path;
use std::process::{Command, Stdio};

/// The outputs of one round step; empty when the round did not run.
#[derive(Debug, Default, Clone)]
pub struct Round {
    pub outcome: String,
    pub verdict: String,
    pub findings: String,
}

#[derive(Debug, PartialEq, Eq)]
pub struct Decision {
    /// pr, draft or comment.
    pub action: &'static str,
    pub outcome: String,
    pub verdict: String,
    pub findings: String,
    pub rounds: usize,
}

/// The decision for the rounds in order, with `ahead` commits between the base and HEAD.
pub fn decide(rounds: &[Round], ahead: u64) -> Decision {
    let mut d = Decision {
        action: "comment",
        outcome: "none".into(),
        verdict: "none".into(),
        findings: String::new(),
        rounds: 0,
    };
    for (n, r) in rounds.iter().enumerate() {
        if r.outcome.is_empty() {
            continue;
        }
        d.outcome = r.outcome.clone();
        d.verdict = r.verdict.clone();
        d.findings = r.findings.clone();
        d.rounds = n + 1;
    }
    if d.outcome == "done" && ahead > 0 {
        d.action = if d.verdict == "pass" { "pr" } else { "draft" };
    }
    d
}

fn git(dir: &Path, git_dir: Option<&Path>, args: &[&str]) -> Result<std::process::Output> {
    let mut cmd = Command::new("git");
    cmd.current_dir(dir)
        .env("GIT_CONFIG_GLOBAL", "/dev/null")
        .env("GIT_CONFIG_NOSYSTEM", "1")
        .stdin(Stdio::null());
    if let Some(g) = git_dir {
        cmd.env("GIT_DIR", g);
    }
    let out = cmd.args(args).output()?;
    if !out.status.success() {
        bail!(
            "git {} failed: {}",
            args.join(" "),
            String::from_utf8_lossy(&out.stderr).trim()
        );
    }
    Ok(out)
}

/// Writes `bundle` with the commits from `base` to HEAD of the checkout at `repo_dir`, fetched
/// first into a fresh bare git dir under `work_dir`.
pub fn bundle(repo_dir: &Path, work_dir: &Path, base: &str, bundle: &Path) -> Result<()> {
    // a new directory each time, as the shell step's mktemp -d was
    let src = (0..)
        .map(|n| work_dir.join(format!("bundle-src.{}.{n}", std::process::id())))
        .find(|p| !p.exists())
        .context("no free directory name for the bundle source")?;
    std::fs::create_dir_all(&src)?;
    git(
        work_dir,
        None,
        &["init", "-q", "--bare", &src.to_string_lossy()],
    )?;
    let src = src.as_path();
    let repo = repo_dir.canonicalize()?;
    // the checkout is a shallow clone; without --update-shallow the fetch refuses the ref and exits 0
    git(
        work_dir,
        Some(src),
        &[
            "fetch",
            "-q",
            "--update-shallow",
            &repo.to_string_lossy(),
            "HEAD:refs/push/head",
        ],
    )?;
    if let Some(parent) = bundle.parent() {
        std::fs::create_dir_all(parent)?;
    }
    git(
        work_dir,
        Some(src),
        &[
            "bundle",
            "create",
            &bundle.to_string_lossy(),
            "refs/push/head",
            &format!("^{base}"),
        ],
    )?;
    Ok(())
}

/// Decides, bundles a pull request or draft into `work_dir/bundle/publish.bundle`, and appends
/// `action`, `outcome`, `verdict`, `findings_file`, `rounds` and `ahead` to `github_output`.
pub fn run(
    repo_dir: &Path,
    work_dir: &Path,
    base: &str,
    rounds: &[Round],
    github_output: &Path,
) -> Result<bool> {
    let ahead: u64 = String::from_utf8_lossy(
        &git(
            repo_dir,
            None,
            &["rev-list", "--count", &format!("{base}..HEAD")],
        )?
        .stdout,
    )
    .trim()
    .parse()
    .context("git rev-list --count did not print a number")?;
    let d = decide(rounds, ahead);
    if d.action != "comment" {
        bundle(
            repo_dir,
            work_dir,
            base,
            &work_dir.join("bundle/publish.bundle"),
        )?;
    }
    let mut out = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(github_output)
        .with_context(|| format!("cannot open {}", github_output.display()))?;
    writeln!(out, "action={}", d.action)?;
    writeln!(out, "outcome={}", d.outcome)?;
    writeln!(out, "verdict={}", d.verdict)?;
    writeln!(out, "findings_file={}", d.findings)?;
    writeln!(out, "rounds={}", d.rounds)?;
    writeln!(out, "ahead={ahead}")?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn r(outcome: &str, verdict: &str, findings: &str) -> Round {
        Round {
            outcome: outcome.into(),
            verdict: verdict.into(),
            findings: findings.into(),
        }
    }

    #[test]
    fn the_last_round_that_ran_decides() {
        let d = decide(&[r("done", "pass", "/r1")], 1);
        assert_eq!((d.action, d.rounds), ("pr", 1));
        let d = decide(
            &[
                r("done", "fail", "/r1"),
                r("done", "fail", "/r2"),
                r("done", "fail", "/r3"),
            ],
            1,
        );
        assert_eq!(
            (d.action, d.rounds, d.findings.as_str()),
            ("draft", 3, "/r3")
        );
        let d = decide(
            &[
                r("done", "fail", "/r1"),
                r("done", "pass", "/r2"),
                r("", "", ""),
            ],
            2,
        );
        assert_eq!((d.action, d.rounds), ("pr", 2));
    }

    #[test]
    fn anything_but_a_done_round_with_commits_is_a_comment() {
        for (rounds, ahead) in [
            (vec![r("blocked", "none", "/r1")], 1),
            (vec![r("failed", "none", "/r1")], 1),
            (
                vec![r("done", "fail", "/r1"), r("blocked", "none", "/r2")],
                1,
            ),
            (vec![r("done", "pass", "/r1")], 0),
        ] {
            assert_eq!(
                decide(&rounds, ahead).action,
                "comment",
                "{rounds:?} {ahead}"
            );
        }
        let d = decide(&[r("", "", ""), r("", "", ""), r("", "", "")], 0);
        assert_eq!(
            (d.action, d.outcome.as_str(), d.rounds),
            ("comment", "none", 0)
        );
    }
}
