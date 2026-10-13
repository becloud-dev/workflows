//! The rules the CLI enforces on the two calls' outputs (review of #74). Each broken rule is one
//! sentence naming the issues, so the retry prompt and the failure say exactly what to fix.

use super::input::{Input, Issue, tier};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::{BTreeMap, HashMap, HashSet};

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct Ranked {
    pub number: u64,
    pub reason: String,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Order {
    pub order: Vec<Ranked>,
    pub summary: String,
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct Duplicate {
    pub number: u64,
    pub duplicate_of: u64,
    pub evidence: String,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Duplicates {
    pub duplicates: Vec<Duplicate>,
}

/// A blocker the order cannot honour: in a lower tier than the issue it blocks, or not ranked.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Conflict {
    pub issue: u64,
    pub blocker: String,
    pub why: String,
}

fn priority(i: &Issue) -> &str {
    i.priority.as_deref().unwrap_or("none")
}

/// The order covers the ranked set, each issue once; no parent with open sub-issues is ranked
/// (a); tiers never go up; inside a tier a blocker comes before the issue it blocks (b).
pub fn order_rules(input: &Input, output: &Value) -> Vec<String> {
    let Ok(order) = serde_json::from_value::<Order>(output.clone()) else {
        return vec!["the output does not have the shape of an order".into()];
    };
    let ranked: HashMap<u64, &Issue> = input.issues.iter().map(|i| (i.number, i)).collect();
    let parents: HashSet<u64> = input.parents.iter().map(|i| i.number).collect();
    let mut broken = Vec::new();

    let mut count: BTreeMap<u64, usize> = BTreeMap::new();
    for r in &order.order {
        *count.entry(r.number).or_default() += 1;
    }
    for (&n, &c) in &count {
        if parents.contains(&n) {
            broken.push(format!(
                "#{n} has open sub-issues, so it is not ranked as work; leave it out of the order"
            ));
        } else if !ranked.contains_key(&n) {
            broken.push(format!(
                "#{n} is not in the ranked set; leave it out of the order"
            ));
        } else if c > 1 {
            broken.push(format!(
                "#{n} appears {c} times; each issue appears exactly once"
            ));
        }
    }
    for i in &input.issues {
        if !count.contains_key(&i.number) {
            broken.push(format!("#{} is missing from the order", i.number));
        }
    }

    let placed: Vec<&Issue> = order
        .order
        .iter()
        .filter_map(|r| ranked.get(&r.number).copied())
        .collect();
    for pair in placed.windows(2) {
        let (a, b) = (pair[0], pair[1]);
        if tier(a.priority.as_deref()) > tier(b.priority.as_deref()) {
            broken.push(format!(
                "#{} ({}) is ranked before #{} ({}); the tiers keep the order Urgent, High, Medium, Low",
                a.number,
                priority(a),
                b.number,
                priority(b)
            ));
        }
    }

    let position: HashMap<u64, usize> = order
        .order
        .iter()
        .enumerate()
        .map(|(p, r)| (r.number, p))
        .rev()
        .collect();
    for i in &input.issues {
        for b in i.blocked_by.iter().filter(|b| b.repo == input.repo) {
            let Some(blocker) = ranked.get(&b.number) else {
                continue;
            };
            if blocker.priority != i.priority {
                continue;
            }
            if let (Some(pi), Some(pb)) = (position.get(&i.number), position.get(&b.number))
                && pi < pb
            {
                broken.push(format!(
                    "#{} is ranked before #{}, which blocks it; in one tier a blocker comes first",
                    i.number, b.number
                ));
            }
        }
    }
    broken
}

/// Every issue a duplicate names is in the input, and no issue duplicates itself (c).
pub fn duplicate_rules(input: &Input, output: &Value) -> Vec<String> {
    let Ok(dups) = serde_json::from_value::<Duplicates>(output.clone()) else {
        return vec!["the output does not have the shape of a duplicate list".into()];
    };
    let known: HashSet<u64> = all_issues(input).map(|i| i.number).collect();
    let mut broken = Vec::new();
    for d in &dups.duplicates {
        for n in [d.number, d.duplicate_of] {
            if !known.contains(&n) {
                broken.push(format!("#{n} is not in the input; name only issues in it"));
            }
        }
        if d.number == d.duplicate_of {
            broken.push(format!("#{} is named as a duplicate of itself", d.number));
        }
    }
    broken.dedup();
    broken
}

/// Blockers the order does not move: a blocker in a lower tier (the tiers are triage's), or one
/// outside the ranked set (a parent, unprioritised, filtered, closed later or in another repo).
pub fn conflicts(input: &Input) -> Vec<Conflict> {
    let ranked: HashMap<u64, &Issue> = input.issues.iter().map(|i| (i.number, i)).collect();
    let mut out = Vec::new();
    for i in &input.issues {
        for b in &i.blocked_by {
            let name = if b.repo == input.repo {
                format!("#{}", b.number)
            } else {
                format!("{}#{}", b.repo, b.number)
            };
            let why = match ranked.get(&b.number).filter(|_| b.repo == input.repo) {
                Some(blocker)
                    if tier(blocker.priority.as_deref()) > tier(i.priority.as_deref()) =>
                {
                    format!(
                        "the blocker is {} and the issue {}; the tiers are triage's, not reordered",
                        priority(blocker),
                        priority(i)
                    )
                }
                Some(_) => continue,
                None => "the blocker is not in the ranked set".to_string(),
            };
            out.push(Conflict {
                issue: i.number,
                blocker: name,
                why,
            });
        }
    }
    out
}

/// The ranked issues, then the parents, then the unprioritised ones.
pub fn all_issues(input: &Input) -> impl Iterator<Item = &Issue> {
    input
        .issues
        .iter()
        .chain(&input.parents)
        .chain(&input.unprioritised)
}

#[cfg(test)]
mod tests {
    use super::super::input::Ref;
    use super::*;
    use serde_json::json;

    fn issue(number: u64, priority: &str, blocked_by: &[u64]) -> Issue {
        Issue {
            number,
            title: format!("issue {number}"),
            created_at: String::new(),
            kind: Some("Task".into()),
            priority: Some(priority.into()),
            labels: vec![],
            parent: None,
            open_sub_issues: vec![],
            blocked_by: blocked_by
                .iter()
                .map(|&n| Ref {
                    repo: "o/r".into(),
                    number: n,
                })
                .collect(),
            blocking: vec![],
            body: String::new(),
        }
    }

    fn input(issues: Vec<Issue>, parents: Vec<Issue>) -> Input {
        Input {
            repo: "o/r".into(),
            total: issues.len() + parents.len(),
            truncated: false,
            issues,
            parents,
            unprioritised: vec![],
            no_type: vec![],
        }
    }

    fn order(numbers: &[u64]) -> Value {
        json!({
            "order": numbers.iter().map(|n| json!({"number": n, "reason": "r"})).collect::<Vec<_>>(),
            "summary": "s"
        })
    }

    fn base() -> Input {
        input(
            vec![
                issue(1, "High", &[]),
                issue(2, "Medium", &[]),
                issue(3, "Medium", &[2]),
                issue(4, "Low", &[]),
            ],
            vec![issue(9, "Medium", &[])],
        )
    }

    #[test]
    fn a_valid_order_breaks_no_rule() {
        assert!(order_rules(&base(), &order(&[1, 2, 3, 4])).is_empty());
    }

    #[test]
    fn coverage_names_missing_repeated_and_unknown_issues() {
        let broken = order_rules(&base(), &order(&[1, 2, 2, 3, 7]));
        assert_eq!(
            broken,
            [
                "#2 appears 2 times; each issue appears exactly once",
                "#7 is not in the ranked set; leave it out of the order",
                "#4 is missing from the order",
            ]
        );
    }

    #[test]
    fn a_parent_with_open_sub_issues_is_not_ranked() {
        let broken = order_rules(&base(), &order(&[1, 2, 3, 9, 4]));
        assert_eq!(
            broken,
            ["#9 has open sub-issues, so it is not ranked as work; leave it out of the order"]
        );
    }

    #[test]
    fn tiers_never_go_up() {
        let broken = order_rules(&base(), &order(&[2, 1, 3, 4]));
        assert_eq!(
            broken,
            [
                "#2 (Medium) is ranked before #1 (High); the tiers keep the order Urgent, High, Medium, Low"
            ]
        );
    }

    #[test]
    fn in_one_tier_a_blocker_comes_first() {
        let broken = order_rules(&base(), &order(&[1, 3, 2, 4]));
        assert_eq!(
            broken,
            ["#3 is ranked before #2, which blocks it; in one tier a blocker comes first"]
        );
    }

    #[test]
    fn a_blocker_in_a_lower_tier_is_a_conflict_not_a_rule() {
        let mut i = base();
        i.issues[0] = issue(1, "High", &[2]);
        assert!(order_rules(&i, &order(&[1, 2, 3, 4])).is_empty());
        let c = conflicts(&i);
        assert_eq!(c.len(), 1);
        assert_eq!((c[0].issue, c[0].blocker.as_str()), (1, "#2"));
        assert!(c[0].why.contains("Medium and the issue High"));
    }

    #[test]
    fn a_blocker_outside_the_ranked_set_is_named() {
        let mut i = base();
        i.issues[3] = issue(4, "Low", &[9]);
        let c = conflicts(&i);
        assert_eq!(c[0].issue, 4);
        assert_eq!(c[0].why, "the blocker is not in the ranked set");
    }

    #[test]
    fn duplicates_name_only_issues_in_the_input() {
        let out = json!({"duplicates": [
            {"number": 3, "duplicate_of": 2, "evidence": "e"},
            {"number": 9, "duplicate_of": 70, "evidence": "e"},
            {"number": 4, "duplicate_of": 4, "evidence": "e"}
        ]});
        assert_eq!(
            duplicate_rules(&base(), &out),
            [
                "#70 is not in the input; name only issues in it",
                "#4 is named as a duplicate of itself",
            ]
        );
    }
}
