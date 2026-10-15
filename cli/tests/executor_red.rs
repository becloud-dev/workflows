//! The red check and the bundle against real git history, on a shallow clone (`--depth 1`), the
//! shape `actions/checkout` gives the rounds job: the cases of the shell suites they replace
//! (tests/dev-round-red, the bundle cases of tests/dev-execute).

use becloud_workflows::executor::{decide, red};
use std::path::{Path, PathBuf};
use std::process::Command;

fn git(dir: &Path, args: &[&str]) -> String {
    let out = Command::new("git")
        .current_dir(dir)
        .args(["-c", "user.email=t@t", "-c", "user.name=t"])
        .args(args)
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "git {args:?}: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    String::from_utf8(out.stdout).unwrap().trim().to_string()
}

fn write(dir: &Path, path: &str, text: &str) {
    let p = dir.join(path);
    std::fs::create_dir_all(p.parent().unwrap()).unwrap();
    std::fs::write(p, text).unwrap();
}

struct Clone {
    _root: tempfile::TempDir,
    dir: PathBuf,
    base: String,
}

/// An origin with `bin/greet` and a passing `tests/greet_test.sh`, cloned with depth 1; `change`
/// then commits in the clone.
fn clone(change: impl FnOnce(&Path)) -> Clone {
    let root = tempfile::tempdir().unwrap();
    let origin = root.path().join("origin");
    std::fs::create_dir_all(&origin).unwrap();
    git(&origin, &["init", "-q", "-b", "main"]);
    write(&origin, "bin/greet", "echo hi\n");
    write(
        &origin,
        "tests/greet_test.sh",
        "test \"$(sh bin/greet)\" = hi\n",
    );
    write(&origin, "tests/README.md", "notes\n");
    git(&origin, &["add", "-A"]);
    git(&origin, &["commit", "-q", "-m", "base"]);
    let url = format!("file://{}", origin.display());
    git(root.path(), &["clone", "-q", "--depth", "1", &url, "clone"]);
    let dir = root.path().join("clone");
    let base = git(&dir, &["rev-parse", "HEAD"]);
    change(&dir);
    Clone {
        _root: root,
        dir,
        base,
    }
}

fn commit(dir: &Path, msg: &str) {
    git(dir, &["add", "-A"]);
    git(dir, &["commit", "-q", "-m", msg]);
}

const TEST: &str = "for t in tests/*_test.sh; do sh \"$t\" || exit 1; done";

/// Runs the check; returns the state and the section it appended.
fn run(c: &Clone, test: &str, paths: &str, base: &str) -> (String, String) {
    let work = tempfile::tempdir().unwrap();
    let results = work.path().join("results.md");
    let out = work.path().join("output");
    assert!(red::run(&c.dir, work.path(), base, test, paths, "1", &results, &out).unwrap());
    let state = std::fs::read_to_string(out)
        .unwrap()
        .trim()
        .strip_prefix("red_state=")
        .unwrap()
        .to_string();
    let worktrees = git(&c.dir, &["worktree", "list"]);
    assert_eq!(worktrees.lines().count(), 1, "worktree left: {worktrees}");
    (state, std::fs::read_to_string(results).unwrap())
}

#[test]
fn a_new_test_without_the_implementation_is_red() {
    // the test-writer's commit only: the test expects a --shout the base greet does not have, and
    // no implementation is present, so the test command fails (red)
    let c = clone(|d| {
        write(
            d,
            "tests/shout_test.sh",
            "test \"$(sh bin/greet --shout)\" = HI\n",
        );
        commit(d, "test: shout");
    });
    let (state, text) = run(&c, TEST, "tests/*", &c.base);
    assert_eq!(state, "red");
    assert!(text.contains("test files: tests/shout_test.sh\n"), "{text}");
    assert!(
        text.contains("exit code without the implementation: 1\n"),
        "{text}"
    );
}

#[test]
fn a_new_test_that_passes_without_the_implementation_is_green_without_impl() {
    // a test that passes although no implementation was written does not pin the change
    let c = clone(|d| {
        write(d, "tests/exists_test.sh", "test -f bin/greet\n");
        commit(d, "test: exists");
    });
    assert_eq!(run(&c, TEST, "tests/*", &c.base).0, "green_without_impl");
}

#[test]
fn lines_added_to_an_existing_test_are_checked() {
    // a line added to an existing test, with no implementation: the new assertion fails (red)
    let c = clone(|d| {
        let p = d.join("tests/greet_test.sh");
        let mut t = std::fs::read_to_string(&p).unwrap();
        t.push_str("test \"$(sh bin/greet --shout)\" = HI\n");
        std::fs::write(p, t).unwrap();
        commit(d, "test: shout line");
    });
    assert_eq!(run(&c, TEST, "tests/*", &c.base).0, "red");
}

