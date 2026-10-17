//! The scope check against real git history: the cases of the shell suite it replaces
//! (tests/dev-round-scope): deletions, renames and workflow changes against the plan Files list.

use becloud_workflows::executor::scope;
use std::path::Path;
use std::process::Command;
use std::sync::atomic::{AtomicUsize, Ordering};

static COUNTER: AtomicUsize = AtomicUsize::new(0);

struct Repo {
    dir: tempfile::TempDir,
    base: String,
}

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

impl Repo {
    /// A base commit holding `files`; the change is made by `change` and committed.
    fn new(files: &[&str], change: impl FnOnce(&Path)) -> Repo {
        let dir = tempfile::tempdir().unwrap();
        git(dir.path(), &["init", "-q", "-b", "main"]);
        for f in files {
            let p = dir.path().join(f);
            std::fs::create_dir_all(p.parent().unwrap()).unwrap();
            std::fs::write(p, format!("{f}\n")).unwrap();
        }
        git(dir.path(), &["add", "-A"]);
        git(dir.path(), &["commit", "-q", "-m", "base"]);
        let base = git(dir.path(), &["rev-parse", "HEAD"]);
        change(dir.path());
        git(dir.path(), &["add", "-A"]);
        git(
            dir.path(),
            &["commit", "-q", "--allow-empty", "-m", "change"],
        );
        Repo { dir, base }
    }

    /// Runs the check with `plan`; returns the outputs as (state, violations, kinds) and the section.
    fn check(&self, plan: &str) -> (String, String, String, String) {
        let n = COUNTER.fetch_add(1, Ordering::SeqCst);
        // inside the test's own directory: untracked, so it is not part of the diff
        let plan_file = self.dir.path().join(format!(".plan-{n}.md"));
        std::fs::write(&plan_file, plan).unwrap();
        self.run_with(&plan_file, &self.base)
    }

    fn run_with(&self, plan_file: &Path, base: &str) -> (String, String, String, String) {
        let tmp = tempfile::tempdir().unwrap();
        let results = tmp.path().join("results.md");
        let outputs = tmp.path().join("output");
        // the plan-Files cases use no test-writer boundary; the implementer-tests case calls
        // scope::run directly with one
        assert!(scope::run(self.dir.path(), base, plan_file, "", "", &results, &outputs).unwrap());
        let out = std::fs::read_to_string(outputs).unwrap();
        let get = |k: &str| {
            out.lines()
                .find_map(|l| l.strip_prefix(&format!("{k}=")))
                .unwrap()
                .to_string()
        };
        (
            get("scope_state"),
            get("scope_violations"),
            get("scope_violation_kinds"),
            std::fs::read_to_string(results).unwrap(),
        )
    }
}

fn rm(dir: &Path, p: &str) {
    std::fs::remove_file(dir.join(p)).unwrap();
}

fn put(dir: &Path, p: &str) {
    let path = dir.join(p);
    std::fs::create_dir_all(path.parent().unwrap()).unwrap();
    std::fs::write(path, "new\n").unwrap();
}

const HEAD: &str = "**Objective.** x\n**Files**\n";

