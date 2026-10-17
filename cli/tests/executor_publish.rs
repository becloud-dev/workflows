//! `wf executor publish-check` end to end against a real git directory holding the bundle's tip at
//! `refs/push/head`, with the pinned comment read through the stub `gh` (the forged-plan case of
//! #65: the rounds edit the comment after the gate pinned it).

mod common;

use becloud_workflows::executor::gate::sha256_hex;
use common::{REPO, Stubs};
use serde_json::{Value, json};
use std::path::Path;
use std::process::{Command, Output};

const PLAN: &str = "<!-- dev-plan -->\n**Files**\n- `src/a.rs`\n";

fn git(dir: &Path, args: &[&str]) -> String {
    let out = Command::new("git")
        .current_dir(dir)
        .args(["-c", "user.email=t@t", "-c", "user.name=t"])
        .args(args)
        .output()
        .unwrap();
    assert!(out.status.success(), "git {args:?}");
    String::from_utf8(out.stdout).unwrap().trim().to_string()
}

/// A repository whose `refs/push/head` deletes `deleted`; returns it with the base commit.
fn bundle(deleted: &str) -> (tempfile::TempDir, String) {
    let dir = tempfile::tempdir().unwrap();
    git(dir.path(), &["init", "-q", "-b", "main"]);
    for f in ["src/a.rs", "src/b.rs"] {
        let p = dir.path().join(f);
        std::fs::create_dir_all(p.parent().unwrap()).unwrap();
        std::fs::write(p, "x\n").unwrap();
    }
    git(dir.path(), &["add", "-A"]);
    git(dir.path(), &["commit", "-q", "-m", "base"]);
    let base = git(dir.path(), &["rev-parse", "HEAD"]);
    std::fs::remove_file(dir.path().join(deleted)).unwrap();
    git(dir.path(), &["add", "-A"]);
    git(dir.path(), &["commit", "-q", "-m", "change"]);
    git(dir.path(), &["update-ref", "refs/push/head", "HEAD"]);
    (dir, base)
}

/// A repository whose `refs/push/head` adds `added`; returns it with the base commit.
fn bundle_adding(added: &str) -> (tempfile::TempDir, String) {
    let dir = tempfile::tempdir().unwrap();
    git(dir.path(), &["init", "-q", "-b", "main"]);
    let a = dir.path().join("src/a.rs");
    std::fs::create_dir_all(a.parent().unwrap()).unwrap();
    std::fs::write(a, "x\n").unwrap();
    git(dir.path(), &["add", "-A"]);
    git(dir.path(), &["commit", "-q", "-m", "base"]);
    let base = git(dir.path(), &["rev-parse", "HEAD"]);
    let p = dir.path().join(added);
    std::fs::create_dir_all(p.parent().unwrap()).unwrap();
    std::fs::write(p, "x\n").unwrap();
    git(dir.path(), &["add", "-A"]);
    git(dir.path(), &["commit", "-q", "-m", "change"]);
    git(dir.path(), &["update-ref", "refs/push/head", "HEAD"]);
    (dir, base)
}

fn comment(body: &str) -> Value {
    json!({"id": 41, "user": {"login": "github-actions[bot]"}, "body": body,
           "issue_url": format!("https://api.github.com/repos/{REPO}/issues/13")})
}

fn run(dir: &Path, base: &str, body: &str, pinned: &str) -> Output {
    let stubs = Stubs::new().gh_object(&format!("repos/{REPO}/issues/comments/41"), &comment(body));
    let path = format!(
        "{}:{}",
        stubs.path().display(),
        std::env::var("PATH").unwrap()
    );
    Command::new(env!("CARGO_BIN_EXE_wf"))
        .args([
            "executor",
            "publish-check",
            "--repo",
            REPO,
            "--issue",
            "13",
            "--plan-comment-id",
            "41",
            "--plan-sha256",
            pinned,
            "--base",
            base,
            "--git-dir",
        ])
        .arg(dir.join(".git"))
        .arg("--github-output")
        .arg(dir.join("github-output"))
        .env_clear()
        .env("PATH", path)
        .output()
        .unwrap()
}

#[test]
fn the_approved_plan_naming_the_deletion_is_published() {
    let (dir, base) = bundle("src/a.rs");
    let out = run(dir.path(), &base, PLAN, &sha256_hex(PLAN));
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stdout)
    );
    // no workflow file changed, so the token is minted without the workflows permission
    assert_eq!(
        std::fs::read_to_string(dir.path().join("github-output")).unwrap(),
        "workflows=false\n"
    );
}

#[test]
fn a_deletion_the_plan_does_not_name_is_refused_with_its_path() {
    let (dir, base) = bundle("src/b.rs");
    let out = run(dir.path(), &base, PLAN, &sha256_hex(PLAN));
    assert!(!out.status.success());
    assert!(
        String::from_utf8_lossy(&out.stdout)
            .contains("::error::deleted but not named in the plan Files list: src/b.rs")
    );
}

#[test]
fn a_plan_edited_after_the_approval_is_refused_although_it_now_names_the_deletion() {
    let (dir, base) = bundle("src/b.rs");
    let edited = format!("{PLAN}- `src/b.rs`\n");
    // the gate pinned the hash of PLAN; the rounds then edited the comment to the text above
    let out = run(dir.path(), &base, &edited, &sha256_hex(PLAN));
    assert!(!out.status.success());
    assert!(
        String::from_utf8_lossy(&out.stdout)
            .contains("::error::the plan comment was changed after it was approved")
    );
}

#[test]
fn a_forged_plan_naming_an_unapproved_workflow_is_refused() {
    // The rounds job leaves a plan comment that names a workflow the owner never approved, and a
    // bundle that adds it. The gate pinned the hash of the approved plan (which named only src/a.rs),
    // so publish-check refuses on the pin before the bundle's workflow change is ever considered: the
    // forged-plan half of #65, which on v0 is published (tests/executor-fixtures/run.sh).
    let (dir, base) = bundle_adding(".github/workflows/evil.yml");
    let forged = format!("{PLAN}- `.github/workflows/evil.yml`\n");
    let out = run(dir.path(), &base, &forged, &sha256_hex(PLAN));
    assert!(!out.status.success());
    assert!(
        String::from_utf8_lossy(&out.stdout)
            .contains("::error::the plan comment was changed after it was approved")
    );
}

#[test]
fn a_local_action_the_plan_does_not_name_is_refused_with_its_path() {
    // a local action runs in the pull request's checks with the secrets its caller passes (#53)
    let (dir, base) = bundle_adding(".github/actions/x/action.yml");
    let out = run(dir.path(), &base, PLAN, &sha256_hex(PLAN));
    assert!(!out.status.success());
    assert!(String::from_utf8_lossy(&out.stdout).contains(
        "::error::changed under .github/actions but not named in the plan Files list: .github/actions/x/action.yml"
    ));
}

#[test]
fn a_named_local_action_is_published_without_the_workflows_permission() {
    let plan = format!("{PLAN}- `.github/actions/x/action.yml`\n");
    let (dir, base) = bundle_adding(".github/actions/x/action.yml");
    let out = run(dir.path(), &base, &plan, &sha256_hex(&plan));
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stdout)
    );
    // the permission covers `.github/workflows` only; a local action needs contents write alone
    assert_eq!(
        std::fs::read_to_string(dir.path().join("github-output")).unwrap(),
        "workflows=false\n"
    );
}
