//! The red check of a round: the test files the change added lines to must fail on the base tree.
//! The test command runs in a worktree of the base with those files taken from HEAD; a pass there
//! means the new tests do not pin the change, and the verdict fails the round.

use anyhow::{Context, Result};
use std::fs::File;
use std::io::Write;
use std::path::Path;
use std::process::{Command, Stdio};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum State {
    /// No test file with added lines, no test command or no test paths configured.
    None,
    Red,
    GreenOnBase,
    /// The diff, the worktree or the checkout of the test files failed.
    Error,
}

impl State {
    pub fn as_str(self) -> &'static str {
        match self {
            State::None => "none",
            State::Red => "red",
            State::GreenOnBase => "green_on_base",
            State::Error => "error",
        }
    }
}

/// A shell `case` pattern: `*` matches any string (`/` included), `?` one character, `[...]` one
/// character of a set (`!` or `^` negates, `a-z` ranges); anything else matches itself.
pub fn glob_match(pattern: &str, text: &str) -> bool {
    let p: Vec<char> = pattern.chars().collect();
    let t: Vec<char> = text.chars().collect();
    fn class(p: &[char], c: char) -> Option<(bool, usize)> {
        // p[0] is '['; returns (matched, length of the class) or None when it is not closed
        let mut i = 1;
        let negate = matches!(p.get(1), Some('!') | Some('^'));
        if negate {
            i += 1;
        }
        let mut matched = false;
        let mut first = true;
        while i < p.len() {
            if p[i] == ']' && !first {
                return Some((matched != negate, i + 1));
            }
            first = false;
            if i + 2 < p.len() && p[i + 1] == '-' && p[i + 2] != ']' {
                if p[i] <= c && c <= p[i + 2] {
                    matched = true;
                }
                i += 3;
            } else {
                if p[i] == c {
                    matched = true;
                }
                i += 1;
            }
        }
        None
    }
    fn go(p: &[char], t: &[char]) -> bool {
        match p.first() {
            None => t.is_empty(),
            Some('*') => (0..=t.len()).any(|k| go(&p[1..], &t[k..])),
            Some('?') => !t.is_empty() && go(&p[1..], &t[1..]),
            Some('[') => match (t.first(), class(p, *t.first().unwrap_or(&'\0'))) {
                (Some(_), Some((true, len))) => go(&p[len..], &t[1..]),
                (Some(_), Some((false, _))) => false,
                (None, _) => false,
                (Some(c), None) => *c == '[' && go(&p[1..], &t[1..]),
            },
            Some(c) => t.first() == Some(c) && go(&p[1..], &t[1..]),
        }
    }
    go(&p, &t)
}

/// The test files of the change: paths in `numstat` (`added<TAB>deleted<TAB>path` lines) with added
/// lines (a binary file, `-`, counts) that match one of the comma-separated `test_paths` globs.
pub fn test_files(numstat: &str, test_paths: &str) -> Vec<String> {
    let globs: Vec<&str> = test_paths.split(',').collect();
    numstat
        .lines()
        .filter_map(|line| {
            let mut parts = line.splitn(3, '\t');
            let added = parts.next()?;
            let _removed = parts.next()?;
            let path = parts.next()?;
            if path.is_empty() {
                return None;
            }
            let has_added = added == "-" || added.parse::<u64>().is_ok_and(|n| n > 0);
            (has_added && globs.iter().any(|g| glob_match(g, path))).then(|| path.to_string())
        })
        .collect()
}

fn git(dir: &Path, args: &[&str], log: &File) -> Result<bool> {
    Ok(Command::new("git")
        .current_dir(dir)
        .args(args)
        .stdin(Stdio::null())
        .stdout(log.try_clone()?)
        .stderr(log.try_clone()?)
        .status()?
        .success())
}

/// The last 30 lines of `text`, then its last 2000 bytes, without trailing newlines, as the shell
/// step's `$(tail -n 30 | tail -c 2000)` printed them.
fn tail(text: &str) -> String {
    let lines: Vec<&str> = text.lines().collect();
    let joined = lines[lines.len().saturating_sub(30)..].join("\n");
    let bytes = joined.as_bytes();
    let cut = &bytes[bytes.len().saturating_sub(2000)..];
    String::from_utf8_lossy(cut)
        .trim_end_matches('\n')
        .to_string()
}

