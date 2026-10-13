//! The backlog planner's input against a stub `gh` (tests/bin/gh). The answers start from real
//! responses of becloud-dev/workflows recorded on 2026-10-13 (tests/fixtures/gh-recorded: the open
//! issues, #69's sub-issues, #16's empty blocked-by list, #69 itself). The recorded issues have no
//! open parent and no dependency, so `scenario` derives those cases in code from the recorded
//! objects, and each change is named there.

use becloud_workflows::github::Gh;
use becloud_workflows::planner::backlog::{self, Ref};
use serde_json::{Value, json};
use std::path::Path;

const RECORDED: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/gh-recorded");
const STUB: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/bin/gh");
const REPO: &str = "becloud-dev/workflows";

fn recorded(name: &str) -> Value {
    serde_json::from_slice(&std::fs::read(Path::new(RECORDED).join(name)).unwrap()).unwrap()
}

fn find(issues: &[Value], number: u64) -> Value {
    issues
        .iter()
        .find(|i| i["number"] == number)
        .unwrap()
        .clone()
}

struct Stub {
    dir: tempfile::TempDir,
}

impl Stub {
    /// `answers`: API path and the list of items it returns, served as one page.
    fn new(answers: &[(String, Vec<Value>)]) -> Self {
        let dir = tempfile::tempdir().unwrap();
        std::fs::copy(STUB, dir.path().join("gh")).unwrap();
        for (path, items) in answers {
            let key: String = path
                .chars()
                .map(|c| if "/?&=".contains(c) { '_' } else { c })
                .collect();
            let pages = json!([items]);
            std::fs::write(dir.path().join(format!("{key}.json")), pages.to_string()).unwrap();
        }
        Stub { dir }
    }

    fn gh(&self) -> Gh {
        Gh {
            program: self.dir.path().join("gh"),
        }
    }

    fn calls(&self) -> Vec<String> {
        std::fs::read_to_string(self.dir.path().join("calls.log"))
            .unwrap_or_default()
            .lines()
            .map(String::from)
            .collect()
    }
}

fn list_path() -> String {
    format!("repos/{REPO}/issues?state=open&per_page=100")
}

fn rel_path(number: u64, kind: &str) -> String {
    format!("repos/{REPO}/issues/{number}/{kind}?per_page=100")
}

/// The recorded open issues, changed as follows:
/// - #69 is reopened (its recorded object, `state` open): a parent with 4 open sub-issues (63, 65,
///   56, 59) of the 6 recorded;
/// - #59 (Medium) is blocked by #57 (Medium), and #63 (High) by #56 (Medium);
/// - #82 is a pull request, #79 has a milestone and #54 the `needs-info` label: all three leave;
/// - #21 has no type and #20 no priority.
fn scenario() -> Vec<(String, Vec<Value>)> {
    let mut issues: Vec<Value> = recorded("issues-open.json")[0].as_array().unwrap().clone();
    let mut parent = recorded("issue-69.json");
    parent["state"] = json!("open");
    issues.push(parent);
    for i in issues.iter_mut() {
        match i["number"].as_u64().unwrap() {
            82 => {
                i["pull_request"] =
                    json!({"url": "https://api.github.com/repos/becloud-dev/workflows/pulls/82"})
            }
            79 => i["milestone"] = json!({"title": "R1: CLI"}),
            54 => i["labels"] = json!([{"name": "needs-info"}]),
            21 => i["type"] = Value::Null,
            20 => i["issue_field_values"] = json!([]),
            59 | 63 => i["issue_dependencies_summary"]["total_blocked_by"] = json!(1),
            57 | 56 => i["issue_dependencies_summary"]["total_blocking"] = json!(1),
            _ => {}
        }
    }
    let sub_issues = recorded("sub-issues-69.json")[0]
        .as_array()
        .unwrap()
        .clone();
    let open = |n: u64| -> Value {
        let mut i = find(&issues, n);
        i["state"] = json!("open");
        i
    };
    vec![
        (rel_path(69, "sub_issues"), sub_issues),
        (rel_path(59, "dependencies/blocked_by"), vec![open(57)]),
        (rel_path(57, "dependencies/blocking"), vec![open(59)]),
        (rel_path(63, "dependencies/blocked_by"), vec![open(56)]),
        (rel_path(56, "dependencies/blocking"), vec![open(63)]),
        (list_path(), issues),
    ]
}