#[test]
fn a_planned_deletion_is_ok_and_an_unnamed_one_is_out_of_scope() {
    let r = Repo::new(&["src/a.rs", "src/b.rs"], |d| {
        rm(d, "src/a.rs");
        rm(d, "src/b.rs");
    });
    let (state, v, k, text) = r.check(&format!("{HEAD}- `src/a.rs`\n"));
    assert_eq!(state, "out_of_scope");
    assert_eq!(v, r#"["src/b.rs"]"#);
    assert_eq!(k, r#"["deleted"]"#);
    assert!(text.contains("- src/b.rs"));
    let (state, v, _, _) = r.check(&format!("{HEAD}- `src/a.rs`\n- `src/b.rs`\n"));
    assert_eq!((state.as_str(), v.as_str()), ("ok", "[]"));
}

#[test]
fn a_directory_entry_covers_what_is_below_it_but_not_a_sibling_prefix() {
    let r = Repo::new(&["docs/a.md", "docs2/b.md"], |d| {
        rm(d, "docs/a.md");
        rm(d, "docs2/b.md");
    });
    let (state, v, _, _) = r.check(&format!("{HEAD}- `docs/`\n"));
    assert_eq!(state, "out_of_scope");
    assert_eq!(v, r#"["docs2/b.md"]"#);
    // an entry without the slash names exactly that file
    let (state, _, _, _) = r.check(&format!("{HEAD}- `docs`\n- `docs2`\n"));
    assert_eq!(state, "out_of_scope");
}

#[test]
fn a_rename_counts_as_a_deletion_of_the_old_path() {
    let r = Repo::new(&["src/old.rs"], |d| {
        std::fs::rename(d.join("src/old.rs"), d.join("src/new.rs")).unwrap();
    });
    let (state, v, _, _) = r.check(&format!("{HEAD}- `src/new.rs`\n"));
    assert_eq!(
        (state.as_str(), v.as_str()),
        ("out_of_scope", r#"["src/old.rs"]"#)
    );
    let (state, _, _, _) = r.check(&format!("{HEAD}- `src/old.rs`\n"));
    assert_eq!(state, "ok");
}

#[test]
fn a_workflow_added_or_modified_must_be_named_exactly() {
    let r = Repo::new(&[".github/workflows/ci.yml"], |d| {
        put(d, ".github/workflows/ci.yml");
        put(d, ".github/workflows/new.yml");
        put(d, "src/code.rs");
    });
    let (state, v, k, text) = r.check(&format!("{HEAD}- `.github/workflows/ci.yml`\n"));
    assert_eq!(state, "out_of_scope");
    assert_eq!(v, r#"[".github/workflows/new.yml"]"#);
    assert_eq!(k, r#"["changed"]"#);
    assert!(text.contains("changed under .github/workflows or .github/actions but not named"));
    // a glob is literal, a directory with its slash covers the files below it
    let (state, _, _, _) = r.check(&format!("{HEAD}- `.github/workflows/*`\n"));
    assert_eq!(state, "out_of_scope");
    let (state, _, _, _) = r.check(&format!("{HEAD}- `.github/workflows/`\n"));
    assert_eq!(state, "ok");
}

#[test]
fn a_local_action_added_or_modified_must_be_named_exactly() {
    // a pull_request run resolves a local action at the pull request's commit, with the secrets its
    // caller passes, so `.github/actions` is guarded as `.github/workflows` is (#53)
    let r = Repo::new(&[".github/actions/x/action.yml"], |d| {
        put(d, ".github/actions/x/action.yml");
        put(d, ".github/actions/y/action.yml");
        put(d, ".github/actions-notes/z.md");
    });
    let (state, v, k, text) = r.check(&format!("{HEAD}- `.github/actions/x/action.yml`\n"));
    assert_eq!(state, "out_of_scope");
    // a sibling directory that only shares the prefix is not guarded
    assert_eq!(v, r#"[".github/actions/y/action.yml"]"#);
    assert_eq!(k, r#"["changed"]"#);
    assert!(text.contains("- .github/actions/y/action.yml\n"));
    let (state, _, _, _) = r.check(&format!("{HEAD}- `.github/actions/`\n"));
    assert_eq!(state, "ok");
}

#[test]
fn names_with_spaces_survive_the_nul_separated_diff() {
    let r = Repo::new(&["my docs/a b.md"], |d| rm(d, "my docs/a b.md"));
    let (state, _, _, _) = r.check(&format!("{HEAD}- `my docs/a b.md`\n"));
    assert_eq!(state, "ok");
}

#[test]
fn a_plan_without_a_files_heading_or_a_bad_base_is_an_error() {
    let r = Repo::new(&["src/a.rs"], |d| rm(d, "src/a.rs"));
    let (state, _, _, text) = r.check("**Objective.** x\n- `src/a.rs`\n");
    assert_eq!(state, "error");
    assert!(text.contains(
        "the deletions, the workflow and action changes or the plan Files list could not be read"
    ));
    let plan = r.dir.path().join(".plan-bad-base.md");
    std::fs::write(&plan, format!("{HEAD}- `src/a.rs`\n")).unwrap();
    let (state, _, _, _) = r.run_with(&plan, "0000000000000000000000000000000000000000");
    assert_eq!(state, "error");
    let (state, _, _, _) = r.run_with(&r.dir.path().join("missing-plan.md"), &r.base);
    assert_eq!(state, "error");
}

#[test]
fn nothing_deleted_and_no_workflow_changed_is_none() {
    let r = Repo::new(&["src/a.rs"], |d| put(d, "src/b.rs"));
    let (state, v, _, _) = r.check(&format!("{HEAD}- `src/zzz.rs`\n"));
    assert_eq!((state.as_str(), v.as_str()), ("none", "[]"));
}

#[test]
fn a_test_file_the_implementer_changed_is_out_of_scope() {
    // base, then the test-writer's commit (TW_SHA), then the implementer's commit editing a test
    // file. Only the test-writer may touch the tests, so the change between TW_SHA and HEAD over the
    // test paths is a violation whether or not the plan names the file.
    let dir = tempfile::tempdir().unwrap();
    git(dir.path(), &["init", "-q", "-b", "main"]);
    put(dir.path(), "src/a.rs");
    put(dir.path(), "tests/a_test.sh");
    git(dir.path(), &["add", "-A"]);
    git(dir.path(), &["commit", "-q", "-m", "base"]);
    let base = git(dir.path(), &["rev-parse", "HEAD"]);
    // the test-writer adds a test
    std::fs::write(dir.path().join("tests/b_test.sh"), "exit 1\n").unwrap();
    git(dir.path(), &["add", "-A"]);
    git(dir.path(), &["commit", "-q", "-m", "test: b"]);
    let tw = git(dir.path(), &["rev-parse", "HEAD"]);
    // the implementer then edits a test file and the implementation
    std::fs::write(dir.path().join("tests/a_test.sh"), "changed\n").unwrap();
    std::fs::write(dir.path().join("src/a.rs"), "impl\n").unwrap();
    git(dir.path(), &["add", "-A"]);
    git(dir.path(), &["commit", "-q", "-m", "feat: a"]);

    let tmp = tempfile::tempdir().unwrap();
    let results = tmp.path().join("results.md");
    let outputs = tmp.path().join("output");
    let plan = tmp.path().join("plan.md");
    // the plan names every file, so only the test-touch rule can fail the round
    std::fs::write(
        &plan,
        format!("{HEAD}- `src/a.rs`\n- `tests/a_test.sh`\n- `tests/b_test.sh`\n"),
    )
    .unwrap();
    assert!(scope::run(dir.path(), &base, &plan, &tw, "tests/*", &results, &outputs).unwrap());
    let out = std::fs::read_to_string(&outputs).unwrap();
    assert!(out.contains("scope_state=out_of_scope"), "{out}");
    assert!(
        out.contains(r#"scope_violations=["tests/a_test.sh"]"#),
        "{out}"
    );
    assert!(out.contains(r#"scope_violation_kinds=["test"]"#), "{out}");
    let text = std::fs::read_to_string(&results).unwrap();
    assert!(
        text.contains(
            "a test file the implementer changed (only the test-writer may):\n- tests/a_test.sh\n"
        ),
        "{text}"
    );
}