#[test]
fn nothing_to_check_is_none() {
    let code_only = clone(|d| {
        write(d, "bin/greet", "echo hello\n");
        commit(d, "feat: x");
    });
    assert_eq!(run(&code_only, TEST, "tests/*", &code_only.base).0, "none");
    let deleted = clone(|d| {
        std::fs::remove_file(d.join("tests/greet_test.sh")).unwrap();
        commit(d, "test: drop");
    });
    assert_eq!(run(&deleted, TEST, "tests/*", &deleted.base).0, "none");
    let new_test = clone(|d| {
        write(d, "tests/shout_test.sh", "exit 1\n");
        commit(d, "test: x");
    });
    assert_eq!(run(&new_test, TEST, "", &new_test.base).0, "none");
    assert_eq!(run(&new_test, "", "tests/*", &new_test.base).0, "none");
    assert_eq!(run(&new_test, TEST, "spec/*", &new_test.base).0, "none");
    let no_commits = clone(|_| {});
    assert_eq!(
        run(&no_commits, TEST, "tests/*", &no_commits.base).0,
        "none"
    );
}

#[test]
fn a_test_in_any_of_two_globs_counts() {
    let c = clone(|d| {
        write(d, "spec/a_spec.sh", "exit 1\n");
        commit(d, "test: spec");
    });
    assert_eq!(
        run(&c, "sh spec/a_spec.sh", "tests/*,spec/*", &c.base).0,
        "red"
    );
}

#[test]
fn a_base_that_does_not_exist_is_an_error() {
    let c = clone(|d| {
        write(d, "tests/shout_test.sh", "exit 1\n");
        commit(d, "test: x");
    });
    let (state, _) = run(
        &c,
        TEST,
        "tests/*",
        "0000000000000000000000000000000000000000",
    );
    assert_eq!(state, "error");
}

#[test]
fn the_bundle_holds_the_commits_and_runs_no_hook_of_a_planted_global_config() {
    let c = clone(|d| {
        write(d, "bin/greet", "echo hello\n");
        commit(d, "feat: hello");
    });
    // the rounds run as the runner's user and can write its global git config; git honours
    // uploadpack.packObjectsHook there (not in the repository's config), and the fetch that makes
    // the bundle would run it. Without GIT_CONFIG_GLOBAL=/dev/null in the CLI this test fails.
    let marker = c.dir.join("../hook-ran");
    let evil = c.dir.join("../evil.gitconfig");
    std::fs::write(
        &evil,
        format!(
            "[uploadpack]\n\tpackObjectsHook = \"touch {}; \"\n",
            marker.display()
        ),
    )
    .unwrap();
    let work = tempfile::tempdir().unwrap();
    let out = Command::new(env!("CARGO_BIN_EXE_wf"))
        .current_dir(&c.dir)
        .args(["executor", "decide", "--base", &c.base, "--work-dir"])
        .arg(work.path())
        .arg("--github-output")
        .arg(work.path().join("output"))
        .env("GIT_CONFIG_GLOBAL", &evil)
        .env("R1_OUTCOME", "done")
        .env("R1_VERDICT", "pass")
        .env("R1_FINDINGS", "/f")
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert!(!marker.exists(), "a hook of a planted global config ran");
    let bundle = work.path().join("bundle/publish.bundle");
    let heads = Command::new("git")
        .args(["bundle", "list-heads"])
        .arg(&bundle)
        .output()
        .unwrap();
    let heads = String::from_utf8_lossy(&heads.stdout);
    assert!(
        heads.contains(&git(&c.dir, &["rev-parse", "HEAD"])) && heads.contains("refs/push/head"),
        "{heads}"
    );
}

#[test]
fn decide_counts_the_commits_ahead_and_bundles_only_for_a_pull_request_or_draft() {
    let c = clone(|d| {
        write(d, "bin/greet", "echo hello\n");
        commit(d, "feat: hello");
    });
    let round = |o: &str, v: &str| decide::Round {
        outcome: o.into(),
        verdict: v.into(),
        findings: "/f".into(),
    };
    for (rounds, action) in [
        (vec![round("done", "pass")], "pr"),
        (vec![round("blocked", "none")], "comment"),
    ] {
        let work = tempfile::tempdir().unwrap();
        let out = work.path().join("output");
        assert!(decide::run(&c.dir, work.path(), &c.base, &rounds, &out).unwrap());
        let text = std::fs::read_to_string(&out).unwrap();
        assert!(text.contains(&format!("action={action}\n")), "{text}");
        assert!(text.contains("ahead=1\n"), "{text}");
        assert_eq!(
            work.path().join("bundle/publish.bundle").exists(),
            action != "comment"
        );
    }
}