/// Runs the check in `repo_dir` for the commits from `base` to HEAD, with the worktree and log in
/// `work_dir`; appends the section to `results` and `red_state` to `github_output`.
#[allow(clippy::too_many_arguments)]
pub fn run(
    repo_dir: &Path,
    work_dir: &Path,
    base: &str,
    test: &str,
    test_paths: &str,
    round: &str,
    results: &Path,
    github_output: &Path,
) -> Result<bool> {
    let mut state = State::None;
    let mut files = Vec::new();
    if !test.is_empty() && !test_paths.is_empty() {
        let out = Command::new("git")
            .current_dir(repo_dir)
            .args(["diff", "--numstat", "--no-renames", "--diff-filter=AMR"])
            .arg(format!("{base}...HEAD"))
            .stdin(Stdio::null())
            .output()?;
        if out.status.success() {
            files = test_files(&String::from_utf8_lossy(&out.stdout), test_paths);
        } else {
            state = State::Error;
        }
    }
    let section = if files.is_empty() {
        format!(
            "### red check\nstate: {} (no test file with added lines in the diff, not configured, or the diff failed)\n\n",
            state.as_str()
        )
    } else {
        let tree = work_dir.join(format!("base-tree-{round}"));
        let log_path = work_dir.join(format!("red-{round}.log"));
        let log = File::create(&log_path)
            .with_context(|| format!("cannot create {}", log_path.display()))?;
        let tree_s = tree.to_string_lossy().to_string();
        let head = String::from_utf8_lossy(
            &Command::new("git")
                .current_dir(repo_dir)
                .args(["rev-parse", "HEAD"])
                .output()?
                .stdout,
        )
        .trim()
        .to_string();
        let mut code = None;
        let mut checkout = vec!["-C", &tree_s, "checkout", &head, "--"];
        checkout.extend(files.iter().map(String::as_str));
        if git(
            repo_dir,
            &["worktree", "add", "--detach", &tree_s, base],
            &log,
        )? && git(repo_dir, &checkout, &log)?
        {
            let status = Command::new("bash")
                .current_dir(&tree)
                .args(["-c", test])
                .stdin(Stdio::null())
                .stdout(log.try_clone()?)
                .stderr(log.try_clone()?)
                .status()?;
            let c = status.code().unwrap_or(1);
            state = if c == 0 {
                State::GreenOnBase
            } else {
                State::Red
            };
            code = Some(c);
        } else {
            state = State::Error;
        }
        let _ = Command::new("git")
            .current_dir(repo_dir)
            .args(["worktree", "remove", "--force", &tree_s])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
        let text = std::fs::read_to_string(&log_path).unwrap_or_default();
        format!(
            "### red check\nstate: {}\ntest files: {}\nexit code on the base tree: {}\n```\n{}\n```\n\n",
            state.as_str(),
            files.join(" "),
            code.map_or("n/a".to_string(), |c| c.to_string()),
            tail(&text)
        )
    };
    let mut r = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(results)
        .with_context(|| format!("cannot open {}", results.display()))?;
    r.write_all(section.as_bytes())?;
    let mut out = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(github_output)
        .with_context(|| format!("cannot open {}", github_output.display()))?;
    writeln!(out, "red_state={}", state.as_str())?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn globs_match_as_a_shell_case_pattern_does() {
        assert!(glob_match("tests/*", "tests/a/b_test.sh"));
        assert!(glob_match("*_test.sh", "src/x_test.sh"));
        assert!(!glob_match("tests/*", "spec/a.sh"));
        assert!(glob_match("t?sts/*", "tests/a"));
        assert!(glob_match("tests/[ab]*", "tests/b.sh"));
        assert!(!glob_match("tests/[!ab]*", "tests/b.sh"));
        assert!(glob_match("tests/[a-c].sh", "tests/b.sh"));
        assert!(glob_match("a[b", "a[b"));
    }

    #[test]
    fn test_files_have_added_lines_and_match_a_glob() {
        let numstat = "3\t0\ttests/new_test.sh\n0\t5\ttests/trimmed_test.sh\n-\t-\ttests/data.bin\n2\t1\tsrc/code.rs\n1\t0\tspec/a_spec.sh\n";
        assert_eq!(
            test_files(numstat, "tests/*,spec/*"),
            vec!["tests/new_test.sh", "tests/data.bin", "spec/a_spec.sh"]
        );
        assert!(test_files(numstat, "docs/*").is_empty());
    }

    #[test]
    fn the_log_tail_keeps_the_last_30_lines_and_2000_bytes() {
        let text: String = (1..=40).map(|n| format!("line {n}\n")).collect();
        let t = tail(&text);
        assert!(t.starts_with("line 11\n") && t.ends_with("line 40"));
        assert!(tail(&"x".repeat(5000)).len() == 2000);
    }
}
