//! The backlog planner's input against the stub `gh`, from the recorded responses and the derived
//! [`common::scenario`].

mod common;

use becloud_workflows::planner::backlog::{self, Ref};
use common::{REPO, Stubs, list_path, recorded_issues, scenario};

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
    let stubs = Stubs::new().gh_answers(&[(list_path(), recorded_issues())]);
    let input = backlog::fetch(&stubs.gh(), REPO).unwrap();
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
    assert_eq!(stubs.gh_calls().len(), 1);
}

#[test]
fn a_parent_with_open_sub_issues_is_listed_with_them_not_ranked() {
    let stubs = Stubs::new().gh_answers(&scenario());
    let input = backlog::fetch(&stubs.gh(), REPO).unwrap();
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
    let stubs = Stubs::new().gh_answers(&scenario());
    let input = backlog::fetch(&stubs.gh(), REPO).unwrap();
    let get = |n: u64| input.issues.iter().find(|i| i.number == n).unwrap();
    assert_eq!(get(59).blocked_by, [r(57)]);
    assert_eq!(get(57).blocking, [r(59)]);
    assert_eq!(get(63).blocked_by, [r(56)]);
    assert!(get(65).blocked_by.is_empty());
    // The list, #69's sub-issues and four dependency lists; nothing for the issues without any.
    assert_eq!(stubs.gh_calls().len(), 6, "{:?}", stubs.gh_calls());
}

#[test]
fn pull_requests_milestones_and_needs_info_leave_the_input() {
    let stubs = Stubs::new().gh_answers(&scenario());
    let input = backlog::fetch(&stubs.gh(), REPO).unwrap();
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
    let stubs = Stubs::new().gh_answers(&scenario());
    let input = backlog::fetch(&stubs.gh(), REPO).unwrap();
    assert_eq!(input.no_type, [21]);
    assert_eq!(numbers(&input.unprioritised), [20]);
}

#[test]
fn a_failed_api_call_names_its_path() {
    let mut answers = scenario();
    answers.retain(|(p, _)| !p.contains("/sub_issues"));
    let stubs = Stubs::new().gh_answers(&answers);
    let err = backlog::fetch(&stubs.gh(), REPO).unwrap_err().to_string();
    assert!(err.contains("issues/69/sub_issues"), "{err}");
    assert!(err.contains("HTTP 404"), "{err}");
}