fn numbers(issues: &[backlog::Issue]) -> Vec<u64> {
    issues.iter().map(|i| i.number).collect()
}

fn r(number: u64) -> Ref {
    Ref {
        repo: REPO.into(),
        number,
    }
}

#[test]
fn the_recorded_issues_build_as_they_are() {
    let stub = Stub::new(&[(
        list_path(),
        recorded("issues-open.json")[0].as_array().unwrap().clone(),
    )]);
    let input = backlog::fetch(&stub.gh(), REPO).unwrap();
    assert_eq!(input.total, 15);
    assert_eq!(
        numbers(&input.issues)[0..3],
        [53, 63, 65],
        "High first, oldest first"
    );
    assert!(input.parents.is_empty() && input.unprioritised.is_empty());
    assert_eq!(input.issues[0].parent, Some(r(68)));
    assert!(input.no_type.is_empty());
    // Nothing has sub-issues or dependencies: the list is the only call.
    assert_eq!(stub.calls().len(), 1);
}

#[test]
fn a_parent_with_open_sub_issues_is_listed_with_them_not_ranked() {
    let stub = Stub::new(&scenario());
    let input = backlog::fetch(&stub.gh(), REPO).unwrap();
    assert_eq!(numbers(&input.parents), [69]);
    assert_eq!(
        input.parents[0].open_sub_issues,
        [r(63), r(65), r(56), r(59)],
        "the 2 closed sub-issues (#46, #52) are left out"
    );
    assert!(!numbers(&input.issues).contains(&69));
}

#[test]
fn open_dependencies_are_read_for_the_issues_that_have_them() {
    let stub = Stub::new(&scenario());
    let input = backlog::fetch(&stub.gh(), REPO).unwrap();
    let get = |n: u64| input.issues.iter().find(|i| i.number == n).unwrap();
    assert_eq!(get(59).blocked_by, [r(57)]);
    assert_eq!(get(57).blocking, [r(59)]);
    assert_eq!(get(63).blocked_by, [r(56)]);
    assert!(get(65).blocked_by.is_empty());
    // The list, #69's sub-issues and four dependency lists; nothing for the issues without any.
    assert_eq!(stub.calls().len(), 6, "{:?}", stub.calls());
}

#[test]
fn pull_requests_milestones_and_needs_info_leave_the_input() {
    let stub = Stub::new(&scenario());
    let input = backlog::fetch(&stub.gh(), REPO).unwrap();
    let all: Vec<u64> = [&input.issues, &input.parents, &input.unprioritised]
        .iter()
        .flat_map(|l| numbers(l))
        .collect();
    for gone in [82, 79, 54] {
        assert!(!all.contains(&gone), "#{gone} is still in the input");
    }
    assert_eq!(input.total, 13, "15 recorded + #69 - 3 filtered");
}

#[test]
fn no_type_and_no_priority_are_computed() {
    let stub = Stub::new(&scenario());
    let input = backlog::fetch(&stub.gh(), REPO).unwrap();
    assert_eq!(input.no_type, [21]);
    assert_eq!(numbers(&input.unprioritised), [20]);
}

#[test]
fn a_failed_api_call_names_its_path() {
    let mut answers = scenario();
    answers.retain(|(p, _)| !p.contains("/sub_issues"));
    let stub = Stub::new(&answers);
    let err = backlog::fetch(&stub.gh(), REPO).unwrap_err().to_string();
    assert!(err.contains("issues/69/sub_issues"), "{err}");
    assert!(err.contains("HTTP 404"), "{err}");
}
